import crypto from 'node:crypto';

export const MANIFEST_SCHEMA_VERSION = 1;
export const DEFAULT_MAX_PACKAGE_BYTES = 16 * 1024 * 1024;

const METADATA_FIELDS = Object.freeze(['title', 'description', 'tags']);
const TAG_RE = /^[a-z0-9][a-z0-9_-]{0,23}$/;
const PUBLISHER_RE = /^[A-Za-z0-9][A-Za-z0-9_-]{0,95}$/;
const PACKAGE_ID_RE = /^[a-z0-9][a-z0-9_-]*$/;
const CONTROL_RE = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/;

function reject(code, details = {}) {
  return { accepted: false, code, ...details };
}

function clone(value) {
  return structuredClone(value);
}

function canonicalJson(value) {
  if (Array.isArray(value)) return '[' + value.map(canonicalJson).join(',') + ']';
  if (value && typeof value === 'object') {
    return '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonicalJson(value[key])).join(',') + '}';
  }
  return JSON.stringify(value);
}

function sha256(text) {
  return crypto.createHash('sha256').update(text, 'utf8').digest('hex');
}

function publicationIdFor(publisherId, packageId) {
  return 'pub_' + sha256(publisherId + '\u0000' + packageId).slice(0, 32);
}

function normalizeText(value, { field, min = 0, max }) {
  if (typeof value !== 'string') return reject('METADATA_FIELD_INVALID', { field });
  const normalized = value.trim();
  if (normalized.length < min || normalized.length > max || CONTROL_RE.test(normalized)) {
    return reject('METADATA_FIELD_INVALID', { field });
  }
  return { accepted: true, value: normalized };
}

export function validatePublicationMetadata(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return reject('METADATA_INVALID');
  if (Object.keys(input).some(key => !METADATA_FIELDS.includes(key))) return reject('METADATA_FIELDS_INVALID');

  const title = normalizeText(input.title, { field: 'title', min: 1, max: 80 });
  if (!title.accepted) return title;

  const description = normalizeText(input.description ?? '', { field: 'description', max: 500 });
  if (!description.accepted) return description;

  if (!Array.isArray(input.tags)) return reject('METADATA_FIELD_INVALID', { field: 'tags' });
  if (input.tags.length > 8) return reject('METADATA_TAGS_LIMIT');

  const tags = [];
  const seen = new Set();
  for (const rawTag of input.tags) {
    if (typeof rawTag !== 'string') return reject('METADATA_TAG_INVALID');
    const tag = rawTag.trim();
    if (!TAG_RE.test(tag)) return reject('METADATA_TAG_INVALID', { tag });
    if (seen.has(tag)) return reject('METADATA_TAG_DUPLICATE', { tag });
    seen.add(tag);
    tags.push(tag);
  }

  return {
    accepted: true,
    metadata: Object.freeze({
      title: title.value,
      description: description.value,
      tags: Object.freeze(tags)
    })
  };
}

function validateTrustedPublisherId(value) {
  return typeof value === 'string' && PUBLISHER_RE.test(value);
}

function validatePackageEnvelope(pkg) {
  if (!pkg || typeof pkg !== 'object' || Array.isArray(pkg)) return reject('PACKAGE_INVALID');
  const schemaVersion = pkg.schema_version;
  const packageId = pkg.package_id;
  const packageVersion = pkg.package_version;

  if (!Number.isInteger(schemaVersion) || schemaVersion < 1) return reject('PACKAGE_SCHEMA_INVALID');
  if (typeof packageId !== 'string' || !PACKAGE_ID_RE.test(packageId)) return reject('PACKAGE_ID_INVALID');
  if (!Number.isInteger(packageVersion) || packageVersion < 1) return reject('PACKAGE_VERSION_INVALID');

  return {
    accepted: true,
    package_schema_version: schemaVersion,
    package_id: packageId,
    package_version: packageVersion
  };
}

async function validateFullPackage(validatePackage, pkg, envelope) {
  if (typeof validatePackage !== 'function') return reject('PACKAGE_VALIDATOR_UNAVAILABLE');

  let validation;
  try {
    validation = await validatePackage(clone(pkg));
  } catch {
    return reject('PACKAGE_VALIDATION_ERROR');
  }

  if (!validation || validation.accepted !== true) {
    return reject('PACKAGE_VALIDATION_FAILED', {
      validation_code: String(validation?.code || 'PACKAGE_REJECTED')
    });
  }

  if (
    validation.package_id !== envelope.package_id ||
    validation.package_version !== envelope.package_version ||
    validation.package_schema_version !== envelope.package_schema_version
  ) {
    return reject('PACKAGE_VALIDATOR_IDENTITY_MISMATCH');
  }

  return { accepted: true };
}

function sameMetadata(a, b) {
  return a.title === b.title &&
    a.description === b.description &&
    JSON.stringify(a.tags) === JSON.stringify(b.tags);
}

