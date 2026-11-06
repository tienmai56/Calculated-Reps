begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- The session slot is independent of the immutable image used by an Activity post.
-- Replacing/removing a session photo must not rewrite a previously published memory.
alter table public.media_assets add column session_photo boolean not null default false;
alter table public.media_assets add constraint session_photo_ready check (not session_photo or (session_id is not null and state='ready'));
with latest as (
 select distinct on (session_id,owner) id from public.media_assets
 where session_id is not null and state='ready'
 order by session_id,owner,created_at desc,id desc
)
update public.media_assets m set session_photo=true from latest where m.id=latest.id;
create unique index one_session_photo_per_person on public.media_assets(session_id,owner) where session_photo;

-- Both the existing host composer and the participant composer select the slot
-- when finalizing an upload. All command paths lock the session before this write.
create function private.select_session_photo() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.state='ready' and new.session_id is not null then
  update public.media_assets set session_photo=false
  where session_id=new.session_id and owner=new.owner and id<>new.id and session_photo;
  new.session_photo:=true;
 end if;
 return new;
end $$;
revoke all on function private.select_session_photo() from public,anon,authenticated;
create trigger select_session_photo before update of state on public.media_assets
for each row execute function private.select_session_photo();

create function private.participant_photo_command(operation text,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid:=auth.uid(); s public.sessions; media uuid; current_media uuid; expected uuid;
begin
 if actor is null then raise exception 'Authentication required'; end if;
 select * into s from public.sessions where id=(payload->>'session_id')::uuid for update;
 if not found or s.status not in ('planned','completed') or s.starts_at>now()
  or public.blocked(actor,s.organizer) then raise exception 'Available after your session'; end if;
 if not exists(select 1 from public.session_participants
  where session_id=s.id and user_id=actor and rsvp='going' and attended)
 then raise exception 'Confirmed attendance required'; end if;
 if operation='prepare_participant_photo' then
  media:=gen_random_uuid();
  insert into public.media_assets(id,owner,session_id,object_key)
  values(media,actor,s.id,actor::text||'/'||media::text||'.jpg');
  return jsonb_build_object('id',media,'object_key',actor::text||'/'||media::text||'.jpg');
 end if;
 select id into current_media from public.media_assets
 where session_id=s.id and owner=actor and session_photo;
 expected:=nullif(payload->>'expected_media_id','')::uuid;
 if current_media is distinct from expected then raise exception 'Your photo changed. Reopen the session and try again'; end if;
 if operation='post_participant_photo' then
  media:=(payload->>'media_id')::uuid;
  if not exists(select 1 from public.media_assets m join storage.objects o
   on o.name=m.object_key and o.bucket_id='session-photos'
   where m.id=media and m.session_id=s.id and m.owner=actor)
  then raise exception 'Photo upload not ready'; end if;
  update public.media_assets set state='ready' where id=media;
  return jsonb_build_object('id',media);
 elsif operation='remove_participant_photo' then
  if expected is null then raise exception 'Photo required'; end if;
  update public.media_assets set session_photo=false where id=current_media and owner=actor;
  return jsonb_build_object('id',current_media);
 end if;
 raise exception 'Unknown photo command';
end $$;
revoke all on function private.participant_photo_command(text,jsonb) from public,anon,authenticated;

-- Preserve receipts, serialization, rate limits and every existing operation.
do $migration$
declare definition text:=pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 anchor text:=$a$ elsif operation='create_session' then$a$;
 branch text:=$b$ elsif operation in ('prepare_participant_photo','post_participant_photo','remove_participant_photo') then
 result:=private.participant_photo_command(operation,payload);
$b$;
begin
 if strpos(definition,anchor)=0 then raise exception 'Command changed; review participant photo migration'; end if;
 execute replace(definition,anchor,branch||anchor);
end $migration$;

-- Correcting attendance, declining or removing a guest also removes their slot.
-- No attendance or credit changes occur when a photo alone is removed.
create function private.clear_absent_session_photo() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then
  update public.media_assets set session_photo=false where session_id=old.session_id and owner=old.user_id and session_photo;
 elsif new.rsvp<>'going' or (old.attended and not new.attended) then
  update public.media_assets set session_photo=false where session_id=new.session_id and owner=new.user_id and session_photo;
 end if;
 return null;
end $$;
revoke all on function private.clear_absent_session_photo() from public,anon,authenticated;
create trigger clear_absent_session_photo after delete or update of attended,rsvp on public.session_participants
for each row execute function private.clear_absent_session_photo();

-- Accepted members can see active slots. Followers, pending/declined invitations
-- and blocked accounts gain no new photo access. Existing post access is retained.
alter policy media_read on public.media_assets using (
 owner=(select auth.uid())
 or exists(select 1 from public.posts p where p.media_id=media_assets.id and public.can_post(p.id))
 or (state='ready' and session_photo and not public.blocked((select auth.uid()),owner)
  and exists(select 1 from public.sessions s where s.id=media_assets.session_id and s.status<>'cancelled'
   and not public.blocked((select auth.uid()),s.organizer)
   and (s.organizer=(select auth.uid()) or exists(select 1 from public.session_participants p
    where p.session_id=s.id and p.user_id=(select auth.uid()) and p.rsvp='going'))))
);
-- Enforce the same boundary on private objects independently of media RLS.
alter policy photo_read on storage.objects using (
 bucket_id='session-photos' and exists(select 1 from public.media_assets m where m.object_key=name and (
  m.owner=(select auth.uid())
  or exists(select 1 from public.posts p where p.media_id=m.id and public.can_post(p.id))
  or (m.state='ready' and m.session_photo and not public.blocked((select auth.uid()),m.owner)
   and exists(select 1 from public.sessions s where s.id=m.session_id and s.status<>'cancelled'
    and not public.blocked((select auth.uid()),s.organizer)
    and (s.organizer=(select auth.uid()) or exists(select 1 from public.session_participants p
     where p.session_id=s.id and p.user_id=(select auth.uid()) and p.rsvp='going'))))
 ))
);

-- Old clients ignore this optional capability; new clients don't offer guest
-- writes until the migration is deployed. Keep the full existing snapshot.
alter function public.snapshot() rename to snapshot_before_participant_photos;
create function public.snapshot() returns jsonb language sql stable security invoker set search_path='' as $$
 select public.snapshot_before_participant_photos() || jsonb_build_object('participant_photos_available',true);
$$;
revoke all on function public.snapshot() from public,anon;
grant execute on function public.snapshot() to authenticated;
commit;
