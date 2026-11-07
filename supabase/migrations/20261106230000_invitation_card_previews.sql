-- Invitation cards (Notifications › Invites and the Activity Invites card) preview
-- each pending invitation's session title and venue, so members can tell their
-- invitations apart before answering. Product decision, 2026-11-06.
--
-- Only `title` and `venue` are returned. The start time, notes, focus and guest
-- list stay private until the invitee accepts, as before. Invitations from a
-- blocked host, cancelled or completed sessions, and your own sessions are left out.
-- The existing `training_invitations` snapshot key is unchanged; clients merge
-- `invitation_previews` into it by session id and fall back to the generic card.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create function private.invitation_previews() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'title',s.title,'venue',s.venue) order by s.starts_at,s.id),'[]'::jsonb)
 from public.session_participants p
 join public.sessions s on s.id=p.session_id
 where p.user_id=auth.uid() and p.rsvp='invited' and s.status='planned'
   and s.organizer<>auth.uid() and not public.blocked(auth.uid(),s.organizer);
$$;
revoke all on function private.invitation_previews() from public,anon;
grant execute on function private.invitation_previews() to authenticated;

alter function public.snapshot() rename to snapshot_before_invitation_previews;
revoke all on function public.snapshot_before_invitation_previews() from public,anon;
create function public.snapshot() returns jsonb language sql stable security invoker set search_path='' as $$
 select public.snapshot_before_invitation_previews() || jsonb_build_object(
 'invitation_previews',private.invitation_previews());
$$;
revoke all on function public.snapshot() from public,anon;
grant execute on function public.snapshot() to authenticated;

commit;
