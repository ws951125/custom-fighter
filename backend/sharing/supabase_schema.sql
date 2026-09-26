-- Custom Fighter V2-7 WU4 Supabase schema contract.
-- This file is a reviewed deployment reference only. It is NOT applied automatically.
-- Apply only to a dedicated, explicitly approved Custom Fighter Supabase project.

create table if not exists public.custom_fighter_sharing_publications (
  publication_id text primary key,
  publisher_id uuid not null,
  package_id text not null,
  latest_revision integer not null check (latest_revision >= 1),
  created_at timestamptz not null,
  updated_at timestamptz not null,
  unique (publisher_id, package_id),
  check (publication_id ~ '^pub_[0-9a-f]{32}$'),
  check (package_id ~ '^[a-z0-9][a-z0-9_-]*$')
);

create table if not exists public.custom_fighter_sharing_revisions (
  publication_id text not null references public.custom_fighter_sharing_publications(publication_id),
  revision integer not null check (revision >= 1),
  publisher_id uuid not null,
  package_id text not null,
  package_version integer not null check (package_version >= 1),
  package_schema_version integer not null check (package_schema_version in (1, 2)),
  content_sha256 text not null check (content_sha256 ~ '^[0-9a-f]{64}$'),
  byte_size integer not null check (byte_size >= 1 and byte_size <= 16777216),
  title text not null check (char_length(title) between 1 and 80),
  description text not null check (char_length(description) <= 500),
  tags text[] not null default '{}',
  created_at timestamptz not null,
  updated_at timestamptz not null,
  manifest jsonb not null,
  package_json text not null,
  primary key (publication_id, revision),
  check (package_id ~ '^[a-z0-9][a-z0-9_-]*$'),
  check (cardinality(tags) <= 8)
);

create index if not exists custom_fighter_sharing_revisions_catalog_idx
  on public.custom_fighter_sharing_revisions (updated_at desc, publication_id);

alter table public.custom_fighter_sharing_publications enable row level security;
alter table public.custom_fighter_sharing_revisions enable row level security;

revoke all on table public.custom_fighter_sharing_publications from public, anon, authenticated;
revoke all on table public.custom_fighter_sharing_revisions from public, anon, authenticated;
grant select, insert, update on table public.custom_fighter_sharing_publications to service_role;
grant select, insert on table public.custom_fighter_sharing_revisions to service_role;

create or replace function public.custom_fighter_sharing_get_latest(
  p_publisher_id text,
  p_package_id text
) returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select case when r.publication_id is null then null else
    jsonb_build_object(
      'record',
      jsonb_build_object('manifest', r.manifest, 'package_json', r.package_json)
    )
  end
  from (
    select rev.*
    from public.custom_fighter_sharing_publications p
    join public.custom_fighter_sharing_revisions rev
      on rev.publication_id = p.publication_id
     and rev.revision = p.latest_revision
    where p.publisher_id = p_publisher_id::uuid
      and p.package_id = p_package_id
    limit 1
  ) r;
$$;

create or replace function public.custom_fighter_sharing_commit_revision(
  p_expected_latest_revision integer,
  p_manifest jsonb,
  p_package_json text
) returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_publication_id text := p_manifest->>'publication_id';
  v_publisher_id uuid;
  v_package_id text := p_manifest->>'package_id';
  v_revision integer := (p_manifest->>'revision')::integer;
  v_package_version integer := (p_manifest->>'package_version')::integer;
  v_package_schema_version integer := (p_manifest->>'package_schema_version')::integer;
  v_content_sha256 text := p_manifest->>'content_sha256';
  v_byte_size integer := (p_manifest->>'byte_size')::integer;
  v_title text := p_manifest->>'title';
  v_description text := coalesce(p_manifest->>'description', '');
  v_tags text[] := coalesce(
    array(select jsonb_array_elements_text(coalesce(p_manifest->'tags', '[]'::jsonb))),
    '{}'::text[]
  );
  v_created_at timestamptz := (p_manifest->>'created_at')::timestamptz;
  v_updated_at timestamptz := (p_manifest->>'updated_at')::timestamptz;
  v_current public.custom_fighter_sharing_publications%rowtype;
  v_previous public.custom_fighter_sharing_revisions%rowtype;
