\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_username(ok boolean,message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Username assertion failed: %',message; end if; end $$;
create function pg_temp.username_fails(statement text) returns boolean language plpgsql as $$
begin execute statement; return false; exception when others then return true; end $$;

insert into auth.users(id) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid from generate_series(901,930) i;
insert into public.profiles(id,name,username)
select id,'Same display name',case when right(id::text,3)='901' then 'lookup_me' else 'lookup_'||right(id::text,3) end
from auth.users where id between '00000000-0000-0000-0000-000000000901' and '00000000-0000-0000-0000-000000000930';
update public.profiles set username='lookupx903' where id='00000000-0000-0000-0000-000000000903';
insert into public.blocks values
('00000000-0000-0000-0000-000000000901','00000000-0000-0000-0000-000000000904'),
('00000000-0000-0000-0000-000000000905','00000000-0000-0000-0000-000000000901');
insert into public.sessions(id,organizer,title,starts_at,timezone,venue,status)
values('00000000-0000-0000-0000-000000000950','00000000-0000-0000-0000-000000000902','Training memory',now()-interval '1 day','UTC','Home gym','completed');
insert into public.posts(id,session_id,author,title,venue,occurred_at,caption)
values('00000000-0000-0000-0000-000000000951','00000000-0000-0000-0000-000000000950','00000000-0000-0000-0000-000000000902','Training memory','Home gym',now()-interval '1 day','Good rounds');
insert into public.post_participants values('00000000-0000-0000-0000-000000000951','00000000-0000-0000-0000-000000000902',true);

select pg_temp.assert_username(not has_function_privilege('anon','public.search_usernames(text)','EXECUTE'),'anonymous lookup is revoked');
select pg_temp.assert_username(not has_function_privilege('anon','private.search_usernames(text)','EXECUTE'),'anonymous helper access is revoked');
select pg_temp.assert_username(not (select prosecdef from pg_proc where oid='public.search_usernames(text)'::regprocedure),'public RPC runs as invoker');
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.assert_username(public.search_usernames('lookup')='[]','missing identity returns no results');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000901',true);
select pg_temp.assert_username(public.search_usernames(null)='[]' and public.search_usernames('')='[]'
 and public.search_usernames('@lo')='[]' and public.search_usernames('%')='[]'
 and public.search_usernames('look%')='[]' and public.search_usernames('@@lookup')='[]'
 and public.search_usernames(repeat('x',41))='[]','empty, short and malformed queries do not enumerate');
select pg_temp.assert_username(jsonb_array_length(public.search_usernames('lookup'))=20,'prefix matches are bounded');
select pg_temp.assert_username(public.search_usernames('  @LOOKUP_902  ')->0->>'username'='lookup_902','case, whitespace and @ normalize');
select pg_temp.assert_username(public.search_usernames('Same display name')='[]','global lookup never searches display names');
select pg_temp.assert_username(public.search_usernames('lookup_903')='[]','underscore is literal, not a wildcard');
select pg_temp.assert_username(public.search_usernames('lookup_me')='[]','self is omitted');
select pg_temp.assert_username(public.search_usernames('lookup_904')='[]' and public.search_usernames('lookup_905')='[]','blocks in either direction are omitted');
select pg_temp.assert_username((select array_agg(k order by k) from jsonb_object_keys(public.search_usernames('lookup_902')->0) k)
 =array['belt','gym','id','monkey','monkey_extras','name','stripes','username'],'lookup returns only minimal profile fields');
select pg_temp.assert_username(not exists(select 1 from public.profiles where id='00000000-0000-0000-0000-000000000902'),'lookup does not widen profile RLS');
select pg_temp.assert_username(not exists(select 1 from public.friendships) and not exists(select 1 from public.follows),'search has no connection side effects');
select pg_temp.assert_username(not public.can_post('00000000-0000-0000-0000-000000000951'),'search alone grants no activity access');

select public.command('follow_username','{"username":" @LOOKUP_902 ","user_id":"00000000-0000-0000-0000-000000000902"}','00000000-0000-0000-0000-000000000999');
select public.command('follow_username','{"username":" @LOOKUP_902 ","user_id":"00000000-0000-0000-0000-000000000902"}','00000000-0000-0000-0000-000000000999');
select public.command('follow_username','{"username":"lookup_902","user_id":"00000000-0000-0000-0000-000000000902"}',gen_random_uuid());
select pg_temp.assert_username((select jsonb_array_length(public.snapshot()->'follows'))=1,'follow persists and retries keep one edge');
select pg_temp.assert_username(public.can_post('00000000-0000-0000-0000-000000000951'),'username follow grants the same activity access as scanning');
select public.command('create_session','{"title":"Training invite","starts_at":"2099-01-01T18:00:00Z","timezone":"UTC","venue":"Home gym","invited":["00000000-0000-0000-0000-000000000902"]}',gen_random_uuid());
reset role;
select pg_temp.assert_username((select count(*)=1 from public.notifications where recipient='00000000-0000-0000-0000-000000000902' and kind='friend'),'same notification behavior as scanning, without duplicates');
select pg_temp.assert_username(exists(select 1 from public.follows where follower='00000000-0000-0000-0000-000000000902' and followee='00000000-0000-0000-0000-000000000901'),'username following creates a mutual connection');
set local role authenticated;
select pg_temp.assert_username(pg_temp.username_fails($q$select public.command('follow_username','{"username":"lookup_904","user_id":"00000000-0000-0000-0000-000000000904"}',gen_random_uuid())$q$),'cannot follow someone you blocked');
select pg_temp.assert_username(pg_temp.username_fails($q$select public.command('follow_username','{"username":"lookup_905","user_id":"00000000-0000-0000-0000-000000000905"}',gen_random_uuid())$q$),'cannot follow someone who blocked you');
select pg_temp.assert_username(pg_temp.username_fails($q$select public.command('follow_username','{"username":"lookup_me","user_id":"00000000-0000-0000-0000-000000000901"}',gen_random_uuid())$q$),'cannot follow yourself');
select pg_temp.assert_username(pg_temp.username_fails($q$select public.command('follow_username','{"username":"lookup_902","user_id":"00000000-0000-0000-0000-000000000903"}',gen_random_uuid())$q$),'stale username ownership is rejected');
select pg_temp.assert_username(pg_temp.username_fails($q$select public.command('follow_username','{"username":"missing","user_id":"00000000-0000-0000-0000-000000000902"}',gen_random_uuid())$q$),'unknown usernames are rejected');
select public.command('set_follow','{"user_id":"00000000-0000-0000-0000-000000000902","follow":false}',gen_random_uuid());
select pg_temp.assert_username((select jsonb_array_length(public.snapshot()->'follows'))=0,'normal unfollow works for a username connection');
-- The deployed follow/invitation migration makes activity access follow-only.
-- This also runs against the older local chain used by the legacy regression suite.
do $$ begin
 if to_regprocedure('private.is_following(uuid)') is not null then
  perform pg_temp.assert_username(not public.can_post('00000000-0000-0000-0000-000000000951'),'unfollow revokes activity access');
  perform pg_temp.assert_username(pg_temp.username_fails($q$select public.command('create_session','{"title":"No longer followed","starts_at":"2099-01-01T18:00:00Z","timezone":"UTC","venue":"Home gym","invited":["00000000-0000-0000-0000-000000000902"]}',gen_random_uuid())$q$),'unfollow revokes invitation access');
 end if;
end $$;
select public.command('follow_username','{"username":"lookup_902","user_id":"00000000-0000-0000-0000-000000000902"}',gen_random_uuid());
select public.command('block_user','{"user_id":"00000000-0000-0000-0000-000000000902"}',gen_random_uuid());
select pg_temp.assert_username(public.search_usernames('lookup_902')='[]' and (select jsonb_array_length(public.snapshot()->'follows'))=0,'blocking hides a username connection and removes its follow');
rollback;
