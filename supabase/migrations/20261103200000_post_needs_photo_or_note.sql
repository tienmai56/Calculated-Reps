-- A shared session is never blank: every post carries a photo, a note, or both
-- (DESIGN.md, "Share the session"). The session focus doesn't count, and a note
-- of only whitespace or @tags counts as empty, matching ShareRule in the app.
-- Checked on write only, so posts published before this rule are left as they are.

create or replace function public.post_has_words(caption text) returns boolean
language sql immutable set search_path='' as $$
 select exists(select 1 from regexp_split_to_table(coalesce(caption,''),'\s+') word where word<>'' and left(word,1)<>'@')
$$;

create or replace function public.require_photo_or_note() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if new.media_id is null and not public.post_has_words(new.caption) then
   raise exception 'Add a photo or a few words first';
 end if;
 return new;
end $$;

drop trigger if exists posts_require_photo_or_note on public.posts;
create trigger posts_require_photo_or_note
 before insert or update of caption, media_id on public.posts
 for each row execute function public.require_photo_or_note();

revoke all on function public.require_photo_or_note() from public, anon, authenticated;
revoke all on function public.post_has_words(text) from public, anon, authenticated;
