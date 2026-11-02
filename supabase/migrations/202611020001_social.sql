-- Shared social data only. Legacy notebooks have no cloud tables or upload route.
create extension if not exists pgcrypto with schema extensions;
create table public.profiles (id uuid primary key references auth.users on delete cascade, name text not null check(length(name) between 1 and 120), belt text not null default 'white', stripes int not null default 0 check(stripes between 0 and 4), gym text not null default '', avatar_key text);
create table public.account_settings (user_id uuid primary key references auth.users on delete cascade, timezone text not null default 'UTC', push_enabled boolean not null default true);
create table public.friendships (id uuid primary key default gen_random_uuid(), a uuid not null references public.profiles, b uuid not null references public.profiles, hue text not null default 'mint', timezone text not null, connected_at timestamptz not null default now(), active boolean not null default true, check(a<b), unique(a,b));
create table public.blocks (actor uuid references public.profiles, target uuid references public.profiles, primary key(actor,target), check(actor<>target));
create table public.sessions (id uuid primary key default gen_random_uuid(), organizer uuid not null references public.profiles, title text not null check(length(title) between 1 and 160), starts_at timestamptz not null, timezone text not null, venue text not null check(length(venue) between 1 and 240), note text not null default '' check(length(note)<=4000), join_mode text not null default 'friends' check(join_mode in ('friends','link')), status text not null default 'planned' check(status in ('planned','completed','cancelled')), completed_at timestamptz, version int not null default 1);
create table public.session_participants (session_id uuid references public.sessions on delete cascade, user_id uuid references public.profiles, rsvp text not null check(rsvp in ('invited','going','declined')), attended boolean not null default false, primary key(session_id,user_id));
create table public.capabilities (id uuid primary key default gen_random_uuid(), owner uuid not null references public.profiles, kind text not null check(kind in ('friend','session')), session_id uuid references public.sessions, token_hash bytea not null unique, expires_at timestamptz not null, revoked boolean not null default false);
create table public.posts (id uuid primary key default gen_random_uuid(), session_id uuid not null unique references public.sessions, author uuid not null references public.profiles, title text not null, venue text not null, occurred_at timestamptz not null, caption text not null default '' check(length(caption)<=4000), published_at timestamptz not null default now(), deleted_at timestamptz, version int not null default 1);
create table public.post_participants (post_id uuid references public.posts on delete cascade, user_id uuid references public.profiles, visible boolean not null default true, primary key(post_id,user_id));
create table public.media_assets (id uuid primary key default gen_random_uuid(), owner uuid not null references public.profiles, session_id uuid references public.sessions, object_key text not null unique, state text not null default 'pending' check(state in ('pending','ready')), created_at timestamptz not null default now());
alter table public.posts add column media_id uuid references public.media_assets;
create table public.post_likes (post_id uuid references public.posts on delete cascade, user_id uuid references public.profiles, primary key(post_id,user_id));
create table public.comments (id uuid primary key default gen_random_uuid(), post_id uuid not null references public.posts on delete cascade, author uuid not null references public.profiles, body text not null check(length(trim(body)) between 1 and 2000), created_at timestamptz not null default now());
create table public.friendship_session_credits (friendship_id uuid references public.friendships, session_id uuid references public.sessions, week_start date not null, primary key(friendship_id,session_id));
create view public.friendship_weeks with (security_invoker=true) as select friendship_id,week_start,count(*) qualifying_count from public.friendship_session_credits group by friendship_id,week_start;
create table public.notifications (id uuid primary key default gen_random_uuid(), recipient uuid not null references public.profiles, actor uuid references public.profiles, kind text not null, entity_id uuid, message text not null, created_at timestamptz not null default now(), read_at timestamptz, dedupe_key text not null unique);
create table public.device_tokens (user_id uuid references public.profiles, token text primary key, environment text not null check(environment in ('sandbox','production')));
create table public.notification_outbox (id uuid primary key references public.notifications on delete cascade, attempts int not null default 0, next_attempt timestamptz not null default now(), delivered_at timestamptz, last_error text);
create table public.command_receipts (actor uuid references public.profiles, operation text not null, key uuid not null, request jsonb not null, result jsonb not null, created_at timestamptz not null default now(), primary key(actor,operation,key));
create table public.reports (id uuid primary key default gen_random_uuid(), reporter uuid not null references public.profiles, post_id uuid references public.posts, reason text not null check(length(reason) between 1 and 2000), created_at timestamptz default now());
create index friendships_b on public.friendships(b);
create index sessions_start on public.sessions(organizer,starts_at);
create index participants_user on public.session_participants(user_id,rsvp,session_id);
create index posts_cursor on public.posts(published_at desc,id desc) where deleted_at is null;
create index comments_post on public.comments(post_id,created_at,id);
create index credits_weeks on public.friendship_session_credits(friendship_id,week_start);
create index notifications_user on public.notifications(recipient,created_at desc);
create index outbox_pending on public.notification_outbox(next_attempt) where delivered_at is null;

