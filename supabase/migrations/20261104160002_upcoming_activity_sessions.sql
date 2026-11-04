-- Upcoming link-visible sessions appear in the host's and the host's friends' Activity.
-- Completed memories remain separate posts; discovery never grants attendance credit.
-- Extend the existing RLS helper while preserving hosts' and participants' access.
create or replace function public.can_session(s uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists (
  select 1 from public.sessions t where t.id=s and (
   t.organizer=auth.uid() or (
    not public.blocked(auth.uid(),t.organizer) and (
     exists(select 1 from public.session_participants p where p.session_id=s and p.user_id=auth.uid())
     or (t.status='planned' and t.join_mode='link' and t.starts_at>now() and public.are_friends(auth.uid(),t.organizer))
    )
   )
  )
 );
$$;
revoke all on function public.can_session(uuid) from public,anon;
grant execute on function public.can_session(uuid) to authenticated;

-- Extend only RSVP handling, preserving later session-editing and comment commands.
-- Retain the command's actor lock, rate limit, grants and retry receipts.
do $migration$
declare
 definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 old_branch text := $old$ if s.status<>'planned' or not exists(select 1 from public.session_participants where session_id=s.id and user_id=actor) then raise exception 'Invitation required'; end if;
 if payload->>'rsvp' not in ('going','declined') then raise exception 'Invalid RSVP'; end if;
 update public.session_participants set rsvp=payload->>'rsvp' where session_id=s.id and user_id=actor;$old$;
 new_branch text := $new$ if s.status<>'planned' or public.blocked(actor,s.organizer) then raise exception 'Session unavailable'; end if;
 if coalesce(payload->>'rsvp','') not in ('going','declined') then raise exception 'Invalid RSVP'; end if;
 if not exists(select 1 from public.session_participants where session_id=s.id and user_id=actor) then
 -- Feed discovery permits friends to join an upcoming link-visible plan only.
 if payload->>'rsvp'<>'going' or s.join_mode<>'link' or s.starts_at<=now() or not public.are_friends(actor,s.organizer) then raise exception 'Invitation required'; end if;
 insert into public.session_participants values(s.id,actor,'going',false);
 else
 update public.session_participants set rsvp=payload->>'rsvp' where session_id=s.id and user_id=actor;
 end if;$new$;
begin
 if strpos(definition,old_branch)=0 then
  raise exception 'Session command changed; review Activity join migration';
 end if;
 execute replace(definition,old_branch,new_branch);
end $migration$;

-- Discovery has a separate, bounded list; personal sessions retain their own quota.
create or replace function public.snapshot() returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object(
 'server_time',now(),
 'profiles',coalesce((select jsonb_agg(t) from public.profiles t),'[]'::jsonb),
 'friendships',coalesce((select jsonb_agg(t) from public.friendships t where active),'[]'::jsonb),
 'sessions',coalesce((select jsonb_agg(t) from (select * from public.sessions s where status<>'cancelled'
  and (organizer=auth.uid() or exists(select 1 from public.session_participants p where p.session_id=s.id and p.user_id=auth.uid()))
  order by starts_at desc,id desc limit 100) t),'[]'::jsonb),
 'activity_sessions',coalesce((select jsonb_agg(t) from (select * from public.sessions s
  where status='planned' and join_mode='link' and starts_at>now() and organizer<>auth.uid()
  and not exists(select 1 from public.session_participants p where p.session_id=s.id and p.user_id=auth.uid())
  order by starts_at,id limit 100) t),'[]'::jsonb),
 'participants',coalesce((select jsonb_agg(t) from public.session_participants t),'[]'::jsonb),
 'posts',coalesce((select jsonb_agg(t) from (select * from public.posts where deleted_at is null order by published_at desc,id desc limit 30) t),'[]'::jsonb),
 'tags',coalesce((select jsonb_agg(t) from public.post_participants t where visible),'[]'::jsonb),
 'likes',coalesce((select jsonb_agg(t) from public.post_likes t),'[]'::jsonb),
 'comments',coalesce((select jsonb_agg(t) from (select * from public.comments order by created_at desc limit 300) t),'[]'::jsonb),
 'credits',coalesce((select jsonb_agg(t) from public.friendship_session_credits t),'[]'::jsonb),
 'media',coalesce((select jsonb_agg(t) from public.media_assets t where state='ready'),'[]'::jsonb),
 'notifications',coalesce((select jsonb_agg(t) from (select * from public.notifications order by created_at desc limit 100) t),'[]'::jsonb),
 'shared_goals',coalesce((select jsonb_agg(t) from (select * from public.shared_goals where deleted_at is null order by updated_at desc limit 200) t),'[]'::jsonb),
 'goal_shares',coalesce((select jsonb_agg(t) from (select * from public.goal_shares order by created_at desc limit 1000) t),'[]'::jsonb),
 'circle',public.my_circle(),
 'follows',coalesce((select jsonb_agg(t) from public.follows t),'[]'::jsonb));
$$;
revoke all on function public.snapshot() from public,anon;
grant execute on function public.snapshot() to authenticated;
