-- Extend only comment delivery, preserving the command's authorization, post
-- lock, rate limit, retry receipts and all unrelated operations.
do $migration$
declare
 definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 old_branch text := $old$ -- A tagged post author receives the mention instead of two alerts for this comment.
 if not exists(select 1 from public.notifications n where n.dedupe_key=c.id::text||p.author::text||'mention') then
 perform public.emit_notification(p.author,actor,'comment',p.id,'commented on your memory',idempotency_key::text);
 end if;$old$;
 new_branch text := $new$ -- Notify the post author and everyone already participating in its comments.
 -- UNION gives each recipient one alert even when they have commented repeatedly.
 -- The post lock above serializes comments, so concurrent writers see each other.
 for person in
 select recipients.id from (
  select p.author as id
  union
  select previous.author from public.comments previous where previous.post_id=p.id
 ) recipients
 where recipients.id<>actor
 and public.mention_can_view(p.id,recipients.id)
 and not exists(select 1 from public.notifications n
  where n.dedupe_key=c.id::text||recipients.id::text||'mention')
 loop
 perform public.emit_notification(person,actor,'comment',p.id,
  case when person=p.author then 'commented on your memory'
   else 'commented on a memory you commented on' end,
  c.id::text||person::text||'comment');
 end loop;$new$;
begin
 if strpos(definition,old_branch)=0 then
  raise exception 'Comment command changed; review comment thread notification migration';
 end if;
 execute replace(definition,old_branch,new_branch);
end $migration$;
