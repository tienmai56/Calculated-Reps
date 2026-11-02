\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
insert into auth.users values ('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002'),('00000000-0000-0000-0000-000000000003'),('00000000-0000-0000-0000-000000000004');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.command('save_profile','{"name":"A","timezone":"America/Los_Angeles"}','10000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select public.command('save_profile','{"name":"B"}','10000000-0000-0000-0000-000000000002');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
select public.command('save_profile','{"name":"C"}','10000000-0000-0000-0000-000000000003');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
select public.command('save_profile','{"name":"Stranger"}','10000000-0000-0000-0000-000000000004');
reset role;
insert into public.friendships(a,b,timezone,connected_at) values
('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','America/Los_Angeles',now()-interval '1 month'),
('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','UTC',now()-interval '1 month'),
('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003','UTC',now()-interval '1 month');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.command('create_session',jsonb_build_object('title','Open mat','venue','Gym','timezone','America/Los_Angeles','starts_at',now()-interval '1 hour','invited',jsonb_build_array('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003')),'20000000-0000-0000-0000-000000000001')->>'id' as sid \gset
select set_config('test.session',:'sid',true);
select pg_temp.assert_true((select count(*)=0 from public.friendship_session_credits),'RSVP grants no credit');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select public.command('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','going'),'20000000-0000-0000-0000-000000000002');
do $$ begin
 begin perform public.command('complete_and_publish',jsonb_build_object('session_id',current_setting('test.session'),'attendees',jsonb_build_array(auth.uid()::text)),gen_random_uuid()); raise exception 'Expected organizer rejection'; exception when others then if sqlerrm='Expected organizer rejection' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
select public.command('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','going'),'20000000-0000-0000-0000-000000000003');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.command('prepare_media',jsonb_build_object('session_id',:'sid'),gen_random_uuid())->>'id' as mid \gset
reset role;
insert into storage.objects(bucket_id,name) select 'session-photos',object_key from public.media_assets where id=:'mid';
set local role authenticated;
select public.command('complete_and_publish',jsonb_build_object('session_id',:'sid','caption','Together','media_id',:'mid','attendees',jsonb_build_array('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003')),'30000000-0000-0000-0000-000000000001')->>'id' as pid \gset
select set_config('test.post',:'pid',true);
select public.command('complete_and_publish',jsonb_build_object('session_id',:'sid','caption','Together','media_id',:'mid','attendees',jsonb_build_array('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003')),'30000000-0000-0000-0000-000000000001');
select pg_temp.assert_true((select count(*)=1 from public.posts),'one shared post across publish retries');
reset role;
select pg_temp.assert_true((select count(*)=3 from public.friendship_session_credits),'every attendee pair earns credit including pair without organizer');
set local role authenticated;
select public.command('set_like',jsonb_build_object('post_id',:'pid','liked',true),'40000000-0000-0000-0000-000000000001');
select public.command('set_like',jsonb_build_object('post_id',:'pid','liked',true),'40000000-0000-0000-0000-000000000002');
select pg_temp.assert_true((select count(*)=1 from public.post_likes),'desired-state likes do not duplicate');
select pg_temp.assert_true(public.snapshot()->'posts' is not null,'snapshot reads caller-authorized records');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true((select count(*)=1 from public.media_assets),'participant can read published photo metadata');
select pg_temp.assert_true((select count(*)=1 from storage.objects),'participant can read private photo');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
select pg_temp.assert_true((select count(*)=0 from storage.objects),'stranger cannot read photo');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);

select pg_temp.assert_true(jsonb_array_length(public.post_details(:'pid'::uuid)->'posts')=1,'post detail respects visible post');
select public.command('delete_post',jsonb_build_object('post_id',:'pid','version',1),'50000000-0000-0000-0000-000000000001');
select pg_temp.assert_true((select count(*)=0 from public.posts),'deleted post leaves feed');
select pg_temp.assert_true((select count(*)=2 from public.friendship_session_credits),'post deletion preserves viewer streak credits');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select public.command('correct_attendance',jsonb_build_object('session_id',:'sid','user_id','00000000-0000-0000-0000-000000000002','attended',false),'60000000-0000-0000-0000-000000000001');
reset role;
select pg_temp.assert_true((select count(*)=1 from public.friendship_session_credits),'attendance correction rebuilds pair credits');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
select pg_temp.assert_true((select count(*)=0 from public.sessions),'stranger cannot read sessions');
select pg_temp.assert_true((select count(*)=0 from public.notifications),'stranger cannot read notifications');
select pg_temp.assert_true((select count(*)=1 from public.profiles),'stranger only sees own profile');
do $$ begin
 begin insert into public.sessions(organizer,title,starts_at,timezone,venue) values(auth.uid(),'Bypass',now(),'UTC','Gym'); raise exception 'Write bypass succeeded'; exception when insufficient_privilege then null; end;
 begin perform public.rebuild_credits(current_setting('test.session')::uuid); raise exception 'Privileged helper bypass succeeded'; exception when insufficient_privilege then null; end;
end $$;
reset role;
-- Calendar boundaries are based on a fixed IANA timezone, including DST.
select pg_temp.assert_true(date_trunc('week','2026-03-09T06:59:59Z'::timestamptz at time zone 'America/Los_Angeles')::date='2026-03-02','Sunday before Monday boundary');
select pg_temp.assert_true(date_trunc('week','2026-03-09T07:00:00Z'::timestamptz at time zone 'America/Los_Angeles')::date='2026-03-09','Monday DST boundary');
select public.erase_social_account('00000000-0000-0000-0000-000000000001');
select pg_temp.assert_true((select count(*)=0 from public.profiles where id='00000000-0000-0000-0000-000000000001'),'account data deletion');
rollback;
