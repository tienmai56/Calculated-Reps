-- Push for every in-app notification: likes and new training partners now notify,
-- alongside invites, RSVPs, comments and shared memories (all go through the outbox).
-- Comments can be reported, as posts already could. Everything else matches 20261102190144.
alter table public.reports add column comment_id uuid references public.comments on delete cascade;
-- The push worker reads the actor's name to write "Sarah liked your memory".
grant select on public.profiles to service_role;

create or replace function public.command(operation text,payload jsonb,idempotency_key uuid) returns jsonb language plpgsql security definer set search_path='' as $$

#variable_conflict use_variable
 declare actor uuid:=auth.uid(); s public.sessions; p public.posts; cap public.capabilities; receipt public.command_receipts; result jsonb:='{}'; target uuid; entity uuid; person uuid; token text; zone text; media uuid; avatar text; phone_number text; c public.comments; was_friend boolean;
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
 elsif operation in ('friend_token','session_token') then
 entity:=nullif(payload->>'session_id','')::uuid;
 if operation='session_token' and not exists(select 1 from public.sessions where id=entity and organizer=actor and status='planned') then raise exception 'Organizer required'; end if;
 update public.capabilities set revoked=true where owner=actor and kind=case when operation='friend_token' then 'friend' else 'session' end and session_id is not distinct from entity;
 token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.capabilities(owner,kind,session_id,token_hash,expires_at) values(actor,case when operation='friend_token' then 'friend' else 'session' end,entity,extensions.digest(token,'sha256'),now()+interval '1 day');
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
 insert into public.session_participants values(s.id,person,'going',false) on conflict(session_id,user_id) do update set rsvp='going';
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
 for person in select user_id from public.session_participants where session_id=s.id and attended loop perform public.emit_notification(person,actor,'published',p.id,'shared a training memory',p.id::text||person::text); end loop;
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
 else update public.posts set deleted_at=now(),version=version+1 where id=p.id; end if;
 elsif operation='remove_tag' then update public.post_participants set visible=false where post_id=p.id and user_id=actor;
 elsif operation='set_like' then
 if (payload->>'liked')::boolean then
 insert into public.post_likes values(p.id,actor) on conflict do nothing;
 -- One notification per person per post, so unlike/like again never re-notifies.
 perform public.emit_notification(p.author,actor,'like',p.id,'liked your memory',p.id::text||actor::text||'like');
 else delete from public.post_likes where post_id=p.id and user_id=actor; end if;
 elsif operation='add_comment' then
 insert into public.comments(post_id,author,body) values(p.id,actor,trim(payload->>'body'));
 perform public.emit_notification(p.author,actor,'comment',p.id,'commented on your memory',idempotency_key::text);
 else insert into public.reports(reporter,post_id,reason) values(actor,p.id,payload->>'reason'); end if;
 elsif operation='report_comment' then
 select * into c from public.comments where id=(payload->>'comment_id')::uuid;
 if not found or not public.can_post(c.post_id) then raise exception 'Comment unavailable'; end if;
 if c.author=actor then raise exception 'You cannot report your own comment'; end if;
 insert into public.reports(reporter,post_id,comment_id,reason) values(actor,c.post_id,c.id,payload->>'reason');
 elsif operation='read_notifications' then update public.notifications set read_at=now() where recipient=actor and read_at is null;
 elsif operation='unregister_device' then delete from public.device_tokens where user_id=actor and device_tokens.token=payload->>'token';
 elsif operation='register_device' then insert into public.device_tokens values(actor,payload->>'token',payload->>'environment') on conflict on constraint device_tokens_pkey do update set user_id=actor,environment=excluded.environment;
 elsif operation='block_user' then
 target:=(payload->>'user_id')::uuid;
 insert into public.blocks values(actor,target) on conflict do nothing;
 update public.friendships set active=false where a=least(actor,target) and b=greatest(actor,target);
 else raise exception 'Unknown command';
 end if;
 insert into public.command_receipts(actor,operation,key,request,result) values(actor,operation,idempotency_key,payload,result);
 return result;
 end $$;
