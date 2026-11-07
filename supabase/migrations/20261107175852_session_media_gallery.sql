begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

-- Keep the legacy cover for older clients. Order is explicit, never created_at.
alter table public.posts add column media_ids uuid[] not null default '{}';
update public.posts set media_ids=array[media_id] where media_id is not null;
alter table public.posts add constraint post_media_limit check(cardinality(media_ids)<=5);
-- NULL means an older client has not selected a gallery; {} means explicitly cleared.
alter table public.sessions add column media_ids uuid[];
alter table public.sessions add constraint session_media_limit check(cardinality(media_ids)<=5);
update storage.buckets set file_size_limit=52428800,
 allowed_mime_types=array['image/jpeg','video/mp4','video/quicktime','video/x-m4v']
where id='session-photos';

create function private.validate_post_gallery() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if cardinality(new.media_ids)=0 and new.media_id is not null then new.media_ids:=array[new.media_id]; end if;
 if cardinality(new.media_ids)>5 or cardinality(new.media_ids)<>(select count(distinct id) from unnest(new.media_ids) id)
 then raise exception 'Choose up to 5 different photos or videos'; end if;
 if exists(select 1 from unnest(new.media_ids) candidate(id) where not exists(
  select 1 from public.media_assets m join storage.objects o on o.name=m.object_key and o.bucket_id='session-photos'
  where m.id=candidate.id and m.owner=new.author and m.session_id=new.session_id and m.state='ready'
 )) then raise exception 'Media upload not ready'; end if;
 new.media_id:=new.media_ids[1];
 return new;
end $$;
revoke all on function private.validate_post_gallery() from public,anon,authenticated;
-- Run before the existing nonempty-post trigger.
create trigger a_validate_post_gallery before insert or update of media_ids,media_id on public.posts
 for each row execute function private.validate_post_gallery();

