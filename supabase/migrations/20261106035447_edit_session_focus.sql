-- Focus is editable independently of training completion. Keep metadata edits,
-- attendance, photos, credits and publishing behind their existing commands.
do $migration$
declare
 definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 old_branch text := $old$ elsif operation in ('set_rsvp','edit_session','edit_session_details','manage_participant','cancel_session','complete_and_publish','correct_attendance','prepare_media','save_session_photo') then$old$;
 new_branch text := $new$ elsif operation='edit_session_focus' then
 select * into s from public.sessions where id=(payload->>'session_id')::uuid for update;
 if not found then raise exception 'Session unavailable'; end if;
 if actor<>s.organizer then raise exception 'Organizer required'; end if;
 if (payload->>'version')::int is distinct from s.version then raise exception 'Session changed. Refresh before editing'; end if;
 if jsonb_typeof(payload->'note') is distinct from 'string' then raise exception 'Focus note required'; end if;
 update public.sessions set note=payload->>'note',version=version+1 where id=s.id;
 result:=jsonb_build_object('id',s.id);
$new$;
begin
 if strpos(definition,old_branch)=0 then
  raise exception 'Session command changed; review focus editing migration';
 end if;
 execute replace(definition,old_branch,new_branch||old_branch);
end $migration$;
