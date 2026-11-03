\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
-- 201 owner · 202 and 203 the owner's training partners · 204 a stranger with the link
insert into auth.users(id) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid from generate_series(201,204) i;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000201',true);
select public.command('save_profile','{"name":"Sarah"}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
select public.command('save_profile','{"name":"Dani"}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000203',true);
select public.command('save_profile','{"name":"Kenji"}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000204',true);
select public.command('save_profile','{"name":"Jordan"}',gen_random_uuid());
reset role;
insert into public.friendships(a,b,timezone) values
('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000202','UTC'),
('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000203','UTC');
select set_config('test.photo','00000000-0000-0000-0000-000000000201/'||repeat('a',64)||'.jpg',true);
set local role authenticated;

-- Uploads: only into your own folder, with the expected name.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
select pg_temp.assert_true(pg_temp.fails($q$insert into storage.objects(bucket_id,name) values('goal-media',current_setting('test.photo'))$q$),'cannot upload into someone else''s goal folder');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000201',true);
select pg_temp.assert_true(pg_temp.fails($q$insert into storage.objects(bucket_id,name) values('goal-media','00000000-0000-0000-0000-000000000201/photo.jpg')$q$),'goal photo names are checked');
insert into storage.objects(bucket_id,name) values('goal-media',current_setting('test.photo'));

-- Publishing
select pg_temp.assert_true(pg_temp.fails($q$select public.command('publish_goal',jsonb_build_object('client_id','g1','title','Single leg','photos',jsonb_build_array('00000000-0000-0000-0000-000000000201/'||repeat('b',64)||'.jpg')),gen_random_uuid())$q$),'photos must be uploaded first');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('publish_goal',jsonb_build_object('client_id','g1','title','Single leg','links',jsonb_build_array('javascript:alert(1)')),gen_random_uuid())$q$),'only web links');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('publish_goal',jsonb_build_object('client_id','g1','title','   '),gen_random_uuid())$q$),'a goal needs a name');
select public.command('publish_goal',jsonb_build_object('client_id','g1','title','Single leg','notes','Head on the hip',
 'links',jsonb_build_array('https://example.com/instructional'),
 'parts',jsonb_build_array(jsonb_build_object('id','p1','title','Run the pipe','notes','','link','https://www.youtube.com/watch?v=x','photos',jsonb_build_array(current_setting('test.photo'))))),
 gen_random_uuid())->>'id' as gid \gset
select set_config('test.goal',:'gid',true);
select public.command('publish_goal',jsonb_build_object('client_id','g1','title','Single leg finish','notes','Head on the hip',
 'parts',jsonb_build_array(jsonb_build_object('id','p1','title','Run the pipe','photos',jsonb_build_array(current_setting('test.photo'))))),gen_random_uuid());
select pg_temp.assert_true((select count(*)=1 and min(version)=2 and min(title)='Single leg finish' from public.shared_goals),'saving again updates the same shared copy');
select pg_temp.assert_true((select media=array[current_setting('test.photo')] from public.shared_goals),'part photos are tracked for access');

-- Sharing with friends
select pg_temp.assert_true(pg_temp.fails($q$select public.command('share_goal',jsonb_build_object('goal_id',current_setting('test.goal'),'recipients',jsonb_build_array('00000000-0000-0000-0000-000000000204')),gen_random_uuid())$q$),'direct shares are for training partners only');
select public.command('share_goal',jsonb_build_object('goal_id',:'gid','recipients',jsonb_build_array('00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000203')),gen_random_uuid());
select public.command('share_goal',jsonb_build_object('goal_id',:'gid','recipients',jsonb_build_array('00000000-0000-0000-0000-000000000202')),gen_random_uuid());
select pg_temp.assert_true((select count(*)=2 from public.goal_shares where status='pending'),'owner sees both pending invitations');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('share_goal',jsonb_build_object('goal_id',current_setting('test.goal'),'recipients',jsonb_build_array('00000000-0000-0000-0000-000000000201')),gen_random_uuid())$q$),'only the owner shares');
select pg_temp.assert_true((select count(*)=1 from public.notifications where kind='goal_share'),'one invitation alert even when shared twice');
select pg_temp.assert_true(jsonb_array_length(public.snapshot()->'shared_goals')=1,'a pending recipient can preview the goal');
select pg_temp.assert_true((select count(*)=1 from storage.objects where bucket_id='goal-media'),'and its photos');
select public.command('respond_goal_share',jsonb_build_object('goal_id',:'gid','accept',true),gen_random_uuid());
select pg_temp.assert_true((select status='accepted' from public.goal_shares where recipient=auth.uid()),'accepted');
select pg_temp.assert_true((select count(*)=0 from public.notifications where kind='goal_share' and read_at is null),'answering marks the alert read');

