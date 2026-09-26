import assert from 'node:assert/strict';
import {
  createSupabasePublicationRepository,
  createSupabasePublisherResolver,
  createSupabaseSharingAdapters,
  readSupabaseSharingConfig
} from '../backend/sharing/supabase_provider.mjs';

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

const validEnv = {
  CUSTOM_FIGHTER_SHARING_SUPABASE_URL: 'https://custom-fighter.supabase.co',
  CUSTOM_FIGHTER_SHARING_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_test_key_123456789',
  CUSTOM_FIGHTER_SHARING_SUPABASE_SECRET_KEY: 'sb_secret_test_key_123456789'
};

assert.deepEqual(
  readSupabaseSharingConfig({}),
  { configured: false, invalid: false }
);
assert.equal(
  readSupabaseSharingConfig({
    CUSTOM_FIGHTER_SHARING_SUPABASE_URL: validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_URL
  }).invalid,
  true
);
assert.equal(
  readSupabaseSharingConfig({
    ...validEnv,
    CUSTOM_FIGHTER_SHARING_SUPABASE_URL: 'http://custom-fighter.supabase.co'
  }).invalid,
  true
);
const parsedConfig = readSupabaseSharingConfig(validEnv);
assert.equal(parsedConfig.configured, true);
assert.equal(parsedConfig.url, validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_URL);

const authCalls = [];
const resolver = createSupabasePublisherResolver({
  url: validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_URL,
  publishableKey: validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_PUBLISHABLE_KEY,
  fetchImpl: async (url, options) => {
    authCalls.push({ url, options });
    return jsonResponse({
      id: '123e4567-e89b-42d3-a456-426614174000',
      user_metadata: {
        publisher_id: 'forged_metadata_identity'
      }
    });
  }
});
assert.equal(typeof resolver, 'function');
assert.deepEqual(await resolver({ headers: {} }), { authenticated: false });

const identity = await resolver({
  headers: { authorization: 'Bearer real-user-access-token' }
});
assert.deepEqual(identity, {
  authenticated: true,
  publisher_id: '123e4567-e89b-42d3-a456-426614174000'
});
assert.equal(authCalls.length, 1);
assert.equal(authCalls[0].url, 'https://custom-fighter.supabase.co/auth/v1/user');
assert.equal(
  authCalls[0].options.headers.apikey,
  validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_PUBLISHABLE_KEY
);
assert.equal(
  authCalls[0].options.headers.Authorization,
  'Bearer real-user-access-token'
);
assert.notEqual(identity.publisher_id, 'forged_metadata_identity');

const rejectedResolver = createSupabasePublisherResolver({
  url: validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_URL,
  publishableKey: validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_PUBLISHABLE_KEY,
  fetchImpl: async () => jsonResponse({ message: 'invalid token' }, 401)
});
assert.deepEqual(
  await rejectedResolver({ headers: { authorization: 'Bearer invalid-token' } }),
  { authenticated: false }
);

const malformedIdentityResolver = createSupabasePublisherResolver({
  url: validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_URL,
  publishableKey: validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_PUBLISHABLE_KEY,
  fetchImpl: async () => jsonResponse({ id: 'not-a-uuid' })
});
await assert.rejects(
  malformedIdentityResolver({ headers: { authorization: 'Bearer token' } }),
  /SUPABASE_AUTH_IDENTITY_INVALID/
);

const manifest = {
  manifest_schema_version: 1,
  publication_id: 'pub_0123456789abcdef0123456789abcdef',
  package_id: 'gallery_hero_001',
  package_version: 1,
  package_schema_version: 2,
  revision: 1,
  content_sha256: 'a'.repeat(64),
  byte_size: 100,
  title: 'Gallery Hero',
  description: 'Safe package',
  tags: ['starter'],
  publisher_id: '123e4567-e89b-42d3-a456-426614174000',
  created_at: '2026-09-26T08:00:00.000Z',
  updated_at: '2026-09-26T08:00:00.000Z'
};

