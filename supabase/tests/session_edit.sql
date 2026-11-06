\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000071'),('00000000-0000-0000-0000-000000000072'),
 ('00000000-0000-0000-0000-000000000073'),('00000000-0000-0000-0000-000000000074');
insert into public.profiles(id,name) select id,'Editor '||right(id::text,1) from auth.users where right(id::text,2) in ('71','72','73','74');
insert into public.friendships(a,b,timezone) values
 ('00000000-0000-0000-0000-000000000071','00000000-0000-0000-0000-000000000072','UTC'),
 ('00000000-0000-0000-0000-000000000071','00000000-0000-0000-0000-000000000073','UTC');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000071',true);
select public.command('create_session',jsonb_build_object('title','Old title','venue','Gym','timezone','UTC','starts_at',now()+interval '1 day',
 'invited',jsonb_build_array('00000000-0000-0000-0000-000000000072')),gen_random_uuid())->>'id' as sid \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000072',true);
select public.command('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','going'),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000071',true);
select set_config('test.session_edit',jsonb_build_object('session_id',:'sid','version',1,'title','Mount class','venue','New gym',
 'timezone','UTC','starts_at',now()+interval '2 days','note','encoded focus outline',
 'added_guests',jsonb_build_array('00000000-0000-0000-0000-000000000073','00000000-0000-0000-0000-000000000073'),
 'removed_guests','[]'::jsonb)::text,true);
select gen_random_uuid() as edit_key \gset
select public.command('edit_session_details',current_setting('test.session_edit')::jsonb,:'edit_key');
select public.command('edit_session_details',current_setting('test.session_edit')::jsonb,:'edit_key');
select pg_temp.assert_true((select title='Mount class' and venue='New gym' and note='encoded focus outline' and version=2 from public.sessions where id=:'sid'),'all form fields save with one version bump; retries are idempotent');
select pg_temp.assert_true((select rsvp='going' from public.session_participants where session_id=:'sid' and user_id='00000000-0000-0000-0000-000000000072'),'retained guest keeps RSVP');
select pg_temp.assert_true((select rsvp='invited' from public.session_participants where session_id=:'sid' and user_id='00000000-0000-0000-0000-000000000073'),'new guest is invited');
reset role;
select pg_temp.assert_true((select count(*)=1 from public.notifications n join public.notification_outbox o on o.id=n.id where n.entity_id=:'sid' and n.recipient='00000000-0000-0000-0000-000000000073'),'duplicate guests and retries queue only one invite');
set local role authenticated;
select set_config('test.session_edit',(current_setting('test.session_edit')::jsonb||'{"version":2,"title":"Must roll back","removed_guests":["00000000-0000-0000-0000-000000000072"],"added_guests":["00000000-0000-0000-0000-000000000074"]}')::text,true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('edit_session_details',current_setting('test.session_edit')::jsonb,gen_random_uuid())$q$),'a nonfriend cannot be invited');
select pg_temp.assert_true((select title='Mount class' and version=2 from public.sessions where id=:'sid'),'failed guest edit rolls back form fields and version');
select pg_temp.assert_true(exists(select 1 from public.session_participants where session_id=:'sid' and user_id='00000000-0000-0000-0000-000000000072'),'failed addition rolls back removals');
select set_config('test.session_edit',(current_setting('test.session_edit')::jsonb||'{"added_guests":[],"removed_guests":["00000000-0000-0000-0000-000000000071"]}')::text,true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('edit_session_details',current_setting('test.session_edit')::jsonb,gen_random_uuid())$q$),'organizer cannot be removed');
select set_config('test.session_edit',(current_setting('test.session_edit')::jsonb||'{"removed_guests":null}')::text,true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('edit_session_details',current_setting('test.session_edit')::jsonb,gen_random_uuid())$q$),'malformed guest lists are refused');
select set_config('test.session_edit',(current_setting('test.session_edit')::jsonb||'{"version":1,"removed_guests":[]}')::text,true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('edit_session_details',current_setting('test.session_edit')::jsonb,gen_random_uuid())$q$),'stale edits are refused');
select set_config('test.session_edit',(current_setting('test.session_edit')::jsonb||'{"version":2,"removed_guests":[]}')::text,true);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000072',true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('edit_session_details',current_setting('test.session_edit')::jsonb,gen_random_uuid())$q$),'guests cannot edit sessions');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000071',true);
select public.command('edit_session_details',current_setting('test.session_edit')::jsonb||jsonb_build_object('title','Solo rolls','note','',
 'removed_guests',jsonb_build_array('00000000-0000-0000-0000-000000000072','00000000-0000-0000-0000-000000000073')),gen_random_uuid());
select pg_temp.assert_true((select count(*)=1 from public.session_participants where session_id=:'sid'),'all guests can be removed while host remains');
select public.command('edit_session_details',current_setting('test.session_edit')::jsonb||jsonb_build_object('version',3,
 'starts_at',now()-interval '1 hour','added_guests',jsonb_build_array('00000000-0000-0000-0000-000000000073')),gen_random_uuid());
