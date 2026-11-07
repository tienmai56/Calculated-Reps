\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_invitation(ok boolean, message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Invitation assertion failed: %',message; end if; end $$;
create function pg_temp.invite_details() returns jsonb language sql as $$
 select item from jsonb_array_elements(public.snapshot()->'invitation_previews') item
 where item->>'id'='10000000-0000-0000-0000-000000001101';
$$;
insert into auth.users(id) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid from generate_series(1101,1104) i;
insert into public.profiles(id,name) values
 ('00000000-0000-0000-0000-000000001101','Host'),('00000000-0000-0000-0000-000000001102','Invitee'),
 ('00000000-0000-0000-0000-000000001103','Guest'),('00000000-0000-0000-0000-000000001104','Stranger');
insert into public.sessions(id,organizer,title,starts_at,timezone,venue,note,join_mode) values
 ('10000000-0000-0000-0000-000000001101','00000000-0000-0000-0000-000000001101',
 'Lunch rolls','2099-01-01T18:00:00Z','America/Los_Angeles','Tidewater BJJ',
 'matmind-focus-v1:'||encode(convert_to('{"note":"Bring your gi","focus":[{"title":"Knee cut","children":[{"title":"Control the hip"}]}]}','UTF8'),'base64'),'friends');
insert into public.session_participants(session_id,user_id,rsvp) values
 ('10000000-0000-0000-0000-000000001101','00000000-0000-0000-0000-000000001101','going'),
 ('10000000-0000-0000-0000-000000001101','00000000-0000-0000-0000-000000001102','invited'),
 ('10000000-0000-0000-0000-000000001101','00000000-0000-0000-0000-000000001103','going');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000001102',true);
select pg_temp.assert_invitation(pg_temp.invite_details()->>'title'='Lunch rolls','pending invitee reads title');
select pg_temp.assert_invitation(pg_temp.invite_details()->>'venue'='Tidewater BJJ','pending invitee reads gym');
select pg_temp.assert_invitation((pg_temp.invite_details()->>'starts_at')::timestamptz='2099-01-01T18:00:00Z'::timestamptz,'pending invitee reads exact start');
select pg_temp.assert_invitation(pg_temp.invite_details()->>'timezone'='America/Los_Angeles','timezone is preserved');
select pg_temp.assert_invitation(convert_from(decode(substr(pg_temp.invite_details()->>'note',18),'base64'),'UTF8')::jsonb->>'note'='Bring your gi','description is available');
select pg_temp.assert_invitation(convert_from(decode(substr(pg_temp.invite_details()->>'note',18),'base64'),'UTF8')::jsonb#>>'{focus,0,children,0,title}'='Control the hip','nested focus details are available');
select pg_temp.assert_invitation(jsonb_array_length(pg_temp.invite_details()->'participants')=3,'guest list is available');
select pg_temp.assert_invitation(pg_temp.invite_details()#>>'{participants,0,name}'='Host','host appears first with a name');
reset role;
select pg_temp.assert_invitation((select rsvp='invited' and not attended from public.session_participants where session_id='10000000-0000-0000-0000-000000001101' and user_id='00000000-0000-0000-0000-000000001102'),'reading keeps RSVP pending and attendance unchanged');
select pg_temp.assert_invitation(not exists(select 1 from public.command_receipts),'reading sends no commands');
select pg_temp.assert_invitation(not exists(select 1 from public.notifications),'reading creates no notifications');
select pg_temp.assert_invitation(not has_function_privilege('anon','private.invitation_previews()','EXECUTE'),'anonymous users cannot read pending details');

-- A blocked guest is omitted, without hiding the invitation itself.
insert into public.blocks(actor,target) values('00000000-0000-0000-0000-000000001102','00000000-0000-0000-0000-000000001103');
set local role authenticated;
select pg_temp.assert_invitation(jsonb_array_length(pg_temp.invite_details()->'participants')=2,'blocked guest is hidden');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000001104',true);
select pg_temp.assert_invitation(pg_temp.invite_details() is null,'unrelated account cannot read details');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000001103',true);
select pg_temp.assert_invitation(pg_temp.invite_details() is null,'accepted guest has no pending invitation');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000001101',true);
select pg_temp.assert_invitation(pg_temp.invite_details() is null,'host has no pending invitation');
reset role;

-- Either direction of a host block, cancellation and completion remove details.
insert into public.blocks(actor,target) values('00000000-0000-0000-0000-000000001101','00000000-0000-0000-0000-000000001102');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000001102',true);
select pg_temp.assert_invitation(pg_temp.invite_details() is null,'blocked host invitation is hidden');
reset role;
update public.blocks set actor=target,target=actor where actor='00000000-0000-0000-0000-000000001101';
set local role authenticated;
select pg_temp.assert_invitation(pg_temp.invite_details() is null,'blocking the host hides details');
reset role;
delete from public.blocks;
update public.sessions set status='cancelled' where id='10000000-0000-0000-0000-000000001101';
set local role authenticated;
select pg_temp.assert_invitation(pg_temp.invite_details() is null,'cancelled invitation is hidden');
reset role;
update public.sessions set status='completed' where id='10000000-0000-0000-0000-000000001101';
set local role authenticated;
select pg_temp.assert_invitation(pg_temp.invite_details() is null,'completed invitation is hidden');
reset role;
update public.sessions set status='planned',title='Updated rolls' where id='10000000-0000-0000-0000-000000001101';
set local role authenticated;
select pg_temp.assert_invitation(pg_temp.invite_details()->>'title'='Updated rolls','details reflect host edits');
select public.command('set_rsvp','{"session_id":"10000000-0000-0000-0000-000000001101","rsvp":"going"}',gen_random_uuid());
select pg_temp.assert_invitation(pg_temp.invite_details() is null,'accepting removes pending details');
select public.command('set_rsvp','{"session_id":"10000000-0000-0000-0000-000000001101","rsvp":"declined"}',gen_random_uuid());
select pg_temp.assert_invitation(pg_temp.invite_details() is null,'declining removes pending details');
reset role;
update public.session_participants set rsvp='invited' where session_id='10000000-0000-0000-0000-000000001101' and user_id='00000000-0000-0000-0000-000000001102';
delete from public.session_participants where session_id='10000000-0000-0000-0000-000000001101' and user_id='00000000-0000-0000-0000-000000001102';
set local role authenticated;
select pg_temp.assert_invitation(pg_temp.invite_details() is null,'removing the invitation revokes details');
rollback;
