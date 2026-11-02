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
rollback;
