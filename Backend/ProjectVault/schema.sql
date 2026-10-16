-- Private Cookies-owned storage. External service sessions are validated by the
-- Edge Function; no original-service table, key or entitlement is modified.
create table if not exists public.cookies_vault_projects (
  owner_id uuid not null,
  project_id uuid not null,
  revision_id uuid not null,
  generation bigint not null check (generation > 0),
  head jsonb not null,
  updated_at timestamptz not null default now(),
  primary key(owner_id, project_id)
);
create table if not exists public.cookies_vault_revisions (
  owner_id uuid not null,
  project_id uuid not null,
  revision_id uuid not null,
  expected_generation bigint not null check (expected_generation >= 0),
  head jsonb not null,
  byte_size bigint not null check(byte_size > 0 and byte_size <= 134217728),
  stage text not null check(stage in ('pending','current','retired')),
  created_at timestamptz not null default now(),
  retired_at timestamptz,
  primary key(owner_id,project_id,revision_id)
);
alter table public.cookies_vault_projects enable row level security;
alter table public.cookies_vault_revisions enable row level security;
revoke all on public.cookies_vault_projects,public.cookies_vault_revisions from anon,authenticated;
grant all on public.cookies_vault_projects,public.cookies_vault_revisions to service_role;
create index if not exists cookies_vault_revisions_cleanup on public.cookies_vault_revisions(stage,created_at);

-- All physical revisions, including interrupted uploads and retired versions,
-- remain charged until their objects are actually deleted. A failed cleanup
-- can never create fictitious free space or accidentally erase the current head.
create or replace function public.cookies_vault_reserve(p_owner uuid,p_project uuid,p_revision uuid,p_expected bigint,p_head jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare n bigint; existing public.cookies_vault_revisions; current_generation bigint;
begin
  perform pg_advisory_xact_lock(74198612);
  select * into existing from public.cookies_vault_revisions where owner_id=p_owner and project_id=p_project and revision_id=p_revision;
  if found then
    if existing.head=p_head and existing.expected_generation=p_expected then return to_jsonb(existing); end if;
    raise sqlstate 'PT409' using message='Revision already exists with different content';
  end if;
  select generation into current_generation from public.cookies_vault_projects where owner_id=p_owner and project_id=p_project;
  if coalesce(current_generation,0)<>p_expected then raise sqlstate 'PT409' using message='Newer project version exists'; end if;
  n=(p_head->>'bytes')::bigint;
  if n is null or n<=0 or n>134217728 then raise sqlstate 'PT413' using message='Project exceeds transfer limit'; end if;
  if coalesce((select sum(byte_size) from public.cookies_vault_revisions),0)+n>838860800 then
    raise sqlstate 'PT507' using message='Vault free-plan capacity reached';
  end if;
  if coalesce((select sum(byte_size) from public.cookies_vault_revisions where owner_id=p_owner),0)+n>536870912 then
    raise sqlstate 'PT507' using message='Account vault capacity reached';
  end if;
  -- Byte budgets alone must not permit unbounded tiny pending revisions.
  -- The same transaction lock serializes these metadata capacity checks.
  if (select count(*) from public.cookies_vault_revisions)>=4096 or
     (select count(*) from public.cookies_vault_revisions where owner_id=p_owner)>=1024 then
    raise sqlstate 'PT507' using message='Vault project index capacity reached';
  end if;
  insert into public.cookies_vault_revisions(owner_id,project_id,revision_id,expected_generation,head,byte_size,stage)
    values(p_owner,p_project,p_revision,p_expected,p_head,n,'pending') returning * into existing;
  return to_jsonb(existing);
end $$;

create or replace function public.cookies_vault_commit(p_owner uuid,p_project uuid,p_revision uuid)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare upload public.cookies_vault_revisions; current_generation bigint; result public.cookies_vault_projects;
begin
  perform pg_advisory_xact_lock(74198612);
  select * into upload from public.cookies_vault_revisions where owner_id=p_owner and project_id=p_project and revision_id=p_revision for update;
  if not found then raise sqlstate 'PT404' using message='Upload not found'; end if;
  select * into result from public.cookies_vault_projects where owner_id=p_owner and project_id=p_project for update;
  if found and result.revision_id=p_revision then return to_jsonb(result); end if;
  if upload.stage<>'pending' then raise sqlstate 'PT409' using message='Upload is not pending'; end if;
  current_generation=coalesce(result.generation,0);
  if current_generation<>upload.expected_generation then raise sqlstate 'PT409' using message='Newer project version exists'; end if;
  update public.cookies_vault_revisions set stage='retired',retired_at=now() where owner_id=p_owner and project_id=p_project and stage='current';
  update public.cookies_vault_revisions set stage='current' where owner_id=p_owner and project_id=p_project and revision_id=p_revision;
  insert into public.cookies_vault_projects(owner_id,project_id,revision_id,generation,head)
    values(p_owner,p_project,p_revision,current_generation+1,upload.head)
    on conflict(owner_id,project_id) do update set revision_id=excluded.revision_id,generation=excluded.generation,head=excluded.head,updated_at=now()
    returning * into result;
  return to_jsonb(result);
end $$;

create or replace function public.cookies_vault_remove_revision(p_owner uuid,p_project uuid,p_revision uuid)
returns boolean language plpgsql security invoker set search_path='' as $$
begin
  perform pg_advisory_xact_lock(74198612);
  if exists(select 1 from public.cookies_vault_projects where owner_id=p_owner and project_id=p_project and revision_id=p_revision) then
    raise sqlstate 'PT409' using message='Cannot remove current revision';
  end if;
  delete from public.cookies_vault_revisions where owner_id=p_owner and project_id=p_project and revision_id=p_revision and stage='retired' and retired_at<now()-interval '15 minutes';
  return found;
end $$;
revoke execute on function public.cookies_vault_reserve(uuid,uuid,uuid,bigint,jsonb),public.cookies_vault_commit(uuid,uuid,uuid),public.cookies_vault_remove_revision(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.cookies_vault_reserve(uuid,uuid,uuid,bigint,jsonb),public.cookies_vault_commit(uuid,uuid,uuid),public.cookies_vault_remove_revision(uuid,uuid,uuid) to service_role;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('cookies-projects','cookies-projects',false,8388608,array['application/octet-stream'])
on conflict(id) do nothing;

create or replace function public.cookies_vault_expire(p_owner uuid)
returns void language plpgsql security invoker set search_path='' as $$
begin
  perform pg_advisory_xact_lock(74198612);
  update public.cookies_vault_revisions set stage='retired',retired_at=now() where (p_owner is null or owner_id=p_owner) and stage='pending' and created_at<now()-interval '1 hour';
end $$;
create or replace function public.cookies_vault_delete(p_owner uuid,p_project uuid,p_expected bigint)
returns void language plpgsql security invoker set search_path='' as $$
begin
  perform pg_advisory_xact_lock(74198612);
  if not exists(select 1 from public.cookies_vault_projects where owner_id=p_owner and project_id=p_project and generation=p_expected) then raise sqlstate 'PT409' using message='Project changed before deletion'; end if;
  update public.cookies_vault_revisions set stage='retired',retired_at=now() where owner_id=p_owner and project_id=p_project and stage<>'retired';
  delete from public.cookies_vault_projects where owner_id=p_owner and project_id=p_project;
end $$;
revoke execute on function public.cookies_vault_expire(uuid),public.cookies_vault_delete(uuid,uuid,bigint) from public,anon,authenticated;
grant execute on function public.cookies_vault_expire(uuid),public.cookies_vault_delete(uuid,uuid,bigint) to service_role;
