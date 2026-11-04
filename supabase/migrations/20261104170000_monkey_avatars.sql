-- Monkey avatars: each member can build a monkey (mood, fur color, haircut) that
-- appears after their name. Stored as 'mood.fur.haircut' text so it reaches the
-- client through the existing snapshot (profiles are returned whole); null means
-- the member hasn't built one yet. set_monkey is the only way to change it.
alter table public.profiles add column monkey text check(monkey is null or monkey ~ '^(happy|grin|focused|tired|side|tapped)\.(ink-900|ink-700|ink-500|coral-700|sky-700|plum-700|mint-700)\.(clean|tuft|fringe|mohawk|topknot|curls)$');

-- Add only the set_monkey branch, keeping every other operation exactly as deployed
-- (including the text-patched RSVP branch from 20261104160002), with the same
-- actor lock, rate limit, grants and retry receipts.
do $migration$
declare
 definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 anchor text := $a$ elsif operation='create_session' then$a$;
 branch text := $b$ elsif operation='set_monkey' then
 -- The monkey shown after a member's name: mood.fur.haircut, or empty to remove it.
 token:=nullif(trim(coalesce(payload->>'monkey','')),'');
 if token is not null and token !~ '^(happy|grin|focused|tired|side|tapped)\.(ink-900|ink-700|ink-500|coral-700|sky-700|plum-700|mint-700)\.(clean|tuft|fringe|mohawk|topknot|curls)$' then raise exception 'Invalid monkey'; end if;
 update public.profiles set monkey=token where id=actor;
 result:=jsonb_build_object('monkey',coalesce(token,''));
$b$;
begin
 if strpos(definition,anchor)=0 or strpos(substr(definition,strpos(definition,anchor)+1),anchor)>0 then
  raise exception 'Session command changed; review monkey avatar migration';
 end if;
 if strpos(definition,'operation=''set_monkey''')>0 then
  raise exception 'set_monkey already exists; review monkey avatar migration';
 end if;
 execute replace(definition,anchor,branch||anchor);
end $migration$;