const dataCalls = [];
const repository = createSupabasePublicationRepository({
  url: validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_URL,
  secretKey: validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_SECRET_KEY,
  fetchImpl: async (url, options) => {
    dataCalls.push({ url, options });
    const parsed = new URL(url);

    if (parsed.pathname === '/rest/v1/cf_sharing_publications') {
      return jsonResponse([{ manifest }]);
    }
    if (parsed.pathname === '/rest/v1/cf_sharing_publication_revisions') {
      const select = parsed.searchParams.get('select');
      if (select === 'revision') {
        return jsonResponse([{ revision: 1 }, { revision: 2 }]);
      }
      return jsonResponse([{ manifest, package_json: '{"schema_version":2}' }]);
    }
    if (parsed.pathname === '/rest/v1/rpc/cf_sharing_commit_revision') {
      return jsonResponse({ accepted: true });
    }
    if (parsed.pathname === '/rest/v1/rpc/cf_sharing_list_publications') {
      return jsonResponse({ items: [manifest], has_more: false });
    }
    return jsonResponse({ message: 'unexpected route' }, 404);
  }
});

assert.equal(typeof repository?.getLatest, 'function');
const latest = await repository.getLatest(
  '123e4567-e89b-42d3-a456-426614174000',
  'gallery_hero_001'
);
assert.equal(latest.manifest.publication_id, manifest.publication_id);

const committed = await repository.commitRevision({
  expected_latest_revision: 0,
  manifest,
  package_json: '{"schema_version":2}'
});
assert.deepEqual(committed, { accepted: true });

const publication = await repository.getPublication(manifest.publication_id);
assert.equal(publication.manifest.package_id, 'gallery_hero_001');

const revision = await repository.getRevision(manifest.publication_id, 1);
assert.equal(revision.package_json, '{"schema_version":2}');
assert.deepEqual(await repository.listRevisions(manifest.publication_id), [1, 2]);

const listed = await repository.listPublications({
  query: 'hero',
  tags: ['starter'],
  limit: 20,
  offset: 0
});
assert.equal(listed.items.length, 1);
assert.equal(listed.has_more, false);

assert.ok(dataCalls.length >= 6);
for (const call of dataCalls) {
  assert.equal(
    call.options.headers.apikey,
    validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_SECRET_KEY
  );
  assert.equal('Authorization' in call.options.headers, false);
  assert.equal(call.url.includes(validEnv.CUSTOM_FIGHTER_SHARING_SUPABASE_SECRET_KEY), false);
}

const commitCall = dataCalls.find(call =>
  new URL(call.url).pathname === '/rest/v1/rpc/cf_sharing_commit_revision'
);
assert.equal(commitCall.options.method, 'POST');
const commitBody = JSON.parse(commitCall.options.body);
assert.equal(commitBody.p_expected_latest_revision, 0);
assert.equal(commitBody.p_manifest.publication_id, manifest.publication_id);

const browseCall = dataCalls.find(call =>
  new URL(call.url).pathname === '/rest/v1/rpc/cf_sharing_list_publications'
);
const browseBody = JSON.parse(browseCall.options.body);
assert.deepEqual(browseBody, {
  p_query: 'hero',
  p_tags: ['starter'],
  p_limit: 20,
  p_offset: 0
});

const adapters = createSupabaseSharingAdapters({
  env: validEnv,
  fetchImpl: async () => jsonResponse([])
});
assert.equal(adapters.configured, true);
assert.equal(adapters.invalid, false);
assert.equal(adapters.durable, true);
assert.equal(typeof adapters.repository?.getRevision, 'function');
assert.equal(typeof adapters.resolvePublisher, 'function');

const disabled = createSupabaseSharingAdapters({ env: {} });
assert.deepEqual(disabled, {
  configured: false,
  invalid: false,
  durable: false,
  repository: null,
  resolvePublisher: null
});

console.log('SUPABASE_SHARING_PROVIDER_TESTS_PASSED');
