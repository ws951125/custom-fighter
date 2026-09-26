-- Custom Fighter V2-7 WU4 Supabase schema contract.
-- Repository artifact only: do NOT apply to an unrelated Supabase project.
-- Apply only to a dedicated no-cost Custom Fighter project after explicit authorization.
--
-- Security model:
-- - browser clients never access these tables directly;
-- - anon/authenticated have no table privileges;
-- - backend secret key is server-only and bypasses RLS;
-- - publisher identity is verified by Supabase Auth before the backend calls the repository;
-- - historical revisions are immutable.

create table if not exists public.cf_sharing_publications (
  publication_id text primary key,
  publisher_id uuid not null,
  package_id text not null,
  latest_revision integer not null check (latest_revision >= 1),
  manifest jsonb not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  unique (publisher_id, package_id),
  constraint cf_sharing_publication_id_format
    check (publication_id ~ '^pub_[a-f0-9]{32}$'),
  constraint cf_sharing_package_id_format
    check (package_id ~ '^[a-z0-9][a-z0-9_-]*$')
);

create table if not exists public.cf_sharing_publication_revisions (
  publication_id text not null references public.cf_sharing_publications(publication_id) on delete restrict,
  revision integer not null check (revision >= 1),
  manifest jsonb not null,
  package_json text not null,
  created_at timestamptz not null,
  primary key (publication_id, revision),
  constraint cf_sharing_package_json_nonempty
    check (octet_length(package_json) between 1 and 16777216)
);

alter table public.cf_sharing_publications enable row level security;
alter table public.cf_sharing_publication_revisions enable row level security;

revoke all on table public.cf_sharing_publications from anon, authenticated;
revoke all on table public.cf_sharing_publication_revisions from anon, authenticated;
grant select, insert, update on table public.cf_sharing_publications to service_role;
grant select, insert on table public.cf_sharing_publication_revisions to service_role;

create or replace function public.cf_sharing_commit_revision(
  p_expected_latest_revision integer,
  p_manifest jsonb,
  p_package_json text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_publication_id text := p_manifest->>'publication_id';
  v_publisher_id_text text := p_manifest->>'publisher_id';
  v_package_id text := p_manifest->>'package_id';
  v_revision integer;
  v_current_revision integer;
  v_created_at timestamptz;
  v_updated_at timestamptz;
begin
  if p_expected_latest_revision is null or p_expected_latest_revision < 0 then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_EXPECTATION_INVALID');
  end if;

  if p_manifest is null or jsonb_typeof(p_manifest) <> 'object' then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_RECORD_INVALID');
  end if;

  if v_publication_id !~ '^pub_[a-f0-9]{32}$'
     or v_publisher_id_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or v_package_id !~ '^[a-z0-9][a-z0-9_-]*$' then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_RECORD_INVALID');
  end if;

  begin
    v_revision := (p_manifest->>'revision')::integer;
    v_created_at := (p_manifest->>'created_at')::timestamptz;
    v_updated_at := (p_manifest->>'updated_at')::timestamptz;
  exception when others then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_RECORD_INVALID');
  end;

  if v_revision < 1
     or p_package_json is null
     or octet_length(p_package_json) < 1
     or octet_length(p_package_json) > 16777216 then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_RECORD_INVALID');
  end if;

  select latest_revision
    into v_current_revision
    from public.cf_sharing_publications
    where publisher_id = v_publisher_id_text::uuid
      and package_id = v_package_id
    for update;

  v_current_revision := coalesce(v_current_revision, 0);
  if v_current_revision <> p_expected_latest_revision then
    return jsonb_build_object(
      'accepted', false,
      'code', 'REVISION_CONFLICT',
      'current_revision', v_current_revision
    );
  end if;

  if v_revision <> p_expected_latest_revision + 1 then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_SEQUENCE_INVALID');
  end if;

  if exists (
    select 1
      from public.cf_sharing_publication_revisions
      where publication_id = v_publication_id
        and revision = v_revision
  ) then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_ALREADY_EXISTS');
  end if;

  if v_current_revision = 0 then
    insert into public.cf_sharing_publications (
      publication_id,
      publisher_id,
      package_id,
      latest_revision,
      manifest,
      created_at,
      updated_at
    ) values (
      v_publication_id,
      v_publisher_id_text::uuid,
      v_package_id,
      v_revision,
      p_manifest,
      v_created_at,
      v_updated_at
    );
  else
    update public.cf_sharing_publications
      set latest_revision = v_revision,
          manifest = p_manifest,
          updated_at = v_updated_at
      where publication_id = v_publication_id
        and publisher_id = v_publisher_id_text::uuid
        and package_id = v_package_id;

    if not found then
      return jsonb_build_object('accepted', false, 'code', 'REPOSITORY_IDENTITY_MISMATCH');
    end if;
  end if;

  insert into public.cf_sharing_publication_revisions (
    publication_id,
    revision,
    manifest,
    package_json,
    created_at
  ) values (
    v_publication_id,
    v_revision,
    p_manifest,
    p_package_json,
    v_updated_at
  );

  return jsonb_build_object('accepted', true);
exception
  when unique_violation then
    return jsonb_build_object('accepted', false, 'code', 'REVISION_CONFLICT');
end;
$$;

revoke all on function public.cf_sharing_commit_revision(integer, jsonb, text) from public, anon, authenticated;
grant execute on function public.cf_sharing_commit_revision(integer, jsonb, text) to service_role;

create or replace function public.cf_sharing_list_publications(
  p_query text default '',
  p_tags text[] default array[]::text[],
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_query text := lower(trim(coalesce(p_query, '')));
  v_tags text[] := coalesce(p_tags, array[]::text[]);
  v_rows jsonb;
  v_has_more boolean;
begin
  if char_length(v_query) > 80
     or cardinality(v_tags) > 8
     or p_limit < 1
     or p_limit > 50
     or p_offset < 0
     or p_offset > 100000 then
    raise exception 'CATALOG_QUERY_INVALID' using errcode = '22023';
  end if;

  with matched as (
    select manifest, updated_at, publication_id
      from public.cf_sharing_publications
      where (
        v_query = ''
        or lower(coalesce(manifest->>'package_id', '')) like '%' || v_query || '%'
        or lower(coalesce(manifest->>'title', '')) like '%' || v_query || '%'
        or lower(coalesce(manifest->>'description', '')) like '%' || v_query || '%'
        or exists (
          select 1
            from jsonb_array_elements_text(coalesce(manifest->'tags', '[]'::jsonb)) tag
            where lower(tag) like '%' || v_query || '%'
        )
      )
      and coalesce(manifest->'tags', '[]'::jsonb) @> to_jsonb(v_tags)
      order by updated_at desc, publication_id asc
      offset p_offset
      limit p_limit + 1
  ),
  page as (
    select manifest, row_number() over () as row_num
      from matched
  )
  select
    coalesce(jsonb_agg(manifest order by row_num) filter (where row_num <= p_limit), '[]'::jsonb),
    coalesce(bool_or(row_num > p_limit), false)
    into v_rows, v_has_more
    from page;

  return jsonb_build_object('items', v_rows, 'has_more', v_has_more);
end;
$$;

revoke all on function public.cf_sharing_list_publications(text, text[], integer, integer) from public, anon, authenticated;
grant execute on function public.cf_sharing_list_publications(text, text[], integer, integer) to service_role;
