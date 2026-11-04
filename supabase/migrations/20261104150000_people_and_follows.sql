-- Search & discover people, and following.
-- * Your circle: your training partners plus the people they train with (one
--   shared partner is enough). Suggestions and name search only ever come from
--   here; there is no public directory. Circle members can see each other's
--   profile (name, belt, gym, photo) so Search can show who someone is.
-- * follows: one-way, instant, no approval. Following never widens what anyone
--   can see: a post stays visible only to the people in it and their training
--   partners (can_post is unchanged).
-- * snapshot gains 'circle' (each circle member with the partners you share)
--   and 'follows' (who you follow).
-- * command gains set_follow, and block_user also removes follows both ways.
--   Everything else matches 20261104130000_notify_added_participants.sql.

create table public.follows (
 follower uuid not null references public.profiles on delete cascade,
 followee uuid not null references public.profiles on delete cascade,
 created_at timestamptz not null default now(),
 primary key(follower,followee),
 check(follower<>followee));
create index follows_followee on public.follows(followee);
alter table public.follows enable row level security;
revoke all on public.follows from anon, authenticated;
grant select on public.follows to authenticated;
create policy follow_read on public.follows for select to authenticated using(follower=auth.uid());

-- x and y share at least one active, unblocked training partner, and haven't blocked each other.
create function public.in_circle(x uuid,y uuid) returns boolean language sql stable security definer set search_path='' as $$
 select x<>y and not public.blocked(x,y) and exists(
 select 1 from public.friendships f where f.active and x in (f.a,f.b)
 and public.are_friends(x,case when f.a=x then f.b else f.a end)
 and public.are_friends(case when f.a=x then f.b else f.a end,y))
$$;
revoke all on function public.in_circle(uuid,uuid) from public,anon;
grant execute on function public.in_circle(uuid,uuid) to authenticated;

-- The signed-in member's circle, minus their own partners: each person with the
-- partners you share, most shared partners first. Capped at 300 people.
create function public.my_circle() returns jsonb language sql stable security definer set search_path='' as $$
 with partners as (
 select case when f.a=auth.uid() then f.b else f.a end as pid from public.friendships f
 where f.active and auth.uid() in (f.a,f.b) and not public.blocked(auth.uid(),case when f.a=auth.uid() then f.b else f.a end)),
 links as (
 select case when f.a=p.pid then f.b else f.a end as person,p.pid from public.friendships f join partners p on p.pid in (f.a,f.b)
 where f.active and not public.blocked(f.a,f.b)),
 people as (
 select l.person,array_agg(l.pid order by l.pid) as mutual from links l
 where l.person<>auth.uid() and l.person not in (select pid from partners) and not public.blocked(auth.uid(),l.person)
 group by l.person order by count(*) desc,l.person limit 300)
 select coalesce(jsonb_agg(jsonb_build_object('id',person,'mutual',to_jsonb(mutual)) order by cardinality(mutual) desc,person),'[]'::jsonb) from people
$$;
revoke all on function public.my_circle() from public,anon;
grant execute on function public.my_circle() to authenticated;

drop policy profile_read on public.profiles;
create policy profile_read on public.profiles for select to authenticated using (id=auth.uid() or public.are_friends(auth.uid(),id)
 or public.in_circle(auth.uid(),id)
 or exists(select 1 from public.session_participants p where p.user_id=id and public.can_session(p.session_id))
 or exists(select 1 from public.post_participants p where p.user_id=id and public.can_post(p.post_id))
 or exists(select 1 from public.shared_goals g where g.owner=profiles.id and public.can_goal(g.id))
 or exists(select 1 from public.goal_shares s join public.shared_goals g on g.id=s.goal_id where s.recipient=profiles.id and g.owner=auth.uid()));

create or replace function public.command(operation text,payload jsonb,idempotency_key uuid) returns jsonb language plpgsql security definer set search_path='' as $$

