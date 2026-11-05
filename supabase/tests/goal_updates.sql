\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
create function pg_temp.updates() returns bigint language sql as $$ select count(*) from public.notifications where kind='goal_update' $$;
create function pg_temp.publish_patch(patch jsonb) returns jsonb language plpgsql as $$
declare payload jsonb := current_setting('test.goal_payload')::jsonb || patch;
begin
 perform set_config('test.goal_payload',payload::text,true);
 return public.command('publish_goal',payload,gen_random_uuid());
end $$;

-- Owner, accepted friend, accepted link recipient, pending, declined, stranger.
insert into auth.users(id) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid from generate_series(221,226) i;
insert into public.profiles(id,name) select id,'Goal member '||right(id::text,3) from auth.users
 where id between '00000000-0000-0000-0000-000000000221' and '00000000-0000-0000-0000-000000000226';
insert into public.friendships(a,b,timezone) select
 '00000000-0000-0000-0000-000000000221'::uuid,
 ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'UTC' from unnest(array[222,224,225]) i;
select set_config('test.goal_payload','{"client_id":"updates","title":"Single leg","notes":"","links":[],"photos":[],"parts":[]}',true);
select set_config('test.photo','00000000-0000-0000-0000-000000000221/'||repeat('a',64)||'.jpg',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000221',true);
insert into storage.objects(bucket_id,name) values('goal-media',current_setting('test.photo'));
select pg_temp.publish_patch('{}')->>'id' as gid \gset
select set_config('test.goal',:'gid',true);
select public.command('share_goal',jsonb_build_object('goal_id',:'gid','recipients',jsonb_build_array(
 '00000000-0000-0000-0000-000000000222','00000000-0000-0000-0000-000000000224','00000000-0000-0000-0000-000000000225')),gen_random_uuid());
select public.command('goal_token',jsonb_build_object('goal_id',:'gid'),gen_random_uuid())->>'token' as token \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000222',true);
select public.command('respond_goal_share',jsonb_build_object('goal_id',:'gid','accept',true),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000223',true);
select public.command('redeem_goal_link',jsonb_build_object('token',:'token'),gen_random_uuid());
select public.command('respond_goal_share',jsonb_build_object('goal_id',:'gid','accept',true),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000225',true);
select public.command('respond_goal_share',jsonb_build_object('goal_id',:'gid','accept',false),gen_random_uuid());
reset role;
select pg_temp.assert_true(pg_temp.updates()=0,'initial publishing, sharing and accepting do not create update alerts');

-- Actual saves notify both accepted recipients, including a non-friend via link.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000221',true);
select pg_temp.publish_patch('{"title":"Single leg finish"}');
reset role;
select pg_temp.assert_true(pg_temp.updates()=2,'one update per accepted recipient');
select pg_temp.assert_true((select count(*)=2 from public.notifications where kind='goal_update'
 and recipient in ('00000000-0000-0000-0000-000000000222','00000000-0000-0000-0000-000000000223')
 and actor='00000000-0000-0000-0000-000000000221' and entity_id=:'gid'
 and message='updated Single leg finish' and read_at is null),'correct recipient, actor, goal, text and unread state');
select pg_temp.assert_true((select count(*)=2 from public.notifications n join public.notification_outbox o using(id)
 where n.kind='goal_update' and o.delivered_at is null),'each in-app update also queues a push');

-- Retrying a publish and saving identical content with a fresh key stay quiet.
set local role authenticated;
select gen_random_uuid() as retry_key \gset
select public.command('publish_goal',current_setting('test.goal_payload')::jsonb,:'retry_key');
select public.command('publish_goal',current_setting('test.goal_payload')::jsonb,:'retry_key');
select pg_temp.publish_patch('{}');
reset role;
select pg_temp.assert_true(pg_temp.updates()=2,'unchanged saves and retries do not re-notify');
set local role authenticated;
select gen_random_uuid() as edit_key \gset
select set_config('test.goal_payload',(current_setting('test.goal_payload')::jsonb||'{"notes":"Head on the hip"}')::text,true);
select public.command('publish_goal',current_setting('test.goal_payload')::jsonb,:'edit_key');
select public.command('publish_goal',current_setting('test.goal_payload')::jsonb,:'edit_key');
reset role;
select pg_temp.assert_true(pg_temp.updates()=4,'a changed save notifies once even when retried');

-- Every shared content field, including nested part progress, triggers updates.
set local role authenticated;
select pg_temp.publish_patch('{"links":["https://example.com/video"]}');
select pg_temp.publish_patch(jsonb_build_object('photos',jsonb_build_array(current_setting('test.photo'))));
select pg_temp.publish_patch('{"parts":[{"id":"p1","title":"Run the pipe","done":false}]}');
select pg_temp.publish_patch('{"parts":[{"id":"p1","title":"Run the pipe","done":true}]}');
reset role;
select pg_temp.assert_true(pg_temp.updates()=12,'links, photos, parts and part completion all notify');
select pg_temp.assert_true((select count(*)=12 from public.notifications n join public.notification_outbox o using(id)
 where n.kind='goal_update'),'every update has exactly one push job');

-- Client isolation and authorization remain enforced.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000222',true);
select pg_temp.assert_true((select count(*)=6 from public.notifications where kind='goal_update'),'recipient sees only their updates');
select pg_temp.assert_true(jsonb_array_length(public.snapshot()->'notifications')>=6,'updates reach the app snapshot');
select pg_temp.assert_true(pg_temp.fails($q$update public.shared_goals set title='Changed by recipient' where id=current_setting('test.goal')::uuid$q$),'recipients cannot update the owner''s copy');
select pg_temp.assert_true(pg_temp.fails($q$select public.notify_goal_update()$q$),'clients cannot invoke the trigger helper');
select public.command('read_notifications','{}',gen_random_uuid());
select pg_temp.assert_true((select count(*)=0 from public.notifications where kind='goal_update' and read_at is null),'updates can be marked read normally');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000226',true);
select pg_temp.assert_true((select count(*)=0 from public.notifications),'strangers receive and see no updates');
reset role;
select pg_temp.assert_true(not has_function_privilege('anon','public.notify_goal_update()','execute')
 and not has_function_privilege('authenticated','public.notify_goal_update()','execute')
 and not has_function_privilege('service_role','public.notify_goal_update()','execute'),'trigger helper is private to all API roles');

-- Blocks in either direction suppress both in-app notifications and push jobs.
insert into public.blocks values
 ('00000000-0000-0000-0000-000000000221','00000000-0000-0000-0000-000000000222'),
 ('00000000-0000-0000-0000-000000000223','00000000-0000-0000-0000-000000000221');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000221',true);
select pg_temp.publish_patch('{"notes":"Blocked edit"}');
reset role;
select pg_temp.assert_true(pg_temp.updates()=12,'blocked recipients receive no update');
delete from public.blocks;

-- Removing an accepted goal stops updates; link recipients still get them.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000222',true);
select public.command('respond_goal_share',jsonb_build_object('goal_id',:'gid','accept',false),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000221',true);
select pg_temp.publish_patch('{"notes":"Only the link recipient remains"}');
reset role;
select pg_temp.assert_true(pg_temp.updates()=13,'removed recipients stop receiving updates');
select pg_temp.assert_true((select count(*)=7 from public.notifications where kind='goal_update'
 and recipient='00000000-0000-0000-0000-000000000223'),'remaining accepted recipient continues receiving updates');

-- Removing a goal does not send a misleading update or notify its owner.
set local role authenticated;
select public.command('unshare_goal',jsonb_build_object('goal_id',:'gid'),gen_random_uuid());
reset role;
select pg_temp.assert_true(pg_temp.updates()=13,'unsharing does not send update alerts');
select pg_temp.assert_true(not exists(select 1 from public.notifications where kind='goal_update'
 and recipient not in ('00000000-0000-0000-0000-000000000222','00000000-0000-0000-0000-000000000223')),
 'owner, pending, declined and unrelated people never receive updates');
rollback;
