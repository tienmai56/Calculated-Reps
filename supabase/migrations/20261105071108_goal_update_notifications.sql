-- Saving a shared goal notifies people who accepted it. The existing helper
-- writes both the durable in-app notification and its push outbox job atomically.
-- A trigger keeps this independent of the version of command() doing the save.
create function public.notify_goal_update() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is distinct from new.owner
    or old.deleted_at is not null or new.deleted_at is not null then
  return new;
 end if;

 -- publish_goal also updates version/updated_at when the content is unchanged.
 if row(old.title,old.notes,old.links,old.photos,old.parts)
    is not distinct from row(new.title,new.notes,new.links,new.photos,new.parts) then
  return new;
 end if;

 perform public.emit_notification(s.recipient,new.owner,'goal_update',new.id,
  'updated '||new.title,
  new.id::text||':'||new.version::text||':'||s.recipient::text||':goal_update')
 from public.goal_shares s
 where s.goal_id=new.id and s.status='accepted';
 return new;
end $$;

-- Only the table trigger, running within the owner's authorized command, uses
-- this helper. It adds no new client write permissions or privileged function.
revoke all on function public.notify_goal_update() from public,anon,authenticated,service_role;
create trigger shared_goal_updated after update on public.shared_goals
for each row execute function public.notify_goal_update();
