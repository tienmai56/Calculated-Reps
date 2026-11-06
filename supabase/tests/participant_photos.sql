begin;
create function pg_temp.assert_photo(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Photo assertion failed: %',message; end if; end $$;
create function pg_temp.photo_refused(operation text,payload jsonb) returns boolean language plpgsql as $$ begin perform public.command(operation,payload,gen_random_uuid()); return false; exception when others then return true; end $$;
insert into auth.users(id) select ('00000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(901,908) n;
insert into public.profiles(id,name) select id,'Participant photo test' from auth.users where id::text like '00000000-0000-0000-0000-00000000090_';
insert into public.sessions(id,organizer,title,starts_at,timezone,venue,join_mode) values
 ('10000000-0000-0000-0000-000000000901','00000000-0000-0000-0000-000000000901','Past training',now()-interval '1 hour','UTC','Gym','friends'),
 ('10000000-0000-0000-0000-000000000902','00000000-0000-0000-0000-000000000901','Future training',now()+interval '1 day','UTC','Gym','link'),
 ('10000000-0000-0000-0000-000000000903','00000000-0000-0000-0000-000000000901','Other training',now()-interval '1 hour','UTC','Gym','friends');
insert into public.session_participants(session_id,user_id,rsvp,attended) values
 ('10000000-0000-0000-0000-000000000901','00000000-0000-0000-0000-000000000901','going',true),
 ('10000000-0000-0000-0000-000000000901','00000000-0000-0000-0000-000000000902','going',true),
 ('10000000-0000-0000-0000-000000000901','00000000-0000-0000-0000-000000000903','invited',false),
 ('10000000-0000-0000-0000-000000000901','00000000-0000-0000-0000-000000000904','declined',false),
 ('10000000-0000-0000-0000-000000000901','00000000-0000-0000-0000-000000000905','going',true),
 ('10000000-0000-0000-0000-000000000901','00000000-0000-0000-0000-000000000908','going',false),
 ('10000000-0000-0000-0000-000000000902','00000000-0000-0000-0000-000000000902','going',true);
insert into public.blocks(actor,target) values ('00000000-0000-0000-0000-000000000901','00000000-0000-0000-0000-000000000905');
insert into public.friendships(a,b,timezone) values ('00000000-0000-0000-0000-000000000901','00000000-0000-0000-0000-000000000906','UTC');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000901',true);
select public.command('prepare_media','{"session_id":"10000000-0000-0000-0000-000000000901"}',gen_random_uuid())->>'id' as host_media \gset
insert into storage.objects(bucket_id,name) select 'session-photos',object_key from public.media_assets where id=:'host_media';
select public.command('save_session_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','media_id',:'host_media'),gen_random_uuid());
select pg_temp.assert_photo((public.snapshot()->>'participant_photos_available')::boolean,'snapshot advertises capability');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000902',true);
select pg_temp.assert_photo(pg_temp.photo_refused('prepare_participant_photo','{"session_id":"10000000-0000-0000-0000-000000000902"}'),'future training denied even with attendance');
select public.command('prepare_participant_photo','{"session_id":"10000000-0000-0000-0000-000000000901"}',gen_random_uuid())->>'id' as guest_media \gset
select pg_temp.assert_photo(pg_temp.photo_refused('post_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','media_id',:'guest_media')),'missing upload denied');
insert into storage.objects(bucket_id,name) select 'session-photos',object_key from public.media_assets where id=:'guest_media';
select pg_temp.assert_photo(pg_temp.photo_refused('post_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','media_id',:'host_media')),'cannot claim host media');
select pg_temp.assert_photo(pg_temp.photo_refused('post_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000903','media_id',:'guest_media')),'cannot publish into another session');
select gen_random_uuid() as post_key \gset
select public.command('post_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','media_id',:'guest_media'),:'post_key');
select public.command('post_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','media_id',:'guest_media'),:'post_key');
select pg_temp.assert_photo((select count(*)=2 from public.media_assets where session_id='10000000-0000-0000-0000-000000000901' and session_photo),'host and guest have separate slots; retry is idempotent');
select pg_temp.assert_photo((select status='planned' from public.sessions where id='10000000-0000-0000-0000-000000000901'),'guest can post without completing the host session');
select pg_temp.assert_photo(not exists(select 1 from public.posts where session_id='10000000-0000-0000-0000-000000000901'),'participant photo creates no Activity post');

