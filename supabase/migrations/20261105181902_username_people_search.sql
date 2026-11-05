-- Explicit username lookup outside the training circle. This intentionally does
-- not widen profile RLS, suggestions, or name search into a public directory.
create schema if not exists private;
revoke all on schema private from public,anon;
grant usage on schema private to authenticated;

create index profiles_username_prefix on public.profiles(username text_pattern_ops);

create function private.search_usernames(query text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid := auth.uid(); term text := lower(btrim(coalesce(query,''))); result jsonb;
begin
 if left(term,1)='@' then term:=substr(term,2); end if;
 if actor is null or term !~ '^[a-z0-9_]{3,40}$'
 or not exists(select 1 from public.profiles where id=actor) then return '[]'::jsonb; end if;
 select coalesce(jsonb_agg(to_jsonb(p) order by (p.username=term) desc,p.username,p.id),'[]'::jsonb)
 into result from (
  select id,name,username,belt,stripes,gym,monkey from public.profiles
  where username like replace(term,'_','\_')||'%' escape '\'
  and id<>actor and not public.blocked(actor,id)
  order by (username=term) desc,username,id limit 20
 ) p;
 return result;
end $$;
revoke all on function private.search_usernames(text) from public,anon,authenticated;
grant execute on function private.search_usernames(text) to authenticated;

create function public.search_usernames(query text) returns jsonb
language sql stable security invoker set search_path='' as $$
 select private.search_usernames(query)
$$;
revoke all on function public.search_usernames(text) from public,anon,authenticated;
grant execute on function public.search_usernames(text) to authenticated;

-- A username is another way to identify the person whose QR code you'd scan.
-- Resolve it on the server, then share the scan branch, notifications, locks,
-- rate limits and retry receipts. Keep all unrelated command branches intact.
do $migration$
declare
 definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 old_lookup text := $old$ elsif operation in ('redeem_friend','join_link') then
 select * into cap from public.capabilities where token_hash=extensions.digest(payload->>'token','sha256') and not revoked and expires_at>now();
 if not found or public.blocked(actor,cap.owner) then raise exception 'Link expired or unavailable'; end if;
 if operation='redeem_friend' then$old$;
 new_lookup text := $new$ elsif operation in ('redeem_friend','join_link','follow_username') then
 if operation='follow_username' then
 token:=lower(btrim(coalesce(payload->>'username','')));
 if left(token,1)='@' then token:=substr(token,2); end if;
 if token !~ '^[a-z0-9_]{3,40}$' then raise exception 'Username unavailable. Search again'; end if;
 select id into target from public.profiles where username=token;
 -- Bind the handle to the selected person, even if it changed owners since search.
 if target is null or target=actor or public.blocked(actor,target)
 or target is distinct from nullif(payload->>'user_id','')::uuid then
 raise exception 'Username unavailable. Search again'; end if;
 cap.owner:=target; cap.kind:='friend';
 else
 select * into cap from public.capabilities where token_hash=extensions.digest(payload->>'token','sha256') and not revoked and expires_at>now();
 if not found or public.blocked(actor,cap.owner) then raise exception 'Link expired or unavailable'; end if;
 end if;
 if operation in ('redeem_friend','follow_username') then$new$;
begin
 if strpos(definition,old_lookup)=0 then
  raise exception 'Scan command changed; review username follow migration';
 end if;
 definition:=replace(definition,old_lookup,new_lookup);
 -- Older local migration chains predate the deployed follow/invitation migration.
 -- Both entry points must persist the same follow on those chains as well.
 if strpos(definition,'insert into public.follows(follower,followee) values(actor,cap.owner)')=0 then
  definition:=replace(definition,$old$result:=jsonb_build_object('id',cap.owner);$old$,
   $new$insert into public.follows(follower,followee) values(actor,cap.owner) on conflict do nothing;
 result:=jsonb_build_object('id',cap.owner);$new$);
 end if;
 execute definition;
end $migration$;
