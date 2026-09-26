import assert from 'node:assert/strict';
import { createSupabasePublicationRepository, _test as repositoryTest } from '../backend/sharing/supabase_publication_repository.mjs';
import { createSupabasePublisherResolver, _test as resolverTest } from '../backend/sharing/supabase_publisher_resolver.mjs';
import { createSupabaseSharingIntegration, _test as integrationTest } from '../backend/sharing/supabase_integration.mjs';

const PROJECT_URL = 'https://abcdefghijklmnopqrst.supabase.co';
const SECRET_KEY = 'server-only-test-key-not-a-real-credential';
const PUBLISHABLE_KEY = 'publishable-test-key-not-a-real-credential';
const USER_TOKEN = 'header.payload.signature-token-value';
const USER_ID = '123e4567-e89b-42d3-a456-426614174000';
const PUBLICATION_ID = 'pub_0123456789abcdef0123456789abcdef';

function jsonResponse(status, body) {
  return {
    status,
    ok: status >= 200 && status < 300,
    async json() {
      return structuredClone(body);
    }
  };
}

function requestWithBearer(token = USER_TOKEN) {
  return {
    headers: {
      authorization: `Bearer ${token}`
    }
  };
}

assert.equal(repositoryTest.normalizeProjectUrl(PROJECT_URL + '/'), PROJECT_URL);
assert.equal(repositoryTest.normalizeProjectUrl('http://example.com'), '');
assert.equal(repositoryTest.normalizeProjectUrl('https://user:pass@example.com'), '');
assert.equal(repositoryTest.validSecretKey('short'), false);
assert.equal(resolverTest.normalizeProjectUrl(PROJECT_URL + '/'), PROJECT_URL);
assert.equal(resolverTest.normalizeProjectUrl('not a url'), '');
assert.equal(resolverTest.validPublishableKey('short'), false);
assert.equal(resolverTest.bearerToken({ headers: {} }), '');
assert.equal(resolverTest.bearerToken({ headers: { authorization: 'Basic abc' } }), '');
assert.equal(resolverTest.bearerToken(requestWithBearer()), USER_TOKEN);
assert.equal(repositoryTest.RPC.commitRevision, 'custom_fighter_sharing_commit_revision');
assert.equal(integrationTest.ENV.secretKey, 'CUSTOM_FIGHTER_SHARING_SUPABASE_SECRET_KEY');

assert.equal(createSupabasePublicationRepository({
  projectUrl: 'http://bad.example',
  secretKey: SECRET_KEY,
  fetchImpl: async () => {}
}), null);
assert.equal(createSupabasePublisherResolver({
  projectUrl: PROJECT_URL,
  publishableKey: 'short',
  fetchImpl: async () => {}
}), null);

const calls = [];
const manifest = {
  manifest_schema_version: 1,
  publication_id: PUBLICATION_ID,
  package_id: 'gallery_hero_001',
  package_version: 1,
  package_schema_version: 2,
  revision: 1,
  content_sha256: 'a'.repeat(64),
  byte_size: 123,
  title: 'Gallery Hero',
  description: 'Safe package',
  tags: ['starter'],
  publisher_id: USER_ID,
  created_at: '2026-09-26T08:00:00.000Z',
  updated_at: '2026-09-26T08:00:00.000Z'
};
const packageJson = JSON.stringify({
  schema_version: 2,
  package_id: 'gallery_hero_001',
  package_version: 1,
  character: { id: 'gallery_hero_001' },
  skills: []
});

const rpcBodies = new Map([
  [repositoryTest.RPC.getLatest, { record: { manifest, package_json: packageJson } }],
  [repositoryTest.RPC.commitRevision, { accepted: true }],
  [repositoryTest.RPC.getPublication, { record: { manifest } }],
  [repositoryTest.RPC.getRevision, { record: { manifest, package_json: packageJson } }],
  [repositoryTest.RPC.listRevisions, { revisions: [1, 2, 3] }],
  [repositoryTest.RPC.listPublications, { items: [manifest], has_more: false }]
]);

const repository = createSupabasePublicationRepository({
  projectUrl: PROJECT_URL,
  secretKey: SECRET_KEY,
  fetchImpl: async (url, options) => {
    calls.push({ url, options });
    const rpcName = String(url).split('/').pop();
    return jsonResponse(200, rpcBodies.get(rpcName));
  }
});
assert.equal(repository.provider, 'supabase');
assert.equal(repository.durable, true);

const latest = await repository.getLatest(USER_ID, 'gallery_hero_001');
assert.equal(latest.manifest.publication_id, PUBLICATION_ID);
latest.manifest.title = 'mutated';
const latestAgain = await repository.getLatest(USER_ID, 'gallery_hero_001');
assert.equal(latestAgain.manifest.title, 'Gallery Hero');

const commit = await repository.commitRevision({
  expected_latest_revision: 0,
  manifest,
  package_json: packageJson
});
assert.deepEqual(commit, { accepted: true });

const publication = await repository.getPublication(PUBLICATION_ID);
assert.equal(publication.manifest.revision, 1);
const revision = await repository.getRevision(PUBLICATION_ID, 1);
assert.equal(revision.package_json, packageJson);
assert.deepEqual(await repository.listRevisions(PUBLICATION_ID), [1, 2, 3]);
const listing = await repository.listPublications({
  query: 'hero',
  tags: ['starter'],
  limit: 20,
  offset: 0
});
assert.equal(listing.items.length, 1);
assert.equal(listing.has_more, false);

