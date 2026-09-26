import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql = fs.readFileSync(
  new URL('../backend/sharing/supabase_schema.sql', import.meta.url),
  'utf8'
);

assert.match(sql, /alter table public\.cf_sharing_publications enable row level security;/i);
assert.match(sql, /alter table public\.cf_sharing_publication_revisions enable row level security;/i);

assert.match(
  sql,
  /revoke all on table public\.cf_sharing_publications from anon, authenticated;/i
);
assert.match(
  sql,
  /revoke all on table public\.cf_sharing_publication_revisions from anon, authenticated;/i
);
assert.doesNotMatch(
  sql,
  /grant\s+(?:select|insert|update|delete|all)[^;]*\s+to\s+(?:anon|authenticated)/i
);

assert.match(
  sql,
  /grant select, insert, update on table public\.cf_sharing_publications to service_role;/i
);
assert.match(
  sql,
  /grant select, insert on table public\.cf_sharing_publication_revisions to service_role;/i
);

assert.match(sql, /security invoker/gi);
assert.doesNotMatch(sql, /security definer/i);

assert.match(sql, /cf_sharing_commit_revision/i);
assert.match(sql, /p_expected_latest_revision/i);
assert.match(sql, /REVISION_CONFLICT/i);
assert.match(sql, /REVISION_SEQUENCE_INVALID/i);
assert.match(sql, /REVISION_ALREADY_EXISTS/i);

assert.match(sql, /octet_length\(package_json\) between 1 and 16777216/i);
assert.match(sql, /cf_sharing_list_publications/i);
assert.match(sql, /char_length\(v_query\) > 80/i);
assert.match(sql, /cardinality\(v_tags\) > 8/i);
assert.match(sql, /p_limit > 50/i);
assert.match(sql, /p_offset > 100000/i);

assert.match(
  sql,
  /revoke all on function public\.cf_sharing_commit_revision\(integer, jsonb, text\) from public, anon, authenticated;/i
);
assert.match(
  sql,
  /revoke all on function public\.cf_sharing_list_publications\(text, text\[\], integer, integer\) from public, anon, authenticated;/i
);

console.log('SUPABASE_SHARING_SCHEMA_TESTS_PASSED');
