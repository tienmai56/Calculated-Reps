\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
insert into auth.users values('00000000-0000-0000-0000-000000000041'),('00000000-0000-0000-0000-000000000042');
set local role authenticated;

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000041',true);
select public.command('save_profile','{"name":"Sam","gym":"Atos SF","belt":"blue","timezone":"UTC"}',gen_random_uuid());

-- Extras only come with a monkey.
select public.command('set_monkey','{"monkey":"","extras":"headband.shades.none"}',gen_random_uuid());
select pg_temp.assert_true((select monkey is null and monkey_extras is null from public.profiles where id=auth.uid()),'no extras without a monkey');

-- A monkey with up to three extras, one per spot.
select pg_temp.assert_true((select public.command('set_monkey','{"monkey":"grin.coral-700.tuft","extras":"headband.shades.mouthguard"}',gen_random_uuid())
 = '{"monkey":"grin.coral-700.tuft","extras":"headband.shades.mouthguard"}'::jsonb),'set_monkey echoes the monkey and its extras');
select pg_temp.assert_true((select monkey_extras='headband.shades.mouthguard' from public.profiles where id=auth.uid()),'extras saved');
select public.command('set_monkey','{"monkey":"grin.coral-700.tuft","extras":"none.luchador.none"}',gen_random_uuid());
select pg_temp.assert_true((select monkey_extras='none.luchador.none' from public.profiles where id=auth.uid()),'empty spots allowed');

-- Older clients send only the monkey: extras stay.
select public.command('set_monkey','{"monkey":"happy.ink-900.clean"}',gen_random_uuid());
select pg_temp.assert_true((select monkey='happy.ink-900.clean' and monkey_extras='none.luchador.none' from public.profiles where id=auth.uid()),'monkey-only save keeps extras');

-- Clearing.
select public.command('set_monkey','{"monkey":"happy.ink-900.clean","extras":"none.none.none"}',gen_random_uuid());
select pg_temp.assert_true((select monkey_extras is null from public.profiles where id=auth.uid()),'none.none.none clears extras');
select public.command('set_monkey','{"monkey":"happy.ink-900.clean","extras":"earguards.none.none"}',gen_random_uuid());
select public.command('set_monkey','{"monkey":"happy.ink-900.clean","extras":""}',gen_random_uuid());
select pg_temp.assert_true((select monkey_extras is null from public.profiles where id=auth.uid()),'empty extras clears them');
select public.command('set_monkey','{"monkey":"happy.ink-900.clean","extras":"earguards.specs.none"}',gen_random_uuid());
select public.command('set_monkey','{"monkey":""}',gen_random_uuid());
select pg_temp.assert_true((select monkey is null and monkey_extras is null from public.profiles where id=auth.uid()),'removing the monkey removes its extras');

-- Only known extras, in their own spot.
select public.command('set_monkey','{"monkey":"happy.ink-900.clean","extras":"headband.none.none"}',gen_random_uuid());
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_monkey','{"monkey":"happy.ink-900.clean","extras":"crown.none.none"}',gen_random_uuid())$q$),'unknown extra rejected');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_monkey','{"monkey":"happy.ink-900.clean","extras":"specs.none.none"}',gen_random_uuid())$q$),'extra in the wrong spot rejected');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('set_monkey','{"monkey":"happy.ink-900.clean","extras":"headband.shades"}',gen_random_uuid())$q$),'incomplete extras rejected');
select pg_temp.assert_true((select monkey='happy.ink-900.clean' and monkey_extras='headband.none.none' from public.profiles where id=auth.uid()),'a rejected save changes nothing');
select pg_temp.assert_true(pg_temp.fails($q$update public.profiles set monkey_extras='headband.none.none' where id=auth.uid()$q$),'profiles cannot be written directly');

-- Friends see the extras in the snapshot.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000042',true);
select public.command('save_profile','{"name":"Lena","gym":"Atos SF","belt":"purple","timezone":"UTC"}',gen_random_uuid());
reset role;
insert into public.friendships(a,b,timezone) values('00000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000042','UTC');
set local role authenticated;
select pg_temp.assert_true((select snap->'profiles' @> '[{"monkey":"happy.ink-900.clean","monkey_extras":"headband.none.none"}]' from (select public.snapshot() snap) x),'snapshot carries the extras');
rollback;
