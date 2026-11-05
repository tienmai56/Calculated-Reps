-- Experimental feature bundle: intentionally outside supabase/migrations.
-- Apply only to an isolated local/preview database, never the shared production project.
-- Enable for this SQL session with: SET matmonkey.quick_training_log = 'on';
-- The transaction rolls everything back on a missing flag, even without ON_ERROR_STOP.
begin;
do $feature_gate$
begin
 if current_setting('matmonkey.quick_training_log',true) is distinct from 'on' then
  raise exception 'Quick training log is disabled. Opt in only on an isolated test database.';
 end if;
end $feature_gate$;

-- Private quick logs and reversible attendance, independent of publishing.
create table public.quick_logs (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles on delete cascade,
 logged_on date not null, logged_at timestamptz not null default now(), timezone text not null
);
create index quick_logs_owner_day on public.quick_logs(user_id,logged_on);
alter table public.quick_logs enable row level security;
create policy owner_read on public.quick_logs for select to authenticated using (user_id=(select auth.uid()));
-- Writes go through command, which validates timezone and future local dates.
grant select on public.quick_logs to authenticated;
revoke all on public.quick_logs from anon;

create table public.training_actions (
 id uuid primary key, actor uuid not null references public.profiles on delete cascade,
 session_id uuid not null references public.sessions on delete cascade,
 old_status text not null, old_completed_at timestamptz, applied_version int not null,
 changed_users uuid[] not null, undone boolean not null default false
);
alter table public.training_actions enable row level security;
revoke all on public.training_actions from anon,authenticated;

create table public.log_matches (
 id uuid primary key, user_id uuid not null references public.profiles on delete cascade,
 session_id uuid not null references public.sessions on delete cascade,
 action_id uuid not null references public.training_actions on delete cascade,
 logged_on date not null, logged_at timestamptz not null, timezone text not null,
 seen boolean not null default false, restored boolean not null default false
);
alter table public.log_matches enable row level security;
create policy owner_read on public.log_matches for select to authenticated using (user_id=(select auth.uid()));
grant select on public.log_matches to authenticated;
revoke all on public.log_matches from anon;

