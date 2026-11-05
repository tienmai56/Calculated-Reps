-- A photo belongs to the training session as soon as the organizer saves it.
-- Publishing to Activity remains a separate action and reuses the same media.
do $migration$
declare
 definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 old_operations text := $old$'complete_and_publish','correct_attendance','prepare_media')$old$;
 old_branch text := $old$ elsif operation='complete_and_publish' then
 if s.status<>'planned' or s.starts_at>now() then raise exception 'Session cannot be completed'; end if;$old$;
 new_branch text := $new$ elsif operation='save_session_photo' then
 if s.starts_at>now() then raise exception 'Available after your session'; end if;
 media:=(payload->>'media_id')::uuid;
 if not exists(select 1 from public.media_assets m join storage.objects o on o.name=m.object_key and o.bucket_id='session-photos'
  where m.id=media and m.owner=actor and m.session_id=s.id) then raise exception 'Photo upload not ready'; end if;
 update public.media_assets set state='ready' where id=media;
 result:=jsonb_build_object('id',media);
 elsif operation='complete_and_publish' then
 if s.status<>'planned' or s.starts_at>now() then raise exception 'Session cannot be completed'; end if;$new$;
begin
 if strpos(definition,old_operations)=0 or strpos(definition,old_branch)=0 then
  raise exception 'Session command changed; review session photo migration';
 end if;
 definition:=replace(definition,old_operations,$new$'complete_and_publish','correct_attendance','prepare_media','save_session_photo')$new$);
 execute replace(definition,old_branch,new_branch);
end $migration$;

-- Accepted guests can see saved photos without requiring an Activity post.
-- Pending invitations, declined guests, discovery and blocks confer no access.
alter policy media_read on public.media_assets using (
 owner=auth.uid()
 or exists(select 1 from public.posts p where p.media_id=media_assets.id and public.can_post(p.id))
 or (state='ready' and exists (
  select 1 from public.sessions s where s.id=media_assets.session_id and s.status<>'cancelled'
   and not public.blocked(auth.uid(),s.organizer)
   and (s.organizer=auth.uid() or exists (
    select 1 from public.session_participants p
     where p.session_id=s.id and p.user_id=auth.uid() and p.rsvp='going'
   ))
 ))
);

-- Enforce access on the storage object itself as well as the media row.
-- Owners can read pending uploads to recover from a lost upload response.
alter policy photo_read on storage.objects using (
 bucket_id='session-photos' and exists (
  select 1 from public.media_assets m where m.object_key=name and (
   m.owner=auth.uid()
   or (m.state='ready' and (
    exists(select 1 from public.posts p where p.media_id=m.id and public.can_post(p.id))
    or exists (
     select 1 from public.sessions s where s.id=m.session_id and s.status<>'cancelled'
      and not public.blocked(auth.uid(),s.organizer)
      and (s.organizer=auth.uid() or exists (
       select 1 from public.session_participants p
        where p.session_id=s.id and p.user_id=auth.uid() and p.rsvp='going'
      ))
    )
   ))
  )
 )
);
