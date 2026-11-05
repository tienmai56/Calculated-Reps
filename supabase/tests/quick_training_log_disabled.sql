-- A normal migration run must retain the production schema and dispatchers.
begin;
do $$
declare definition text := pg_get_functiondef('public.command(text,jsonb,uuid)'::regprocedure);
begin
 if to_regclass('public.quick_logs') is not null
    or to_regclass('public.training_actions') is not null
    or to_regclass('public.log_matches') is not null then
  raise exception 'Experimental training tables leaked into normal migrations';
 end if;
 if to_regprocedure('public.training_command(text,jsonb)') is not null
    or to_regprocedure('public.training_days(date,date,text)') is not null
    or to_regprocedure('public.snapshot_before_training()') is not null then
  raise exception 'Experimental training functions leaked into normal migrations';
 end if;
 if strpos(definition, 'mark_training_done') > 0 then
  raise exception 'Normal command dispatcher enables experimental training';
 end if;
 if public.snapshot() ?| array['quick_logs','training_days','log_matches','shared_session_ids'] then
  raise exception 'Normal snapshot includes experimental training data';
 end if;
end $$;
rollback;
