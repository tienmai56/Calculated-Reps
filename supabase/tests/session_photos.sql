begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.refused(operation text,payload jsonb) returns boolean language plpgsql as $$ begin perform public.command(operation,payload,gen_random_uuid()); return false; exception when others then return true; end $$;
insert into auth.users(id) select ('00000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(801,807) n;
insert into public.profiles(id,name) select id,'Photo test' from auth.users where id::text like '00000000-0000-0000-0000-00000000080_';
insert into public.sessions(id,organizer,title,starts_at,timezone,venue,join_mode) values
 ('10000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000801','Past training',now()-interval '1 hour','UTC','Gym','link'),
 ('10000000-0000-0000-0000-000000000802','00000000-0000-0000-0000-000000000801','Other training',now()-interval '2 hours','UTC','Gym','friends'),
 ('10000000-0000-0000-0000-000000000803','00000000-0000-0000-0000-000000000801','Future training',now()+interval '1 day','UTC','Gym','link');
insert into public.session_participants(session_id,user_id,rsvp) values
 ('10000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000801','going'),
 ('10000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000802','going'),
 ('10000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000803','invited'),
 ('10000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000804','declined'),
 ('10000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000805','going');
insert into public.blocks(actor,target) values ('00000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000805');
insert into public.friendships(a,b,timezone) values ('00000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000806','UTC');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000801',true);
select public.command('prepare_media','{"session_id":"10000000-0000-0000-0000-000000000801"}',gen_random_uuid())->>'id' as media_id \gset
select pg_temp.assert_true(pg_temp.refused('save_session_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000801','media_id',:'media_id')),'an unuploaded photo cannot be saved');
insert into storage.objects(bucket_id,name) select 'session-photos',object_key from public.media_assets where id=:'media_id';

-- A lost upload response can still be recovered before finalizing the photo.
select pg_temp.assert_true(exists(select 1 from storage.objects o join public.media_assets m on m.object_key=o.name where m.id=:'media_id'),'host can read their pending upload');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000802',true);
select pg_temp.assert_true(not exists(select 1 from public.media_assets where id=:'media_id'),'pending uploads stay private');
select pg_temp.assert_true(not exists(select 1 from storage.objects where bucket_id='session-photos'),'guest cannot download pending uploads');
select pg_temp.assert_true(pg_temp.refused('save_session_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000801','media_id',:'media_id')),'only the host can save session photos');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000801',true);
select pg_temp.assert_true(pg_temp.refused('save_session_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000802','media_id',:'media_id')),'photo must belong to this session');
select gen_random_uuid() as save_key \gset
select public.command('save_session_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000801','media_id',:'media_id'),:'save_key');
select public.command('save_session_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000801','media_id',:'media_id'),:'save_key');
select pg_temp.assert_true((select count(*)=1 from public.media_assets where session_id='10000000-0000-0000-0000-000000000801' and state='ready'),'retry saves one photo');
select pg_temp.assert_true((select status='planned' from public.sessions where id='10000000-0000-0000-0000-000000000801'),'saving a photo does not complete training');
select pg_temp.assert_true(not exists(select 1 from public.posts where session_id='10000000-0000-0000-0000-000000000801'),'saving a photo does not publish a post');
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.snapshot()->'media') m where m->>'id'=:'media_id'),'saved photo survives a fresh snapshot without a post');

-- Approved guests can read both the metadata and the actual private object.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000802',true);
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.snapshot()->'media') m where m->>'id'=:'media_id'),'accepted guest sees saved session photo');
select pg_temp.assert_true(exists(select 1 from storage.objects o join public.media_assets m on m.object_key=o.name where m.id=:'media_id'),'accepted guest can download saved photo');

-- Invitations, declines, blocks, following and unrelated accounts do not grant access.
do $$
declare person uuid;
begin
 for person in select ('00000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(803,807) n loop
  perform set_config('request.jwt.claim.sub',person::text,true);
  perform pg_temp.assert_true(not exists(select 1 from public.media_assets where session_id='10000000-0000-0000-0000-000000000801'),'unauthorized user cannot see photo metadata');
  perform pg_temp.assert_true(not exists(select 1 from storage.objects where bucket_id='session-photos'),'unauthorized user cannot download photo');
 end loop;
end $$;

-- Reuse the saved photo on publish, then keep it with the training if the post is deleted.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000801',true);
select public.command('complete_and_publish',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000801','media_id',:'media_id','attendees',jsonb_build_array('00000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000802')),gen_random_uuid())->>'id' as post_id \gset
select pg_temp.assert_true((select media_id=:'media_id'::uuid from public.posts where id=:'post_id'),'publishing reuses the saved photo');
select pg_temp.assert_true((select count(*)=1 from public.media_assets where session_id='10000000-0000-0000-0000-000000000801'),'publishing does not duplicate session media');
select public.command('delete_post',jsonb_build_object('post_id',:'post_id','version',1),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000802',true);
select pg_temp.assert_true(exists(select 1 from public.media_assets where id=:'media_id'),'session retains its photo independently of the Activity post');
select pg_temp.assert_true(exists(select 1 from storage.objects o join public.media_assets m on m.object_key=o.name where m.id=:'media_id'),'guest can still download session photo after post deletion');

-- A host cannot make future training photos visible early.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000801',true);
select public.command('prepare_media','{"session_id":"10000000-0000-0000-0000-000000000803"}',gen_random_uuid())->>'id' as future_media \gset
insert into storage.objects(bucket_id,name) select 'session-photos',object_key from public.media_assets where id=:'future_media';
select pg_temp.assert_true(pg_temp.refused('save_session_photo',jsonb_build_object('session_id','10000000-0000-0000-0000-000000000803','media_id',:'future_media')),'photos become shareable after training starts');

select pg_temp.assert_true(not has_function_privilege('anon','public.command(text,jsonb,uuid)','EXECUTE'),'anonymous callers cannot use photo commands');

-- Storage must enforce membership independently, even if media RLS changes later.
reset role;
alter table public.media_assets disable row level security;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000807',true);
select pg_temp.assert_true(exists(select 1 from public.media_assets where id=:'media_id'),'fixture exposes media metadata for the independent storage check');
select pg_temp.assert_true(not exists(select 1 from storage.objects where bucket_id='session-photos'),'storage itself denies unrelated users access to ready and pending photos');
reset role;
alter table public.media_assets enable row level security;
rollback;
