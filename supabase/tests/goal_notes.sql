\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
insert into auth.users(id) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid from generate_series(301,303) i;
insert into public.profiles(id,name) select id,'Note member '||right(id::text,3) from auth.users where id between '00000000-0000-0000-0000-000000000301' and '00000000-0000-0000-0000-000000000303';
insert into public.friendships(a,b,timezone) values('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000302','UTC');
select set_config('test.note_photo','00000000-0000-0000-0000-000000000301/'||repeat('a',64)||'.jpg',true);
select set_config('test.note_video','00000000-0000-0000-0000-000000000301/'||repeat('b',64)||'.mp4',true);
select set_config('test.foreign_video','00000000-0000-0000-0000-000000000303/'||repeat('c',64)||'.mov',true);
insert into storage.objects(bucket_id,name) values('goal-media',current_setting('test.foreign_video'));
select pg_temp.assert_true((select not public and file_size_limit=52428800 and allowed_mime_types @> array['video/mp4','video/quicktime','video/x-m4v'] from storage.buckets where id='goal-media'),'private bucket supports movies with a 50 MB cap');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
insert into storage.objects(bucket_id,name) values('goal-media',current_setting('test.note_photo')),('goal-media',current_setting('test.note_video'));
select pg_temp.assert_true(pg_temp.fails($q$insert into storage.objects(bucket_id,name) values('goal-media',current_setting('test.foreign_video'))$q$),'cannot upload into another member folder');
select pg_temp.assert_true(pg_temp.fails($q$insert into storage.objects(bucket_id,name) values('goal-media','00000000-0000-0000-0000-000000000301/script.html')$q$),'media extension allowlist still enforced');
select set_config('test.note_payload',jsonb_build_object('client_id','note-goal','title','Single leg','parts',jsonb_build_array(
 jsonb_build_object('id','setup','title','Setup','noteItems',jsonb_build_array(
 jsonb_build_object('id','entry','text','Collar tie and level change','links',jsonb_build_array('https://example.com/entry'),'photos',jsonb_build_array(current_setting('test.note_photo')),'videos','[]'::jsonb),
 jsonb_build_object('id','finish','text','Turn the corner','links',jsonb_build_array('https://youtu.be/finish'),'photos','[]'::jsonb,'videos',jsonb_build_array(current_setting('test.note_video')))))))::text,true);
select public.command('publish_goal',current_setting('test.note_payload')::jsonb,gen_random_uuid())->>'id' as gid \gset
select set_config('test.note_goal',:'gid',true);
select pg_temp.assert_true((select parts->0->'noteItems'->0->>'text'='Collar tie and level change' and parts->0->'noteItems'->1->'videos'=jsonb_build_array(current_setting('test.note_video')) from public.shared_goals where id=:'gid'),'notes retain their own links, photos and videos');
select pg_temp.assert_true((select cardinality(media)=2 and media @> array[current_setting('test.note_photo'),current_setting('test.note_video')] from public.shared_goals where id=:'gid'),'nested media is tracked for authorization');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('publish_goal',jsonb_set(current_setting('test.note_payload')::jsonb,'{parts,0,noteItems,1,links}','["javascript:alert(1)"]'),gen_random_uuid())$q$),'validate every nested link');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('publish_goal',jsonb_set(current_setting('test.note_payload')::jsonb,'{parts,0,noteItems,1,videos}',jsonb_build_array(current_setting('test.foreign_video'))),gen_random_uuid())$q$),'nested videos must be owned uploads');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('publish_goal',jsonb_set(current_setting('test.note_payload')::jsonb,'{parts,0,noteItems,1,id}','"entry"'),gen_random_uuid())$q$),'reject duplicate note ids');
select pg_temp.assert_true(pg_temp.fails($q$select public.command('publish_goal',jsonb_set(current_setting('test.note_payload')::jsonb,'{parts,0,noteItems,1,photos}','{}'),gen_random_uuid())$q$),'reject malformed nested collections');
select public.command('share_goal',jsonb_build_object('goal_id',:'gid','recipients',jsonb_build_array('00000000-0000-0000-0000-000000000302')),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000302',true);
select public.command('respond_goal_share',jsonb_build_object('goal_id',:'gid','accept',true),gen_random_uuid());
select pg_temp.assert_true((select count(*)=2 from storage.objects where bucket_id='goal-media'),'recipient can read nested photos and videos');
select pg_temp.assert_true(jsonb_array_length(public.snapshot()->'shared_goals'->0->'parts'->0->'noteItems')=2,'snapshot preserves the hierarchy');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
select pg_temp.assert_true((select count(*)=0 from storage.objects where bucket_id='goal-media' and name in (current_setting('test.note_photo'),current_setting('test.note_video'))),'strangers cannot read note media');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select public.command('publish_goal',current_setting('test.note_payload')::jsonb #- '{parts,0,noteItems,0}',gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000302',true);
select pg_temp.assert_true((select count(*)=1 and bool_and(name=current_setting('test.note_video')) from storage.objects where bucket_id='goal-media'),'deleting a note revokes only its media');
select pg_temp.assert_true((select count(*)=1 from public.notifications where kind='goal_update'),'note changes notify accepted recipients');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000301',true);
select public.command('unshare_goal',jsonb_build_object('goal_id',:'gid'),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000302',true);
select pg_temp.assert_true((select count(*)=0 from storage.objects where bucket_id='goal-media'),'unsharing revokes nested media access');
rollback;
