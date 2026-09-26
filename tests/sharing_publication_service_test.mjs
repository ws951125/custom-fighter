import assert from 'node:assert/strict';
import { createPublicationService, validatePublicationMetadata, _test } from '../backend/sharing/publication_service.mjs';
import { createInMemoryPublicationRepository } from '../backend/sharing/in_memory_publication_repository.mjs';

const ALLOWED_PACKAGE_FIELDS = new Set([
  'schema_version',
  'package_id',
  'package_version',
  'character',
  'skills',
  'animation_map',
  'animation_asset',
  'audio_bindings',
  'audio_asset',
  'vfx_asset'
]);

function fullPackageValidator(pkg) {
  if (!pkg || typeof pkg !== 'object' || Array.isArray(pkg)) return { accepted: false, code: 'PACKAGE_INVALID' };
  if (Object.keys(pkg).some(key => !ALLOWED_PACKAGE_FIELDS.has(key))) {
    return { accepted: false, code: 'PACKAGE_FIELDS_INVALID' };
  }
  if (![1, 2].includes(pkg.schema_version)) return { accepted: false, code: 'PACKAGE_SCHEMA_UNSUPPORTED' };
  if (typeof pkg.package_id !== 'string' || !/^[a-z0-9][a-z0-9_-]*$/.test(pkg.package_id)) {
    return { accepted: false, code: 'PACKAGE_ID_INVALID' };
  }
  if (!Number.isInteger(pkg.package_version) || pkg.package_version < 1) {
    return { accepted: false, code: 'PACKAGE_VERSION_INVALID' };
  }
  if (!pkg.character || typeof pkg.character !== 'object' || Array.isArray(pkg.character)) {
    return { accepted: false, code: 'CHARACTER_INVALID' };
  }
  if (pkg.character.id !== pkg.package_id) return { accepted: false, code: 'CHARACTER_ID_MISMATCH' };
  if (!Array.isArray(pkg.skills) || pkg.skills.length === 0) return { accepted: false, code: 'SKILLS_INVALID' };

  return {
    accepted: true,
    package_id: pkg.package_id,
    package_version: pkg.package_version,
    package_schema_version: pkg.schema_version
  };
}

function packageFixture({ version = 1, damage = 12 } = {}) {
  return {
    schema_version: 2,
    package_id: 'gallery_hero_001',
    package_version: version,
    character: {
      schema_version: 1,
      id: 'gallery_hero_001',
      name: 'Gallery Hero',
      skill_slots: { skill_1: 'gallery_bolt_001' }
    },
    skills: [
      {
        schema_version: 1,
        id: 'gallery_bolt_001',
        type: 'projectile',
        damage
      }
    ]
  };
}

const metadata = {
  title: 'Gallery Hero',
  description: 'Safe creator package',
  tags: ['projectile', 'starter']
};

assert.equal(validatePublicationMetadata(metadata).accepted, true);
assert.equal(validatePublicationMetadata({ ...metadata, extra: true }).code, 'METADATA_FIELDS_INVALID');
assert.equal(validatePublicationMetadata({ ...metadata, title: '' }).code, 'METADATA_FIELD_INVALID');
assert.equal(validatePublicationMetadata({ ...metadata, tags: ['BadTag'] }).code, 'METADATA_TAG_INVALID');
assert.equal(validatePublicationMetadata({ ...metadata, tags: ['starter', 'starter'] }).code, 'METADATA_TAG_DUPLICATE');

const repository = createInMemoryPublicationRepository();
const timestamps = [
  '2026-09-26T05:00:00.000Z',
  '2026-09-26T05:01:00.000Z',
  '2026-09-26T05:02:00.000Z',
  '2026-09-26T05:03:00.000Z',
  '2026-09-26T05:04:00.000Z'
];
let clockIndex = 0;
const service = createPublicationService({
  repository,
  validatePackage: fullPackageValidator,
  now: () => timestamps[Math.min(clockIndex++, timestamps.length - 1)]
});

const firstPackage = packageFixture();
const firstJson = JSON.stringify(firstPackage, null, 2);
const first = await service.publish({
  publisher_id: 'publisher_alpha',
  metadata,
  package_json: firstJson
});
assert.equal(first.accepted, true);
assert.equal(first.idempotent, false);
assert.equal(first.manifest.manifest_schema_version, 1);
assert.equal(first.manifest.revision, 1);
assert.equal(first.manifest.package_id, 'gallery_hero_001');
assert.equal(first.manifest.package_version, 1);
assert.equal(first.manifest.package_schema_version, 2);
assert.equal(first.manifest.publisher_id, 'publisher_alpha');
assert.equal(first.manifest.created_at, timestamps[0]);
assert.equal(first.manifest.updated_at, timestamps[0]);
assert.match(first.manifest.publication_id, /^pub_[a-f0-9]{32}$/);
assert.match(first.manifest.content_sha256, /^[a-f0-9]{64}$/);

const canonicalFirst = _test.canonicalJson(firstPackage);
assert.equal(first.manifest.content_sha256, _test.sha256(canonicalFirst));
assert.equal(first.manifest.byte_size, Buffer.byteLength(canonicalFirst, 'utf8'));

const reorderedFirstJson = JSON.stringify({
  skills: firstPackage.skills,
  package_version: firstPackage.package_version,
  package_id: firstPackage.package_id,
  character: firstPackage.character,
  schema_version: firstPackage.schema_version
});
const replay = await service.publish({
  publisher_id: 'publisher_alpha',
  metadata,
  package_json: reorderedFirstJson
});
assert.equal(replay.accepted, true);
assert.equal(replay.idempotent, true);
assert.equal(replay.manifest.revision, 1);
assert.equal(replay.manifest.content_sha256, first.manifest.content_sha256);