-- Private helper, accessible only through the authenticated command dispatcher.
create function public.training_command(operation text,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
 declare actor uuid:=auth.uid(); s public.sessions; a public.training_actions; m public.log_matches;
 zone text; entity uuid; changed uuid[]; q public.quick_logs;
 begin
 if actor is null then raise exception 'Authentication required'; end if;
 if operation='create_quick_log' then
 zone:=payload->>'timezone';
 if not exists(select 1 from pg_timezone_names where name=zone) then raise exception 'Invalid timezone'; end if;
 if (payload->>'logged_on')::date > (now() at time zone zone)::date then raise exception 'Future day'; end if;
 insert into public.quick_logs(id,user_id,logged_on,timezone)
 values((payload->>'id')::uuid,actor,(payload->>'logged_on')::date,zone) returning * into q;
 return jsonb_build_object('id',q.id);
 elsif operation='delete_quick_log' then
 delete from public.quick_logs where id=(payload->>'id')::uuid and user_id=actor;
 elsif operation='mark_training_done' then
 select * into s from public.sessions where id=(payload->>'session_id')::uuid for update;
 if not found or s.status<>'planned' or public.blocked(actor,s.organizer) then raise exception 'Open plan required'; end if;
 zone:=coalesce(payload->>'timezone',s.timezone);
 if not exists(select 1 from pg_timezone_names where name=zone) then raise exception 'Invalid timezone'; end if;
 if s.starts_at>now() then raise exception 'Session has not started'; end if;
 if not exists(select 1 from public.session_participants where session_id=s.id and user_id=actor and rsvp='going' and not attended) then raise exception 'Joined open plan required'; end if;
 select coalesce(array_agg(user_id),'{}') into changed from public.session_participants
 where session_id=s.id and rsvp='going' and not attended and (actor=s.organizer or user_id=actor);
 entity:=(payload->>'action_id')::uuid;
 insert into public.training_actions(id,actor,session_id,old_status,old_completed_at,applied_version,changed_users)
 values(entity,actor,s.id,s.status,s.completed_at,s.version+1,changed);
 update public.session_participants set attended=true where session_id=s.id and user_id=any(changed);
 update public.sessions set status=case when actor=s.organizer then 'completed' else status end,
 completed_at=case when actor=s.organizer then now() else completed_at end,version=version+1 where id=s.id;
 if actor=s.organizer then
 -- Lock and archive matches before deleting. Guest logs remain private to their owner.
 for q in select l.* from public.quick_logs l join public.session_participants p on p.user_id=l.user_id
 where p.session_id=s.id and p.rsvp='going' and p.attended and l.user_id<>actor
 and l.logged_on=(s.starts_at at time zone l.timezone)::date
 and abs(extract(epoch from (l.logged_at-s.starts_at)))<=10800 for update of l loop
 insert into public.log_matches values(q.id,q.user_id,s.id,entity,q.logged_on,q.logged_at,q.timezone,false,false)
 on conflict(id) do update set action_id=excluded.action_id,seen=false,restored=false;
 delete from public.quick_logs where id=q.id;
 end loop;
 end if;
 perform public.rebuild_credits(s.id);
 elsif operation='undo_training_done' then
 select * into a from public.training_actions where id=(payload->>'action_id')::uuid and training_actions.actor=actor for update;
 if not found or a.undone then raise exception 'Undo unavailable'; end if;
 select * into s from public.sessions where id=a.session_id for update;
 -- Never overwrite another attendance correction or a subsequently published post.
 if s.version<>a.applied_version or exists(select 1 from public.posts where session_id=s.id) then raise exception 'Session changed; refresh before correcting attendance'; end if;
 update public.session_participants set attended=false where session_id=s.id and user_id=any(a.changed_users);
 update public.sessions set status=a.old_status,completed_at=a.old_completed_at,version=version+1 where id=s.id;
 insert into public.quick_logs select id,user_id,logged_on,logged_at,timezone from public.log_matches where action_id=a.id and not restored on conflict(id) do nothing;
 update public.log_matches set restored=true,seen=true where action_id=a.id;
 update public.training_actions set undone=true where id=a.id;
 perform public.rebuild_credits(s.id);
 elsif operation in ('restore_matched_log','acknowledge_log_match') then
 select * into m from public.log_matches where id=(payload->>'id')::uuid and user_id=actor for update;
 if not found then raise exception 'Match unavailable'; end if;
 if operation='restore_matched_log' and not m.restored then
 insert into public.quick_logs values(m.id,actor,m.logged_on,m.logged_at,m.timezone) on conflict(id) do nothing;
 update public.log_matches set restored=true where id=m.id;
 end if;
 update public.log_matches set seen=true where id=m.id;
 end if;
 return '{}'::jsonb;
 end $$;
revoke all on function public.training_command(text,jsonb) from public,anon,authenticated;

-- Extend the deployed dispatcher; retain receipts, serialization, limits and all later commands.
do $migration$
declare definition text:=pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 anchor text:=$a$ elsif operation='create_session' then$a$;
 branch text:=$b$ elsif operation in ('create_quick_log','delete_quick_log','mark_training_done','undo_training_done','restore_matched_log','acknowledge_log_match') then
 result:=public.training_command(operation,payload);
$b$;
begin
 if strpos(definition,anchor)=0 then raise exception 'Command changed'; end if;
 definition:=replace(definition,anchor,branch||anchor);
 definition:=replace(definition,
 $a$if operation<>'complete_and_publish' and s.status<>'planned' then$a$,
 $a$if operation not in ('complete_and_publish','prepare_media','manage_participant') and s.status<>'planned' then$a$);
 definition:=replace(definition,
 $a$if s.status<>'planned' or s.starts_at>now() then raise exception 'Session cannot be completed'; end if;$a$,
 $a$if s.status not in ('planned','completed') or s.starts_at>now() or exists(select 1 from public.posts where session_id=s.id) then raise exception 'Session cannot be completed'; end if;$a$);
 definition:=replace(definition,
 $a$if s.status<>'completed' then raise exception 'Completed session required'; end if;$a$,
 $a$if s.status not in ('planned','completed') then raise exception 'Active session required'; end if;
 if s.status='planned' and coalesce((payload->>'attended')::boolean,true) then raise exception 'Use mark training done'; end if;$a$);
 definition:=replace(definition,
 $a$update public.session_participants set rsvp=payload->>'rsvp' where session_id=s.id and user_id=actor;$a$,
 $a$if payload->>'rsvp'='declined' and exists(select 1 from public.session_participants where session_id=s.id and user_id=actor and attended) then
 update public.sessions set version=version+1 where id=s.id;
 end if;
 update public.session_participants set rsvp=payload->>'rsvp',attended=case when payload->>'rsvp'='declined' then false else attended end where session_id=s.id and user_id=actor;
 perform public.rebuild_credits(s.id);$a$);
 definition:=replace(definition,
 $a$elsif operation='prepare_media' then$a$,
 $a$elsif operation='prepare_media' then
 if s.status not in ('planned','completed') then raise exception 'Active session required'; end if;
$a$);
 definition:=replace(definition,'completed_at=now(),version=version+1','completed_at=coalesce(completed_at,now()),version=version+1');
 -- A correction/removal invalidates outstanding undo tokens and rebuilds shared credit.
 definition:=replace(definition,
 $a$perform public.rebuild_credits(s.id);
 else$a$,
 $a$update public.sessions set version=version+1 where id=s.id;
 perform public.rebuild_credits(s.id);
 else$a$);
 definition:=replace(definition,
 $a$elsif operation='manage_participant' then$a$,
 $a$elsif operation='manage_participant' then
 if s.status='cancelled' or (s.status='completed' and not coalesce((payload->>'remove')::boolean,false)) then raise exception 'Participant removal only'; end if;
 if coalesce((payload->>'remove')::boolean,false) and exists(select 1 from public.session_participants where session_id=s.id and user_id=(payload->>'user_id')::uuid and attended) then
 update public.sessions set version=version+1 where id=s.id;
 end if;
$a$);
 definition:=replace(definition,
 $a$delete from public.session_participants where session_id=s.id and user_id=person;$a$,
 $a$delete from public.session_participants where session_id=s.id and user_id=person;
 perform public.rebuild_credits(s.id);$a$);
 execute definition;
end $migration$;

-- A guest can mark attendance before the host; credit still requires both people.
-- rebuild_credits already reads confirmed attendance; permit planned attendance there.
do $migration$
declare definition text:=pg_get_functiondef('public.rebuild_credits(uuid)'::regprocedure);
begin
 definition:=replace(definition,$a$t.status='completed'$a$,$a$t.status in ('planned','completed')$a$);
 execute definition;
end $migration$;

-- One query for days, independent of feed/schedule pagination. Plans never count.
create function public.training_days(first_day date,last_day date,zone text)
returns table(day date,quick_log_count bigint,sessions jsonb)
language sql stable security invoker set search_path='' as $$
 select d::date,
 (select count(*) from public.quick_logs l where l.user_id=auth.uid() and l.logged_on=d::date),
 coalesce((select jsonb_agg(to_jsonb(s)) from public.sessions s join public.session_participants p on p.session_id=s.id
 where p.user_id=auth.uid() and p.attended and s.status in ('planned','completed') and (s.starts_at at time zone zone)::date=d::date),'[]')
 from generate_series(first_day::timestamp,least(last_day,first_day+366)::timestamp,interval '1 day') d
 where auth.uid() is not null;
$$;
revoke all on function public.training_days(date,date,text) from public,anon;
grant execute on function public.training_days(date,date,text) to authenticated;

create function public.shared_training_sessions() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(p.session_id),'[]') from public.posts p
 join public.sessions s on s.id=p.session_id
 where s.organizer=auth.uid() or exists(
 select 1 from public.session_participants sp where sp.session_id=s.id and sp.user_id=auth.uid() and sp.rsvp='going');
$$;
revoke all on function public.shared_training_sessions() from public,anon;
grant execute on function public.shared_training_sessions() to authenticated;

alter function public.snapshot() rename to snapshot_before_training;
revoke all on function public.snapshot_before_training() from public,anon;
create function public.snapshot() returns jsonb language sql stable security invoker set search_path='' as $$
 select public.snapshot_before_training() || jsonb_build_object(
 'shared_session_ids',public.shared_training_sessions(),
 'quick_logs',coalesce((select jsonb_agg(to_jsonb(l)) from public.quick_logs l),'[]'),
 'log_matches',coalesce((select jsonb_agg(to_jsonb(m)) from public.log_matches m where not seen and not restored),'[]'),
 'training_days',coalesce((select jsonb_agg(to_jsonb(d)) from public.training_days(
 -- Include a boundary week so device-local weeks remain complete across timezones.
 (date_trunc('week',now())-interval '17 weeks')::date,current_date+1,
 coalesce((select timezone from public.account_settings where user_id=auth.uid()),'UTC')) d),'[]')
 );
$$;
revoke all on function public.snapshot() from public,anon;
grant execute on function public.snapshot() to authenticated;

commit;
