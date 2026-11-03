-- Opening My code must not revoke an invitation already on another screen.
-- Friend codes are reusable identifiers; session invitations keep their expiry.
-- Preserve explicit revocations and every other command/permission unchanged.
do $migration$
declare
 definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 old_branch text := $old$ elsif operation in ('friend_token','session_token') then
 entity:=nullif(payload->>'session_id','')::uuid;
 if operation='session_token' and not exists(select 1 from public.sessions where id=entity and organizer=actor and status='planned') then raise exception 'Organizer required'; end if;
 update public.capabilities set revoked=true where owner=actor and kind=case when operation='friend_token' then 'friend' else 'session' end and session_id is not distinct from entity;
 token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.capabilities(owner,kind,session_id,token_hash,expires_at) values(actor,case when operation='friend_token' then 'friend' else 'session' end,entity,extensions.digest(token,'sha256'),now()+interval '1 day');
 result:=jsonb_build_object('token',token);$old$;
 new_branch text := $new$ elsif operation='friend_token' then
 -- Commands are serialized per actor above, including across devices.
 -- Recover the caller's existing code only if its capability is still active.
 select r.result->>'token' into token
 from public.command_receipts r
 join public.capabilities issued_capability on issued_capability.token_hash=extensions.digest(r.result->>'token','sha256')
 where r.actor=actor and r.operation='friend_token'
 and issued_capability.owner=actor and issued_capability.kind='friend'
 and issued_capability.session_id is null and not issued_capability.revoked
 order by r.created_at desc,r.key limit 1;
 if token is null then
 token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.capabilities(owner,kind,token_hash,expires_at)
 values(actor,'friend',extensions.digest(token,'sha256'),'infinity'::timestamptz);
 end if;
 result:=jsonb_build_object('token',token);
 elsif operation='session_token' then
 entity:=nullif(payload->>'session_id','')::uuid;
 if not exists(select 1 from public.sessions where id=entity and organizer=actor and status='planned') then raise exception 'Organizer required'; end if;
 update public.capabilities set revoked=true where owner=actor and kind='session' and session_id=entity;
 token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.capabilities(owner,kind,session_id,token_hash,expires_at)
 values(actor,'session',entity,extensions.digest(token,'sha256'),now()+interval '1 day');
 result:=jsonb_build_object('token',token);$new$;
begin
 -- Fail rather than silently overwrite a command that has changed since review.
 if strpos(definition,old_branch)=0 then
 raise exception 'Invitation command changed; review persistent friend code migration';
 end if;
 execute replace(definition,old_branch,new_branch);
end $migration$;

-- Upgrade existing active friend codes, including ones past the old day limit.
-- Previously revoked codes stay revoked; blocked users still cannot redeem.
update public.capabilities set expires_at='infinity'::timestamptz
where kind='friend' and not revoked;
