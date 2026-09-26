import assert from 'node:assert/strict';
import { createServer } from '../backend/server.mjs';
import { createInMemoryPublicationRepository } from '../backend/sharing/in_memory_publication_repository.mjs';
import { DEFAULT_MAX_PUBLICATION_REQUEST_BYTES } from '../backend/sharing/http_api.mjs';

const allowedOrigin = 'https://ws951125.github.io';

const vfxService = async request => ({
  ok: true,
  request_id: request.request_id,
  frame_count: request.frame_count,
  fps: request.fps,
  png_base64: 'dGVzdA=='
});

function packageFixture({ id = 'gallery_hero_001', version = 1, damage = 12 } = {}) {
  return {
    schema_version: 2,
    package_id: id,
    package_version: version,
    character: {
      schema_version: 1,
      id,
      name: id === 'gallery_hero_001' ? 'Gallery Hero' : 'Gallery Mage',
      skill_slots: { skill_1: id + '_bolt' }
    },
    skills: [
      {
        schema_version: 1,
        id: id + '_bolt',
        type: 'projectile',
        damage
      }
    ]
  };
}

async function fullPackageValidator(pkg) {
  if (!pkg || typeof pkg !== 'object' || Array.isArray(pkg)) {
    return { accepted: false, code: 'PACKAGE_INVALID' };
  }
  if (pkg.schema_version !== 2) return { accepted: false, code: 'PACKAGE_SCHEMA_UNSUPPORTED' };
  if (typeof pkg.package_id !== 'string' || !/^[a-z0-9][a-z0-9_-]*$/.test(pkg.package_id)) {
    return { accepted: false, code: 'PACKAGE_ID_INVALID' };
  }
  if (!Number.isInteger(pkg.package_version) || pkg.package_version < 1) {
    return { accepted: false, code: 'PACKAGE_VERSION_INVALID' };
  }
  if (!pkg.character || pkg.character.id !== pkg.package_id) {
    return { accepted: false, code: 'CHARACTER_ID_MISMATCH' };
  }
  if (!Array.isArray(pkg.skills) || pkg.skills.length < 1) {
    return { accepted: false, code: 'SKILLS_INVALID' };
  }
  if ('script' in pkg) return { accepted: false, code: 'PACKAGE_FIELDS_INVALID' };

  return {
    accepted: true,
    package_id: pkg.package_id,
    package_version: pkg.package_version,
    package_schema_version: pkg.schema_version
  };
}

function metadataFor(title, tags = ['starter']) {
  return {
    title,
    description: 'Safe creator Gallery package',
    tags
  };
}

async function listen(server) {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  return `http://127.0.0.1:${port}`;
}

async function close(server) {
  await new Promise(resolve => server.close(resolve));
}

function configuredServer(overrides = {}) {
  const repository = overrides.repository || createInMemoryPublicationRepository();
  const server = createServer({
    service: vfxService,
    sharingRepository: repository,
    sharingRepositoryDurable: true,
    sharingValidatePackage: fullPackageValidator,
    sharingResolvePublisher: async req => {
      if (req.headers.authorization === 'Bearer publisher-alpha') {
        return { authenticated: true, publisher_id: 'publisher_alpha' };
      }
      return { authenticated: false };
    },
    ...overrides,
    sharingRepository: repository
  });
  return { server, repository };
}

async function publish(base, pkg, metadata, extra = {}) {
  return fetch(`${base}/v1/sharing/publications`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Origin': allowedOrigin,
      'Authorization': 'Bearer publisher-alpha'
    },
    body: JSON.stringify({
      metadata,
      package_json: JSON.stringify(pkg),
      ...extra
    })
  });
}

assert.equal(DEFAULT_MAX_PUBLICATION_REQUEST_BYTES, 16 * 1024 * 1024);

const { server, repository } = configuredServer();
const base = await listen(server);

