-- Keep every reference attached to its note, including uploaded movies.
-- Existing payloads without noteItems keep their current behavior.
update storage.buckets set file_size_limit=52428800,
 allowed_mime_types=array['image/jpeg','video/mp4','video/quicktime','video/x-m4v']
where id='goal-media';
alter policy goal_media_upload on storage.objects
with check(bucket_id='goal-media' and split_part(name,'/',1)=auth.uid()::text
 and name ~ '^[0-9a-f-]{36}/[0-9a-f]{64}\.(jpg|mp4|mov|m4v)$');

do $migration$
declare
 definition text:=pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 old_part text:=$old$ if jsonb_typeof(part)<>'object' or length(coalesce(part->>'title',''))>160 or length(coalesce(part->>'notes',''))>4000 or jsonb_typeof(coalesce(part->'photos','[]'))<>'array' then raise exception 'Invalid goal part'; end if;$old$;
 new_part text:=$new$ if jsonb_typeof(part)<>'object' or length(coalesce(part->>'title',''))>160 or length(coalesce(part->>'notes',''))>4000 or jsonb_typeof(coalesce(part->'photos','[]'))<>'array' then raise exception 'Invalid goal part'; end if;
 if jsonb_typeof(coalesce(part->'noteItems','[]'))<>'array' or jsonb_array_length(coalesce(part->'noteItems','[]'))>100 then raise exception 'Invalid goal notes'; end if;
 if (select count(*)<>count(distinct n->>'id') from jsonb_array_elements(coalesce(part->'noteItems','[]')) n) then raise exception 'Duplicate goal note'; end if;
 for goal_note in select value from jsonb_array_elements(coalesce(part->'noteItems','[]')) loop
 if jsonb_typeof(goal_note)<>'object' or jsonb_typeof(goal_note->'id') is distinct from 'string' or length(goal_note->>'id') not between 1 and 160
 or jsonb_typeof(goal_note->'text') is distinct from 'string' or length(goal_note->>'text')>4000
 or jsonb_typeof(goal_note->'links') is distinct from 'array' or jsonb_typeof(goal_note->'photos') is distinct from 'array'
 or jsonb_typeof(goal_note->'videos') is distinct from 'array' then raise exception 'Invalid goal note'; end if;
 if jsonb_array_length(goal_note->'links')>30 or jsonb_array_length(goal_note->'photos')+jsonb_array_length(goal_note->'videos')>20 then raise exception 'Too many references on a note'; end if;
 end loop;$new$;
 old_link text:=$old$ union all select x->>'link' from jsonb_array_elements(coalesce(payload->'parts','[]')) x where coalesce(x->>'link','')<>'' loop$old$;
 new_link text:=$new$ union all select x->>'link' from jsonb_array_elements(coalesce(payload->'parts','[]')) x where coalesce(x->>'link','')<>''
 union all select l.value from jsonb_array_elements(coalesce(payload->'parts','[]')) note_part(value)
 cross join lateral jsonb_array_elements(coalesce(note_part.value->'noteItems','[]')) n
 cross join lateral jsonb_array_elements_text(n->'links') l loop$new$;
 old_media text:=$old$ keys:=array(select value from jsonb_array_elements_text(coalesce(payload->'photos','[]'))
 union all select ph.value from jsonb_array_elements(coalesce(payload->'parts','[]')) x cross join lateral jsonb_array_elements_text(coalesce(x->'photos','[]')) ph);$old$;
 new_media text:=$new$ keys:=array(select value from jsonb_array_elements_text(coalesce(payload->'photos','[]'))
 union select ph.value from jsonb_array_elements(coalesce(payload->'parts','[]')) x cross join lateral jsonb_array_elements_text(coalesce(x->'photos','[]')) ph
 union select ph.value from jsonb_array_elements(coalesce(payload->'parts','[]')) note_part(value)
 cross join lateral jsonb_array_elements(coalesce(note_part.value->'noteItems','[]')) n
 cross join lateral jsonb_array_elements_text(n->'photos') ph
 union select v.value from jsonb_array_elements(coalesce(payload->'parts','[]')) note_part(value)
 cross join lateral jsonb_array_elements(coalesce(note_part.value->'noteItems','[]')) n
 cross join lateral jsonb_array_elements_text(n->'videos') v);$new$;
begin
 if strpos(definition,old_part)=0 or strpos(definition,old_link)=0 or strpos(definition,old_media)=0
 or strpos(definition,'part jsonb;')=0 then raise exception 'Goal sharing command changed; review note references migration'; end if;
 definition:=replace(definition,'part jsonb;','part jsonb; goal_note jsonb;');
 definition:=replace(definition,old_part,new_part);
 definition:=replace(definition,old_link,new_link);
 definition:=replace(definition,old_media,new_media);
 execute definition;
end $migration$;