create function public.blocked(x uuid,y uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.blocks where (actor=x and target=y) or (actor=y and target=x)) $$;
create function public.are_friends(x uuid,y uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.friendships where a=least(x,y) and b=greatest(x,y) and active) and not public.blocked(x,y) $$;
create function public.can_session(s uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.sessions t where t.id=s and (t.organizer=auth.uid() or (not public.blocked(auth.uid(),t.organizer) and exists(select 1 from public.session_participants p where p.session_id=s and p.user_id=auth.uid())))) $$;
create function public.can_post(p uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.posts t where t.id=p and t.deleted_at is null and not public.blocked(auth.uid(),t.author) and (t.author=auth.uid() or exists(select 1 from public.post_participants pp where pp.post_id=p and pp.visible and not public.blocked(auth.uid(),pp.user_id) and (pp.user_id=auth.uid() or public.are_friends(auth.uid(),pp.user_id)))))
$$;
-- Helpers take only IDs and expose boolean authorization decisions, not records.
revoke all on function public.blocked(uuid,uuid),public.are_friends(uuid,uuid),public.can_session(uuid),public.can_post(uuid) from public;
grant execute on function public.blocked(uuid,uuid),public.are_friends(uuid,uuid),public.can_session(uuid),public.can_post(uuid) to authenticated;

