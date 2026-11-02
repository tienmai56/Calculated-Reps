\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
insert into auth.users values('00000000-0000-0000-0000-000000000021'),('00000000-0000-0000-0000-000000000022');
set local role authenticated;

-- A new member uploads a photo into their own folder and completes setup.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000021',true);
insert into storage.objects(bucket_id,name) values('avatars','00000000-0000-0000-0000-000000000021/aaaaaaaa-0000-0000-0000-000000000001.jpg');
select pg_temp.assert_true(pg_temp.fails($q$insert into storage.objects(bucket_id,name) values('avatars','00000000-0000-0000-0000-000000000022/aaaaaaaa-0000-0000-0000-000000000002.jpg')$q$),'upload into another member''s folder is refused');
select pg_temp.assert_true(pg_temp.fails($q$insert into storage.objects(bucket_id,name) values('avatars','00000000-0000-0000-0000-000000000021/notes.txt')$q$),'only <uuid>.jpg names are accepted');
select public.command('save_profile','{"name":"P","gym":"Tidewater BJJ","belt":"blue","phone":"+1 (555) 000-1234","avatar_key":"00000000-0000-0000-0000-000000000021/aaaaaaaa-0000-0000-0000-000000000001.jpg","timezone":"UTC"}',gen_random_uuid());
select pg_temp.assert_true((select phone='+15550001234' from public.account_settings where user_id=auth.uid()),'phone stored in E.164 form');
select pg_temp.assert_true((select avatar_key='00000000-0000-0000-0000-000000000021/aaaaaaaa-0000-0000-0000-000000000001.jpg' from public.profiles where id=auth.uid()),'avatar key saved');

-- Later saves that omit them keep the photo and phone.
select public.command('save_profile','{"name":"P2"}',gen_random_uuid());
select pg_temp.assert_true((select avatar_key is not null from public.profiles where id=auth.uid()),'avatar kept on later save');
select pg_temp.assert_true((select phone='+15550001234' from public.account_settings where user_id=auth.uid()),'phone kept on later save');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('save_profile','{"name":"P","phone":"+12"}',gen_random_uuid())$q$),'too-short phone rejected');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('save_profile','{"name":"P","avatar_key":"00000000-0000-0000-0000-000000000021/bbbbbbbb-0000-0000-0000-000000000009.jpg"}',gen_random_uuid())$q$),'avatar key without an upload rejected');

-- Another member can't claim the photo and, as a stranger, can't see it or the phone.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000022',true);
select public.command('save_profile','{"name":"Q"}',gen_random_uuid());
select pg_temp.assert_true(pg_temp.fails($q$select public.command('save_profile','{"name":"Q","avatar_key":"00000000-0000-0000-0000-000000000021/aaaaaaaa-0000-0000-0000-000000000001.jpg"}',gen_random_uuid())$q$),'cannot claim another member''s photo');
select pg_temp.assert_true((select count(*)=0 from storage.objects where bucket_id='avatars'),'stranger cannot see the photo');
select pg_temp.assert_true((select count(*)=0 from public.account_settings where user_id='00000000-0000-0000-0000-000000000021'),'stranger cannot see the phone');

-- Once friends, the photo is visible; the phone stays private.
reset role;
insert into public.friendships(a,b,timezone) values('00000000-0000-0000-0000-000000000021','00000000-0000-0000-0000-000000000022','UTC');
set local role authenticated;
select pg_temp.assert_true((select count(*)=1 from storage.objects where bucket_id='avatars'),'friend can see the photo');
select pg_temp.assert_true((select count(*)=0 from public.account_settings where user_id='00000000-0000-0000-0000-000000000021'),'friend cannot see the phone');
rollback;