create function private.session_media_command(operation text,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid:=auth.uid(); s public.sessions; ids uuid[]; media uuid; suffix text; mime text;
begin
 if actor is null then raise exception 'Authentication required'; end if;
 select * into s from public.sessions where id=(payload->>'session_id')::uuid for update;
 if not found or s.organizer<>actor or s.status not in ('planned','completed') or s.starts_at>now()
 then raise exception 'Available to the organizer after training'; end if;
 if operation='prepare_session_media' then
  mime:=coalesce(payload->>'content_type','image/jpeg');
  suffix:=case mime when 'image/jpeg' then 'jpg' when 'video/mp4' then 'mp4'
   when 'video/quicktime' then 'mov' when 'video/x-m4v' then 'm4v' end;
  if suffix is null then raise exception 'Unsupported media type'; end if;
  media:=gen_random_uuid();
  insert into public.media_assets(id,owner,session_id,object_key)
  values(media,actor,s.id,actor::text||'/'||media::text||'.'||suffix);
  return jsonb_build_object('id',media,'object_key',actor::text||'/'||media::text||'.'||suffix);
 end if;
 if jsonb_typeof(payload->'media_ids') is distinct from 'array' then raise exception 'Media list required'; end if;
 ids:=array(select value::uuid from jsonb_array_elements_text(payload->'media_ids'));
 if cardinality(ids)>5 or cardinality(ids)<>(select count(distinct id) from unnest(ids) id)
 then raise exception 'Choose up to 5 different photos or videos'; end if;
 if exists(select 1 from unnest(ids) candidate(id) where not exists(
  select 1 from public.media_assets m join storage.objects o on o.name=m.object_key and o.bucket_id='session-photos'
  where m.id=candidate.id and m.owner=actor and m.session_id=s.id
 )) then raise exception 'Media upload not ready'; end if;
 update public.media_assets set state='ready' where id=any(ids) and state<>'ready';
 update public.sessions set media_ids=ids where id=s.id;
 return jsonb_build_object('media_ids',ids);
end $$;
revoke all on function private.session_media_command(text,jsonb) from public,anon,authenticated;

do $migration$
declare definition text:=pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 anchor text:=$a$ elsif operation='create_session' then$a$;
 old_media text:=$a$media:=nullif(payload->>'media_id','')::uuid;$a$;
 insert_old text:=$a$insert into public.posts(session_id,author,title,venue,occurred_at,caption,media_id) values(s.id,actor,s.title,s.venue,s.starts_at,coalesce(payload->>'caption',''),media) returning * into p;$a$;
begin
 if strpos(definition,anchor)=0 or strpos(definition,old_media)=0 or strpos(definition,insert_old)=0 then raise exception 'Review gallery dispatcher anchors'; end if;
 definition:=replace(definition,anchor,$a$ elsif operation in ('prepare_session_media','save_session_media') then
 result:=private.session_media_command(operation,payload);
$a$||anchor);
 definition:=replace(definition,old_media,$a$if payload ? 'media_ids' then
 perform private.session_media_command('save_session_media',payload);
 media:=nullif(payload->'media_ids'->>0,'')::uuid;
 else
 media:=nullif(payload->>'media_id','')::uuid;
 end if;$a$);
 definition:=replace(definition,insert_old,$a$insert into public.posts(session_id,author,title,venue,occurred_at,caption,media_id,media_ids)
 values(s.id,actor,s.title,s.venue,s.starts_at,coalesce(payload->>'caption',''),media,
 case when payload ? 'media_ids' then array(select value::uuid from jsonb_array_elements_text(payload->'media_ids'))
 when media is not null then array[media] else '{}'::uuid[] end) returning * into p;$a$);
 execute definition;
end $migration$;

-- Every gallery slide has the same visibility as its post. Saved drafts still
-- require session membership, and storage independently checks these permissions.
alter policy media_read on public.media_assets using (
 owner=(select auth.uid())
 or exists(select 1 from public.posts p where (p.media_id=media_assets.id or media_assets.id=any(p.media_ids)) and public.can_post(p.id))
 or (state='ready' and not public.blocked((select auth.uid()),owner)
  and exists(select 1 from public.sessions s where s.id=media_assets.session_id and s.status<>'cancelled'
   and (media_assets.session_photo or media_assets.id=any(s.media_ids))
   and not public.blocked((select auth.uid()),s.organizer)
   and (s.organizer=(select auth.uid()) or exists(select 1 from public.session_participants p
    where p.session_id=s.id and p.user_id=(select auth.uid()) and p.rsvp='going'))))
);
alter policy photo_read on storage.objects using (
 bucket_id='session-photos' and exists(select 1 from public.media_assets m where m.object_key=name and (
  m.owner=(select auth.uid())
  or exists(select 1 from public.posts p where (p.media_id=m.id or m.id=any(p.media_ids)) and public.can_post(p.id))
  or (m.state='ready' and not public.blocked((select auth.uid()),m.owner)
   and exists(select 1 from public.sessions s where s.id=m.session_id and s.status<>'cancelled'
    and (m.session_photo or m.id=any(s.media_ids)) and not public.blocked((select auth.uid()),s.organizer)
    and (s.organizer=(select auth.uid()) or exists(select 1 from public.session_participants p
     where p.session_id=s.id and p.user_id=(select auth.uid()) and p.rsvp='going'))))
 ))
);

do $migration$
declare definition text:=pg_get_functiondef('public.post_details(uuid)'::regprocedure);
 anchor text:='m.id in(select media_id from public.posts p where p.id=post_id)';
begin
 if strpos(definition,anchor)=0 then raise exception 'Review post detail gallery anchor'; end if;
 execute replace(definition,anchor,'exists(select 1 from public.posts p where p.id=post_id and (p.media_id=m.id or m.id=any(p.media_ids)))');
end $migration$;
alter function public.snapshot() rename to snapshot_before_session_media;
create function public.snapshot() returns jsonb language sql stable security invoker set search_path='' as $$
 select public.snapshot_before_session_media() || jsonb_build_object('session_media_available',true);
$$;
revoke all on function public.snapshot() from public,anon;
grant execute on function public.snapshot() to authenticated;
commit;
