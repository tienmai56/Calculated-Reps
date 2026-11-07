-- A pending invite authorizes reading the plan before answering it. Keep these
-- details separate from accepted sessions so they never count as attendance,
-- appear in Coming up, or grant access to session photos and write operations.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create or replace function private.invitation_previews() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',s.id,'title',s.title,'venue',s.venue,'starts_at',s.starts_at,
   'timezone',s.timezone,'join_mode',s.join_mode,'note',s.note,
   'participants',coalesce((
     select jsonb_agg(jsonb_build_object('user_id',guest.user_id,'name',profile.name,'rsvp',guest.rsvp)
                      order by (guest.user_id=s.organizer) desc,profile.name,guest.user_id)
     from public.session_participants guest join public.profiles profile on profile.id=guest.user_id
     where guest.session_id=s.id and not public.blocked(auth.uid(),guest.user_id)
       and not public.blocked(s.organizer,guest.user_id)
   ),'[]'::jsonb)
 ) order by s.starts_at,s.id),'[]'::jsonb)
 from public.session_participants p
 join public.sessions s on s.id=p.session_id
 where p.user_id=auth.uid() and p.rsvp='invited' and s.status='planned'
   and s.organizer<>auth.uid() and not public.blocked(auth.uid(),s.organizer);
$$;
revoke all on function private.invitation_previews() from public,anon;
grant execute on function private.invitation_previews() to authenticated;
comment on function private.invitation_previews() is
 'Read-only plan details for the authenticated pending invitee; never accepts an invitation or grants photo access.';

commit;