do $$ declare t text; begin
 foreach t in array array['profiles','account_settings','friendships','blocks','sessions','session_participants','capabilities','posts','post_participants','media_assets','post_likes','comments','friendship_session_credits','notifications','device_tokens','notification_outbox','command_receipts','reports'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 end loop;
end $$;
grant select on public.profiles, public.account_settings, public.friendships, public.sessions, public.session_participants, public.posts, public.post_participants, public.media_assets, public.post_likes, public.comments, public.friendship_session_credits,public.friendship_weeks, public.notifications to authenticated;
create policy profile_read on public.profiles for select to authenticated using (id=auth.uid() or public.are_friends(auth.uid(),id) or exists(select 1 from public.session_participants p where p.user_id=id and public.can_session(p.session_id)) or exists(select 1 from public.post_participants p where p.user_id=id and public.can_post(p.post_id)));
create policy settings_read on public.account_settings for select to authenticated using(user_id=auth.uid());
create policy friendship_read on public.friendships for select to authenticated using(auth.uid() in (a,b));
create policy session_read on public.sessions for select to authenticated using(public.can_session(id));
create policy participant_read on public.session_participants for select to authenticated using(public.can_session(session_id));
create policy post_read on public.posts for select to authenticated using(public.can_post(id));
create policy tags_read on public.post_participants for select to authenticated using(public.can_post(post_id));
create policy likes_read on public.post_likes for select to authenticated using(public.can_post(post_id));
create policy comments_read on public.comments for select to authenticated using(public.can_post(post_id));
create policy media_read on public.media_assets for select to authenticated using(owner=auth.uid() or exists(select 1 from public.posts p where p.media_id=media_assets.id and public.can_post(p.id)));
create policy credits_read on public.friendship_session_credits for select to authenticated using(exists(select 1 from public.friendships f where f.id=friendship_id and auth.uid() in(f.a,f.b)));
create policy notifications_read on public.notifications for select to authenticated using(recipient=auth.uid());

create function public.emit_notification(recipient uuid, actor uuid, kind text, entity uuid, message text, dedupe text) returns void language plpgsql security definer set search_path='' as $$
 declare n uuid; begin
 if recipient=actor or public.blocked(recipient,actor) then return; end if;
 insert into public.notifications(recipient,actor,kind,entity_id,message,dedupe_key) values(recipient,actor,kind,entity,message,dedupe) on conflict(dedupe_key) do nothing returning id into n;
 if n is not null then insert into public.notification_outbox(id) values(n); end if;
 end $$;
revoke all on function public.emit_notification(uuid,uuid,text,uuid,text,text) from public,authenticated;
create function public.rebuild_credits(s uuid) returns void language plpgsql security definer set search_path='' as $$
 begin
 delete from public.friendship_session_credits where session_id=s;
 insert into public.friendship_session_credits(friendship_id,session_id,week_start)
 select f.id,t.id,date_trunc('week',t.starts_at at time zone f.timezone)::date
 from public.sessions t join public.session_participants p on p.session_id=t.id and p.attended
 join public.session_participants q on q.session_id=t.id and q.attended and p.user_id<q.user_id
 join public.friendships f on f.a=p.user_id and f.b=q.user_id and f.active and f.connected_at<=t.starts_at
 where t.id=s and t.status='completed' and not public.blocked(f.a,f.b);
 end $$;
revoke all on function public.rebuild_credits(uuid) from public,authenticated;

-- All social writes use this single transactional boundary. No legacy upload command exists.
create function public.command(operation text,payload jsonb,idempotency_key uuid) returns jsonb language plpgsql security definer set search_path='' as $$

#variable_conflict use_variable
 declare actor uuid:=auth.uid(); s public.sessions; p public.posts; cap public.capabilities; receipt public.command_receipts; result jsonb:='{}'; target uuid; entity uuid; person uuid; token text; zone text; media uuid;
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
 insert into public.profiles(id,name,belt,stripes,gym) values(actor,trim(payload->>'name'),coalesce(payload->>'belt','white'),coalesce((payload->>'stripes')::int,0),coalesce(payload->>'gym','')) on conflict(id) do update set name=excluded.name,belt=excluded.belt,stripes=excluded.stripes,gym=excluded.gym;
 insert into public.account_settings(user_id,timezone) values(actor,zone) on conflict(user_id) do update set timezone=excluded.timezone;
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
 insert into public.friendships(a,b,timezone) values(least(actor,cap.owner),greatest(actor,cap.owner),coalesce(zone,'UTC')) on conflict(a,b) do update set active=true,connected_at=case when public.friendships.active then public.friendships.connected_at else now() end;
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
 if (payload->>'liked')::boolean then insert into public.post_likes values(p.id,actor) on conflict do nothing; else delete from public.post_likes where post_id=p.id and user_id=actor; end if;
 elsif operation='add_comment' then
 insert into public.comments(post_id,author,body) values(p.id,actor,trim(payload->>'body'));
 perform public.emit_notification(p.author,actor,'comment',p.id,'commented on your memory',idempotency_key::text);
 else insert into public.reports(reporter,post_id,reason) values(actor,p.id,payload->>'reason'); end if;
 elsif operation='read_notifications' then update public.notifications set read_at=now() where recipient=actor and read_at is null;
 elsif operation='unregister_device' then delete from public.device_tokens where user_id=actor and token=payload->>'token';
 elsif operation='register_device' then insert into public.device_tokens values(actor,payload->>'token',payload->>'environment') on conflict(token) do update set user_id=actor,environment=excluded.environment;
 elsif operation='block_user' then
 target:=(payload->>'user_id')::uuid;
 insert into public.blocks values(actor,target) on conflict do nothing;
 update public.friendships set active=false where a=least(actor,target) and b=greatest(actor,target);
 else raise exception 'Unknown command';
 end if;
 insert into public.command_receipts(actor,operation,key,request,result) values(actor,operation,idempotency_key,payload,result);
 return result;
 end $$;
revoke all on function public.command(text,jsonb,uuid) from public;
grant execute on function public.command(text,jsonb,uuid) to authenticated;

-- A bounded initial snapshot. Reads execute as the caller, retaining every RLS policy.
create function public.snapshot() returns jsonb language sql stable security invoker set search_path='' as $$
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
 'notifications',coalesce((select jsonb_agg(t) from (select * from public.notifications order by created_at desc limit 100) t),'[]'::jsonb));
$$;
revoke all on function public.snapshot() from public;
grant execute on function public.snapshot() to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('session-photos','session-photos',false,10485760,array['image/jpeg']) on conflict(id) do nothing;
create policy photo_upload on storage.objects for insert to authenticated with check(bucket_id='session-photos' and exists(select 1 from public.media_assets m where m.object_key=name and m.owner=auth.uid() and m.state='pending'));
create policy photo_read on storage.objects for select to authenticated using(bucket_id='session-photos' and exists(select 1 from public.media_assets m where m.object_key=name and (m.owner=auth.uid() or exists(select 1 from public.posts p where p.media_id=m.id and public.can_post(p.id)))));

-- Worker permissions are limited to its explicit integration operations.
grant select on public.notifications,public.account_settings,public.device_tokens,public.media_assets to service_role;
grant update on public.notification_outbox to service_role;
grant delete on public.device_tokens to service_role;

create index command_recent on public.command_receipts(actor,created_at);
