\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
-- Check exact recipients and one durable push job per in-app alert for a comment.
create function pg_temp.recipients(cid uuid) returns uuid[] language sql as $$
 select coalesce(array_agg(n.recipient order by n.recipient),'{}'::uuid[])
 from public.notifications n join public.notification_outbox o on o.id=n.id
 where n.dedupe_key like cid::text||'%' and n.kind in ('comment','mention')
$$;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000101'),('00000000-0000-0000-0000-000000000102'),
 ('00000000-0000-0000-0000-000000000103'),('00000000-0000-0000-0000-000000000104'),
 ('00000000-0000-0000-0000-000000000105');
insert into public.profiles(id,name,username) values
 ('00000000-0000-0000-0000-000000000101','Host','threadhost'),
 ('00000000-0000-0000-0000-000000000102','Alice','threadalice'),
 ('00000000-0000-0000-0000-000000000103','Bob','threadbob'),
 ('00000000-0000-0000-0000-000000000104','Carol','threadcarol'),
 ('00000000-0000-0000-0000-000000000105','Reader','threadreader');
insert into public.account_settings(user_id) select id from public.profiles where username like 'thread%';
-- Each reader knows the host, but the commenters are not friends with each other.
insert into public.friendships(a,b,timezone) select '00000000-0000-0000-0000-000000000101',id,'UTC' from public.profiles where username like 'thread%' and username<>'threadhost';
insert into public.sessions(organizer,title,starts_at,timezone,venue,status)
 values('00000000-0000-0000-0000-000000000101','Thread test',now(),'UTC','Gym','completed') returning id as sid \gset
insert into public.posts(session_id,author,title,venue,occurred_at,caption)
 values(:'sid','00000000-0000-0000-0000-000000000101','Thread test','Gym',now(),'Good rolls') returning id as pid \gset
insert into public.post_participants(post_id,user_id) values(:'pid','00000000-0000-0000-0000-000000000101');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000102',true);
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','First'),gen_random_uuid());
select id as first_cid from public.comments where body='First' \gset
reset role;
select pg_temp.assert_true(pg_temp.recipients(:'first_cid')=array['00000000-0000-0000-0000-000000000101']::uuid[],'first comment notifies only the author, with a push');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000103',true);
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','Second'),gen_random_uuid());
select id as second_cid from public.comments where body='Second' \gset
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','Third'),gen_random_uuid());
select id as third_cid from public.comments where body='Third' \gset
reset role;
select pg_temp.assert_true(pg_temp.recipients(:'second_cid')=array['00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000102']::uuid[],'unrelated commenters notify earlier commenters, excluding self and readers');
select pg_temp.assert_true(pg_temp.recipients(:'third_cid')=pg_temp.recipients(:'second_cid'),'each new comment by the same person queues fresh notifications');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','Host reply'),gen_random_uuid());
select id as host_cid from public.comments where body='Host reply' \gset
reset role;
select pg_temp.assert_true(pg_temp.recipients(:'host_cid')=array['00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000103']::uuid[],'host replies notify all previous commenters only once');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000104',true);
select gen_random_uuid() as retry_key \gset
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','Hi @threadalice @threadhost'),:'retry_key');
select id as mention_cid from public.comments where author=auth.uid() \gset
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','Hi @threadalice @threadhost'),:'retry_key');
reset role;
select pg_temp.assert_true(pg_temp.recipients(:'mention_cid')=array['00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000103']::uuid[],'mentions and repeated participation produce one alert each, even on retry');
select pg_temp.assert_true((select count(*)=2 from public.notifications where dedupe_key like :'mention_cid'||'%' and kind='mention'),'mentioned author and commenter keep their mention alerts');
select pg_temp.assert_true((select count(*)=1 from public.comments where author='00000000-0000-0000-0000-000000000104'),'retry creates no extra comment');
select pg_temp.assert_true((select bool_and(entity_id=:'pid' and read_at is null) from public.notifications where dedupe_key like :'mention_cid'||'%'),'alerts are unread and link to the post');
-- A block between commenters excludes either direction without hiding the post.
insert into public.blocks values('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000104');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000104',true);
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','After block'),gen_random_uuid());
select id as blocked_cid from public.comments where body='After block' \gset
reset role;
select pg_temp.assert_true(pg_temp.recipients(:'blocked_cid')=array['00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000103']::uuid[],'blocked commenters receive neither in-app alerts nor push jobs');
update public.friendships set active=false where b='00000000-0000-0000-0000-000000000103';
set local role authenticated;
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','After access removed'),gen_random_uuid());
select id as inaccessible_cid from public.comments where body='After access removed' \gset
reset role;
select pg_temp.assert_true(pg_temp.recipients(:'inaccessible_cid')=array['00000000-0000-0000-0000-000000000101']::uuid[],'former readers receive no alerts after losing post access');
delete from public.blocks where actor='00000000-0000-0000-0000-000000000102';
update public.account_settings set push_enabled=false where user_id='00000000-0000-0000-0000-000000000102';
set local role authenticated;
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','Push off'),gen_random_uuid());
select id as quiet_cid from public.comments where body='Push off' \gset
reset role;
select pg_temp.assert_true(pg_temp.recipients(:'quiet_cid')=array['00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000102']::uuid[],'push-disabled commenters retain in-app notifications; worker applies preference');
-- Comments on a different post do not subscribe anyone to this thread.
insert into public.sessions(organizer,title,starts_at,timezone,venue,status)
 values('00000000-0000-0000-0000-000000000101','Other thread',now(),'UTC','Gym','completed') returning id as other_sid \gset
insert into public.posts(session_id,author,title,venue,occurred_at,caption)
 values(:'other_sid','00000000-0000-0000-0000-000000000101','Other thread','Gym',now(),'More rolls') returning id as other_pid \gset
insert into public.post_participants(post_id,user_id) values(:'other_pid','00000000-0000-0000-0000-000000000101');
set local role authenticated;
select public.command('add_comment',jsonb_build_object('post_id',:'other_pid','body','Different post'),gen_random_uuid());
select id as other_cid from public.comments where body='Different post' \gset
reset role;
select pg_temp.assert_true(pg_temp.recipients(:'other_cid')=array['00000000-0000-0000-0000-000000000101']::uuid[],'comment recipients are scoped to the same post');
select pg_temp.assert_true(not has_function_privilege('anon','public.command(text,jsonb,uuid)','execute') and has_function_privilege('authenticated','public.command(text,jsonb,uuid)','execute'),'migration preserves command permissions');
rollback;
