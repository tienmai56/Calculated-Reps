begin;
insert into auth.users(id) values ('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002'),('10000000-0000-0000-0000-000000000003');
insert into public.profiles(id,name) select id,'Training test' from auth.users where id::text like '10000000%';
insert into public.account_settings(user_id,timezone) select id,'UTC' from public.profiles where id::text like '10000000%';
-- The assertions below query today; keep this started session on today's date near midnight.
insert into public.sessions(id,organizer,title,starts_at,timezone,venue) values
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','No-gi',greatest(date_trunc('day',now()),now()-interval '30 minutes'),'UTC','Gym');
insert into public.session_participants select '20000000-0000-0000-0000-000000000001',id,'going',false from public.profiles where id::text like '10000000%';
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$begin
 if has_table_privilege('authenticated','public.quick_logs','INSERT')
 or has_table_privilege('authenticated','public.training_actions','SELECT')
 or has_function_privilege('authenticated','private.training_command(text,jsonb)','EXECUTE')
 or has_table_privilege('anon','public.quick_logs','SELECT') then
 raise exception 'Training data exposed outside the authorized dispatcher';
 end if;
end$$;
select public.command('create_quick_log',jsonb_build_object('id','30000000-0000-0000-0000-000000000001','logged_on',current_date,'timezone','UTC'),gen_random_uuid());
-- A same-day plan must have started; timezone cannot bypass the timestamp guard.
reset role;
insert into public.sessions(id,organizer,title,starts_at,timezone,venue) values
 ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Later today',now()+interval '1 minute','UTC','Gym');
insert into public.session_participants values
 ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','going',false);
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$declare refused boolean:=false; begin
 begin
 perform public.command('mark_training_done','{"session_id":"20000000-0000-0000-0000-000000000002","action_id":"40000000-0000-0000-0000-000000000099","timezone":"Pacific/Honolulu"}',gen_random_uuid());
 exception when others then refused:=true; end;
 if not refused then raise exception 'Unstarted plan accepted'; end if;
 refused:=false;
 begin
 perform public.command('complete_and_publish','{"session_id":"20000000-0000-0000-0000-000000000002","caption":"Too early","attendees":["10000000-0000-0000-0000-000000000001"]}',gen_random_uuid());
 exception when others then refused:=true; end;
 if not refused then raise exception 'Unstarted plan published'; end if;
 if exists(select 1 from public.session_participants where session_id='20000000-0000-0000-0000-000000000002' and attended) then raise exception 'Failed completion changed attendance'; end if;
end$$;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
select public.command('mark_training_done','{"session_id":"20000000-0000-0000-0000-000000000001","action_id":"40000000-0000-0000-0000-000000000001"}',gen_random_uuid());
do $$begin
 if (select status from public.sessions where id='20000000-0000-0000-0000-000000000001')<>'planned' then raise exception 'Guest completed host plan'; end if;
 if (select count(*) from public.session_participants where attended)<>1 then raise exception 'Guest affected other attendance'; end if;
 if (select quick_log_count from public.training_days(current_date,current_date,'UTC'))<>1 then raise exception 'Quick log missing'; end if;
end$$;
do $$declare refused boolean:=false; begin
 begin
 perform public.command('complete_and_publish','{"session_id":"20000000-0000-0000-0000-000000000001","caption":"Guest cannot post","attendees":["10000000-0000-0000-0000-000000000002"]}',gen_random_uuid());
 exception when others then refused:=true; end;
 if not refused then raise exception 'Guest published'; end if;
 refused:=false;
 begin
 perform public.command('create_quick_log',jsonb_build_object('id',gen_random_uuid(),'logged_on',current_date+1,'timezone','UTC'),gen_random_uuid());
 exception when others then refused:=true; end;
 if not refused then raise exception 'Future quick log accepted'; end if;
 if (select count(*) from public.training_days(current_date,current_date,'UTC') where quick_log_count=1 and jsonb_array_length(sessions)=1)<>1 then raise exception 'Day query lost guest attendance'; end if;
