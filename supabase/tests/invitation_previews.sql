\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_preview(ok boolean, message text) returns void language plpgsql as $$
begin if not coalesce(ok,false) then raise exception 'Preview assertion failed: %',message; end if; end $$;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000401'),('00000000-0000-0000-0000-000000000402'),
 ('00000000-0000-0000-0000-000000000403'),('00000000-0000-0000-0000-000000000404');
insert into public.profiles(id,name) values
 ('00000000-0000-0000-0000-000000000401','Host'),('00000000-0000-0000-0000-000000000402','Going'),
 ('00000000-0000-0000-0000-000000000403','Invited'),('00000000-0000-0000-0000-000000000404','Declined');
insert into public.sessions(id,organizer,title,starts_at,timezone,venue,note) values
 ('00000000-0000-0000-0000-000000000410','00000000-0000-0000-0000-000000000401',
 'Saturday open mat','2026-11-07T18:00:00Z','America/Los_Angeles','Alliance Jiu-Jitsu',
 'matmind-focus-v1:'||encode(convert_to('{"note":"Private note","focus":[{"title":"Knee cut","children":[{"title":"Private detail"}]},{"title":"Back takes","children":[]}]}','UTF8'),'base64'));
insert into public.session_participants values
 ('00000000-0000-0000-0000-000000000410','00000000-0000-0000-0000-000000000401','going',false),
 ('00000000-0000-0000-0000-000000000410','00000000-0000-0000-0000-000000000402','going',false),
 ('00000000-0000-0000-0000-000000000410','00000000-0000-0000-0000-000000000403','invited',false),
 ('00000000-0000-0000-0000-000000000410','00000000-0000-0000-0000-000000000404','declined',false);
insert into public.capabilities(owner,kind,session_id,token_hash,expires_at) values
 ('00000000-0000-0000-0000-000000000401','session','00000000-0000-0000-0000-000000000410',extensions.digest(repeat('a',64),'sha256'),now()+interval '1 day');
set local role anon;
select pg_temp.assert_preview(public.invitation_preview('session',repeat('a',64))='{"kind":"session"}'::jsonb,'preview contains no session details');
select pg_temp.assert_preview(public.invitation_preview('session',repeat('A',64))='{"kind":"session"}'::jsonb,'preview contains no session details');
select pg_temp.assert_preview(public.invitation_preview('session',repeat('a',64))='{"kind":"session"}'::jsonb,'preview contains no session details');
select pg_temp.assert_preview(public.invitation_preview('friend',repeat('a',64)) is null,'kind must match capability');
select pg_temp.assert_preview(public.invitation_preview('session',repeat('b',64)) is null,'unknown token unavailable');
select pg_temp.assert_preview(public.invitation_preview('session','broken') is null,'malformed token unavailable');
select pg_temp.assert_preview(public.invitation_preview('session',null) is null,'null token unavailable');
do $$ begin
 begin perform * from public.sessions; raise exception 'Anonymous table access succeeded'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select pg_temp.assert_preview((select count(*)=4 from public.session_participants),'preview did not join or change RSVP');
select pg_temp.assert_preview((select count(*)=0 from public.command_receipts),'preview did not redeem or create command receipts');
update public.sessions set note='matmind-focus-v1:broken';
select pg_temp.assert_preview(public.invitation_preview('session',repeat('a',64))='{"kind":"session"}'::jsonb,'preview contains no session details');
update public.sessions set note='An old private plain-text note',title='Updated title';
select pg_temp.assert_preview(public.invitation_preview('session',repeat('a',64))='{"kind":"session"}'::jsonb,'preview contains no session details');
insert into public.blocks(actor,target) values('00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000402');
select pg_temp.assert_preview(public.invitation_preview('session',repeat('a',64))='{"kind":"session"}'::jsonb,'preview contains no session details');
update public.capabilities set revoked=true;
select pg_temp.assert_preview(public.invitation_preview('session',repeat('a',64)) is null,'revoked link unavailable');
update public.capabilities set revoked=false,expires_at=now()-interval '1 second';
select pg_temp.assert_preview(public.invitation_preview('session',repeat('a',64)) is null,'expired link unavailable');
update public.capabilities set expires_at=now()+interval '1 day';
update public.sessions set status='cancelled';
select pg_temp.assert_preview(public.invitation_preview('session',repeat('a',64)) is null,'cancelled session unavailable');
update public.sessions set status='completed';
select pg_temp.assert_preview(public.invitation_preview('session',repeat('a',64)) is null,'completed session unavailable');
-- Other invitation types have branded previews without leaking their content.
insert into public.capabilities(owner,kind,token_hash,expires_at) values
 ('00000000-0000-0000-0000-000000000401','friend',extensions.digest(repeat('c',64),'sha256'),'infinity');
select pg_temp.assert_preview(public.invitation_preview('friend',repeat('c',64))='{"kind":"friend"}','friend preview contains no personal fields');
insert into public.shared_goals(id,owner,client_id,title,notes) values
 ('00000000-0000-0000-0000-000000000420','00000000-0000-0000-0000-000000000401','preview-goal','Private goal title','Private goal notes');
insert into public.capabilities(owner,kind,goal_id,token_hash,expires_at) values
 ('00000000-0000-0000-0000-000000000401','goal','00000000-0000-0000-0000-000000000420',extensions.digest(repeat('d',64),'sha256'),now()+interval '1 day');
set local role anon;
select pg_temp.assert_preview(public.invitation_preview('goal',repeat('d',64))='{"kind":"goal"}','goal preview contains no content');
reset role;
update public.shared_goals set deleted_at=now();
select pg_temp.assert_preview(public.invitation_preview('goal',repeat('d',64)) is null,'deleted goal unavailable');
rollback;
