-- Hosted Supabase projects can grant EXECUTE to anon explicitly through default
-- privileges. Revoking PUBLIC alone does not remove that separate grant.
revoke all on function
  public.blocked(uuid,uuid),
  public.are_friends(uuid,uuid),
  public.can_session(uuid),
  public.can_post(uuid),
  public.command(text,jsonb,uuid),
  public.snapshot(),
  public.feed_page(timestamptz,uuid),
  public.post_details(uuid),
  public.comment_page(uuid,timestamptz,uuid)
from anon;

-- Internal writes are callable only from their trusted database functions.
revoke all on function public.emit_notification(uuid,uuid,text,uuid,text,text),
  public.rebuild_credits(uuid)
from public,anon,authenticated;
