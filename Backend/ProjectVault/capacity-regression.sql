begin;
select pg_advisory_xact_lock(74198612);
do $$
declare a uuid=gen_random_uuid(); b uuid=gen_random_uuid(); p uuid; r uuid; value jsonb;
begin
 insert into public.cookies_vault_revisions(owner_id,project_id,revision_id,expected_generation,head,byte_size,stage)
 select a,gen_random_uuid(),gen_random_uuid(),0,'{"bytes":1}'::jsonb,1,'pending' from generate_series(1,1024);
 select project_id,revision_id into p,r from public.cookies_vault_revisions where owner_id=a limit 1;
 value=public.cookies_vault_reserve(a,p,r,0,'{"bytes":1}'::jsonb);
 if value->>'revision_id'<>r::text then raise exception 'Idempotent retry rejected at capacity'; end if;
 begin
  perform public.cookies_vault_reserve(a,gen_random_uuid(),gen_random_uuid(),0,'{"bytes":1}'::jsonb);
  raise exception 'Account metadata limit failed';
 exception when sqlstate 'PT507' then null; end;
 insert into public.cookies_vault_revisions(owner_id,project_id,revision_id,expected_generation,head,byte_size,stage)
 select gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),0,'{"bytes":1}'::jsonb,1,'pending' from generate_series(1,4096);
 begin
  perform public.cookies_vault_reserve(b,gen_random_uuid(),gen_random_uuid(),0,'{"bytes":1}'::jsonb);
  raise exception 'Global metadata limit failed';
 exception when sqlstate 'PT507' then null; end;
end $$;
select 'account/global metadata limits and idempotent retry passed; test rows rolled back' as verification;
rollback;