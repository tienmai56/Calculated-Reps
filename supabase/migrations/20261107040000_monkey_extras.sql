-- Monkey extras: up to three accessories, one per spot (head, eyes, mouth), worn
-- on top of the monkey's mood, fur and haircut. Stored apart from profiles.monkey
-- as 'head.eyes.mouth' ('none' for an empty spot) so clients that only know
-- 'mood.fur.haircut' keep drawing the monkey as before. Null means no extras.
-- Extras only exist with a monkey: removing the monkey removes them.
alter table public.profiles add column monkey_extras text check(monkey_extras is null or (
 monkey_extras ~ '^(none|earguards|headband)\.(none|specs|shades|goggles|bandit|luchador|sleep)\.(none|mouthguard)$'
 and monkey_extras<>'none.none.none'));

-- set_monkey takes an optional "extras". Leaving it out (older clients) keeps the
-- current extras; an empty value or 'none.none.none' clears them. Every other
-- operation stays exactly as deployed.
do $migration$
declare
 definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
 anchor text := $a$update public\.profiles set monkey=token where id=actor;\s*result:=jsonb_build_object\('monkey',coalesce\(token,''\)\);$a$;
 branch text := $b$update public.profiles set monkey=token,monkey_extras=case when token is null then null else monkey_extras end where id=actor;
 if token is not null and payload ? 'extras' then
  token:=nullif(nullif(trim(coalesce(payload->>'extras','')),''),'none.none.none');
  if token is not null and token !~ '^(none|earguards|headband)[.](none|specs|shades|goggles|bandit|luchador|sleep)[.](none|mouthguard)$' then raise exception 'Invalid monkey extras'; end if;
  update public.profiles set monkey_extras=token where id=actor;
 end if;
 select jsonb_build_object('monkey',coalesce(monkey,''),'extras',coalesce(monkey_extras,'')) into result from public.profiles where id=actor;$b$;
begin
 if regexp_count(definition,anchor)<>1 then
  raise exception 'set_monkey changed; review monkey extras migration';
 end if;
 if strpos(definition,'monkey_extras')>0 then
  raise exception 'monkey extras already handled; review monkey extras migration';
 end if;
 execute regexp_replace(definition,anchor,branch);
end $migration$;

-- Username lookups return the same monkey fields as the snapshot.
create or replace function private.search_usernames(query text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid := auth.uid(); term text := lower(btrim(coalesce(query,''))); result jsonb;
begin
 if left(term,1)='@' then term:=substr(term,2); end if;
 if actor is null or term !~ '^[a-z0-9_]{3,40}$'
 or not exists(select 1 from public.profiles where id=actor) then return '[]'::jsonb; end if;
 select coalesce(jsonb_agg(to_jsonb(p) order by (p.username=term) desc,p.username,p.id),'[]'::jsonb)
 into result from (
  select id,name,username,belt,stripes,gym,monkey,monkey_extras from public.profiles
  where username like replace(term,'_','\_')||'%' escape '\'
  and id<>actor and not public.blocked(actor,id)
  order by (username=term) desc,username,id limit 20
 ) p;
 return result;
end $$;