end$$;
select public.command('undo_training_done','{"action_id":"40000000-0000-0000-0000-000000000001"}',gen_random_uuid());
reset role;
-- A distant quick log remains separate; the three-hour boundary is inclusive.
insert into public.quick_logs(id,user_id,logged_on,logged_at,timezone) values
 ('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003',current_date,now()-interval '5 hours','UTC');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$begin
 if exists(select 1 from public.quick_logs) then raise exception 'Quick logs leaked to host'; end if;
end$$;
select public.command('mark_training_done','{"session_id":"20000000-0000-0000-0000-000000000001","action_id":"40000000-0000-0000-0000-000000000002"}',gen_random_uuid());
do $$begin
 if (select count(*) from public.session_participants where attended)<>3 then raise exception 'Host did not fill joined days'; end if;
 if exists(select 1 from public.posts) then raise exception 'Mark done published'; end if;
 if exists(select 1 from public.notifications) then raise exception 'Mark done created a notification'; end if;
end$$;
reset role;
do $$begin
 if exists(select 1 from public.quick_logs where id='30000000-0000-0000-0000-000000000001') then raise exception 'Near log not merged'; end if;
 if not exists(select 1 from public.quick_logs where id='30000000-0000-0000-0000-000000000002') then raise exception 'Distant log merged'; end if;
end$$;
set local role authenticated;
select public.command('undo_training_done','{"action_id":"40000000-0000-0000-0000-000000000002"}',gen_random_uuid());
reset role;
do $$begin
 if (select count(*) from public.quick_logs)<>2 then raise exception 'Undo lost merged log'; end if;
 if exists(select 1 from public.session_participants where attended) then raise exception 'Undo retained attendance'; end if;
end$$;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select public.command('mark_training_done','{"session_id":"20000000-0000-0000-0000-000000000001","action_id":"40000000-0000-0000-0000-000000000003"}',gen_random_uuid());
-- Photo preparation must also work after separate completion.
select public.command('prepare_media','{"session_id":"20000000-0000-0000-0000-000000000001"}',gen_random_uuid())->>'id' as completed_media \gset
insert into storage.objects(bucket_id,name) select 'session-photos',object_key from public.media_assets where id=:'completed_media';
select public.command('save_session_photo',jsonb_build_object('session_id','20000000-0000-0000-0000-000000000001','media_id',:'completed_media'),gen_random_uuid());
do $$declare snap jsonb:=public.snapshot(); begin
 if not (snap ?& array['quick_logs','training_days','log_matches','shared_session_ids']) then raise exception 'Live feature snapshot fields missing'; end if;
 if not exists(select 1 from public.media_assets where state='ready') then raise exception 'Completed session photo was not saved'; end if;
end$$;
select public.command('complete_and_publish','{"session_id":"20000000-0000-0000-0000-000000000001","caption":"Good rolls","attendees":["10000000-0000-0000-0000-000000000001","10000000-0000-0000-0000-000000000002"]}',gen_random_uuid());
do $$begin
 if (select count(*) from public.posts)<>1 then raise exception 'Completed session cannot publish'; end if;
 begin
 perform public.command('undo_training_done','{"action_id":"40000000-0000-0000-0000-000000000003"}',gen_random_uuid());
 raise exception 'Published completion was undone';
 exception when others then
 if sqlerrm='Published completion was undone' then raise; end if;
 end;
end$$;
-- Guests also need publication state to hide their completion Undo.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
do $$begin
 if not public.shared_training_sessions() @> '["20000000-0000-0000-0000-000000000001"]'::jsonb then raise exception 'Guest publication state missing'; end if;
end$$;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select public.command('manage_participant','{"session_id":"20000000-0000-0000-0000-000000000001","user_id":"10000000-0000-0000-0000-000000000002","remove":true}',gen_random_uuid());
reset role;
do $$begin
 if exists(select 1 from public.session_participants where user_id='10000000-0000-0000-0000-000000000002') then raise exception 'Removal retained attendance'; end if;
end$$;
rollback;
