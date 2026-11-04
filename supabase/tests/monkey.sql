\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
insert into auth.users values('00000000-0000-0000-0000-000000000031'),('00000000-0000-0000-0000-000000000032'),('00000000-0000-0000-0000-000000000033');
set local role authenticated;

-- A monkey needs a profile first.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000031',true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_monkey','{"monkey":"happy.ink-900.tuft"}',gen_random_uuid())$q$),'no monkey before the profile exists');

-- A new member finishes setup and saves their monkey; it starts empty.
select public.command('save_profile','{"name":"Sam","gym":"Atos SF","belt":"blue","timezone":"UTC"}',gen_random_uuid());
select pg_temp.assert_true((select monkey is null from public.profiles where id=auth.uid()),'new profiles have no monkey');
select pg_temp.assert_true((select public.command('set_monkey','{"monkey":"grin.coral-700.topknot"}',gen_random_uuid())->>'monkey'='grin.coral-700.topknot'),'set_monkey echoes the saved monkey');
select pg_temp.assert_true((select monkey='grin.coral-700.topknot' from public.profiles where id=auth.uid()),'monkey saved');

-- Saving the profile again keeps the monkey.
select public.command('save_profile','{"name":"Sam O"}',gen_random_uuid());
select pg_temp.assert_true((select monkey='grin.coral-700.topknot' from public.profiles where id=auth.uid()),'monkey kept on later profile save');

-- Only known moods, fur colors and haircuts are accepted.
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_monkey','{"monkey":"angry.ink-900.tuft"}',gen_random_uuid())$q$),'unknown mood rejected');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_monkey','{"monkey":"happy.sun-600.tuft"}',gen_random_uuid())$q$),'unknown fur rejected');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_monkey','{"monkey":"happy.ink-900.afro"}',gen_random_uuid())$q$),'unknown haircut rejected');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_monkey','{"monkey":"happy.ink-900"}',gen_random_uuid())$q$),'incomplete monkey rejected');
select pg_temp.assert_true(pg_temp.fails($q$update public.profiles set monkey='happy.ink-900.tuft' where id=auth.uid()$q$),'profiles cannot be written directly');

-- Friends see the monkey; strangers don't see the profile at all.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000032',true);
select public.command('save_profile','{"name":"Lena","gym":"Atos SF","belt":"purple","timezone":"UTC"}',gen_random_uuid());
select pg_temp.assert_true((select count(*)=0 from public.profiles where id='00000000-0000-0000-0000-000000000031'),'stranger cannot see the monkey');
reset role;
insert into public.friendships(a,b,timezone) values('00000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000032','UTC');
set local role authenticated;
select pg_temp.assert_true((select monkey='grin.coral-700.topknot' from public.profiles where id='00000000-0000-0000-0000-000000000031'),'friend sees the monkey');
select pg_temp.assert_true((select snap->'profiles' @> '[{"monkey":"grin.coral-700.topknot"}]' from (select public.snapshot() snap) x),'snapshot carries the monkey');

-- Each member sets only their own; an empty value removes it.
select public.command('set_monkey','{"monkey":"side.ink-500.fringe"}',gen_random_uuid());
select pg_temp.assert_true((select monkey='grin.coral-700.topknot' from public.profiles where id='00000000-0000-0000-0000-000000000031'),'setting yours leaves your friend''s alone');
select public.command('set_monkey','{"monkey":""}',gen_random_uuid());
select pg_temp.assert_true((select monkey is null from public.profiles where id=auth.uid()),'empty value removes the monkey');
rollback;