select pg_temp.assert_true((select rsvp='going' from public.session_participants where session_id=:'sid' and user_id='00000000-0000-0000-0000-000000000073'),'past-session additions use updated start time and record attendance');
-- Legacy edit_session still saves focus/metadata without touching guests.
select public.command('edit_session',current_setting('test.session_edit')::jsonb||'{"version":4,"note":"legacy edit"}',gen_random_uuid());
select pg_temp.assert_true((select count(*)=2 from public.session_participants where session_id=:'sid'),'legacy focus editor preserves guests');
select public.command('cancel_session',jsonb_build_object('session_id',:'sid'),gen_random_uuid());
select pg_temp.assert_true(pg_temp.fails($q$select public.command('edit_session_details',current_setting('test.session_edit')::jsonb||'{"version":6}',gen_random_uuid())$q$),'cancelled sessions cannot be edited');
set local role anon;
select pg_temp.assert_true(pg_temp.fails($q$select public.command('edit_session_details',current_setting('test.session_edit')::jsonb,gen_random_uuid())$q$),'anonymous clients cannot call editor command');
rollback;

-- Focus edits work before and after completion without reopening training.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000071'),('00000000-0000-0000-0000-000000000072');
insert into public.profiles(id,name) select id,'Focus editor' from auth.users where right(id::text,2) in ('71','72');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000071',true);
select public.command('create_session',jsonb_build_object('title','Training','venue','Gym','timezone','UTC',
 'starts_at',now()-interval '1 hour','invited','[]'::jsonb),gen_random_uuid())->>'id' as sid \gset
select set_config('test.focus_edit',jsonb_build_object('session_id',:'sid','version',1,'note','Focus before completion')::text,true);
select public.command('edit_session_focus',current_setting('test.focus_edit')::jsonb,gen_random_uuid());
select pg_temp.assert_true((select status='planned' and note='Focus before completion' and version=2 from public.sessions where id=:'sid'),'focus saves before completion');
select public.command('complete_and_publish',jsonb_build_object('session_id',:'sid','attendees',
 jsonb_build_array('00000000-0000-0000-0000-000000000071'),'caption','Good rounds'),gen_random_uuid());

-- Snapshot every unrelated field and side effect to catch accidental changes.
select set_config('test.focus_before',jsonb_build_object(
 'session',(select to_jsonb(s)-'note'-'version' from public.sessions s where id=:'sid'),
 'people',(select jsonb_agg(p) from public.session_participants p where session_id=:'sid'),
 'posts',(select jsonb_agg(p) from public.posts p where session_id=:'sid'),
 'credits',(select jsonb_agg(c) from public.friendship_session_credits c where session_id=:'sid'))::text,true);
select set_config('test.focus_edit',jsonb_build_object('session_id',:'sid','version',(select version from public.sessions where id=:'sid'),
 'note','Focus after completion','title','Ignore this','starts_at',now()+interval '1 day','added_guests','[]'::jsonb)::text,true);
select gen_random_uuid() as focus_key \gset
select public.command('edit_session_focus',current_setting('test.focus_edit')::jsonb,:'focus_key');
select public.command('edit_session_focus',current_setting('test.focus_edit')::jsonb,:'focus_key');
select pg_temp.assert_true((select status='completed' and note='Focus after completion' and
 version=(current_setting('test.focus_edit')::jsonb->>'version')::int+1 from public.sessions where id=:'sid'),'completed focus saves once on retry');
select pg_temp.assert_true(current_setting('test.focus_before')::jsonb=jsonb_build_object(
 'session',(select to_jsonb(s)-'note'-'version' from public.sessions s where id=:'sid'),
 'people',(select jsonb_agg(p) from public.session_participants p where session_id=:'sid'),
 'posts',(select jsonb_agg(p) from public.posts p where session_id=:'sid'),
 'credits',(select jsonb_agg(c) from public.friendship_session_credits c where session_id=:'sid')),'focus edits preserve metadata, attendance, memories and credits');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('edit_session_focus',current_setting('test.focus_edit')::jsonb,gen_random_uuid())$q$),'stale focus save is rejected');
select set_config('test.focus_edit',(current_setting('test.focus_edit')::jsonb||jsonb_build_object('version',
 (select version from public.sessions where id=:'sid')))::text,true);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000072',true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('edit_session_focus',current_setting('test.focus_edit')::jsonb,gen_random_uuid())$q$),'another user cannot edit focus');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000071',true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('edit_session_focus',current_setting('test.focus_edit')::jsonb-'note',gen_random_uuid())$q$),'missing note cannot erase focus');
select public.command('edit_session_focus',current_setting('test.focus_edit')::jsonb||'{"note":""}',gen_random_uuid());
select pg_temp.assert_true((select note='' and status='completed' from public.sessions where id=:'sid'),'focus can be cleared after completion');
set local role anon;
select pg_temp.assert_true(pg_temp.fails($q$select public.command('edit_session_focus',current_setting('test.focus_edit')::jsonb,gen_random_uuid())$q$),'anonymous users cannot edit focus');
rollback;
