begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.refused(operation text,payload jsonb) returns boolean language plpgsql as $$ begin perform public.command(operation,payload,gen_random_uuid()); return false; exception when others then return true; end $$;
insert into auth.users(id) select ('00000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(9501,9505) n;
insert into public.profiles(id,name) select id,'Gallery test' from auth.users where id::text like '00000000-0000-0000-0000-00000000950_';
insert into public.sessions(id,organizer,title,starts_at,timezone,venue,join_mode) values
 ('10000000-0000-0000-0000-000000009501','00000000-0000-0000-0000-000000009501','Gallery',now()-interval '1 hour','UTC','Gym','friends'),
 ('10000000-0000-0000-0000-000000009502','00000000-0000-0000-0000-000000009501','Other',now()-interval '2 hours','UTC','Gym','friends'),
 ('10000000-0000-0000-0000-000000009503','00000000-0000-0000-0000-000000009501','Future',now()+interval '1 day','UTC','Gym','friends');
insert into public.session_participants(session_id,user_id,rsvp) values
 ('10000000-0000-0000-0000-000000009501','00000000-0000-0000-0000-000000009501','going'),
 ('10000000-0000-0000-0000-000000009501','00000000-0000-0000-0000-000000009502','going'),
 ('10000000-0000-0000-0000-000000009501','00000000-0000-0000-0000-000000009503','invited');
insert into public.friendships(a,b,timezone) values ('00000000-0000-0000-0000-000000009501','00000000-0000-0000-0000-000000009504','UTC');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009501',true);
select '10000000-0000-0000-0000-000000009501'::text as session_id \gset
create temporary table picks as select n,(public.command('prepare_session_media',jsonb_build_object('session_id',:'session_id','content_type',case when n%2=0 then 'video/mp4' else 'image/jpeg' end),gen_random_uuid())->>'id')::uuid as id from generate_series(1,6) n;
select jsonb_agg(id order by n desc) filter(where n<=5) as five, jsonb_agg(id order by n) as six from picks \gset
select pg_temp.assert_true(pg_temp.refused('save_session_media',jsonb_build_object('session_id',:'session_id','media_ids',:'five'::jsonb)),'unuploaded assets refused');
insert into storage.objects(bucket_id,name) select 'session-photos',m.object_key from public.media_assets m join picks p on p.id=m.id;
select pg_temp.assert_true(pg_temp.refused('save_session_media',jsonb_build_object('session_id',:'session_id','media_ids',:'six'::jsonb)),'six combined photos/videos refused');
select pg_temp.assert_true(pg_temp.refused('save_session_media',jsonb_build_object('session_id',:'session_id','media_ids',jsonb_build_array((:'five'::jsonb)->>0,(:'five'::jsonb)->>0))),'duplicates refused');
select pg_temp.assert_true(pg_temp.refused('save_session_media',jsonb_build_object('session_id','10000000-0000-0000-0000-000000009502','media_ids',:'five'::jsonb)),'cross-session assets refused');
select pg_temp.assert_true(pg_temp.refused('prepare_session_media',jsonb_build_object('session_id','10000000-0000-0000-0000-000000009503')),'future session refused');
select pg_temp.assert_true(pg_temp.refused('prepare_session_media',jsonb_build_object('session_id',:'session_id','content_type','text/html')),'unsupported type refused');
select gen_random_uuid() as save_key \gset
select public.command('save_session_media',jsonb_build_object('session_id',:'session_id','media_ids',:'five'::jsonb),:'save_key');
select public.command('save_session_media',jsonb_build_object('session_id',:'session_id','media_ids',:'five'::jsonb),:'save_key');
select pg_temp.assert_true((select to_jsonb(media_ids)=:'five'::jsonb from public.sessions where id=:'session_id'),'saved order survives retry');
select pg_temp.assert_true(not exists(select 1 from public.posts where session_id=:'session_id'),'saving does not publish or complete');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009502',true);
select pg_temp.assert_true((select count(*)=5 from public.media_assets where state='ready'),'accepted guest sees entire saved gallery');
select pg_temp.assert_true((select count(*)=5 from storage.objects where bucket_id='session-photos'),'guest downloads all saved slides');
select pg_temp.assert_true(pg_temp.refused('save_session_media',jsonb_build_object('session_id',:'session_id','media_ids',:'five'::jsonb)),'guest cannot change host gallery');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009503',true);
select pg_temp.assert_true(not exists(select 1 from storage.objects where bucket_id='session-photos'),'pending invitee has no media access');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009504',true);
select pg_temp.assert_true(not exists(select 1 from storage.objects where bucket_id='session-photos'),'friend has no unpublished draft access');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009501',true);
select gen_random_uuid() as publish_key \gset
select public.command('complete_and_publish',jsonb_build_object('session_id',:'session_id','media_ids',:'five'::jsonb,'attendees',jsonb_build_array('00000000-0000-0000-0000-000000009501','00000000-0000-0000-0000-000000009502')),:'publish_key')->>'id' as post_id \gset
select pg_temp.assert_true((select to_jsonb(media_ids)=:'five'::jsonb and media_id=media_ids[1] from public.posts where id=:'post_id'),'post preserves five mixed items and cover');
select public.command('save_session_media',jsonb_build_object('session_id',:'session_id','media_ids','[]'::jsonb),gen_random_uuid());
select pg_temp.assert_true((select cardinality(media_ids)=5 from public.posts where id=:'post_id'),'clearing session gallery leaves published post intact');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009504',true);
select pg_temp.assert_true((select count(*)=5 from storage.objects where bucket_id='session-photos'),'friend can download every published slide');
select pg_temp.assert_true(jsonb_array_length(public.post_details(:'post_id')->'media')=5,'direct post hydration returns every slide');
reset role;
insert into public.blocks(actor,target) values ('00000000-0000-0000-0000-000000009501','00000000-0000-0000-0000-000000009504');
set local role authenticated;
select pg_temp.assert_true(not exists(select 1 from storage.objects where bucket_id='session-photos'),'block revokes all slide downloads');
select pg_temp.assert_true(not has_function_privilege('authenticated','private.session_media_command(text,jsonb)','EXECUTE'),'private gallery mutation cannot bypass dispatcher');
rollback;
