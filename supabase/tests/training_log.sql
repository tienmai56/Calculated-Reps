begin;
insert into auth.users(id) values ('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002'),('10000000-0000-0000-0000-000000000003');
insert into public.profiles(id,name) select id,'Training test' from auth.users where id::text like '10000000%';
insert into public.account_settings(user_id,timezone) select id,'UTC' from public.profiles where id::text like '10000000%';
insert into public.sessions(id,organizer,title,starts_at,timezone,venue) values
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','No-gi',now()-interval '30 minutes','UTC','Gym');
insert into public.session_participants select '20000000-0000-0000-0000-000000000001',id,'going',false from public.profiles where id::text like '10000000%';
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select public.command('create_quick_log',jsonb_build_object('id','30000000-0000-0000-0000-000000000001','logged_on',current_date,'timezone','UTC'),gen_random_uuid());
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
select public.command('prepare_media','{"session_id":"20000000-0000-0000-0000-000000000001"}',gen_random_uuid());
select public.command('complete_and_publish','{"session_id":"20000000-0000-0000-0000-000000000001","caption":"Good rolls","attendees":["10000000-0000-0000-0000-000000000001","10000000-0000-0000-0000-000000000002"]}',gen_random_uuid());
do $$begin
 if (select count(*) from public.posts)<>1 then raise exception 'Completed session cannot publish'; end if;
end$$;
select public.command('manage_participant','{"session_id":"20000000-0000-0000-0000-000000000001","user_id":"10000000-0000-0000-0000-000000000002","remove":true}',gen_random_uuid());
reset role;
do $$begin
 if exists(select 1 from public.session_participants where user_id='10000000-0000-0000-0000-000000000002') then raise exception 'Removal retained attendance'; end if;
end$$;
rollback;