const metadataRevision = await service.publish({
  publisher_id: 'publisher_alpha',
  metadata: { ...metadata, description: 'Updated public description' },
  package_json: reorderedFirstJson
});
assert.equal(metadataRevision.accepted, true);
assert.equal(metadataRevision.idempotent, false);
assert.equal(metadataRevision.manifest.revision, 2);
assert.equal(metadataRevision.manifest.package_version, 1);
assert.equal(metadataRevision.manifest.content_sha256, first.manifest.content_sha256);
assert.equal(metadataRevision.manifest.created_at, timestamps[0]);
assert.equal(metadataRevision.manifest.updated_at, timestamps[2]);

const versionReuse = await service.publish({
  publisher_id: 'publisher_alpha',
  metadata,
  package_json: JSON.stringify(packageFixture({ version: 1, damage: 20 }))
});
assert.equal(versionReuse.accepted, false);
assert.equal(versionReuse.code, 'PACKAGE_VERSION_REUSE');

const secondPackage = packageFixture({ version: 2, damage: 20 });
const second = await service.publish({
  publisher_id: 'publisher_alpha',
  metadata,
  package_json: JSON.stringify(secondPackage)
});
assert.equal(second.accepted, true);
assert.equal(second.idempotent, false);
assert.equal(second.manifest.revision, 3);
assert.equal(second.manifest.package_version, 2);
assert.notEqual(second.manifest.content_sha256, first.manifest.content_sha256);

const rollback = await service.publish({
  publisher_id: 'publisher_alpha',
  metadata,
  package_json: JSON.stringify(packageFixture({ version: 1, damage: 12 }))
});
assert.equal(rollback.code, 'PACKAGE_VERSION_ROLLBACK');

const revision1 = await repository.getRevision(first.manifest.publication_id, 1);
const revision2 = await repository.getRevision(first.manifest.publication_id, 2);
const revision3 = await repository.getRevision(first.manifest.publication_id, 3);
assert.equal(revision1.manifest.revision, 1);
assert.equal(revision2.manifest.revision, 2);
assert.equal(revision3.manifest.revision, 3);
assert.deepEqual(await repository.listRevisions(first.manifest.publication_id), [1, 2, 3]);
assert.equal(revision1.package_json, canonicalFirst);
assert.equal(revision3.package_json, _test.canonicalJson(secondPackage));

revision3.manifest.title = 'mutated copy';
const revision3Again = await repository.getRevision(first.manifest.publication_id, 3);
assert.equal(revision3Again.manifest.title, metadata.title);

const otherPublisher = await service.publish({
  publisher_id: 'publisher_beta',
  metadata,
  package_json: firstJson
});
assert.equal(otherPublisher.accepted, true);
assert.equal(otherPublisher.manifest.revision, 1);
assert.notEqual(otherPublisher.manifest.publication_id, first.manifest.publication_id);

const unsafe = packageFixture();
unsafe.script = 'res://evil.gd';
const unsafeResult = await service.publish({
  publisher_id: 'publisher_alpha',
  metadata,
  package_json: JSON.stringify(unsafe)
});
assert.equal(unsafeResult.code, 'PACKAGE_VALIDATION_FAILED');
assert.equal(unsafeResult.validation_code, 'PACKAGE_FIELDS_INVALID');

const noValidator = createPublicationService({ repository });
assert.equal((await noValidator.publish({
  publisher_id: 'publisher_alpha',
  metadata,
  package_json: firstJson
})).code, 'PACKAGE_VALIDATOR_UNAVAILABLE');

const mismatchValidator = createPublicationService({
  repository,
  validatePackage: async () => ({
    accepted: true,
    package_id: 'forged_id',
    package_version: 1,
    package_schema_version: 2
  })
});
assert.equal((await mismatchValidator.publish({
  publisher_id: 'publisher_alpha',
  metadata,
  package_json: firstJson
})).code, 'PACKAGE_VALIDATOR_IDENTITY_MISMATCH');

const throwingValidator = createPublicationService({
  repository,
  validatePackage: async () => {
    throw new Error('validator failed');
  }
});
assert.equal((await throwingValidator.publish({
  publisher_id: 'publisher_alpha',
  metadata,
  package_json: firstJson
})).code, 'PACKAGE_VALIDATION_ERROR');

const noRepository = createPublicationService({ validatePackage: fullPackageValidator });
assert.equal((await noRepository.publish({
  publisher_id: 'publisher_alpha',
  metadata,
  package_json: firstJson
})).code, 'REPOSITORY_UNAVAILABLE');

const tinyLimitService = createPublicationService({
  repository,
  validatePackage: fullPackageValidator,
  maxPackageBytes: 16
});
assert.equal((await tinyLimitService.publish({
  publisher_id: 'publisher_alpha',
  metadata,
  package_json: ' '.repeat(17)
})).code, 'PACKAGE_SIZE_LIMIT');

assert.equal((await service.publish({
  publisher_id: 'bad publisher',
  metadata,
  package_json: firstJson
})).code, 'PUBLISHER_ID_INVALID');

const conflictRepository = {
  getLatest: async () => null,
  commitRevision: async () => ({ accepted: false, code: 'REVISION_CONFLICT' })
};
const conflictService = createPublicationService({
  repository: conflictRepository,
  validatePackage: fullPackageValidator
});
assert.equal((await conflictService.publish({
  publisher_id: 'publisher_gamma',
  metadata,
  package_json: firstJson
})).code, 'REVISION_CONFLICT');

console.log('SHARING_PUBLICATION_SERVICE_TESTS_PASSED');