#variable_conflict use_variable
 declare actor uuid:=auth.uid(); s public.sessions; p public.posts; cap public.capabilities; receipt public.command_receipts; result jsonb:='{}'; target uuid; entity uuid; person uuid; token text; zone text; media uuid; avatar text; phone_number text; c public.comments; was_friend boolean; g public.shared_goals; share_status text; part jsonb; link text; photo text; keys text[];
 begin
 if actor is null then raise exception 'Authentication required'; end if;
 -- Serialize commands per actor, including simultaneous retries before profile creation.
 perform pg_advisory_xact_lock(hashtextextended(actor::text,0));
 select * into receipt from public.command_receipts r where r.actor=actor and r.operation=operation and r.key=idempotency_key;
 if found then if receipt.request<>payload then raise exception 'Idempotency key reused with different payload'; end if; return receipt.result; end if;
 if (select count(*) from public.command_receipts r where r.actor=actor and r.created_at>now()-interval '1 minute')>=120 then raise exception 'Too many requests. Try again shortly'; end if;
 if operation='add_comment' and (select count(*) from public.command_receipts r where r.actor=actor and r.operation='add_comment' and r.created_at>now()-interval '1 minute')>=20 then raise exception 'Please wait before commenting again'; end if;
 if operation='save_profile' then
 zone:=coalesce(payload->>'timezone','UTC'); if not exists(select 1 from pg_timezone_names where name=zone) then raise exception 'Invalid timezone'; end if;
 if coalesce(payload->>'belt','white') not in ('white','blue','purple','brown','black','coral','red','grey','yellow','orange','green') then raise exception 'Invalid belt'; end if;
 -- Optional profile photo: must be the caller's own upload in the avatars bucket.
 avatar:=nullif(payload->>'avatar_key','');
 if avatar is not null and (split_part(avatar,'/',1)<>actor::text or not exists(select 1 from storage.objects o where o.bucket_id='avatars' and o.name=avatar)) then raise exception 'Profile photo upload missing'; end if;
 -- Optional phone number, stored privately in account settings in E.164 form.
 phone_number:=nullif(regexp_replace(coalesce(payload->>'phone',''),'[^0-9+]','','g'),'');
 if phone_number is not null and phone_number !~ '^\+[0-9]{7,15}$' then raise exception 'Invalid phone number'; end if;
 insert into public.profiles(id,name,belt,stripes,gym,avatar_key) values(actor,trim(payload->>'name'),coalesce(payload->>'belt','white'),coalesce((payload->>'stripes')::int,0),coalesce(payload->>'gym',''),avatar) on conflict(id) do update set name=excluded.name,belt=excluded.belt,stripes=excluded.stripes,gym=excluded.gym,avatar_key=coalesce(excluded.avatar_key,public.profiles.avatar_key);
 insert into public.account_settings(user_id,timezone,phone) values(actor,zone,phone_number) on conflict(user_id) do update set timezone=excluded.timezone,phone=coalesce(excluded.phone,public.account_settings.phone);
 elsif not exists(select 1 from public.profiles where id=actor) then raise exception 'Create a profile first';
 elsif operation='set_username' then
 token:=lower(trim(coalesce(payload->>'username','')));
 if token !~ '^[a-z0-9_]{3,40}$' then raise exception 'Use 3–40 letters, numbers or underscores for your username'; end if;
 begin
 update public.profiles set username=token where id=actor;
 exception when unique_violation then raise exception 'That username is already taken'; end;
 result:=jsonb_build_object('username',token);
 elsif operation='create_session' then
 zone:=payload->>'timezone'; if not exists(select 1 from pg_timezone_names where name=zone) then raise exception 'Invalid timezone'; end if;
 insert into public.sessions(organizer,title,starts_at,timezone,venue,note,join_mode) values(actor,trim(payload->>'title'),(payload->>'starts_at')::timestamptz,zone,trim(payload->>'venue'),coalesce(payload->>'note',''),coalesce(payload->>'join_mode','friends')) returning * into s;
 insert into public.session_participants values(s.id,actor,'going',false);
 for person in select value::text::uuid from jsonb_array_elements_text(coalesce(payload->'invited','[]')) loop
 if not public.are_friends(actor,person) then raise exception 'Invite friends only'; end if;
 insert into public.session_participants values(s.id,person,'invited',false);
 perform public.emit_notification(person,actor,'invite',s.id,'invited you to '||s.title,s.id::text||person::text||'invite');
 end loop;
 result:=jsonb_build_object('id',s.id);
 elsif operation='friend_token' then
 -- Commands are serialized per actor above, including across devices.
 -- Recover the caller's existing code only if its capability is still active.
 select r.result->>'token' into token
 from public.command_receipts r
 join public.capabilities issued_capability on issued_capability.token_hash=extensions.digest(r.result->>'token','sha256')
 where r.actor=actor and r.operation='friend_token'
 and issued_capability.owner=actor and issued_capability.kind='friend'
 and issued_capability.session_id is null and not issued_capability.revoked
 order by r.created_at desc,r.key limit 1;
 if token is null then
 token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.capabilities(owner,kind,token_hash,expires_at)
 values(actor,'friend',extensions.digest(token,'sha256'),'infinity'::timestamptz);
 end if;
 result:=jsonb_build_object('token',token);
 elsif operation='session_token' then
 entity:=nullif(payload->>'session_id','')::uuid;
 if not exists(select 1 from public.sessions where id=entity and organizer=actor and status='planned') then raise exception 'Organizer required'; end if;
 update public.capabilities set revoked=true where owner=actor and kind='session' and session_id=entity;
 token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.capabilities(owner,kind,session_id,token_hash,expires_at)
 values(actor,'session',entity,extensions.digest(token,'sha256'),now()+interval '1 day');
 result:=jsonb_build_object('token',token);
 elsif operation in ('redeem_friend','join_link') then
 select * into cap from public.capabilities where token_hash=extensions.digest(payload->>'token','sha256') and not revoked and expires_at>now();
 if not found or public.blocked(actor,cap.owner) then raise exception 'Link expired or unavailable'; end if;
 if operation='redeem_friend' then
 if cap.kind<>'friend' or cap.owner=actor then raise exception 'Invalid friend code'; end if;
 select timezone into zone from public.account_settings where user_id=cap.owner;
 was_friend:=public.are_friends(actor,cap.owner);
 insert into public.friendships(a,b,timezone) values(least(actor,cap.owner),greatest(actor,cap.owner),coalesce(zone,'UTC')) on conflict(a,b) do update set active=true,connected_at=case when public.friendships.active then public.friendships.connected_at else now() end;
 -- Tell the code's owner someone new connected (re-scanning an active friendship stays quiet).
 if not was_friend then perform public.emit_notification(cap.owner,actor,'friend',actor,'added you as a training partner',idempotency_key::text); end if;
 result:=jsonb_build_object('id',cap.owner);
 else
 if cap.kind<>'session' then raise exception 'Invalid session link'; end if;
 select * into s from public.sessions where id=cap.session_id for update;
 if s.status<>'planned' then raise exception 'Session is not open'; end if;
 insert into public.session_participants values(s.id,actor,'going',false) on conflict(session_id,user_id) do update set rsvp='going';
 result:=jsonb_build_object('id',s.id);
 end if;
 elsif operation in ('set_rsvp','edit_session','manage_participant','cancel_session','complete_and_publish','correct_attendance','prepare_media') then
 select * into s from public.sessions where id=(payload->>'session_id')::uuid for update;
 if not found then raise exception 'Session unavailable'; end if;
 if operation='set_rsvp' then
 if s.status<>'planned' or not exists(select 1 from public.session_participants where session_id=s.id and user_id=actor) then raise exception 'Invitation required'; end if;
 if payload->>'rsvp' not in ('going','declined') then raise exception 'Invalid RSVP'; end if;
 update public.session_participants set rsvp=payload->>'rsvp' where session_id=s.id and user_id=actor;
 perform public.emit_notification(s.organizer,actor,'joined',s.id,'responded to '||s.title,idempotency_key::text);
 elsif operation='correct_attendance' then
 person:=(payload->>'user_id')::uuid;
 if actor<>s.organizer and (person<>actor or coalesce((payload->>'attended')::boolean,true)) then raise exception 'Cannot change another attendance'; end if;
 if s.status<>'completed' then raise exception 'Completed session required'; end if;
 update public.session_participants set attended=(payload->>'attended')::boolean where session_id=s.id and user_id=person;
 perform public.rebuild_credits(s.id);
 else
 if actor<>s.organizer then raise exception 'Organizer required'; end if;
 if operation<>'complete_and_publish' and s.status<>'planned' then raise exception 'Planned session required'; end if;
 if operation='edit_session' then
 if (payload->>'version')::int is distinct from s.version then raise exception 'Session changed. Refresh before editing'; end if;
 zone:=payload->>'timezone'; if not exists(select 1 from pg_timezone_names where name=zone) then raise exception 'Invalid timezone'; end if;
 update public.sessions set title=trim(payload->>'title'),starts_at=(payload->>'starts_at')::timestamptz,timezone=zone,venue=trim(payload->>'venue'),note=coalesce(payload->>'note',''),version=version+1 where id=s.id;
 elsif operation='manage_participant' then
 person:=(payload->>'user_id')::uuid;
 if person=actor then raise exception 'Organizer cannot be removed'; end if;
 if (payload->>'remove')::boolean then delete from public.session_participants where session_id=s.id and user_id=person;
 else
 if not public.are_friends(actor,person) then raise exception 'Friends only'; end if;
 if s.starts_at>now() then
 -- Upcoming: invite and notify. Someone who declined is invited again; anyone already going stays going.
 insert into public.session_participants values(s.id,person,'invited',false) on conflict(session_id,user_id) do update set rsvp='invited' where public.session_participants.rsvp='declined';
 if found then perform public.emit_notification(person,actor,'invite',s.id,'invited you to '||s.title,s.id::text||person::text||'invite'||idempotency_key::text); end if;
 else
 insert into public.session_participants values(s.id,person,'going',false) on conflict(session_id,user_id) do update set rsvp='going';
 end if;
 end if;
 elsif operation='cancel_session' then update public.sessions set status='cancelled',version=version+1 where id=s.id;
 elsif operation='prepare_media' then
 media:=gen_random_uuid();
 insert into public.media_assets(id,owner,session_id,object_key) values(media,actor,s.id,actor::text||'/'||media::text||'.jpg');
 result:=jsonb_build_object('id',media,'object_key',actor::text||'/'||media::text||'.jpg');
 elsif operation='complete_and_publish' then
 if s.status<>'planned' or s.starts_at>now() then raise exception 'Session cannot be completed'; end if;
 if jsonb_array_length(payload->'attendees')<1 or not (payload->'attendees' ? actor::text) then raise exception 'Organizer must attend'; end if;
 for person in select value::text::uuid from jsonb_array_elements_text(payload->'attendees') loop
 if not exists(select 1 from public.session_participants where session_id=s.id and user_id=person and rsvp='going') then raise exception 'Invalid attendee'; end if;
 end loop;
 media:=nullif(payload->>'media_id','')::uuid;
 if media is not null then
 if not exists(select 1 from public.media_assets m join storage.objects o on o.name=m.object_key and o.bucket_id='session-photos' where m.id=media and m.owner=actor and m.session_id=s.id) then raise exception 'Photo upload not ready'; end if;
 update public.media_assets set state='ready' where id=media;
 end if;
 update public.sessions set status='completed',completed_at=now(),version=version+1 where id=s.id;
 update public.session_participants set attended=(payload->'attendees' ? user_id::text) where session_id=s.id;
 insert into public.posts(session_id,author,title,venue,occurred_at,caption,media_id) values(s.id,actor,s.title,s.venue,s.starts_at,coalesce(payload->>'caption',''),media) returning * into p;
 insert into public.post_participants select p.id,user_id,true from public.session_participants where session_id=s.id and attended;
 perform public.rebuild_credits(s.id);
 perform public.emit_mentions(p.id,p.caption,p.id::text,false);
 for person in select user_id from public.session_participants where session_id=s.id and attended and not exists(select 1 from public.notifications n where n.dedupe_key=p.id::text||user_id::text||'mention') loop perform public.emit_notification(person,actor,'published',p.id,'shared a training memory',p.id::text||person::text); end loop;
 result:=jsonb_build_object('id',p.id);
 end if;
 end if;
 elsif operation in ('edit_post','delete_post','remove_tag','set_like','add_comment','report_post') then
 select * into p from public.posts where id=(payload->>'post_id')::uuid for update;
 if not found or not public.can_post(p.id) then raise exception 'Post unavailable'; end if;
 if operation in ('edit_post','delete_post') then
 if p.author<>actor then raise exception 'Organizer required'; end if;
 if (payload->>'version')::int is distinct from p.version then raise exception 'Post changed. Refresh before editing'; end if;
 if operation='edit_post' then update public.posts set caption=payload->>'caption',version=version+1 where id=p.id;
 perform public.emit_mentions(p.id,payload->>'caption',p.id::text,false);
 else update public.posts set deleted_at=now(),version=version+1 where id=p.id; end if;
 elsif operation='remove_tag' then update public.post_participants set visible=false where post_id=p.id and user_id=actor;
 elsif operation='set_like' then
 if (payload->>'liked')::boolean then
 insert into public.post_likes values(p.id,actor) on conflict do nothing;
 -- One notification per person per post, so unlike/like again never re-notifies.
 perform public.emit_notification(p.author,actor,'like',p.id,'liked your memory',p.id::text||actor::text||'like');
 else delete from public.post_likes where post_id=p.id and user_id=actor; end if;
 elsif operation='add_comment' then
 insert into public.comments(post_id,author,body) values(p.id,actor,trim(payload->>'body')) returning * into c;
 perform public.emit_mentions(p.id,c.body,c.id::text,true);
 -- A tagged post author receives the mention instead of two alerts for this comment.
 if not exists(select 1 from public.notifications n where n.dedupe_key=c.id::text||p.author::text||'mention') then
 perform public.emit_notification(p.author,actor,'comment',p.id,'commented on your memory',idempotency_key::text);
 end if;
 else insert into public.reports(reporter,post_id,reason) values(actor,p.id,payload->>'reason'); end if;
 elsif operation='report_comment' then
 select * into c from public.comments where id=(payload->>'comment_id')::uuid;
 if not found or not public.can_post(c.post_id) then raise exception 'Comment unavailable'; end if;
 if c.author=actor then raise exception 'You cannot report your own comment'; end if;
 insert into public.reports(reporter,post_id,comment_id,reason) values(actor,c.post_id,c.id,payload->>'reason');
 elsif operation='publish_goal' then
 -- Creates or updates the owner's shared copy. Photos must already be the owner's uploads.
 if length(coalesce(payload->>'client_id',''))=0 then raise exception 'Invalid goal'; end if;
 if length(trim(coalesce(payload->>'title','')))=0 or length(payload->>'title')>160 then raise exception 'Name the goal first'; end if;
 if length(coalesce(payload->>'notes',''))>8000 then raise exception 'Those goal notes are too long'; end if;
 if jsonb_typeof(coalesce(payload->'links','[]'))<>'array' or jsonb_typeof(coalesce(payload->'photos','[]'))<>'array' or jsonb_typeof(coalesce(payload->'parts','[]'))<>'array' then raise exception 'Invalid goal'; end if;
 if jsonb_array_length(coalesce(payload->'parts','[]'))>40 or jsonb_array_length(coalesce(payload->'links','[]'))>30 then raise exception 'That goal has too many parts or links to share'; end if;
 for part in select value from jsonb_array_elements(coalesce(payload->'parts','[]')) loop
 if jsonb_typeof(part)<>'object' or length(coalesce(part->>'title',''))>160 or length(coalesce(part->>'notes',''))>4000 or jsonb_typeof(coalesce(part->'photos','[]'))<>'array' then raise exception 'Invalid goal part'; end if;
 end loop;
 for link in select value from jsonb_array_elements_text(coalesce(payload->'links','[]'))
 union all select x->>'link' from jsonb_array_elements(coalesce(payload->'parts','[]')) x where coalesce(x->>'link','')<>'' loop
 if link !~* '^https?://\S+$' or length(link)>2000 then raise exception 'Invalid link'; end if;
 end loop;
 keys:=array(select value from jsonb_array_elements_text(coalesce(payload->'photos','[]'))
 union all select ph.value from jsonb_array_elements(coalesce(payload->'parts','[]')) x cross join lateral jsonb_array_elements_text(coalesce(x->'photos','[]')) ph);
 if cardinality(keys)>60 then raise exception 'That goal has too many photos to share'; end if;
 foreach photo in array keys loop
 if split_part(photo,'/',1)<>actor::text or not exists(select 1 from storage.objects o where o.bucket_id='goal-media' and o.name=photo) then raise exception 'Goal photo upload missing'; end if;
 end loop;
 insert into public.shared_goals(owner,client_id,title,notes,links,photos,parts,media)
 values(actor,payload->>'client_id',trim(payload->>'title'),coalesce(payload->>'notes',''),coalesce(payload->'links','[]'),coalesce(payload->'photos','[]'),coalesce(payload->'parts','[]'),keys)
 on conflict(owner,client_id) do update set title=excluded.title,notes=excluded.notes,links=excluded.links,photos=excluded.photos,parts=excluded.parts,media=excluded.media,
 version=public.shared_goals.version+1,updated_at=now(),deleted_at=null returning * into g;
 result:=jsonb_build_object('id',g.id,'version',g.version);
 elsif operation in ('share_goal','goal_token','unshare_goal') then
 select * into g from public.shared_goals where id=(payload->>'goal_id')::uuid for update;
 if not found or g.owner<>actor or g.deleted_at is not null then raise exception 'Goal unavailable'; end if;
 if operation='share_goal' then
 if jsonb_typeof(payload->'recipients') is distinct from 'array' or jsonb_array_length(payload->'recipients') not between 1 and 50 then raise exception 'Pick who to share it with'; end if;
 for person in select value::uuid from jsonb_array_elements_text(payload->'recipients') loop
 if person=actor or not public.are_friends(actor,person) then raise exception 'Share with training partners only'; end if;
 select gs.status into share_status from public.goal_shares gs where gs.goal_id=g.id and gs.recipient=person for update;
 if not found then insert into public.goal_shares(goal_id,recipient) values(g.id,person);
 -- Sharing again after a decline asks again; pending or accepted stays quiet.
 elsif share_status='declined' then update public.goal_shares set status='pending',created_at=now(),responded_at=null where goal_id=g.id and recipient=person;
 else continue; end if;
 perform public.emit_notification(person,actor,'goal_share',g.id,'shared '||g.title||' with you',g.id::text||person::text||idempotency_key::text);
 end loop;
 result:=jsonb_build_object('id',g.id);
 elsif operation='goal_token' then
 -- Links stay valid together: copying a new one doesn't break one already sent.
 token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.capabilities(owner,kind,goal_id,token_hash,expires_at) values(actor,'goal',g.id,extensions.digest(token,'sha256'),now()+interval '30 days');
 result:=jsonb_build_object('token',token);
 else
 update public.shared_goals set deleted_at=now(),version=version+1 where id=g.id;
 update public.capabilities set revoked=true where goal_id=g.id;
 end if;
 elsif operation='redeem_goal_link' then
 select * into cap from public.capabilities where token_hash=extensions.digest(payload->>'token','sha256') and kind='goal' and not revoked and expires_at>now();
 if not found or public.blocked(actor,cap.owner) then raise exception 'Link expired or unavailable'; end if;
 select * into g from public.shared_goals where id=cap.goal_id;
 if not found or g.deleted_at is not null then raise exception 'That goal isn''t shared anymore'; end if;
 if g.owner<>actor then
 insert into public.goal_shares(goal_id,recipient,via) values(g.id,actor,'link')
 on conflict(goal_id,recipient) do update set status='pending',created_at=now(),responded_at=null where public.goal_shares.status='declined';
 end if;
 result:=jsonb_build_object('id',g.id,'own',g.owner=actor);
 elsif operation='respond_goal_share' then
 perform 1 from public.goal_shares gs join public.shared_goals sg on sg.id=gs.goal_id
 where gs.goal_id=(payload->>'goal_id')::uuid and gs.recipient=actor and sg.deleted_at is null and not public.blocked(actor,sg.owner) for update of gs;
 if not found then raise exception 'That goal isn''t shared anymore'; end if;
 update public.goal_shares set status=case when (payload->>'accept')::boolean then 'accepted' else 'declined' end,responded_at=now()
 where goal_id=(payload->>'goal_id')::uuid and recipient=actor;
 update public.notifications set read_at=now() where recipient=actor and kind='goal_share' and entity_id=(payload->>'goal_id')::uuid and read_at is null;
 elsif operation='read_notifications' then update public.notifications set read_at=now() where recipient=actor and read_at is null;
 elsif operation='unregister_device' then delete from public.device_tokens where user_id=actor and device_tokens.token=payload->>'token';
 elsif operation='register_device' then insert into public.device_tokens values(actor,payload->>'token',payload->>'environment') on conflict on constraint device_tokens_pkey do update set user_id=actor,environment=excluded.environment;
 elsif operation='block_user' then
 target:=(payload->>'user_id')::uuid;
 insert into public.blocks values(actor,target) on conflict do nothing;
 update public.friendships set active=false where a=least(actor,target) and b=greatest(actor,target);
 delete from public.follows where (follower=actor and followee=target) or (follower=target and followee=actor);
 elsif operation='set_follow' then
 -- One-way and instant, no approval. Only people in your circle (your training partners and
 -- the people they train with), or on a partner list you can see (20261104160000_partner_lists.sql).
 target:=(payload->>'user_id')::uuid;
 if target is null or target=actor then raise exception 'Choose someone to follow'; end if;
 if coalesce((payload->>'follow')::boolean,true) then
 if not (public.are_friends(actor,target) or public.in_circle(actor,target) or public.listed_partner(actor,target)) then raise exception 'You can follow people who train with your training partners'; end if;
 insert into public.follows(follower,followee) values(actor,target) on conflict do nothing;
 else
 delete from public.follows where follower=actor and followee=target;
 end if;
 else raise exception 'Unknown command';
 end if;
 insert into public.command_receipts(actor,operation,key,request,result) values(actor,operation,idempotency_key,payload,result);
 return result;
 end $$;
