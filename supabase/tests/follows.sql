\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
-- 301 Dani · 302 Sarah, Dani's training partner · 303 Rafa, Sarah's partner (Dani's circle)
-- 304 Jordan, a stranger · 305 Lena, Rafa's partner only (two partners away: outside Dani's circle)
insert into auth.users(id) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid from generate_series(301,305) i;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select public.command('save_profile','{"name":"Dani"}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000302',true);
select public.command('save_profile','{"name":"Sarah"}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
select public.command('save_profile','{"name":"Rafa"}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000304',true);
select public.command('save_profile','{"name":"Jordan"}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000305',true);
select public.command('save_profile','{"name":"Lena"}',gen_random_uuid());
reset role;
insert into public.friendships(a,b,timezone) values
('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000302','UTC'),
('00000000-0000-0000-0000-000000000302','00000000-0000-0000-0000-000000000303','UTC'),
('00000000-0000-0000-0000-000000000303','00000000-0000-0000-0000-000000000305','UTC');
set local role authenticated;

-- Suggestions: people who share a partner with you, never your partners, strangers or people further out.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select pg_temp.assert_true((select public.snapshot()->'circle')=jsonb_build_array(jsonb_build_object(
 'id','00000000-0000-0000-0000-000000000303','mutual',jsonb_build_array('00000000-0000-0000-0000-000000000302'))),'the circle is Rafa, through Sarah');
select pg_temp.assert_true(exists(select 1 from public.profiles where id='00000000-0000-0000-0000-000000000303'),'circle profiles are readable');
select pg_temp.assert_true(not exists(select 1 from public.profiles where id='00000000-0000-0000-0000-000000000304'),'strangers stay hidden');

-- Partner lists: anyone in your circle shows their full list, your own partners first.
select pg_temp.assert_true((select jsonb_agg(x->>'name') from jsonb_array_elements(public.partners_of('00000000-0000-0000-0000-000000000303')) x)='["Sarah","Lena"]'::jsonb,'Rafa''s partners, yours first');
select pg_temp.assert_true(exists(select 1 from public.profiles where id='00000000-0000-0000-0000-000000000305'),'partners on a visible list are readable');
select pg_temp.assert_true(public.partners_of('00000000-0000-0000-0000-000000000305') is null,'no list for people outside your circle');
select pg_temp.assert_true(public.partners_of('00000000-0000-0000-0000-000000000304') is null,'no list for strangers');
select pg_temp.assert_true(public.partners_of('00000000-0000-0000-0000-000000000302') is not null,'your partners'' lists are visible');
select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000305","follow":true}',gen_random_uuid());
select pg_temp.assert_true((select count(*)=1 from public.follows where followee='00000000-0000-0000-0000-000000000305'),'people on a visible partner list can be followed');
select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000305","follow":false}',gen_random_uuid());

-- Following: instant and mutual, discoverable people only.
select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000303","follow":true}',gen_random_uuid());
select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000303","follow":true}',gen_random_uuid());
select pg_temp.assert_true((select jsonb_array_length(public.snapshot()->'follows'))=1,'following twice keeps one follow');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000304","follow":true}',gen_random_uuid())$q$),'cannot follow a stranger');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000301","follow":true}',gen_random_uuid())$q$),'cannot follow yourself');
select pg_temp.assert_true(pg_temp.fails($q$insert into public.follows values('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000302')$q$),'follows are written only through commands');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
select pg_temp.assert_true((select count(*)=1 from public.follows where follower=auth.uid() and followee='00000000-0000-0000-0000-000000000301'),'the other partner follows you too');
select pg_temp.assert_true(not exists(select 1 from public.follows where follower<>auth.uid()),'only your own follow rows are readable');
select pg_temp.assert_true(public.are_friends(auth.uid(),'00000000-0000-0000-0000-000000000301'),'Follow creates a mutual training partnership');
select pg_temp.assert_true(not exists(select 1 from jsonb_array_elements(public.snapshot()->'circle') x where x->>'id'='00000000-0000-0000-0000-000000000301'),'partners leave suggestions');