-- Preparing a replacement does not disturb the visible photo. Stale devices cannot overwrite it.
select public.command('prepare_participant_photo','{"session_id":"10000000-0000-0000-0000-000000000901"}',gen_random_uuid())->>'id' as replacement \gset
select object_key as replacement_key from public.media_assets where id=:'replacement' \gset
insert into storage.objects(bucket_id,name) select 'session-photos',object_key from public.media_assets where id=:'replacement';
select pg_temp.assert_photo((select session_photo from public.media_assets where id=:'guest_media'),'old photo stays visible until post');
select pg_temp.assert_photo(pg_temp.photo_refused('post_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','media_id',:'replacement')),'a second unqualified post cannot overwrite the current slot');
select public.command('post_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','media_id',:'replacement','expected_media_id',:'guest_media'),gen_random_uuid());
select pg_temp.assert_photo((select not session_photo from public.media_assets where id=:'guest_media'),'replacement detaches old session photo');
select pg_temp.assert_photo((select count(*)=1 from public.media_assets where owner=auth.uid() and session_photo),'one photo per person after replace');
select pg_temp.assert_photo(pg_temp.photo_refused('remove_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','expected_media_id',:'guest_media')),'stale removal cannot remove replacement');
select pg_temp.assert_photo(pg_temp.photo_refused('remove_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','expected_media_id',:'host_media')),'guest cannot remove host photo');

-- New guests, followers, blocked accounts and unrelated accounts receive neither bytes nor metadata.
do $$ declare person uuid; begin
 for person in select ('00000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(903,907) n loop
  perform set_config('request.jwt.claim.sub',person::text,true);
  perform pg_temp.assert_photo(not exists(select 1 from public.media_assets where session_id='10000000-0000-0000-0000-000000000901'),'nonmember photo metadata denied');
  perform pg_temp.assert_photo(not exists(select 1 from storage.objects where bucket_id='session-photos'),'nonmember private object denied');
  perform pg_temp.assert_photo(pg_temp.photo_refused('prepare_participant_photo','{"session_id":"10000000-0000-0000-0000-000000000901"}'),'nonattendee preparation denied');
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000908',true);
select pg_temp.assert_photo(pg_temp.photo_refused('prepare_participant_photo','{"session_id":"10000000-0000-0000-0000-000000000901"}'),'accepted but unconfirmed attendee cannot post');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000901',true);
select pg_temp.assert_photo(exists(select 1 from public.media_assets where id=:'replacement'),'host sees guest attribution');
select pg_temp.assert_photo(exists(select 1 from storage.objects o join public.media_assets m on o.name=m.object_key where m.id=:'replacement'),'host downloads guest photo');
select pg_temp.assert_photo(not exists(select 1 from public.media_assets where id=:'guest_media'),'host loses access to replaced guest photo');
select public.command('complete_and_publish',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','media_id',:'host_media','attendees',jsonb_build_array('00000000-0000-0000-0000-000000000901','00000000-0000-0000-0000-000000000902')),gen_random_uuid());
select public.command('remove_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','expected_media_id',:'host_media'),gen_random_uuid());
select pg_temp.assert_photo((select media_id=:'host_media'::uuid from public.posts where session_id='10000000-0000-0000-0000-000000000901'),'host session removal preserves published memory');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000906',true);
select pg_temp.assert_photo(exists(select 1 from public.media_assets where id=:'host_media'),'existing host Activity audience retains its image');
select pg_temp.assert_photo(not exists(select 1 from public.media_assets where id=:'replacement'),'Activity audience does not gain guest photo metadata');
select pg_temp.assert_photo(not exists(select 1 from storage.objects o where o.name=:'replacement_key'),'Activity audience cannot read guest photo bytes');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000902',true);
select public.command('remove_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','expected_media_id',:'replacement'),gen_random_uuid());
select pg_temp.assert_photo((select attended from public.session_participants where session_id='10000000-0000-0000-0000-000000000901' and user_id=auth.uid()),'photo removal preserves attendance');
select public.command('post_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','media_id',:'replacement'),gen_random_uuid());
select public.command('correct_attendance','{"session_id":"10000000-0000-0000-0000-000000000901","user_id":"00000000-0000-0000-0000-000000000902","attended":false}',gen_random_uuid());
select pg_temp.assert_photo(not exists(select 1 from public.media_assets where owner=auth.uid() and session_photo),'correcting attendance clears the slot');
select pg_temp.assert_photo(pg_temp.photo_refused('post_participant_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000901','media_id',:'replacement')),'absent person cannot repost');
select pg_temp.assert_photo(not has_function_privilege('anon','public.command(text,jsonb,uuid)','EXECUTE'),'anonymous commands denied');
select pg_temp.assert_photo(not has_function_privilege('authenticated','private.participant_photo_command(text,jsonb)','EXECUTE'),'private helper is not directly callable');

-- Independent storage boundary: exposing media metadata must not expose private bytes.
reset role;
alter table public.media_assets disable row level security;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000907',true);
select pg_temp.assert_photo(not exists(select 1 from storage.objects where bucket_id='session-photos'),'storage independently denies outsiders');
reset role;
rollback;
