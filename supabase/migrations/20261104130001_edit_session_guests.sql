-- Save the session form and guest changes in one transaction. A separate command
-- makes older servers reject the new editor instead of silently ignoring guests.
-- Generated with migration new, then ordered after the existing planned migrations.
do $migration$
declare
 definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 old_operations text := $old$'set_rsvp','edit_session','manage_participant'$old$;
 new_operations text := $new$'set_rsvp','edit_session','edit_session_details','manage_participant'$new$;
 old_branch text := $old$ if operation='edit_session' then
 if (payload->>'version')::int is distinct from s.version then raise exception 'Session changed. Refresh before editing'; end if;
 zone:=payload->>'timezone'; if not exists(select 1 from pg_timezone_names where name=zone) then raise exception 'Invalid timezone'; end if;
 update public.sessions set title=trim(payload->>'title'),starts_at=(payload->>'starts_at')::timestamptz,timezone=zone,venue=trim(payload->>'venue'),note=coalesce(payload->>'note',''),version=version+1 where id=s.id;$old$;
 new_branch text := $new$ if operation in ('edit_session','edit_session_details') then
 if (payload->>'version')::int is distinct from s.version then raise exception 'Session changed. Refresh before editing'; end if;
 zone:=payload->>'timezone'; if not exists(select 1 from pg_timezone_names where name=zone) then raise exception 'Invalid timezone'; end if;
 update public.sessions set title=trim(payload->>'title'),starts_at=(payload->>'starts_at')::timestamptz,timezone=zone,venue=trim(payload->>'venue'),note=coalesce(payload->>'note',''),version=version+1 where id=s.id returning * into s;
 if operation='edit_session_details' then
 if jsonb_typeof(payload->'added_guests') is distinct from 'array' or jsonb_typeof(payload->'removed_guests') is distinct from 'array' then raise exception 'Guest changes required'; end if;
 for person in select value::uuid from jsonb_array_elements_text(payload->'removed_guests') loop
 if person=actor then raise exception 'Organizer cannot be removed'; end if;
 delete from public.session_participants where session_id=s.id and user_id=person;
 end loop;
 for person in select distinct value::uuid from jsonb_array_elements_text(payload->'added_guests') loop
 if person=actor or not public.are_friends(actor,person) then raise exception 'Invite friends only'; end if;
 -- Retained guests keep their RSVP, even if a second device added them meanwhile.
 insert into public.session_participants values(s.id,person,case when s.starts_at>now() then 'invited' else 'going' end,false) on conflict(session_id,user_id) do nothing;
 if found and s.starts_at>now() then
 perform public.emit_notification(person,actor,'invite',s.id,'invited you to '||s.title,s.id::text||person::text||'invite'||idempotency_key::text);
 end if;
 end loop;
 end if;$new$;
begin
 if strpos(definition,old_operations)=0 or strpos(definition,old_branch)=0 then
 raise exception 'Session command changed; review session editor migration';
 end if;
 execute replace(replace(definition,old_operations,new_operations),old_branch,new_branch);
end $migration$;
