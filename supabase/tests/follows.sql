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
select pg_temp.assert_true(not exists(select 1 from public.profiles where id='00000000-0000-0000-0000-000000000305'),'two partners away stays hidden');

-- Following: instant, circle only, and only you see who you follow.
select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000303","follow":true}',gen_random_uuid());
select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000303","follow":true}',gen_random_uuid());
select pg_temp.assert_true((select jsonb_array_length(public.snapshot()->'follows'))=1,'following twice keeps one follow');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000304","follow":true}',gen_random_uuid())$q$),'cannot follow a stranger');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000305","follow":true}',gen_random_uuid())$q$),'cannot follow outside the circle');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000301","follow":true}',gen_random_uuid())$q$),'cannot follow yourself');
select pg_temp.assert_true(pg_temp.fails($q$insert into public.follows values('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000302')$q$),'follows are written only through commands');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
select pg_temp.assert_true(not exists(select 1 from public.follows),'other people''s follows stay private');
select pg_temp.assert_true((select public.snapshot()->'circle')=jsonb_build_array(jsonb_build_object(
 'id','00000000-0000-0000-0000-000000000301','mutual',jsonb_build_array('00000000-0000-0000-0000-000000000302'))),'circles are mutual');

-- Unfollow
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000303","follow":false}',gen_random_uuid());
select pg_temp.assert_true((select jsonb_array_length(public.snapshot()->'follows'))=0,'unfollowing removes the follow');

-- Blocking removes follows both ways and takes the person out of your circle.
select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000303","follow":true}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
select public.command('block_user','{"user_id":"00000000-0000-0000-0000-000000000301"}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select pg_temp.assert_true((select jsonb_array_length(public.snapshot()->'follows'))=0,'a block removes the follow');
select pg_temp.assert_true((select jsonb_array_length(public.snapshot()->'circle'))=0,'a block leaves the circle');
select pg_temp.assert_true(not exists(select 1 from public.profiles where id='00000000-0000-0000-0000-000000000303'),'a blocker''s profile is hidden');

-- Account deletion removes follows.
reset role;
delete from public.blocks;
insert into public.follows values('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000303');
select public.erase_social_account('00000000-0000-0000-0000-000000000303');
select pg_temp.assert_true((select count(*)=0 from public.follows),'account deletion removes follows');
rollback;