revoke all on function public.command(text,jsonb,uuid) from public,anon;
grant execute on function public.command(text,jsonb,uuid) to authenticated;

create or replace function public.snapshot() returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object(
 'server_time',now(),
 'profiles',coalesce((select jsonb_agg(t) from public.profiles t),'[]'::jsonb),
 'friendships',coalesce((select jsonb_agg(t) from public.friendships t where active),'[]'::jsonb),
 'sessions',coalesce((select jsonb_agg(t) from (select * from public.sessions where status<>'cancelled' order by starts_at desc limit 100) t),'[]'::jsonb),
 'participants',coalesce((select jsonb_agg(t) from public.session_participants t),'[]'::jsonb),
 'posts',coalesce((select jsonb_agg(t) from (select * from public.posts where deleted_at is null order by published_at desc,id desc limit 30) t),'[]'::jsonb),
 'tags',coalesce((select jsonb_agg(t) from public.post_participants t where visible),'[]'::jsonb),
 'likes',coalesce((select jsonb_agg(t) from public.post_likes t),'[]'::jsonb),
 'comments',coalesce((select jsonb_agg(t) from (select * from public.comments order by created_at desc limit 300) t),'[]'::jsonb),
 'credits',coalesce((select jsonb_agg(t) from public.friendship_session_credits t),'[]'::jsonb),
 'media',coalesce((select jsonb_agg(t) from public.media_assets t where state='ready'),'[]'::jsonb),
 'notifications',coalesce((select jsonb_agg(t) from (select * from public.notifications order by created_at desc limit 100) t),'[]'::jsonb),
 'shared_goals',coalesce((select jsonb_agg(t) from (select * from public.shared_goals where deleted_at is null order by updated_at desc limit 200) t),'[]'::jsonb),
 'goal_shares',coalesce((select jsonb_agg(t) from (select * from public.goal_shares order by created_at desc limit 1000) t),'[]'::jsonb),
 'circle',public.my_circle(),
 'follows',coalesce((select jsonb_agg(t) from public.follows t),'[]'::jsonb));
$$;
revoke all on function public.snapshot() from public,anon;
grant execute on function public.snapshot() to authenticated;
