import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const sql = await readFile(new URL('../backend/sharing/supabase_schema.sql', import.meta.url), 'utf8');
const normalized = sql.toLowerCase();

for (const table of [
  'public.custom_fighter_sharing_publications',
  'public.custom_fighter_sharing_revisions'
]) {
  assert.match(normalized, new RegExp(`alter table ${table.replaceAll('.', '\\.')} enable row level security`));
  assert.match(normalized, new RegExp(`revoke all on table ${table.replaceAll('.', '\\.')} from public, anon, authenticated`));
}

for (const fn of [
  'custom_fighter_sharing_get_latest',
  'custom_fighter_sharing_commit_revision',
  'custom_fighter_sharing_get_publication',
  'custom_fighter_sharing_get_revision',
  'custom_fighter_sharing_list_revisions',
  'custom_fighter_sharing_list_publications'
]) {
  assert.match(normalized, new RegExp(`create or replace function public\\.${fn}`));
  assert.match(normalized, new RegExp(`grant execute on function public\\.${fn}`));
}

assert.equal(normalized.includes('security definer'), false);
assert.equal(/grant\s+execute[\s\S]*?\s+to\s+(?:anon|authenticated|public)\s*;/i.test(sql), false);
assert.equal(/grant\s+(?:select|insert|update|delete|all)[\s\S]*?\s+to\s+(?:anon|authenticated|public)\s*;/i.test(sql), false);

assert.match(normalized, /security invoker/g);
assert.match(normalized, /pg_advisory_xact_lock/);
assert.match(normalized, /octet_length\(p_package_json\)/);
assert.match(normalized, /sha256\(convert_to\(p_package_json, 'utf8'\)\)/);
assert.match(normalized, /storage_quota_reached/);
assert.match(normalized, /134217728/);
assert.match(normalized, /position\(v_query in lower\(/);
assert.match(normalized, /for update/);
assert.match(normalized, /package_version_rollback/);
assert.match(normalized, /package_version_reuse/);
assert.match(normalized, /revision_conflict/);
assert.match(normalized, /byte_size integer not null check \(byte_size >= 1 and byte_size <= 16777216\)/);
assert.match(normalized, /cardinality\(tags\) <= 8/);

console.log('SUPABASE_SCHEMA_CONTRACT_TESTS_PASSED');