-- Following exposes activity in both directions, without unlocking private sessions
-- or automatically sharing notes. Use posts with no other shared participants.
reset role;
insert into public.sessions(id,organizer,title,starts_at,timezone,venue) values
('10000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000301','Dani training',now()-interval '1 day','UTC','Gym'),
('10000000-0000-0000-0000-000000000303','00000000-0000-0000-0000-000000000303','Rafa training',now()-interval '1 day','UTC','Gym');
insert into public.posts(id,session_id,author,title,venue,occurred_at,caption)
select id,id,organizer,title,venue,starts_at,'Training memory' from public.sessions where id in ('10000000-0000-0000-0000-000000000301','10000000-0000-0000-0000-000000000303');
insert into public.post_participants(post_id,user_id) select id,author from public.posts;
set local role authenticated;
select pg_temp.assert_true(exists(select 1 from public.feed_page() where author='00000000-0000-0000-0000-000000000301'),'the followed person sees your activity');
select pg_temp.assert_true(not public.can_session('10000000-0000-0000-0000-000000000301'),'following keeps private session details locked');
select pg_temp.assert_true(not exists(select 1 from public.shared_goals),'following does not automatically share notes');
select public.command('publish_goal','{"client_id":"rafa-notes","title":"Rafa notes","notes":"Guard passing"}',gen_random_uuid())->>'id' as rafa_goal \gset
select public.command('share_goal',jsonb_build_object('goal_id',:'rafa_goal','recipients',jsonb_build_array('00000000-0000-0000-0000-000000000301')),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select pg_temp.assert_true(exists(select 1 from public.feed_page() where author='00000000-0000-0000-0000-000000000303'),'the follower sees the other partner activity');
select pg_temp.assert_true(exists(select 1 from public.shared_goals where id=:'rafa_goal'),'partners can share notes back to the follower');
select public.command('publish_goal','{"client_id":"dani-notes","title":"Dani notes","notes":"Half guard"}',gen_random_uuid())->>'id' as dani_goal \gset
select public.command('share_goal',jsonb_build_object('goal_id',:'dani_goal','recipients',jsonb_build_array('00000000-0000-0000-0000-000000000303')),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
select pg_temp.assert_true(exists(select 1 from public.shared_goals where id=:'dani_goal'),'the follower can share notes with their partner');
select pg_temp.assert_true(not has_function_privilege('authenticated','public.connect_training_partner(uuid,uuid)','EXECUTE'),'clients cannot bypass discovery or QR checks');
select pg_temp.assert_true(not has_function_privilege('anon','public.connect_training_partner(uuid,uuid)','EXECUTE'),'connection helper is private');

-- Unfollow
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000303","follow":false}',gen_random_uuid());
select pg_temp.assert_true((select jsonb_array_length(public.snapshot()->'follows'))=0,'unfollowing removes the follow');
select pg_temp.assert_true(not public.are_friends(auth.uid(),'00000000-0000-0000-0000-000000000303'),'unfollowing removes the training partnership');
select pg_temp.assert_true(not exists(select 1 from public.feed_page() where author='00000000-0000-0000-0000-000000000303'),'unfollowing revokes activity access');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
select pg_temp.assert_true(not exists(select 1 from public.follows),'unfollowing removes the reverse follow');
select pg_temp.assert_true(not exists(select 1 from public.feed_page() where author='00000000-0000-0000-0000-000000000301'),'the other partner also loses activity access');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);

-- Blocking removes follows both ways and takes the person out of your circle.
select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000303","follow":true}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
select public.command('block_user','{"user_id":"00000000-0000-0000-0000-000000000301"}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select pg_temp.assert_true((select jsonb_array_length(public.snapshot()->'follows'))=0,'a block removes the follow');
select pg_temp.assert_true((select jsonb_array_length(public.snapshot()->'circle'))=0,'a block leaves the circle');
select pg_temp.assert_true(not exists(select 1 from public.profiles where id='00000000-0000-0000-0000-000000000303'),'a blocker''s profile is hidden');
select pg_temp.assert_true(public.partners_of('00000000-0000-0000-0000-000000000303') is null,'a blocker''s list is hidden');
select pg_temp.assert_true(not exists(select 1 from public.profiles where id='00000000-0000-0000-0000-000000000305'),'and so are the partners only it listed');

-- Account deletion removes follows.
reset role;
delete from public.blocks;
insert into public.follows values('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000303');
select public.erase_social_account('00000000-0000-0000-0000-000000000303');
select pg_temp.assert_true((select count(*)=0 from public.follows),'account deletion removes follows');
rollback;
