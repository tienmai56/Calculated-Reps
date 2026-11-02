create function public.claim_notifications(batch_size int default 25) returns setof public.notification_outbox language sql security definer set search_path='' as $$
 update public.notification_outbox set attempts=attempts+1,next_attempt=now()+interval '5 minutes'
 where id in (select id from public.notification_outbox where delivered_at is null and next_attempt<=now() order by next_attempt for update skip locked limit least(batch_size,100)) returning *;
$$;
revoke all on function public.claim_notifications(int) from public,anon,authenticated;
grant execute on function public.claim_notifications(int) to service_role;

create function public.erase_social_account(target uuid) returns void language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
begin
 delete from public.command_receipts where actor=target;
 delete from public.notifications where recipient=target or actor=target;
 delete from public.device_tokens where user_id=target;
 delete from public.reports where reporter=target or post_id in(select id from public.posts where author=target);
 delete from public.comments where author=target or post_id in(select id from public.posts where author=target);
 delete from public.post_likes where user_id=target;
 delete from public.friendship_session_credits where friendship_id in(select id from public.friendships where target in(a,b)) or session_id in(select id from public.sessions where organizer=target);
 delete from public.friendships where target in(a,b);
 delete from public.post_participants where user_id=target;
 delete from public.posts where author=target;
 delete from public.media_assets where owner=target;
 delete from public.capabilities where owner=target or session_id in(select id from public.sessions where organizer=target);
 delete from public.session_participants where user_id=target;
 delete from public.sessions where organizer=target;
 delete from public.blocks where actor=target or public.blocks.target=erase_social_account.target;
 delete from public.account_settings where user_id=target;
 delete from public.profiles where id=target;
end $$;
revoke all on function public.erase_social_account(uuid) from public,anon,authenticated;
grant execute on function public.erase_social_account(uuid) to service_role;

-- Cursor query for subsequent feed pages; visibility remains policy-controlled.
create function public.feed_page(before_time timestamptz default null,before_id uuid default null) returns setof public.posts language sql stable security invoker set search_path='' as $$
 select * from public.posts where deleted_at is null and (before_time is null or (published_at,id)<(before_time,before_id)) order by published_at desc,id desc limit 30;
$$;
revoke all on function public.feed_page(timestamptz,uuid) from public;
grant execute on function public.feed_page(timestamptz,uuid) to authenticated;