-- Declining and asking again
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000203',true);
select public.command('respond_goal_share',jsonb_build_object('goal_id',:'gid','accept',false),gen_random_uuid());
select pg_temp.assert_true((select count(*)=0 from public.shared_goals),'a declined goal disappears');
select pg_temp.assert_true((select count(*)=0 from storage.objects where bucket_id='goal-media'),'with its photos');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000201',true);
select public.command('share_goal',jsonb_build_object('goal_id',:'gid','recipients',jsonb_build_array('00000000-0000-0000-0000-000000000203')),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000203',true);
select pg_temp.assert_true((select count(*)=2 from public.notifications where kind='goal_share'),'sharing after a decline asks again');

-- Links for people who aren't training partners
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000204',true);
select pg_temp.assert_true((select count(*)=0 from public.shared_goals),'strangers see nothing');
select pg_temp.assert_true((select count(*)=0 from public.profiles where name='Sarah'),'or who owns it');
select pg_temp.assert_true((select count(*)=0 from storage.objects where bucket_id='goal-media'),'or its photos');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000201',true);
select public.command('goal_token',jsonb_build_object('goal_id',:'gid'),gen_random_uuid())->>'token' as tok \gset
select public.command('goal_token',jsonb_build_object('goal_id',:'gid'),gen_random_uuid())->>'token' as tok2 \gset
select set_config('test.token',:'tok',true);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000204',true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('redeem_friend',jsonb_build_object('token',current_setting('test.token')),gen_random_uuid())$q$),'a goal link is not a friend code');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('join_link',jsonb_build_object('token',current_setting('test.token')),gen_random_uuid())$q$),'or a session link');
select pg_temp.assert_true((select (public.command('redeem_goal_link',jsonb_build_object('token',:'tok'),gen_random_uuid())->>'id')=:'gid'),'opening the link');
select pg_temp.assert_true((select status='pending' and via='link' from public.goal_shares where recipient=auth.uid()),'creates a pending invitation');
select pg_temp.assert_true((select count(*)=1 from public.shared_goals),'that previews the goal');
select pg_temp.assert_true((select count(*)=1 from public.profiles where name='Sarah'),'and who sent it');
select pg_temp.assert_true((select count(*)=1 from storage.objects where bucket_id='goal-media'),'and its photos');
select pg_temp.assert_true((select count(*)=0 from public.goal_shares where recipient<>auth.uid()),'without revealing other recipients');
select public.command('respond_goal_share',jsonb_build_object('goal_id',:'gid','accept',false),gen_random_uuid());
select pg_temp.assert_true((select count(*)=0 from public.shared_goals),'declining hides it');
select public.command('redeem_goal_link',jsonb_build_object('token',:'tok2'),gen_random_uuid());
select pg_temp.assert_true((select status='pending' from public.goal_shares where recipient=auth.uid()),'an older link still works and asks again');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000201',true);
select pg_temp.assert_true((select own::boolean from (select public.command('redeem_goal_link',jsonb_build_object('token',:'tok'),gen_random_uuid())->>'own' as own) t),'the owner opening their own link');
select pg_temp.assert_true((select count(*)=0 from public.goal_shares where recipient=auth.uid()),'does not invite themselves');
select pg_temp.assert_true((select count(*)=1 from public.profiles where name='Jordan'),'the owner sees who opened the link');

-- Blocking hides the goal
reset role;
insert into public.blocks values('00000000-0000-0000-0000-000000000204','00000000-0000-0000-0000-000000000201');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000204',true);
select pg_temp.assert_true((select count(*)=0 from public.shared_goals),'blocked owners are hidden');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('respond_goal_share',jsonb_build_object('goal_id',current_setting('test.goal'),'accept',true),gen_random_uuid())$q$),'and cannot be accepted');
reset role;
delete from public.blocks;
set local role authenticated;

-- Stop sharing (the owner deleted the goal)
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000201',true);
select public.command('unshare_goal',jsonb_build_object('goal_id',:'gid'),gen_random_uuid());
select pg_temp.assert_true(pg_temp.fails($q$select public.command('goal_token',jsonb_build_object('goal_id',current_setting('test.goal')),gen_random_uuid())$q$),'a removed goal cannot be shared');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
select pg_temp.assert_true((select count(*)=0 from public.shared_goals),'removed for accepted recipients');
select pg_temp.assert_true((select count(*)=0 from storage.objects where bucket_id='goal-media'),'photos too');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000204',true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('redeem_goal_link',jsonb_build_object('token',current_setting('test.token')),gen_random_uuid())$q$),'links stop working');

reset role;
select public.erase_social_account('00000000-0000-0000-0000-000000000201');
select pg_temp.assert_true((select count(*)=0 from public.shared_goals)
 and (select count(*)=0 from public.goal_shares)
 and (select count(*)=0 from public.capabilities where kind='goal'),'account deletion removes shared goals');
rollback;
