-- Restore the summary contract consumed by the published invitation website.
-- The hosted follows_and_private_invitations migration reduced this response to
-- {kind: "session"}; the website rejects that incomplete shape and returns 503.
-- A complete, active bearer link permits this limited preview. Full notes, nested
-- focus details and IDs stay private; this read never accepts or redeems a link.
-- Intentionally public, read-only bearer-link API for social preview crawlers.
-- A full, active 256-bit invitation token is the authorization. No table grants
-- or RLS policies change; viewing a preview never joins/redeems the invitation.
create or replace function public.invitation_preview(link_kind text, token text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
 cap public.capabilities;
 session public.sessions;
 content jsonb;
 focuses jsonb := '[]'::jsonb;
begin
 if link_kind not in ('friend','session','goal') or token is null
    or token !~ '^[a-fA-F0-9]{64}$' then return null; end if;
 select * into cap from public.capabilities c
 where c.kind=link_kind and c.token_hash=extensions.digest(lower(token),'sha256')
 and not c.revoked and c.expires_at>now();
 if not found then return null; end if;
 if link_kind='friend' then return jsonb_build_object('kind','friend'); end if;
 if link_kind='goal' then
   if not exists(select 1 from public.shared_goals g where g.id=cap.goal_id
                 and g.owner=cap.owner and g.deleted_at is null) then return null; end if;
   -- Goal contents remain private, including the title.
   return jsonb_build_object('kind','goal');
 end if;
 select * into session from public.sessions s
 where s.id=cap.session_id and s.organizer=cap.owner and s.status='planned';
 if not found then return null; end if;
 -- SessionNoteCodec v1: decode locally; never return notes or nested details.
 if session.note like 'matmind-focus-v1:%' then
   begin
     content := convert_from(decode(substr(session.note,18),'base64'),'UTF8')::jsonb;
     if jsonb_typeof(content->'focus')='array' then
       select coalesce(jsonb_agg(f.title order by f.position),'[]'::jsonb) into focuses
       from (select left(trim(item->>'title'),120) as title, position
             from jsonb_array_elements(content->'focus') with ordinality as items(item,position)
             where jsonb_typeof(item->'title')='string' and length(trim(item->>'title'))>0
             order by position limit 3) f;
     end if;
   exception when data_exception then focuses := '[]'::jsonb;
   end;
 end if;
 return jsonb_build_object(
   'kind','session', 'title',session.title, 'starts_at',session.starts_at,
   'timezone',session.timezone, 'venue',session.venue, 'focus',focuses,
   'participants',coalesce((select jsonb_agg(p.name order by p.organizer desc,p.name,p.user_id)
       from (select left(pr.name,80) as name, sp.user_id, sp.user_id=session.organizer as organizer
             from public.session_participants sp join public.profiles pr on pr.id=sp.user_id
             where sp.session_id=session.id and sp.rsvp='going'
             and not public.blocked(session.organizer,sp.user_id)
             order by (sp.user_id=session.organizer) desc,pr.name,sp.user_id limit 3) p),'[]'::jsonb),
   'participant_count',(select count(*) from public.session_participants sp
       where sp.session_id=session.id and sp.rsvp='going'
       and not public.blocked(session.organizer,sp.user_id)));
end $$;
revoke all on function public.invitation_preview(text,text) from public,anon,authenticated;
grant execute on function public.invitation_preview(text,text) to anon,authenticated,service_role;
comment on function public.invitation_preview(text,text) is
 'Intentional anonymous read-only preview; requires an active bearer invitation. Exposes only the approved session summary, never notes, nested focus details or IDs.';