begin
  if p_expected_latest_revision is null or p_expected_latest_revision < 0 then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_EXPECTATION_INVALID');
  end if;
  if p_manifest is null or p_package_json is null or p_package_json = '' then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_RECORD_INVALID');
  end if;

  begin
    v_publisher_id := (p_manifest->>'publisher_id')::uuid;
  exception when others then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_RECORD_INVALID');
  end;

  -- Bound aggregate stored package bytes to 128 MiB on Free-tier deployments.
  -- A transaction-scoped global lock makes the quota check safe for concurrent publishers.
  perform pg_advisory_xact_lock(27874, 4);
  if v_byte_size is null
     or v_byte_size <> octet_length(p_package_json)
     or v_content_sha256 is distinct from
       encode(sha256(convert_to(p_package_json, 'UTF8')), 'hex') then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_RECORD_INVALID');
  end if;
  if p_package_json::jsonb->>'package_id' is distinct from v_package_id
     or (p_package_json::jsonb->>'package_version')::integer is distinct from v_package_version
     or (p_package_json::jsonb->>'schema_version')::integer is distinct from v_package_schema_version then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_RECORD_INVALID');
  end if;
  if (select coalesce(sum(byte_size), 0)
      from public.custom_fighter_sharing_revisions) + v_byte_size > 134217728 then
    return jsonb_build_object('accepted', false, 'code', 'STORAGE_QUOTA_REACHED');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_publication_id, 0));

  select *
    into v_current
    from public.custom_fighter_sharing_publications
   where publication_id = v_publication_id
   for update;

  if not found then
    if p_expected_latest_revision <> 0 or v_revision <> 1 then
      return jsonb_build_object(
        'accepted', false,
        'code', 'REVISION_CONFLICT',
        'current_revision', 0
      );
    end if;

    insert into public.custom_fighter_sharing_publications (
      publication_id, publisher_id, package_id, latest_revision, created_at, updated_at
    ) values (
      v_publication_id, v_publisher_id, v_package_id, 1, v_created_at, v_updated_at
    );
  else
    if v_current.publisher_id <> v_publisher_id or v_current.package_id <> v_package_id then
      return jsonb_build_object('accepted', false, 'code', 'REPOSITORY_IDENTITY_MISMATCH');
    end if;
    if v_current.latest_revision <> p_expected_latest_revision or v_revision <> v_current.latest_revision + 1 then
      return jsonb_build_object(
        'accepted', false,
        'code', 'REVISION_CONFLICT',
        'current_revision', v_current.latest_revision
      );
    end if;

    select *
      into v_previous
      from public.custom_fighter_sharing_revisions
     where publication_id = v_publication_id
       and revision = v_current.latest_revision;

    if not found then
      return jsonb_build_object('accepted', false, 'code', 'REPOSITORY_IDENTITY_MISMATCH');
    end if;
    if v_created_at <> v_previous.created_at then
      return jsonb_build_object('accepted', false, 'code', 'REPOSITORY_IDENTITY_MISMATCH');
    end if;
    if v_package_version < v_previous.package_version then
      return jsonb_build_object('accepted', false, 'code', 'PACKAGE_VERSION_ROLLBACK');
    end if;
    if v_package_version = v_previous.package_version
       and v_content_sha256 <> v_previous.content_sha256 then
      return jsonb_build_object('accepted', false, 'code', 'PACKAGE_VERSION_REUSE');
    end if;
  end if;

  insert into public.custom_fighter_sharing_revisions (
    publication_id, revision, publisher_id, package_id, package_version,
    package_schema_version, content_sha256, byte_size, title, description,
    tags, created_at, updated_at, manifest, package_json
  ) values (
    v_publication_id, v_revision, v_publisher_id, v_package_id, v_package_version,
    v_package_schema_version, v_content_sha256, v_byte_size, v_title, v_description,
    v_tags, v_created_at, v_updated_at, p_manifest, p_package_json
  );

  update public.custom_fighter_sharing_publications
     set latest_revision = v_revision,
         updated_at = v_updated_at
   where publication_id = v_publication_id;

  return jsonb_build_object('accepted', true);