function manifestFrom({
  publicationId,
  publisherId,
  envelope,
  metadata,
  revision,
  contentSha256,
  byteSize,
  createdAt,
  updatedAt
}) {
  return Object.freeze({
    manifest_schema_version: MANIFEST_SCHEMA_VERSION,
    publication_id: publicationId,
    package_id: envelope.package_id,
    package_version: envelope.package_version,
    package_schema_version: envelope.package_schema_version,
    revision,
    content_sha256: contentSha256,
    byte_size: byteSize,
    title: metadata.title,
    description: metadata.description,
    tags: Object.freeze([...metadata.tags]),
    publisher_id: publisherId,
    created_at: createdAt,
    updated_at: updatedAt
  });
}

export function createPublicationService({
  repository,
  validatePackage,
  now = () => new Date().toISOString(),
  maxPackageBytes = DEFAULT_MAX_PACKAGE_BYTES
} = {}) {
  async function publish({ publisher_id: publisherId, metadata, package_json: packageJson } = {}) {
    if (!validateTrustedPublisherId(publisherId)) return reject('PUBLISHER_ID_INVALID');

    const metadataResult = validatePublicationMetadata(metadata);
    if (!metadataResult.accepted) return metadataResult;

    if (typeof packageJson !== 'string') return reject('PACKAGE_JSON_INVALID');
    const inputByteSize = Buffer.byteLength(packageJson, 'utf8');
    if (inputByteSize <= 0) return reject('PACKAGE_JSON_EMPTY');
    if (!Number.isInteger(maxPackageBytes) || maxPackageBytes < 1 || inputByteSize > maxPackageBytes) {
      return reject('PACKAGE_SIZE_LIMIT');
    }

    let pkg;
    try {
      pkg = JSON.parse(packageJson);
    } catch {
      return reject('PACKAGE_JSON_INVALID');
    }

    const envelope = validatePackageEnvelope(pkg);
    if (!envelope.accepted) return envelope;

    const fullValidation = await validateFullPackage(validatePackage, pkg, envelope);
    if (!fullValidation.accepted) return fullValidation;

    const canonicalPackageJson = canonicalJson(pkg);
    const byteSize = Buffer.byteLength(canonicalPackageJson, 'utf8');
    if (byteSize <= 0 || byteSize > maxPackageBytes) return reject('PACKAGE_SIZE_LIMIT');

    if (
      !repository ||
      typeof repository.getLatest !== 'function' ||
      typeof repository.commitRevision !== 'function'
    ) {
      return reject('REPOSITORY_UNAVAILABLE');
    }

    let latest;
    try {
      latest = await repository.getLatest(publisherId, envelope.package_id);
    } catch {
      return reject('REPOSITORY_ERROR');
    }

    const contentSha256 = sha256(canonicalPackageJson);
    const normalizedMetadata = metadataResult.metadata;
    const publicationId = publicationIdFor(publisherId, envelope.package_id);
    const timestamp = String(now());

    if (latest) {
      const previous = latest.manifest;
      if (
        !previous ||
        previous.publication_id !== publicationId ||
        previous.publisher_id !== publisherId ||
        previous.package_id !== envelope.package_id
      ) {
        return reject('REPOSITORY_IDENTITY_MISMATCH');
      }

      if (envelope.package_version < previous.package_version) {
        return reject('PACKAGE_VERSION_ROLLBACK');
      }

      if (
        envelope.package_version === previous.package_version &&
        contentSha256 !== previous.content_sha256
      ) {
        return reject('PACKAGE_VERSION_REUSE');
      }

      const exactReplay =
        envelope.package_version === previous.package_version &&
        contentSha256 === previous.content_sha256 &&
        sameMetadata(normalizedMetadata, previous);

      if (exactReplay) {
        return {
          accepted: true,
          idempotent: true,
          manifest: clone(previous)
        };
      }

      const manifest = manifestFrom({
        publicationId,
        publisherId,
        envelope,
        metadata: normalizedMetadata,
        revision: previous.revision + 1,
        contentSha256,
        byteSize,
        createdAt: previous.created_at,
        updatedAt: timestamp
      });

      try {
        const committed = await repository.commitRevision({
          expected_latest_revision: previous.revision,
          manifest: clone(manifest),
          package_json: canonicalPackageJson
        });
        if (!committed?.accepted) return reject(String(committed?.code || 'REVISION_COMMIT_FAILED'));
      } catch {
        return reject('REPOSITORY_ERROR');
      }

      return { accepted: true, idempotent: false, manifest: clone(manifest) };
    }

    const manifest = manifestFrom({
      publicationId,
      publisherId,
      envelope,
      metadata: normalizedMetadata,
      revision: 1,
      contentSha256,
      byteSize,
      createdAt: timestamp,
      updatedAt: timestamp
    });

    try {
      const committed = await repository.commitRevision({
        expected_latest_revision: 0,
        manifest: clone(manifest),
        package_json: canonicalPackageJson
      });
      if (!committed?.accepted) return reject(String(committed?.code || 'REVISION_COMMIT_FAILED'));
    } catch {
      return reject('REPOSITORY_ERROR');
    }

    return { accepted: true, idempotent: false, manifest: clone(manifest) };
  }

  return Object.freeze({ publish });
}

export const _test = Object.freeze({
  canonicalJson,
  publicationIdFor,
  sha256
});