try {
  const health = await fetch(`${base}/healthz`, { headers: { Origin: allowedOrigin } });
  assert.equal(health.status, 200);
  const healthBody = await health.json();
  assert.equal(healthBody.sharing.api_version, 1);
  assert.equal(healthBody.sharing.publications_path, '/v1/sharing/publications');
  assert.equal(healthBody.sharing.repository_configured, true);
  assert.equal(healthBody.sharing.durable_repository, true);
  assert.equal(healthBody.sharing.publisher_auth_configured, true);
  assert.equal(healthBody.sharing.package_validator_configured, true);
  assert.equal(healthBody.sharing.max_publication_request_bytes, DEFAULT_MAX_PUBLICATION_REQUEST_BYTES);

  const preflight = await fetch(`${base}/v1/sharing/publications`, {
    method: 'OPTIONS',
    headers: { Origin: allowedOrigin }
  });
  assert.equal(preflight.status, 204);
  assert.match(preflight.headers.get('access-control-allow-headers') || '', /Authorization/);

  const blockedOrigin = await fetch(`${base}/v1/sharing/publications`, {
    headers: { Origin: 'https://evil.example' }
  });
  assert.equal(blockedOrigin.status, 403);

  const noAuth = await fetch(`${base}/v1/sharing/publications`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Origin': allowedOrigin },
    body: JSON.stringify({
      metadata: metadataFor('Gallery Hero'),
      package_json: JSON.stringify(packageFixture())
    })
  });
  assert.equal(noAuth.status, 401);
  assert.equal((await noAuth.json()).code, 'PUBLISHER_UNAUTHENTICATED');

  const forgedPublisher = await publish(
    base,
    packageFixture(),
    metadataFor('Gallery Hero'),
    { publisher_id: 'forged_browser_identity' }
  );
  assert.equal(forgedPublisher.status, 400);
  assert.equal((await forgedPublisher.json()).code, 'PUBLISH_REQUEST_FIELDS_INVALID');

  const first = await publish(base, packageFixture(), metadataFor('Gallery Hero', ['starter', 'projectile']));
  assert.equal(first.status, 201);
  assert.equal(first.headers.get('access-control-allow-origin'), allowedOrigin);
  const firstBody = await first.json();
  assert.equal(firstBody.ok, true);
  assert.equal(firstBody.idempotent, false);
  assert.equal(firstBody.manifest.publisher_id, 'publisher_alpha');
  assert.equal(firstBody.manifest.revision, 1);
  const publicationId = firstBody.manifest.publication_id;

  const replay = await publish(base, packageFixture(), metadataFor('Gallery Hero', ['starter', 'projectile']));
  assert.equal(replay.status, 200);
  const replayBody = await replay.json();
  assert.equal(replayBody.idempotent, true);
  assert.equal(replayBody.manifest.revision, 1);

  const metadataRevision = await publish(
    base,
    packageFixture(),
    {
      title: 'Gallery Hero Updated',
      description: 'Updated metadata only',
      tags: ['starter', 'projectile']
    }
  );
  assert.equal(metadataRevision.status, 201);
  assert.equal((await metadataRevision.json()).manifest.revision, 2);

  const reusedVersion = await publish(
    base,
    packageFixture({ version: 1, damage: 20 }),
    metadataFor('Gallery Hero', ['starter', 'projectile'])
  );
  assert.equal(reusedVersion.status, 409);
  assert.equal((await reusedVersion.json()).code, 'PACKAGE_VERSION_REUSE');

  const versionTwo = await publish(
    base,
    packageFixture({ version: 2, damage: 20 }),
    metadataFor('Gallery Hero V2', ['starter', 'projectile'])
  );
  assert.equal(versionTwo.status, 201);
  assert.equal((await versionTwo.json()).manifest.revision, 3);

  const second = await publish(
    base,
    packageFixture({ id: 'gallery_mage_001' }),
    metadataFor('Gallery Mage', ['magic'])
  );
  assert.equal(second.status, 201);

  const browse = await fetch(`${base}/v1/sharing/publications?limit=1`, {
    headers: { Origin: allowedOrigin }
  });
  assert.equal(browse.status, 200);
  const browseBody = await browse.json();
  assert.equal(browseBody.items.length, 1);
  assert.equal(typeof browseBody.next_cursor, 'string');

  const browseSecond = await fetch(
    `${base}/v1/sharing/publications?limit=1&cursor=${encodeURIComponent(browseBody.next_cursor)}`,
    { headers: { Origin: allowedOrigin } }
  );
  assert.equal(browseSecond.status, 200);
  const browseSecondBody = await browseSecond.json();
  assert.equal(browseSecondBody.items.length, 1);
  assert.notEqual(browseSecondBody.items[0].publication_id, browseBody.items[0].publication_id);
  assert.equal(browseSecondBody.next_cursor, null);

  const searched = await fetch(`${base}/v1/sharing/publications?q=hero&tag=projectile`);
  assert.equal(searched.status, 200);
  const searchedBody = await searched.json();
  assert.equal(searchedBody.items.length, 1);
  assert.equal(searchedBody.items[0].publication_id, publicationId);
  assert.equal('package_json' in searchedBody.items[0], false);

  const runtimeFieldSearch = await fetch(`${base}/v1/sharing/publications?q=gallery_hero_001_bolt`);
  assert.equal(runtimeFieldSearch.status, 200);
  assert.equal((await runtimeFieldSearch.json()).items.length, 0);

  const invalidQueryField = await fetch(`${base}/v1/sharing/publications?publisher_id=publisher_alpha`);
  assert.equal(invalidQueryField.status, 400);
  assert.equal((await invalidQueryField.json()).code, 'CATALOG_QUERY_FIELDS_INVALID');

  const invalidLimit = await fetch(`${base}/v1/sharing/publications?limit=999`);
  assert.equal(invalidLimit.status, 400);
  assert.equal((await invalidLimit.json()).code, 'CATALOG_LIMIT_INVALID');

  const invalidCursor = await fetch(`${base}/v1/sharing/publications?cursor=not-a-valid-cursor`);
  assert.equal(invalidCursor.status, 400);
  assert.equal((await invalidCursor.json()).code, 'CATALOG_CURSOR_INVALID');

  const detail = await fetch(`${base}/v1/sharing/publications/${publicationId}`);
  assert.equal(detail.status, 200);
  const detailBody = await detail.json();
  assert.equal(detailBody.manifest.revision, 3);
  assert.deepEqual(detailBody.revisions, [1, 2, 3]);

  const revisionOne = await fetch(`${base}/v1/sharing/publications/${publicationId}/revisions/1`);
  assert.equal(revisionOne.status, 200);
  assert.equal((await revisionOne.json()).manifest.revision, 1);

  const downloadOne = await fetch(`${base}/v1/sharing/publications/${publicationId}/revisions/1/package`, {
    headers: { Origin: allowedOrigin }
  });
  assert.equal(downloadOne.status, 200);
  assert.equal(downloadOne.headers.get('access-control-allow-origin'), allowedOrigin);
  assert.match(downloadOne.headers.get('content-disposition') || '', /gallery_hero_001-r1\.custom-fighter\.json/);
  assert.match(downloadOne.headers.get('etag') || '', /^"sha256-[a-f0-9]{64}"$/);
  const downloadedOne = JSON.parse(await downloadOne.text());
  assert.equal(downloadedOne.package_version, 1);
  assert.equal(downloadedOne.skills[0].damage, 12);

  const downloadThree = await fetch(`${base}/v1/sharing/publications/${publicationId}/revisions/3/package`);
  assert.equal(downloadThree.status, 200);
  const downloadedThree = JSON.parse(await downloadThree.text());
  assert.equal(downloadedThree.package_version, 2);
  assert.equal(downloadedThree.skills[0].damage, 20);

  const missingRevision = await fetch(`${base}/v1/sharing/publications/${publicationId}/revisions/99`);
  assert.equal(missingRevision.status, 404);
  assert.equal((await missingRevision.json()).code, 'REVISION_NOT_FOUND');

  const unknownPublication = 'pub_00000000000000000000000000000000';
  const missingPublication = await fetch(`${base}/v1/sharing/publications/${unknownPublication}`);
  assert.equal(missingPublication.status, 404);
  assert.equal((await missingPublication.json()).code, 'PUBLICATION_NOT_FOUND');

  const wrongMethod = await fetch(`${base}/v1/sharing/publications`, { method: 'PUT' });
  assert.equal(wrongMethod.status, 405);
  assert.equal((await wrongMethod.json()).code, 'METHOD_NOT_ALLOWED');

  const storedRevisionOne = await repository.getRevision(publicationId, 1);
  const storedRevisionThree = await repository.getRevision(publicationId, 3);
  assert.equal(JSON.parse(storedRevisionOne.package_json).skills[0].damage, 12);
  assert.equal(JSON.parse(storedRevisionThree.package_json).skills[0].damage, 20);
} finally {
  await close(server);
}

