-- Following is the single permission for activity and inviting someone to train.
-- Existing QR connections retain their activity access. Future scans follow one way.
insert into public.follows(follower,followee)
select a,b from public.friendships where active and not public.blocked(a,b)
union select b,a from public.friendships where active and not public.blocked(a,b)
on conflict do nothing;

create schema if not exists private;
revoke all on schema private from public,anon;
grant usage on schema private to authenticated;

-- Private helpers prevent RLS recursion; all decisions are bound to the caller.
create function private.is_following(target uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and not public.blocked(auth.uid(),target)
 and exists(select 1 from public.follows where follower=auth.uid() and followee=target)
$$;
revoke all on function private.is_following(uuid) from public,anon,authenticated;
grant execute on function private.is_following(uuid) to authenticated;
create policy followed_profile_read on public.profiles for select to authenticated
using(private.is_following(id));

create or replace function public.can_post(p uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.posts t where t.id=p
 and t.deleted_at is null and not public.blocked(auth.uid(),t.author)
 and (t.author=auth.uid() or private.is_following(t.author) or exists(
 select 1 from public.post_participants pp where pp.post_id=p and pp.visible
 and not public.blocked(auth.uid(),pp.user_id)
 and (pp.user_id=auth.uid() or private.is_following(pp.user_id)))))
$$;

create or replace function public.mention_can_view(post uuid, viewer uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select viewer is not null and exists(select 1 from public.posts p where p.id=post
 and p.deleted_at is null and not public.blocked(viewer,p.author)
 and (p.author=viewer or exists(select 1 from public.follows where follower=viewer and followee=p.author)
 or exists(select 1 from public.post_participants pp where pp.post_id=p.id and pp.visible
 and not public.blocked(viewer,pp.user_id) and (pp.user_id=viewer or exists(
 select 1 from public.follows where follower=viewer and followee=pp.user_id)))))
$$;
revoke all on function public.mention_can_view(uuid,uuid) from public,anon,authenticated;

-- An invitation, following, or a known session ID never reveals session details.
create or replace function public.can_session(s uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.sessions t where t.id=s
 and (t.organizer=auth.uid() or (not public.blocked(auth.uid(),t.organizer)
 and exists(select 1 from public.session_participants p where p.session_id=s
 and p.user_id=auth.uid() and p.rsvp='going'))))
$$;

create function private.training_invitations() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'organizer',organizer,'organizer_name',name) order by id),'[]'::jsonb)
 from (select s.id,s.organizer,h.name from public.sessions s
 join public.session_participants p on p.session_id=s.id
 join public.profiles h on h.id=s.organizer
 where auth.uid() is not null and p.user_id=auth.uid() and p.rsvp='invited'
 and s.status='planned' and not public.blocked(auth.uid(),s.organizer)
 order by s.id limit 100) invitations
$$;
revoke all on function private.training_invitations() from public,anon,authenticated;
grant execute on function private.training_invitations() to authenticated;

