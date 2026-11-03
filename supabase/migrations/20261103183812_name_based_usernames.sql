-- Friendly defaults for existing and future profiles. User-selected handles stay
-- stable, including across later display-name edits and older-client upserts.
create extension if not exists unaccent with schema extensions;

create or replace function public.default_username() returns trigger
language plpgsql security invoker set search_path='' as $$
declare base text; candidate text; suffix integer:=1; existing text;
begin
 -- Every insert / username edit takes the same lock before checking availability.
 -- This also serializes manual claims against concurrent automatic allocations;
 -- the existing unique index remains the final database-wide guarantee.
 perform pg_advisory_xact_lock(0,20261103);
 if tg_op='INSERT' and nullif(trim(new.username),'') is null then
   select p.username into existing from public.profiles p where p.id=new.id;
   if found then new.username:=existing; return new; end if;
 end if;
 if nullif(trim(new.username),'') is not null then return new; end if;

 base:=trim(both '_' from regexp_replace(lower(extensions.unaccent(coalesce(new.name,''))),'[^a-z0-9]+','_','g'));
 if base='' then base:='member'; end if;
 -- Retain the app's 3–40 character handle rules for very short / long names.
 if length(base)<3 then base:=rpad(base,3,'1'); end if;
 base:=left(base,40);
 candidate:=base;
 while exists(select 1 from public.profiles p where lower(p.username)=candidate and p.id<>new.id) loop
   suffix:=suffix+1;
   candidate:=left(base,40-length(suffix::text))||suffix::text;
 end loop;
 new.username:=candidate;
 return new;
end $$;
revoke all on function public.default_username() from public,anon,authenticated;

drop trigger if exists profile_default_username on public.profiles;
create trigger profile_default_username before insert or update of username
 on public.profiles for each row execute function public.default_username();

-- Allocate in sign-up order. The first available display name gets the bare
-- handle; subsequent duplicates receive 2, 3, ... . Only the exact old generated
-- placeholder is eligible. A recorded explicit username choice is preserved.
do $$
declare profile_id uuid;
begin
 for profile_id in
   select p.id from public.profiles p join auth.users u on u.id=p.id
   where p.username='member_'||replace(p.id::text,'-','')
   and not exists(select 1 from public.command_receipts r where r.actor=p.id and r.operation='set_username')
   order by u.created_at nulls last,p.id
 loop
   update public.profiles set username=null where id=profile_id;
 end loop;
end $$;
