-- Follow and friend-code redemption establish the same mutual training partnership.
-- Keep the existing authorization rules for posts, invitations and shared notes.
-- Internal invoker helper: only the already-authorized command can call it.
create function public.connect_training_partner(target uuid,notification_key uuid) returns void
language plpgsql security invoker set search_path='' as $$
declare actor uuid:=auth.uid(); was_friend boolean; zone text;
begin
 if actor is null then raise exception 'Authentication required'; end if;
 if target is null or target=actor then raise exception 'Training partner unavailable'; end if;
 -- Serialize both directions, so simultaneous follows/scans notify only once.
 perform pg_advisory_xact_lock(hashtextextended(least(actor,target)::text||greatest(actor,target)::text,0));
 if public.blocked(actor,target) then raise exception 'Training partner unavailable'; end if;
 was_friend:=public.are_friends(actor,target);
 select timezone into zone from public.account_settings where user_id=target;
 insert into public.friendships(a,b,timezone)
 values(least(actor,target),greatest(actor,target),coalesce(zone,'UTC'))
 on conflict(a,b) do update set active=true,
 connected_at=case when public.friendships.active then public.friendships.connected_at else now() end;
 insert into public.follows(follower,followee) values(actor,target),(target,actor) on conflict do nothing;
 if not was_friend then
 perform public.emit_notification(target,actor,'friend',actor,'added you as a training partner',notification_key::text);
 end if;
end $$;
revoke all on function public.connect_training_partner(uuid,uuid) from public,anon,authenticated,service_role;

-- Patch just these branches, preserving later fixes to all other commands.
do $migration$
declare definition text:=pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 old_qr text:=$old$ select timezone into zone from public.account_settings where user_id=cap.owner;
 was_friend:=public.are_friends(actor,cap.owner);
 insert into public.friendships(a,b,timezone) values(least(actor,cap.owner),greatest(actor,cap.owner),coalesce(zone,'UTC')) on conflict(a,b) do update set active=true,connected_at=case when public.friendships.active then public.friendships.connected_at else now() end;
 -- Tell the code's owner someone new connected (re-scanning an active friendship stays quiet).
 if not was_friend then perform public.emit_notification(cap.owner,actor,'friend',actor,'added you as a training partner',idempotency_key::text); end if;
$old$;
 old_follow text:=$old$ elsif operation='set_follow' then
 -- One-way and instant, no approval. Only people in your circle (your training partners and
 -- the people they train with), or on a partner list you can see (20261104160000_partner_lists.sql).
 target:=(payload->>'user_id')::uuid;
 if target is null or target=actor then raise exception 'Choose someone to follow'; end if;
 if coalesce((payload->>'follow')::boolean,true) then
 if not (public.are_friends(actor,target) or public.in_circle(actor,target) or public.listed_partner(actor,target)) then raise exception 'You can follow people who train with your training partners'; end if;
 insert into public.follows(follower,followee) values(actor,target) on conflict do nothing;
 else
 delete from public.follows where follower=actor and followee=target;
 end if;
$old$;
 new_follow text:=$new$ elsif operation='set_follow' then
 target:=(payload->>'user_id')::uuid;
 if target is null or target=actor then raise exception 'Choose someone to follow'; end if;
 if coalesce((payload->>'follow')::boolean,true) then
 if not (public.are_friends(actor,target) or public.in_circle(actor,target) or public.listed_partner(actor,target)) then raise exception 'You can follow people who train with your training partners'; end if;
 perform public.connect_training_partner(target,idempotency_key);
 else
 perform pg_advisory_xact_lock(hashtextextended(least(actor,target)::text||greatest(actor,target)::text,0));
 update public.friendships set active=false where a=least(actor,target) and b=greatest(actor,target);
 delete from public.follows where (follower=actor and followee=target) or (follower=target and followee=actor);
 end if;
$new$;
begin
 if strpos(definition,old_qr)=0 or strpos(definition,old_follow)=0 then
 raise exception 'Connection command changed; review training partner migration';
 end if;
 definition:=replace(definition,old_qr,' perform public.connect_training_partner(cap.owner,idempotency_key);'||chr(10));
 definition:=replace(definition,old_follow,new_follow);
 -- Blocking and connecting the same pair must serialize too.
 definition:=replace(definition,
  ' insert into public.blocks values(actor,target) on conflict do nothing;',
  ' perform pg_advisory_xact_lock(hashtextextended(least(actor,target)::text||greatest(actor,target)::text,0));'||chr(10)||
  ' insert into public.blocks values(actor,target) on conflict do nothing;');
 execute definition;
end $migration$;

-- Upgrade existing one-way follows without replaying connection notifications.
delete from public.follows where public.blocked(follower,followee);
insert into public.friendships(a,b,timezone)
select distinct on (least(f.follower,f.followee),greatest(f.follower,f.followee))
 least(f.follower,f.followee),greatest(f.follower,f.followee),coalesce(s.timezone,'UTC')
from public.follows f left join public.account_settings s on s.user_id=f.followee
order by least(f.follower,f.followee),greatest(f.follower,f.followee),f.created_at,f.follower
on conflict(a,b) do update set active=true,
 connected_at=case when public.friendships.active then public.friendships.connected_at else now() end;
insert into public.follows(follower,followee)
select a,b from public.friendships where active and not public.blocked(a,b)
union select b,a from public.friendships where active and not public.blocked(a,b)
on conflict do nothing;

-- A shared note or co-participant must never make a blocked profile readable.
create policy profile_unblocked on public.profiles as restrictive
for select to authenticated using(id=auth.uid() or not public.blocked(auth.uid(),id));