assert.equal(calls.length, 7);
for (const call of calls) {
  assert.equal(call.options.method, 'POST');
  assert.equal(call.options.headers.apikey, SECRET_KEY);
  assert.equal(call.options.headers.Authorization, `Bearer ${SECRET_KEY}`);
  assert.equal(call.options.headers['Content-Type'], 'application/json');
  assert.equal(String(call.url).startsWith(PROJECT_URL + '/rest/v1/rpc/'), true);
}
const getLatestPayload = JSON.parse(calls[0].options.body);
assert.deepEqual(getLatestPayload, {
  p_publisher_id: USER_ID,
  p_package_id: 'gallery_hero_001'
});
const commitPayload = JSON.parse(calls[2].options.body);
assert.equal(commitPayload.p_expected_latest_revision, 0);
assert.equal(commitPayload.p_manifest.publication_id, PUBLICATION_ID);
assert.equal(commitPayload.p_package_json, packageJson);

const conflictRepository = createSupabasePublicationRepository({
  projectUrl: PROJECT_URL,
  secretKey: SECRET_KEY,
  fetchImpl: async () => jsonResponse(409, { code: '23505' })
});
assert.deepEqual(await conflictRepository.commitRevision({
  expected_latest_revision: 1,
  manifest: { ...manifest, revision: 2 },
  package_json: packageJson
}), { accepted: false, code: 'REVISION_CONFLICT' });

const errorRepository = createSupabasePublicationRepository({
  projectUrl: PROJECT_URL,
  secretKey: SECRET_KEY,
  fetchImpl: async () => jsonResponse(500, { message: 'database unavailable' })
});
await assert.rejects(
  () => errorRepository.getPublication(PUBLICATION_ID),
  /SUPABASE_REPOSITORY_READ_FAILED/
);

let authCall = null;
const resolver = createSupabasePublisherResolver({
  projectUrl: PROJECT_URL,
  publishableKey: PUBLISHABLE_KEY,
  fetchImpl: async (url, options) => {
    authCall = { url, options };
    return jsonResponse(200, {
      id: USER_ID,
      email: 'creator@example.com',
      is_anonymous: false,
      user_metadata: { publisher_id: 'forged_browser_value' }
    });
  }
});
assert.deepEqual(await resolver({ headers: {} }), { authenticated: false });
assert.equal(authCall, null);

const publisher = await resolver(requestWithBearer());
assert.deepEqual(publisher, {
  authenticated: true,
  publisher_id: USER_ID
});
assert.equal(authCall.url, PROJECT_URL + '/auth/v1/user');
assert.equal(authCall.options.headers.apikey, PUBLISHABLE_KEY);
assert.equal(authCall.options.headers.Authorization, `Bearer ${USER_TOKEN}`);

const unauthorizedResolver = createSupabasePublisherResolver({
  projectUrl: PROJECT_URL,
  publishableKey: PUBLISHABLE_KEY,
  fetchImpl: async () => jsonResponse(401, { error: 'invalid token' })
});
assert.deepEqual(await unauthorizedResolver(requestWithBearer()), { authenticated: false });

const anonymousResolver = createSupabasePublisherResolver({
  projectUrl: PROJECT_URL,
  publishableKey: PUBLISHABLE_KEY,
  fetchImpl: async () => jsonResponse(200, {
    id: USER_ID,
    is_anonymous: true,
    user_metadata: { role: 'publisher' }
  })
});
assert.deepEqual(await anonymousResolver(requestWithBearer()), { authenticated: false });

const malformedIdentityResolver = createSupabasePublisherResolver({
  projectUrl: PROJECT_URL,
  publishableKey: PUBLISHABLE_KEY,
  fetchImpl: async () => jsonResponse(200, {
    id: 'not-a-uuid',
    is_anonymous: false
  })
});
await assert.rejects(
  () => malformedIdentityResolver(requestWithBearer()),
  /SUPABASE_AUTH_RESULT_INVALID/
);

const unavailableResolver = createSupabasePublisherResolver({
  projectUrl: PROJECT_URL,
  publishableKey: PUBLISHABLE_KEY,
  fetchImpl: async () => jsonResponse(503, { error: 'upstream down' })
});
await assert.rejects(
  () => unavailableResolver(requestWithBearer()),
  /SUPABASE_AUTH_UNAVAILABLE/
);

const unconfigured = createSupabaseSharingIntegration({ env: {}, fetchImpl: async () => {} });
assert.equal(unconfigured.configured, false);
assert.equal(unconfigured.reason, 'unconfigured');
assert.equal(unconfigured.repository, null);
assert.equal(unconfigured.repositoryDurable, false);
assert.equal(unconfigured.resolvePublisher, null);

const incomplete = createSupabaseSharingIntegration({
  env: {
    CUSTOM_FIGHTER_SHARING_SUPABASE_URL: PROJECT_URL,
    CUSTOM_FIGHTER_SHARING_SUPABASE_SECRET_KEY: SECRET_KEY
  },
  fetchImpl: async () => {}
});
assert.equal(incomplete.configured, false);
assert.equal(incomplete.reason, 'incomplete_environment');
assert.equal(incomplete.repositoryDurable, false);

const configured = createSupabaseSharingIntegration({
  env: {
    CUSTOM_FIGHTER_SHARING_SUPABASE_URL: PROJECT_URL,
    CUSTOM_FIGHTER_SHARING_SUPABASE_SECRET_KEY: SECRET_KEY,
    CUSTOM_FIGHTER_SHARING_SUPABASE_PUBLISHABLE_KEY: PUBLISHABLE_KEY
  },
  fetchImpl: async () => jsonResponse(500, {})
});
assert.equal(configured.configured, true);
assert.equal(configured.reason, 'configured');
assert.equal(configured.repository.provider, 'supabase');
assert.equal(configured.repositoryDurable, true);
assert.equal(typeof configured.resolvePublisher, 'function');

console.log('SUPABASE_SHARING_ADAPTER_TESTS_PASSED');
