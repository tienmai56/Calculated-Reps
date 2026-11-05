\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.refused(operation text,payload jsonb) returns boolean language plpgsql as $$ begin perform public.command(operation,payload,gen_random_uuid()); return false; exception when others then return true; end $$;

insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000501'),
 ('00000000-0000-0000-0000-000000000502'),
 ('00000000-0000-0000-0000-000000000503');
insert into public.profiles(id,name) values
 ('00000000-0000-0000-0000-000000000501','Host'),
 ('00000000-0000-0000-0000-000000000502','Invited friend'),
 ('00000000-0000-0000-0000-000000000503','Link recipient');
insert into public.friendships(a,b,timezone) values
 ('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000502','UTC');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000501',true);
select public.command('create_session',jsonb_build_object('title','Open mat','venue','Gym','timezone','UTC','starts_at',now()+interval '1 day','join_mode','link','invited',jsonb_build_array('00000000-0000-0000-0000-000000000502')),gen_random_uuid())->>'id' as sid \gset
select public.command('session_token',jsonb_build_object('session_id',:'sid'),gen_random_uuid())->>'token' as token \gset

-- Reproduce the report: decline, reload, then reopen the invitation.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000502',true);
select public.command('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','declined'),gen_random_uuid());
select pg_temp.assert_true(public.snapshot()->'participants' @> jsonb_build_array(jsonb_build_object('session_id',:'sid','user_id',auth.uid(),'rsvp','declined')),'decline is persisted in the next app snapshot');
select pg_temp.assert_true(public.command('join_link',jsonb_build_object('token',:'token'),gen_random_uuid())->>'id'=:'sid','reopening still returns the session for navigation');
select pg_temp.assert_true(public.snapshot()->'participants' @> jsonb_build_array(jsonb_build_object('session_id',:'sid','user_id',auth.uid(),'rsvp','declined')),'reopening a link preserves the declined RSVP');
select public.command('join_link',jsonb_build_object('token',:'token'),gen_random_uuid());
select pg_temp.assert_true((select rsvp='declined' from public.session_participants where session_id=:'sid' and user_id=auth.uid()),'another link open with a fresh request key preserves the decline');

-- A first-time link recipient retains the existing join behavior.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000503',true);
select gen_random_uuid() as join_key \gset
select public.command('join_link',jsonb_build_object('token',:'token'),:'join_key');
select pg_temp.assert_true((select count(*)=1 from public.session_participants where session_id=:'sid' and user_id=auth.uid() and rsvp='going'),'first link open creates one going participant');
select public.command('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','declined'),gen_random_uuid());
select public.command('join_link',jsonb_build_object('token',:'token'),:'join_key');
select public.command('join_link',jsonb_build_object('token',:'token'),gen_random_uuid());
select pg_temp.assert_true((select count(*)=1 from public.session_participants where session_id=:'sid' and user_id=auth.uid() and rsvp='declined'),'retries and fresh opens after a decline do not rejoin or duplicate the participant');

-- Generating a replacement invitation must not reset a saved response either.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000501',true);
select public.command('session_token',jsonb_build_object('session_id',:'sid'),gen_random_uuid())->>'token' as replacement \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000502',true);
select pg_temp.assert_true(pg_temp.refused('join_link',jsonb_build_object('token',:'token')),'revoked invitation still refuses access');
select public.command('join_link',jsonb_build_object('token',:'replacement'),gen_random_uuid());
select pg_temp.assert_true((select rsvp='declined' from public.session_participants where session_id=:'sid' and user_id=auth.uid()),'a new invitation link also preserves the decline');

-- Only an explicit RSVP changes a saved response to going.
select public.command('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','going'),gen_random_uuid());
select public.command('join_link',jsonb_build_object('token',:'replacement'),gen_random_uuid());
select pg_temp.assert_true(public.snapshot()->'participants' @> jsonb_build_array(jsonb_build_object('session_id',:'sid','user_id',auth.uid(),'rsvp','going')),'explicitly joining again persists through reopening and reload');

-- Opening a link also leaves a pending invitation unanswered.
reset role;
update public.session_participants set rsvp='invited' where session_id=:'sid' and user_id='00000000-0000-0000-0000-000000000502';
set local role authenticated;
select public.command('join_link',jsonb_build_object('token',:'replacement'),gen_random_uuid());
select pg_temp.assert_true((select rsvp='invited' from public.session_participants where session_id=:'sid' and user_id=auth.uid()),'opening a pending invitation does not answer it');

-- Existing participants still have to pass capability and session checks.
select pg_temp.assert_true(pg_temp.refused('join_link',jsonb_build_object('token',repeat('f',64))),'unknown token is refused');
reset role;
update public.capabilities set expires_at=now()-interval '1 second' where session_id=:'sid';
set local role authenticated;
select pg_temp.assert_true(pg_temp.refused('join_link',jsonb_build_object('token',:'replacement')),'expired token is refused');
reset role;
update public.capabilities set expires_at=now()+interval '1 day' where token_hash=extensions.digest(:'replacement','sha256');
insert into public.blocks(actor,target) values('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000502');
set local role authenticated;
select pg_temp.assert_true(pg_temp.refused('join_link',jsonb_build_object('token',:'replacement')),'blocked participant is refused');
reset role;
delete from public.blocks where actor='00000000-0000-0000-0000-000000000501' and target='00000000-0000-0000-0000-000000000502';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000501',true);
select public.command('cancel_session',jsonb_build_object('session_id',:'sid'),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000502',true);
select pg_temp.assert_true(pg_temp.refused('join_link',jsonb_build_object('token',:'replacement')),'cancelled session is refused');
rollback;
