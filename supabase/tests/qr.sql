\set ON_ERROR_STOP on
begin;
insert into auth.users values('00000000-0000-0000-0000-000000000011'),('00000000-0000-0000-0000-000000000012');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000011',true);
select public.command('save_profile','{"name":"X"}',gen_random_uuid());
select public.command('friend_token','{}',gen_random_uuid())->>'token' as token \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000012',true);
select public.command('save_profile','{"name":"Y"}',gen_random_uuid());
select public.command('redeem_friend',jsonb_build_object('token',:'token'),gen_random_uuid());
select public.command('redeem_friend',jsonb_build_object('token',:'token'),gen_random_uuid());
do $$ begin if (select count(*) from public.friendships)<>1 then raise exception 'QR replay duplicated friendship'; end if; end $$;
select public.post_details('00000000-0000-0000-0000-000000000099');
select * from public.feed_page();
select * from public.comment_page('00000000-0000-0000-0000-000000000099');
select public.command('block_user','{"user_id":"00000000-0000-0000-0000-000000000011"}',gen_random_uuid());
do $$ begin if public.are_friends('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000012') then raise exception 'Block did not remove friendship visibility'; end if; end $$;
-- Device registration must upsert by the table constraint, not the local
-- PL/pgSQL token variable. Unregister must remove only the caller's token.
select public.command('register_device',jsonb_build_object('token',repeat('a',64),'environment','sandbox'),gen_random_uuid());
select public.command('register_device',jsonb_build_object('token',repeat('a',64),'environment','sandbox'),gen_random_uuid());
reset role;
do $$ begin if (select count(*) from public.device_tokens)<>1 then raise exception 'Device registration did not upsert'; end if; end $$;
set local role authenticated;
select public.command('unregister_device',jsonb_build_object('token',repeat('a',64)),gen_random_uuid());
reset role;
do $$ begin if exists(select 1 from public.device_tokens) then raise exception 'Logout did not unregister device'; end if; end $$;
-- Hosted defaults must not expose social RPCs or internal helpers anonymously.
do $$ begin
 if exists(
   select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and has_function_privilege('anon',p.oid,'EXECUTE')
   and p.oid<>'public.invitation_preview(text,text)'::regprocedure
 ) then raise exception 'An app function is anonymously executable'; end if;
 if has_function_privilege('authenticated','public.emit_notification(uuid,uuid,text,uuid,text,text)','EXECUTE')
 or has_function_privilege('authenticated','public.rebuild_credits(uuid)','EXECUTE') then
   raise exception 'A client can call an internal write helper';
 end if;
end $$;
rollback;
