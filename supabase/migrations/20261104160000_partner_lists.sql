-- Training partner lists on someone else's profile.
-- You can see the full partner list of anyone in your circle (your partners and
-- the people they train with): name, belt, gym, username and photo of each
-- partner. Those partners' profiles become readable, and nothing else does:
-- posts keep their rules, and name search still covers only your circle.

-- target trains with someone whose partner list viewer may see, and they haven't blocked each other.
create function public.listed_partner(viewer uuid,target uuid) returns boolean language sql stable security definer set search_path='' as $$
 select not public.blocked(viewer,target) and exists(
 select 1 from public.friendships f where f.active and target in (f.a,f.b)
 and not public.blocked(f.a,f.b)
 and (public.are_friends(viewer,case when f.a=target then f.b else f.a end)
 or public.in_circle(viewer,case when f.a=target then f.b else f.a end)))
$$;
revoke all on function public.listed_partner(uuid,uuid) from public,anon;
grant execute on function public.listed_partner(uuid,uuid) to authenticated;

drop policy profile_read on public.profiles;
create policy profile_read on public.profiles for select to authenticated using (id=auth.uid() or public.are_friends(auth.uid(),id)
 or public.in_circle(auth.uid(),id)
 or public.listed_partner(auth.uid(),id)
 or exists(select 1 from public.session_participants p where p.user_id=id and public.can_session(p.session_id))
 or exists(select 1 from public.post_participants p where p.user_id=id and public.can_post(p.post_id))
 or exists(select 1 from public.shared_goals g where g.owner=profiles.id and public.can_goal(g.id))
 or exists(select 1 from public.goal_shares s join public.shared_goals g on g.id=s.goal_id where s.recipient=profiles.id and g.owner=auth.uid()));

-- A person's training partners, your own partners first, then by name. Null when
-- you can't see their list (they're outside your circle, or one of you blocked the other).
create function public.partners_of(person uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select case when auth.uid() is null or person is null or public.blocked(auth.uid(),person)
 or not (person=auth.uid() or public.are_friends(auth.uid(),person) or public.in_circle(auth.uid(),person)) then null
 else coalesce((
 select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'belt',p.belt,'stripes',p.stripes,'gym',p.gym,'avatar_key',p.avatar_key,'username',p.username)
 order by public.are_friends(auth.uid(),p.id) desc,p.name,p.id)
 from public.friendships f join public.profiles p on p.id=case when f.a=person then f.b else f.a end
 where f.active and person in (f.a,f.b) and not public.blocked(f.a,f.b) and not public.blocked(auth.uid(),p.id)),'[]'::jsonb)
 end
$$;
revoke all on function public.partners_of(uuid) from public,anon;
grant execute on function public.partners_of(uuid) to authenticated;
