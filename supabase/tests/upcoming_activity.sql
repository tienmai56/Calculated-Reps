\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.refused(op text,body jsonb) returns boolean language plpgsql as $$ begin perform public.command(op,body,gen_random_uuid()); return false; exception when others then return true; end $$;
insert into auth.users(id) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid from generate_series(501,505) i;
insert into public.profiles(id,name) select id,case right(id::text,1) when '1' then 'Host' when '2' then 'Scanner' when '3' then 'Mutual' when '4' then 'Follower' else 'Stranger' end from auth.users where id::text like '%00000000050_';
insert into public.friendships(a,b,timezone) values
('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000503','UTC'),
('00000000-0000-0000-0000-000000000503','00000000-0000-0000-0000-000000000504','UTC');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000501',true);
select public.command('friend_token','{}',gen_random_uuid())->>'token' as host_code \gset
select public.command('create_session',jsonb_build_object('title','Shared memory','venue','Gym','timezone','UTC','starts_at',now()-interval '1 hour'),gen_random_uuid())->>'id' as past_id \gset
select public.command('complete_and_publish',jsonb_build_object('session_id',:'past_id','caption','Good rolls','attendees',jsonb_build_array(auth.uid())),gen_random_uuid())->>'id' as post_id \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000502',true);
select public.command('redeem_friend',jsonb_build_object('token',:'host_code'),gen_random_uuid());
select public.command('redeem_friend',jsonb_build_object('token',:'host_code'),gen_random_uuid());
select pg_temp.assert_true((select count(*)=1 from public.follows),'scanning follows once without approval');
select pg_temp.assert_true(exists(select 1 from public.posts where id=:'post_id'),'scan grants activity visibility');
select public.command('set_follow',jsonb_build_object('user_id','00000000-0000-0000-0000-000000000501','follow',false),gen_random_uuid());
select pg_temp.assert_true(not exists(select 1 from public.posts where id=:'post_id'),'unfollow removes activity even with a legacy friendship');
select public.command('set_follow',jsonb_build_object('user_id','00000000-0000-0000-0000-000000000501','follow',true),gen_random_uuid());
select public.command('create_session',jsonb_build_object('title','Scanner invites host','venue','Gym','timezone','UTC','starts_at',now()+interval '1 day','invited',jsonb_build_array('00000000-0000-0000-0000-000000000501')),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000504',true);
select public.command('set_follow',jsonb_build_object('user_id','00000000-0000-0000-0000-000000000501','follow',true),gen_random_uuid());
select pg_temp.assert_true(exists(select 1 from public.posts where id=:'post_id'),'manual follow grants the same activity access');
select public.command('create_session',jsonb_build_object('title','Follower invites host','venue','Gym','timezone','UTC','starts_at',now()+interval '1 day','invited',jsonb_build_array('00000000-0000-0000-0000-000000000501')),gen_random_uuid());
select pg_temp.assert_true(pg_temp.refused('create_session',jsonb_build_object('title','No follow','venue','Gym','timezone','UTC','starts_at',now()+interval '1 day','invited',jsonb_build_array('00000000-0000-0000-0000-000000000503'))),'friendship alone does not permit invitations');
select pg_temp.assert_true(pg_temp.refused('set_follow',jsonb_build_object('user_id','00000000-0000-0000-0000-000000000505','follow',true)),'stranger discovery remains restricted');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000501',true);
select public.command('set_follow',jsonb_build_object('user_id','00000000-0000-0000-0000-000000000502','follow',true),gen_random_uuid());
select public.command('create_session',jsonb_build_object('title','Secret title','venue','Secret venue','note','Secret focus and notes','timezone','UTC','starts_at',now()+interval '1 day','join_mode','link','invited',jsonb_build_array('00000000-0000-0000-0000-000000000502')),gen_random_uuid())->>'id' as sid \gset
select public.command('session_token',jsonb_build_object('session_id',:'sid'),gen_random_uuid())->>'token' as session_code \gset
select pg_temp.assert_true(public.invitation_preview('session',:'session_code')='{"kind":"session"}'::jsonb,'link preview never reveals details');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000502',true);
select pg_temp.assert_true(not public.can_session(:'sid'),'pending invitation grants no session permission');
select pg_temp.assert_true(not exists(select 1 from public.sessions where id=:'sid'),'direct session reads are hidden before accepting');
select pg_temp.assert_true(not exists(select 1 from public.session_participants where session_id=:'sid'),'guest list is hidden before accepting');
select pg_temp.assert_true(not exists(select 1 from jsonb_array_elements(public.snapshot()->'sessions') s where s->>'id'=:'sid'),'snapshot excludes invited session details');
select pg_temp.assert_true((select x=jsonb_build_object('id',:'sid','organizer','00000000-0000-0000-0000-000000000501','organizer_name','Host') from jsonb_array_elements(public.snapshot()->'training_invitations') x where x->>'id'=:'sid'),'pending invitation exposes only identity and host');
select pg_temp.assert_true(public.snapshot()::text not like '%Secret%','no session detail leaks through snapshot or notifications');
select pg_temp.assert_true(public.snapshot()->'activity_sessions'='[]'::jsonb,'following never reveals unaccepted upcoming details');
select gen_random_uuid() as accept_key \gset
select public.command('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','going'),:'accept_key');
select public.command('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','going'),:'accept_key');
select pg_temp.assert_true(exists(select 1 from public.sessions where id=:'sid' and title='Secret title' and venue='Secret venue' and note='Secret focus and notes'),'acceptance unlocks full details');
select pg_temp.assert_true(not exists(select 1 from jsonb_array_elements(public.snapshot()->'training_invitations') x where x->>'id'=:'sid'),'accepted invitation leaves pending list');
select pg_temp.assert_true((select count(*)=0 from public.friendship_session_credits),'following and accepting do not grant training credit');
select public.command('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','declined'),gen_random_uuid());
select pg_temp.assert_true(not public.can_session(:'sid'),'declining revokes details');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000504',true);
select pg_temp.assert_true(not public.can_session(:'sid'),'following a host is insufficient to read upcoming details');
select pg_temp.assert_true(pg_temp.refused('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','going')),'known ID does not substitute for invitation');
select public.command('join_link',jsonb_build_object('token',:'session_code'),gen_random_uuid());
select pg_temp.assert_true(not public.can_session(:'sid'),'opening link does not accept it');
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.snapshot()->'training_invitations') x where x->>'id'=:'sid'),'link creates a pending invitation');
select public.command('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','going'),gen_random_uuid());
select public.command('join_link',jsonb_build_object('token',:'session_code'),gen_random_uuid());
select pg_temp.assert_true(public.can_session(:'sid'),'reopening a link preserves accepted RSVP');
select public.command('block_user',jsonb_build_object('user_id','00000000-0000-0000-0000-000000000501'),gen_random_uuid());
select pg_temp.assert_true(not public.can_session(:'sid'),'blocking revokes even accepted access');
select pg_temp.assert_true(pg_temp.refused('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','going')),'blocked host cannot be accepted');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000501',true);
select public.command('manage_participant',jsonb_build_object('session_id',:'sid','user_id','00000000-0000-0000-0000-000000000502','remove',false),gen_random_uuid());
select public.command('block_user',jsonb_build_object('user_id','00000000-0000-0000-0000-000000000502'),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000502',true);
select pg_temp.assert_true(not public.can_session(:'sid'),'host blocking hides details');
select pg_temp.assert_true(not exists(select 1 from jsonb_array_elements(public.snapshot()->'training_invitations') x where x->>'id'=:'sid'),'blocked invitations disappear');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000505',true);
select pg_temp.assert_true(not public.can_session(:'sid'),'stranger cannot read session');
select pg_temp.assert_true(pg_temp.refused('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','going')),'stranger cannot accept arbitrary ID');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.assert_true(not public.can_session(:'sid'),'missing identity cannot read session');
select pg_temp.assert_true(not has_function_privilege('anon','public.can_session(uuid)','execute'),'anonymous users cannot call session authorization');
select pg_temp.assert_true(not has_function_privilege('anon','private.training_invitations()','execute'),'anonymous users cannot list invitations');
rollback;
