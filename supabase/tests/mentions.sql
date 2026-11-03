\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
insert into auth.users values
 ('00000000-0000-0000-0000-000000000041'),('00000000-0000-0000-0000-000000000042'),
 ('00000000-0000-0000-0000-000000000043'),('00000000-0000-0000-0000-000000000044'),
 ('00000000-0000-0000-0000-000000000045'),('00000000-0000-0000-0000-000000000046');
insert into public.profiles(id,name,username) values
 ('00000000-0000-0000-0000-000000000041','Host','monkeyhost'),
 ('00000000-0000-0000-0000-000000000042','Hippo','hippo'),
 ('00000000-0000-0000-0000-000000000043','Stranger','outsider'),
 ('00000000-0000-0000-0000-000000000044','Blocked','blocked'),
 ('00000000-0000-0000-0000-000000000045','Quiet','quiet');
insert into public.profiles(id,name) values('00000000-0000-0000-0000-000000000046','Partner');
select pg_temp.assert_true((select username='member_00000000000000000000000000000046' from public.profiles where name='Partner'),'older clients receive a unique default username');
insert into public.account_settings(user_id,push_enabled) select id,username<>'quiet' from public.profiles;
insert into public.friendships(a,b,timezone) select '00000000-0000-0000-0000-000000000041',id,'UTC' from public.profiles where username in ('hippo','blocked','quiet') or name='Partner';
insert into public.blocks values('00000000-0000-0000-0000-000000000044','00000000-0000-0000-0000-000000000041');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000041',true);
select public.command('set_username','{"username":"  MonkeyHost  "}',gen_random_uuid());
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_username','{"username":"HIPPO"}',gen_random_uuid())$q$),'case-insensitive username uniqueness');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_username','{"username":"hi there"}',gen_random_uuid())$q$),'invalid username rejected');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_username','{"username":"ab"}',gen_random_uuid())$q$),'short username rejected');
select pg_temp.assert_true(not has_function_privilege('authenticated','public.emit_mentions(uuid,text,text,boolean)','execute'),'clients cannot emit arbitrary mentions');
select pg_temp.assert_true(not has_function_privilege('anon','public.mention_can_view(uuid,uuid)','execute'),'recipient access helper is private');
select public.command('create_session',jsonb_build_object('title','Rolls','venue','Gym','timezone','UTC','starts_at',now()-interval '1 hour','invited',jsonb_build_array('00000000-0000-0000-0000-000000000046')),gen_random_uuid())->>'id' as sid \gset
select public.command('manage_participant',jsonb_build_object('session_id',:'sid','user_id','00000000-0000-0000-0000-000000000046','remove',false),gen_random_uuid());
select gen_random_uuid() as publish_key \gset
select public.command('complete_and_publish',jsonb_build_object('session_id',:'sid','attendees',jsonb_build_array('00000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000046'),'caption','Great @HIPPO @hippo @outsider @blocked @quiet @monkeyhost hi@hippo.test @hippo_extra @missing @hippooooooooooooooooooooooooooooooooooooooooo'),:'publish_key')->>'id' as pid \gset
-- Lost-response retry returns the same result without repeating notifications.
select public.command('complete_and_publish',jsonb_build_object('session_id',:'sid','attendees',jsonb_build_array('00000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000046'),'caption','Great @HIPPO @hippo @outsider @blocked @quiet @monkeyhost hi@hippo.test @hippo_extra @missing @hippooooooooooooooooooooooooooooooooooooooooo'),:'publish_key');
reset role;
select pg_temp.assert_true((select count(*)=2 from public.notifications where kind='mention'),'only Hippo and Quiet receive caption mentions, once each');
select pg_temp.assert_true((select count(*)=2 from public.notification_outbox o join public.notifications n on o.id=n.id where n.kind='mention' and n.entity_id=:'pid'),'mentions enter the durable push queue with a post deep link');
select pg_temp.assert_true((select count(*)=1 from public.notifications where kind='mention' and recipient='00000000-0000-0000-0000-000000000045'),'push-disabled users retain in-app notifications');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000041',true);
select public.command('edit_post',jsonb_build_object('post_id',:'pid','version',1,'caption','Again @hippo'),gen_random_uuid());
select public.command('edit_post',jsonb_build_object('post_id',:'pid','version',2,'caption','Removed'),gen_random_uuid());
select public.command('edit_post',jsonb_build_object('post_id',:'pid','version',3,'caption','Back @hippo'),gen_random_uuid());
reset role;
select pg_temp.assert_true((select count(*)=2 from public.notifications where kind='mention'),'edits and removing/readding a tag do not re-notify');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000042',true);
select gen_random_uuid() as comment_key \gset
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','😀 (@MONKEYHOST), @monkeyhost! @quiet @outsider @hippo'),:'comment_key');
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','😀 (@MONKEYHOST), @monkeyhost! @quiet @outsider @hippo'),:'comment_key');
reset role;
select pg_temp.assert_true((select count(*)=1 from public.notifications where kind='mention' and recipient='00000000-0000-0000-0000-000000000041'),'comment mentions support emoji, punctuation, mixed case and retries');
select pg_temp.assert_true((select count(*)=0 from public.notifications where kind='comment'),'tagged post authors receive one mention instead of a duplicate comment alert');
select pg_temp.assert_true((select count(*)=4 from public.notifications where kind='mention'),'comment can mention another eligible reader');
-- Whole-token matching: email and longer username must not match the host.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000042',true);
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','a@monkeyhost.com @monkeyhost_extra @monkeyhost123456789012345678901234567890123456'),gen_random_uuid());
reset role;
select pg_temp.assert_true((select count(*)=4 from public.notifications where kind='mention'),'no partial handles or email addresses');
select pg_temp.assert_true((select count(*)=1 from public.notifications where kind='comment'),'ordinary comments still notify the author');
-- A third party's friend cannot mention them into content they cannot view.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000043',true);
select set_config('test.post',:'pid',true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('add_comment',jsonb_build_object('post_id',current_setting('test.post'),'body','@hippo'),gen_random_uuid())$q$),'strangers cannot create comments or mentions');
reset role;
-- An edit can introduce a new eligible recipient, and future profile saves
-- from older clients preserve the chosen username.
update public.profiles set username='partner' where id='00000000-0000-0000-0000-000000000046';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000041',true);
select public.command('save_profile','{"name":"Host renamed"}',gen_random_uuid());
select pg_temp.assert_true((select username='monkeyhost' from public.profiles where id=auth.uid()),'profile saves preserve usernames');
select public.command('edit_post',jsonb_build_object('post_id',:'pid','version',4,'caption','New tag @partner'),gen_random_uuid());
reset role;
select pg_temp.assert_true((select count(*)=1 from public.notifications where kind='mention' and entity_id=:'pid' and recipient='00000000-0000-0000-0000-000000000046'),'new tags in caption edits notify eligible readers');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000041',true);
select public.command('create_session',jsonb_build_object('title','Second rolls','venue','Gym','timezone','UTC','starts_at',now()-interval '1 hour','invited',jsonb_build_array('00000000-0000-0000-0000-000000000046')),gen_random_uuid())->>'id' as second_sid \gset
select public.command('manage_participant',jsonb_build_object('session_id',:'second_sid','user_id','00000000-0000-0000-0000-000000000046','remove',false),gen_random_uuid());
select public.command('complete_and_publish',jsonb_build_object('session_id',:'second_sid','attendees',jsonb_build_array('00000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000046'),'caption','Thanks @partner'),gen_random_uuid())->>'id' as second_pid \gset
reset role;
select pg_temp.assert_true((select count(*)=1 from public.notifications where entity_id=:'second_pid' and recipient='00000000-0000-0000-0000-000000000046'),'tagged attendees receive one mention instead of a second published alert');
select pg_temp.assert_true((select kind='mention' from public.notifications where entity_id=:'second_pid' and recipient='00000000-0000-0000-0000-000000000046'),'attendee alert is a mention');
rollback;