exception
  when unique_violation or serialization_failure then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_CONFLICT');
end;
$$;

create or replace function public.custom_fighter_sharing_get_publication(
  p_publication_id text
) returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select case when r.publication_id is null then null else
    jsonb_build_object('record', jsonb_build_object('manifest', r.manifest))
  end
  from (
    select rev.*
    from public.custom_fighter_sharing_publications p
    join public.custom_fighter_sharing_revisions rev
      on rev.publication_id = p.publication_id
     and rev.revision = p.latest_revision
    where p.publication_id = p_publication_id
    limit 1
  ) r;
$$;

create or replace function public.custom_fighter_sharing_get_revision(
  p_publication_id text,
  p_revision integer
) returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select case when r.publication_id is null then null else
    jsonb_build_object(
      'record',
      jsonb_build_object('manifest', r.manifest, 'package_json', r.package_json)
    )
  end
  from (
    select *
    from public.custom_fighter_sharing_revisions
    where publication_id = p_publication_id
      and revision = p_revision
    limit 1
  ) r;
$$;

create or replace function public.custom_fighter_sharing_list_revisions(
  p_publication_id text
) returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'revisions',
    coalesce(jsonb_agg(revision order by revision), '[]'::jsonb)
  )
  from public.custom_fighter_sharing_revisions
  where publication_id = p_publication_id;
$$;

create or replace function public.custom_fighter_sharing_list_publications(
  p_query text default '',
  p_tags text[] default '{}',
  p_limit integer default 20,
  p_offset integer default 0
) returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_query text := lower(trim(coalesce(p_query, '')));
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 50));
  v_offset integer := greatest(0, least(coalesce(p_offset, 0), 100000));
  v_items jsonb;
  v_has_more boolean;
begin
  with matching as (
    select rev.*
    from public.custom_fighter_sharing_publications p
    join public.custom_fighter_sharing_revisions rev
      on rev.publication_id = p.publication_id
     and rev.revision = p.latest_revision
    where (coalesce(array_length(p_tags, 1), 0) = 0 or p_tags <@ rev.tags)
      and (
        v_query = ''
        or position(v_query in lower(
          rev.package_id || E'\n' ||
          rev.title || E'\n' ||
          rev.description || E'\n' ||
          array_to_string(rev.tags, E'\n')
        )) > 0
      )
    order by rev.updated_at desc, rev.publication_id asc
  ),
  page as (
    select * from matching
    offset v_offset
    limit v_limit + 1
  )
  select
    coalesce(jsonb_agg(manifest order by updated_at desc, publication_id asc)
      filter (where row_number <= v_limit), '[]'::jsonb),
    count(*) > v_limit
  into v_items, v_has_more
  from (
    select page.*, row_number() over (order by updated_at desc, publication_id asc) as row_number
    from page
  ) ranked;

  return jsonb_build_object('items', v_items, 'has_more', v_has_more);
end;
$$;

revoke all on function public.custom_fighter_sharing_get_latest(text, text) from public, anon, authenticated;
revoke all on function public.custom_fighter_sharing_commit_revision(integer, jsonb, text) from public, anon, authenticated;
revoke all on function public.custom_fighter_sharing_get_publication(text) from public, anon, authenticated;
revoke all on function public.custom_fighter_sharing_get_revision(text, integer) from public, anon, authenticated;
revoke all on function public.custom_fighter_sharing_list_revisions(text) from public, anon, authenticated;
revoke all on function public.custom_fighter_sharing_list_publications(text, text[], integer, integer) from public, anon, authenticated;

grant execute on function public.custom_fighter_sharing_get_latest(text, text) to service_role;
grant execute on function public.custom_fighter_sharing_commit_revision(integer, jsonb, text) to service_role;
grant execute on function public.custom_fighter_sharing_get_publication(text) to service_role;
grant execute on function public.custom_fighter_sharing_get_revision(text, integer) to service_role;
grant execute on function public.custom_fighter_sharing_list_revisions(text) to service_role;
grant execute on function public.custom_fighter_sharing_list_publications(text, text[], integer, integer) to service_role;
