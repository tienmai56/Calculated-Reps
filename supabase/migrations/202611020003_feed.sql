create function public.post_details(post_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$
select jsonb_build_object(
'posts',coalesce((select jsonb_agg(p) from public.posts p where p.id=post_id),'[]'::jsonb),
'profiles',coalesce((select jsonb_agg(p) from public.profiles p where p.id in(select user_id from public.post_participants t where t.post_id=post_details.post_id)),'[]'::jsonb),
'media',coalesce((select jsonb_agg(m) from public.media_assets m where m.id in(select media_id from public.posts p where p.id=post_id)),'[]'::jsonb),
'comments',coalesce((select jsonb_agg(c) from (select * from public.comments c where c.post_id=post_details.post_id order by created_at desc,id desc limit 100) c),'[]'::jsonb),
'likes',coalesce((select jsonb_agg(l) from public.post_likes l where l.post_id=post_details.post_id),'[]'::jsonb),
'participants',coalesce((select jsonb_agg(t) from public.post_participants t where t.post_id=post_details.post_id and visible),'[]'::jsonb));
$$;
revoke all on function public.post_details(uuid) from public;
grant execute on function public.post_details(uuid) to authenticated;

create function public.comment_page(target_post uuid,before_time timestamptz default null,before_id uuid default null) returns setof public.comments language sql stable security invoker set search_path='' as $$
select * from public.comments where post_id=target_post and (before_time is null or (created_at,id)<(before_time,before_id)) order by created_at desc,id desc limit 100;
$$;
revoke all on function public.comment_page(uuid,timestamptz,uuid) from public;
grant execute on function public.comment_page(uuid,timestamptz,uuid) to authenticated;
