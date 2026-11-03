\set ON_ERROR_STOP on
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'Assertion failed: %',message; end if; end $$;
create function pg_temp.fails(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return true; end $$;
create function pg_temp.refused_as_blank(statement text) returns boolean language plpgsql as $$ begin execute statement; return false; exception when others then return sqlerrm='Add a photo or a few words first'; end $$;
create function pg_temp.notes(who uuid,k text) returns bigint language sql as $$ select count(*) from public.notifications n join public.notification_outbox o on o.id=n.id where n.recipient=who and n.kind=k $$;
insert into auth.users values('00000000-0000-0000-0000-000000000031'),('00000000-0000-0000-0000-000000000032');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000031',true);
select public.command('save_profile','{"name":"Host"}',gen_random_uuid());
select public.command('friend_token','{}',gen_random_uuid())->>'token' as token \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000032',true);
select public.command('save_profile','{"name":"Guest"}',gen_random_uuid());

-- Connecting with someone's code notifies them once; scanning again stays quiet.
select public.command('redeem_friend',jsonb_build_object('token',:'token'),gen_random_uuid());
select public.command('redeem_friend',jsonb_build_object('token',:'token'),gen_random_uuid());
reset role;
select pg_temp.assert_true(pg_temp.notes('00000000-0000-0000-0000-000000000031','friend')=1,'new training partner notifies the code owner once, with a push queued');
select pg_temp.assert_true((select entity_id='00000000-0000-0000-0000-000000000032' from public.notifications where kind='friend'),'friend notification points at the new partner');
select pg_temp.assert_true(pg_temp.notes('00000000-0000-0000-0000-000000000032','friend')=0,'the person scanning is not notified');

-- Host plans a past session with Guest and shares it.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000031',true);
select public.command('create_session',jsonb_build_object('title','Open mat','venue','Gym','timezone','UTC','starts_at',now()-interval '1 hour','invited',jsonb_build_array('00000000-0000-0000-0000-000000000032')),gen_random_uuid())->>'id' as sid \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000032',true);
select public.command('set_rsvp',jsonb_build_object('session_id',:'sid','rsvp','going'),gen_random_uuid());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000031',true);
-- A post needs a photo or a few words: blank, whitespace-only and tags-only notes are refused.
select pg_temp.assert_true(pg_temp.refused_as_blank(format($q$select public.command('complete_and_publish',jsonb_build_object('session_id',%L,'attendees',jsonb_build_array('00000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000032')),gen_random_uuid())$q$,:'sid')),'a post with no photo and no note is refused');
select pg_temp.assert_true(pg_temp.refused_as_blank(format($q$select public.command('complete_and_publish',jsonb_build_object('session_id',%L,'caption',E' \n\t ','attendees',jsonb_build_array('00000000-0000-0000-0000-000000000031')),gen_random_uuid())$q$,:'sid')),'a whitespace-only note counts as empty');
select pg_temp.assert_true(pg_temp.refused_as_blank(format($q$select public.command('complete_and_publish',jsonb_build_object('session_id',%L,'caption','@guest @host','attendees',jsonb_build_array('00000000-0000-0000-0000-000000000031')),gen_random_uuid())$q$,:'sid')),'a note of only tags counts as empty');
select pg_temp.assert_true((select status='planned' from public.sessions where id=:'sid'),'a refused post leaves the session uncompleted');
select public.command('complete_and_publish',jsonb_build_object('session_id',:'sid','caption','Standups all round','attendees',jsonb_build_array('00000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000032')),gen_random_uuid())->>'id' as pid \gset
select pg_temp.assert_true(pg_temp.refused_as_blank(format($q$select public.command('edit_post',jsonb_build_object('post_id',%L,'version',1,'caption','  '),gen_random_uuid())$q$,:'pid')),'editing a photo-less post down to nothing is refused');
select public.command('set_like',jsonb_build_object('post_id',:'pid','liked',true),gen_random_uuid());
reset role;
select pg_temp.assert_true(pg_temp.notes('00000000-0000-0000-0000-000000000032','invite')=1,'invites queue a push');
select pg_temp.assert_true(pg_temp.notes('00000000-0000-0000-0000-000000000031','like')=0,'liking your own post is silent');

-- Guest likes, unlikes and likes again: one notification.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000032',true);
select public.command('set_like',jsonb_build_object('post_id',:'pid','liked',true),gen_random_uuid());
select public.command('set_like',jsonb_build_object('post_id',:'pid','liked',false),gen_random_uuid());
select public.command('set_like',jsonb_build_object('post_id',:'pid','liked',true),gen_random_uuid());
select public.command('add_comment',jsonb_build_object('post_id',:'pid','body','Great rolls'),gen_random_uuid());
reset role;
select pg_temp.assert_true(pg_temp.notes('00000000-0000-0000-0000-000000000031','like')=1,'a like notifies the author once');
select pg_temp.assert_true(pg_temp.notes('00000000-0000-0000-0000-000000000031','comment')=1,'a comment notifies the author');

-- Comments can be reported by others, not by their author.
select id as cid from public.comments where post_id=:'pid' \gset
set local role authenticated;
select set_config('test.comment',:'cid',true);
select pg_temp.assert_true(pg_temp.fails($q$select public.command('report_comment',jsonb_build_object('comment_id',current_setting('test.comment'),'reason','Spam'),gen_random_uuid())$q$),'authors cannot report their own comment');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000031',true);
select public.command('report_comment',jsonb_build_object('comment_id',:'cid','reason','Spam'),gen_random_uuid());
select public.command('report_post',jsonb_build_object('post_id',:'pid','reason','Inappropriate'),gen_random_uuid());
reset role;
select pg_temp.assert_true((select count(*)=1 from public.reports where comment_id=:'cid' and post_id=:'pid' and reporter='00000000-0000-0000-0000-000000000031'),'comment report is stored with its post');
select pg_temp.assert_true((select count(*)=2 from public.reports where post_id=:'pid'),'post reports still work');
delete from public.comments where id=:'cid';
select pg_temp.assert_true((select count(*)=1 from public.reports where post_id=:'pid'),'deleting a comment removes its reports');
rollback;