const failClosedServer = createServer({ service: vfxService });
const failClosedBase = await listen(failClosedServer);
try {
  const readUnavailable = await fetch(`${failClosedBase}/v1/sharing/publications`);
  assert.equal(readUnavailable.status, 503);
  assert.equal((await readUnavailable.json()).code, 'REPOSITORY_UNAVAILABLE');

  const publishUnavailable = await fetch(`${failClosedBase}/v1/sharing/publications`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Origin': allowedOrigin },
    body: JSON.stringify({
      metadata: metadataFor('Gallery Hero'),
      package_json: JSON.stringify(packageFixture())
    })
  });
  assert.equal(publishUnavailable.status, 503);
  assert.equal((await publishUnavailable.json()).code, 'DURABLE_REPOSITORY_UNAVAILABLE');
} finally {
  await close(failClosedServer);
}

const { server: boundedServer } = configuredServer({
  sharingMaxPublicationRequestBytes: 128
});
const boundedBase = await listen(boundedServer);
try {
  const oversized = await fetch(`${boundedBase}/v1/sharing/publications`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Origin': allowedOrigin,
      'Authorization': 'Bearer publisher-alpha'
    },
    body: JSON.stringify({
      metadata: metadataFor('Gallery Hero'),
      package_json: 'x'.repeat(256)
    })
  });
  assert.equal(oversized.status, 413);
  assert.equal((await oversized.json()).code, 'REQUEST_BODY_TOO_LARGE');

  const vfxStillIndependent = await fetch(`${boundedBase}/v1/vfx/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Origin': allowedOrigin },
    body: JSON.stringify({ request_id: 'req_sharing_limit_independent', frame_count: 2, fps: 12 })
  });
  assert.equal(vfxStillIndependent.status, 200);
} finally {
  await close(boundedServer);
}

console.log('SHARING_HTTP_API_TESTS_PASSED');
