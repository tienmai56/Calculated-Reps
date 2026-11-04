\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.refused(operation text,payload jsonb) returns boolean language plpgsql as $$ begin perform public.command(operation,payload,gen_random_uuid()); return false; exception when others then return true; end $$;
insert into auth.users(id) select ('00000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(301,305) n;
insert into public.profiles(id,name) select id,'Activity '||id::text from auth.users where id::text like '00000000-0000-0000-0000-00000000030_';
insert into public.friendships(a,b,timezone) values
('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000302','UTC'),
('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000304','UTC'),
('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000305','UTC');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select public.command('create_session',jsonb_build_object('title','Open rolls','venue','Gym','timezone','UTC','starts_at',now()+interval '1 day','join_mode','link'),gen_random_uuid())->>'id' as open_id \gset
select public.command('create_session',jsonb_build_object('title','Private rolls','venue','Gym','timezone','UTC','starts_at',now()+interval '1 day','join_mode','friends'),gen_random_uuid())->>'id' as private_id \gset
select public.command('create_session',jsonb_build_object('title','Past rolls','venue','Gym','timezone','UTC','starts_at',now()-interval '1 day','join_mode','link'),gen_random_uuid())->>'id' as past_id \gset
select pg_temp.assert_true(exists(select 1 from public.sessions where id=:'open_id'),'host sees the plan immediately');
select pg_temp.assert_true((select count(*)=0 from public.posts),'creating a plan does not publish a completed memory');

-- An uninvited friend sees the open plan in the regular snapshot, but is not attending.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000302',true);
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.snapshot()->'activity_sessions') s where s->>'id'=:'open_id'),'friend discovers an uninvited link-visible plan');
select pg_temp.assert_true(not exists(select 1 from jsonb_array_elements(public.snapshot()->'sessions') s where s->>'id'=:'open_id'),'discovery stays outside the personal schedule response');
select pg_temp.assert_true(not exists(select 1 from public.session_participants where session_id=:'open_id' and user_id=auth.uid()),'discovery does not RSVP');
select pg_temp.assert_true(not exists(select 1 from public.sessions where id=:'private_id'),'private plans stay out of friends feeds');
select pg_temp.assert_true(not exists(select 1 from public.sessions where id=:'past_id'),'past sessions are not discoverable');
select pg_temp.assert_true(pg_temp.refused('set_rsvp',jsonb_build_object('session_id',:'private_id','rsvp','going')),'friend cannot join private session without an invite');
select pg_temp.assert_true(pg_temp.refused('set_rsvp',jsonb_build_object('session_id',:'past_id','rsvp','going')),'friend cannot join a past plan from the feed');
select pg_temp.assert_true(pg_temp.refused('set_rsvp',jsonb_build_object('session_id',:'open_id','rsvp','declined')),'uninvited users cannot mutate RSVP to declined');
select pg_temp.assert_true(pg_temp.refused('set_rsvp',jsonb_build_object('session_id',:'open_id')),'missing RSVP is refused');
select gen_random_uuid() as join_key \gset
select public.command('set_rsvp',jsonb_build_object('session_id',:'open_id','rsvp','going'),:'join_key');
select public.command('set_rsvp',jsonb_build_object('session_id',:'open_id','rsvp','going'),:'join_key');
select pg_temp.assert_true((select count(*)=1 from public.session_participants where session_id=:'open_id' and user_id=auth.uid() and rsvp='going'),'joining and retrying creates one attendance row');
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.snapshot()->'sessions') s where s->>'id'=:'open_id'),'joined plan enters the personal schedule');
select pg_temp.assert_true(not exists(select 1 from jsonb_array_elements(public.snapshot()->'activity_sessions') s where s->>'id'=:'open_id'),'joined plan is not duplicated in discovery');
select pg_temp.assert_true((select count(*)=0 from public.friendship_session_credits),'joining never awards training credit');
select pg_temp.assert_true(pg_temp.refused('cancel_session',jsonb_build_object('session_id',:'open_id')),'feed access grants no host powers');

-- A signed-in stranger has neither discovery nor direct-ID join access.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
select pg_temp.assert_true(not exists(select 1 from public.sessions where id=:'open_id'),'stranger cannot discover a plan');
select pg_temp.assert_true(pg_temp.refused('set_rsvp',jsonb_build_object('session_id',:'open_id','rsvp','going')),'knowing an ID does not let a stranger join');

-- Friendship removal and either direction of blocking revoke discovery.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000305',true);
select pg_temp.assert_true(exists(select 1 from public.sessions where id=:'open_id'),'current friend can discover');
reset role;
update public.friendships set active=false where b='00000000-0000-0000-0000-000000000305';
insert into public.blocks values('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000304');
set local role authenticated;
select pg_temp.assert_true(not exists(select 1 from public.sessions where id=:'open_id'),'former friend loses discovery');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000304',true);
select pg_temp.assert_true(not exists(select 1 from public.sessions where id=:'open_id'),'host block hides plan');
select pg_temp.assert_true(pg_temp.refused('set_rsvp',jsonb_build_object('session_id',:'open_id','rsvp','going')),'host block prevents joining');
reset role;
delete from public.blocks where target='00000000-0000-0000-0000-000000000304';
insert into public.blocks values('00000000-0000-0000-0000-000000000304','00000000-0000-0000-0000-000000000301');
set local role authenticated;
select pg_temp.assert_true(not exists(select 1 from public.sessions where id=:'open_id'),'viewer block hides plan');

-- Started, completed and cancelled sessions leave discovery; posts remain independent.
reset role;
delete from public.blocks where actor='00000000-0000-0000-0000-000000000304';
update public.sessions set starts_at=now()-interval '1 hour' where id=:'open_id';
set local role authenticated;
select pg_temp.assert_true(not exists(select 1 from public.sessions where id=:'open_id'),'started session leaves discovery');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select public.command('complete_and_publish',jsonb_build_object('session_id',:'open_id','caption','Good rolls','attendees',jsonb_build_array(auth.uid()::text,'00000000-0000-0000-0000-000000000302')),gen_random_uuid());
select pg_temp.assert_true((select count(*)=1 from public.posts where session_id=:'open_id'),'completion publishes exactly one memory');
select pg_temp.assert_true((select count(*)=1 from public.notifications where entity_id=:'open_id' and kind='joined'),'join retries notify the host once');
select public.command('create_session',jsonb_build_object('title','Cancelled rolls','venue','Gym','timezone','UTC','starts_at',now()+interval '1 day','join_mode','link'),gen_random_uuid())->>'id' as cancelled_id \gset
select public.command('cancel_session',jsonb_build_object('session_id',:'cancelled_id'),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000304',true);
select pg_temp.assert_true(not exists(select 1 from public.sessions where id in (:'open_id',:'cancelled_id')),'completed and cancelled plans are not discoverable');
select pg_temp.assert_true(pg_temp.refused('set_rsvp',jsonb_build_object('session_id',:'cancelled_id','rsvp','going')),'cancelled plan refuses joins');
select pg_temp.assert_true(exists(select 1 from public.posts where session_id=:'open_id'),'completed memory uses existing friend visibility');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.assert_true(not public.can_session(:'open_id'),'missing identity grants no session access');
select pg_temp.assert_true(not has_function_privilege('anon','public.can_session(uuid)','execute'),'anonymous users cannot call the session authorization helper');
rollback;