-- No session details in public link previews, including cached social crawler responses.
create or replace function public.invitation_preview(link_kind text, token text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare cap public.capabilities;
begin
 if link_kind not in ('friend','session','goal') or token is null or token !~ '^[a-fA-F0-9]{64}$' then return null; end if;
 select * into cap from public.capabilities c where c.kind=link_kind
 and c.token_hash=extensions.digest(lower(token),'sha256') and not c.revoked and c.expires_at>now();
 if not found then return null; end if;
 if link_kind='session' and not exists(select 1 from public.sessions s where s.id=cap.session_id and s.organizer=cap.owner and s.status='planned') then return null; end if;
 if link_kind='goal' and not exists(select 1 from public.shared_goals g where g.id=cap.goal_id and g.owner=cap.owner and g.deleted_at is null) then return null; end if;
 return jsonb_build_object('kind',link_kind);
end $$;
comment on function public.invitation_preview(text,text) is 'Generic invitation type only. Session details require authenticated acceptance.';
update public.notifications set message='invited you to train' where kind='invite';
update public.notifications set message='started following you' where kind='friend';

-- Patch only the relevant command branches; preserve locks, receipts and other commands.
do $migration$
declare definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
begin
 if strpos(definition,$old$if not public.are_friends(actor,person) then raise exception 'Invite friends only'; end if;$old$)=0 then raise exception 'Command changed; review follow/invitation migration'; end if;
 definition:=replace(definition,$old$if not public.are_friends(actor,person) then raise exception 'Invite friends only'; end if;$old$,$new$if not private.is_following(person) then raise exception 'Follow someone before inviting them'; end if;$new$);
 if strpos(definition,$old$if person=actor or not public.are_friends(actor,person) then raise exception 'Invite friends only'; end if;$old$)=0 then raise exception 'Command changed; review follow/invitation migration'; end if;
 definition:=replace(definition,$old$if person=actor or not public.are_friends(actor,person) then raise exception 'Invite friends only'; end if;$old$,$new$if person=actor or not private.is_following(person) then raise exception 'Follow someone before inviting them'; end if;$new$);
 if strpos(definition,$old$if not public.are_friends(actor,person) then raise exception 'Friends only'; end if;$old$)=0 then raise exception 'Command changed; review follow/invitation migration'; end if;
 definition:=replace(definition,$old$if not public.are_friends(actor,person) then raise exception 'Friends only'; end if;$old$,$new$if not private.is_following(person) then raise exception 'Follow someone before inviting them'; end if;$new$);
 if strpos(definition,$old$'invited you to '||s.title$old$)=0 then raise exception 'Command changed; review follow/invitation migration'; end if;
 definition:=replace(definition,$old$'invited you to '||s.title$old$,$new$'invited you to train'$new$);
 if strpos(definition,$old$result:=jsonb_build_object('id',cap.owner);$old$)=0 then raise exception 'Command changed; review follow/invitation migration'; end if;
 definition:=replace(definition,$old$result:=jsonb_build_object('id',cap.owner);$old$,$new$insert into public.follows(follower,followee) values(actor,cap.owner) on conflict do nothing;
 result:=jsonb_build_object('id',cap.owner);$new$);
 if strpos(definition,$old$public.are_friends(actor,target) or public.in_circle(actor,target) or public.listed_partner(actor,target)$old$)=0 then raise exception 'Command changed; review follow/invitation migration'; end if;
 definition:=replace(definition,$old$public.are_friends(actor,target) or public.in_circle(actor,target) or public.listed_partner(actor,target)$old$,$new$private.is_following(target) or public.are_friends(actor,target) or public.in_circle(actor,target) or public.listed_partner(actor,target)$new$);
 if strpos(definition,$old$insert into public.session_participants values(s.id,actor,'going',false) on conflict(session_id,user_id) do nothing;$old$)=0 then raise exception 'Command changed; review follow/invitation migration'; end if;
 definition:=replace(definition,$old$insert into public.session_participants values(s.id,actor,'going',false) on conflict(session_id,user_id) do nothing;$old$,$new$insert into public.session_participants values(s.id,actor,'invited',false) on conflict(session_id,user_id) do nothing;$new$);
 if strpos(definition,$old$ if s.status<>'planned' or public.blocked(actor,s.organizer) then raise exception 'Session unavailable'; end if;
 if coalesce(payload->>'rsvp','') not in ('going','declined') then raise exception 'Invalid RSVP'; end if;
 if not exists(select 1 from public.session_participants where session_id=s.id and user_id=actor) then
 -- Feed discovery permits friends to join an upcoming link-visible plan only.
 if payload->>'rsvp'<>'going' or s.join_mode<>'link' or s.starts_at<=now() or not public.are_friends(actor,s.organizer) then raise exception 'Invitation required'; end if;
 insert into public.session_participants values(s.id,actor,'going',false);
 else
 update public.session_participants set rsvp=payload->>'rsvp' where session_id=s.id and user_id=actor;
 end if;$old$)=0 then raise exception 'Command changed; review follow/invitation migration'; end if;
 definition:=replace(definition,$old$ if s.status<>'planned' or public.blocked(actor,s.organizer) then raise exception 'Session unavailable'; end if;
 if coalesce(payload->>'rsvp','') not in ('going','declined') then raise exception 'Invalid RSVP'; end if;
 if not exists(select 1 from public.session_participants where session_id=s.id and user_id=actor) then
 -- Feed discovery permits friends to join an upcoming link-visible plan only.
 if payload->>'rsvp'<>'going' or s.join_mode<>'link' or s.starts_at<=now() or not public.are_friends(actor,s.organizer) then raise exception 'Invitation required'; end if;
 insert into public.session_participants values(s.id,actor,'going',false);
 else
 update public.session_participants set rsvp=payload->>'rsvp' where session_id=s.id and user_id=actor;
 end if;$old$,$new$ if s.status<>'planned' or public.blocked(actor,s.organizer) then raise exception 'Session unavailable'; end if;
 if coalesce(payload->>'rsvp','') not in ('going','declined') then raise exception 'Invalid RSVP'; end if;
 if not exists(select 1 from public.session_participants where session_id=s.id and user_id=actor) then raise exception 'Invitation required'; end if;
 if actor=s.organizer and payload->>'rsvp'<>'going' then raise exception 'Organizer cannot decline'; end if;
 update public.session_participants set rsvp=payload->>'rsvp' where session_id=s.id and user_id=actor;
 update public.notifications set read_at=now() where recipient=actor and entity_id=s.id and kind='invite' and read_at is null;$new$);
 definition:=replace(definition,'added you as a training partner','started following you');
 execute definition;
end $migration$;

do $snapshot$
declare definition text := pg_get_functiondef('public.snapshot()'::regprocedure);
 old_branch text := $old$ 'activity_sessions',coalesce((select jsonb_agg(t) from (select * from public.sessions s
  where status='planned' and join_mode='link' and starts_at>now() and organizer<>auth.uid()
  and not exists(select 1 from public.session_participants p where p.session_id=s.id and p.user_id=auth.uid())
  order by starts_at,id limit 100) t),'[]'::jsonb),
$old$;
 new_branch text := $new$ 'activity_sessions','[]'::jsonb,
 'training_invitations',private.training_invitations(),
$new$;
begin
 if strpos(definition,old_branch)=0 then raise exception 'Snapshot changed; review follow/invitation migration'; end if;
 execute replace(definition,old_branch,new_branch);
end $snapshot$;
