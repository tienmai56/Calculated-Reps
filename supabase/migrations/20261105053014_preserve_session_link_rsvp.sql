-- Opening a session link must not overwrite a participant's latest response.
-- Keep first-time link joins, capability checks, locks, receipts and grants.
do $migration$
declare
 definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 old_branch text := $old$ if cap.kind<>'session' then raise exception 'Invalid session link'; end if;
 select * into s from public.sessions where id=cap.session_id for update;
 if s.status<>'planned' then raise exception 'Session is not open'; end if;
 insert into public.session_participants values(s.id,actor,'going',false) on conflict(session_id,user_id) do update set rsvp='going';$old$;
 new_branch text := $new$ if cap.kind<>'session' then raise exception 'Invalid session link'; end if;
 select * into s from public.sessions where id=cap.session_id for update;
 if s.status<>'planned' then raise exception 'Session is not open'; end if;
 -- A link opens existing participants' sessions; only set_rsvp changes their response.
 insert into public.session_participants values(s.id,actor,'going',false) on conflict(session_id,user_id) do nothing;$new$;
begin
 if strpos(definition,old_branch)=0 then
  raise exception 'Session command changed; review session link RSVP migration';
 end if;
 execute replace(definition,old_branch,new_branch);
end $migration$;
