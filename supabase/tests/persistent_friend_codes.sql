\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000021'),
 ('00000000-0000-0000-0000-000000000022'),
 ('00000000-0000-0000-0000-000000000023');
do $$
declare
 owner_id uuid := '00000000-0000-0000-0000-000000000021';
 partner uuid := '00000000-0000-0000-0000-000000000022';
 other_partner uuid := '00000000-0000-0000-0000-000000000023';
 first_code text; next_code text; session_code text; session_id uuid;
begin
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 perform public.command('save_profile','{"name":"Code owner"}',gen_random_uuid());
 first_code:=public.command('friend_token','{}',gen_random_uuid())->>'token';
 next_code:=public.command('friend_token','{}',gen_random_uuid())->>'token';
 if first_code is distinct from next_code then raise exception 'Opening My code replaced the friend code'; end if;
 if not exists(select 1 from public.capabilities where token_hash=extensions.digest(first_code,'sha256') and not revoked and expires_at='infinity'::timestamptz) then
 raise exception 'Friend code expires automatically'; end if;

 perform set_config('request.jwt.claim.sub',partner::text,true);
 perform public.command('save_profile','{"name":"First partner"}',gen_random_uuid());
 perform public.command('redeem_friend',jsonb_build_object('token',first_code),gen_random_uuid());
 perform public.command('redeem_friend',jsonb_build_object('token',first_code),gen_random_uuid());
 if (select count(*) from public.friendships where a=least(owner_id,partner) and b=greatest(owner_id,partner))<>1 then
 raise exception 'Scanning twice duplicated friendship'; end if;

 perform set_config('request.jwt.claim.sub',other_partner::text,true);
 perform public.command('save_profile','{"name":"Second partner"}',gen_random_uuid());
 perform public.command('redeem_friend',jsonb_build_object('token',first_code),gen_random_uuid());
 if not public.are_friends(owner_id,other_partner) then raise exception 'Code cannot be shared with multiple partners'; end if;

 perform public.command('block_user',jsonb_build_object('user_id',owner_id),gen_random_uuid());
 begin
 perform public.command('redeem_friend',jsonb_build_object('token',first_code),gen_random_uuid());
 raise exception 'Blocked user redeemed code';
 exception when raise_exception then
 if sqlerrm<>'Link expired or unavailable' then raise; end if;
 end;

 -- Revocation must still work and must never be undone by opening My code.
 update public.capabilities set revoked=true where token_hash=extensions.digest(first_code,'sha256');
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 next_code:=public.command('friend_token','{}',gen_random_uuid())->>'token';
 if next_code=first_code then raise exception 'Revoked friend code was reused'; end if;
 perform set_config('request.jwt.claim.sub',partner::text,true);
 begin
 perform public.command('redeem_friend',jsonb_build_object('token',first_code),gen_random_uuid());
 raise exception 'Revoked code accepted';
 exception when raise_exception then
 if sqlerrm<>'Link expired or unavailable' then raise; end if;
 end;

 -- Session codes retain their existing one-day expiry and rotation behavior.
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 session_id:=(public.command('create_session',jsonb_build_object('title','Class','starts_at',now()+interval '1 day','timezone','UTC','venue','Gym'),gen_random_uuid())->>'id')::uuid;
 session_code:=public.command('session_token',jsonb_build_object('session_id',session_id),gen_random_uuid())->>'token';
 perform public.command('session_token',jsonb_build_object('session_id',session_id),gen_random_uuid());
 if not exists(select 1 from public.capabilities where token_hash=extensions.digest(session_code,'sha256') and revoked and expires_at=now()+interval '1 day') then
 raise exception 'Session token rotation or expiry changed'; end if;
 if public.command('friend_token','{}',gen_random_uuid())->>'token' is distinct from next_code then
 raise exception 'Creating a session invite invalidated friend code'; end if;
end $$;
rollback;
