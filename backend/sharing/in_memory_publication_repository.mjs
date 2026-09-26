function clone(value) {
  return structuredClone(value);
}

function keyFor(publisherId, packageId) {
  return String(publisherId) + '|' + String(packageId);
}

export function createInMemoryPublicationRepository() {
  const latestByKey = new Map();
  const revisionsByPublication = new Map();

  async function getLatest(publisherId, packageId) {
    const entry = latestByKey.get(keyFor(publisherId, packageId));
    return entry ? clone(entry) : null;
  }

  async function commitRevision({ expected_latest_revision: expectedLatestRevision, manifest, package_json: packageJson } = {}) {
    if (!manifest || typeof manifest !== 'object') {
      return { accepted: false, code: 'REVISION_RECORD_INVALID' };
    }
    if (typeof packageJson !== 'string' || packageJson.length === 0) {
      return { accepted: false, code: 'REVISION_RECORD_INVALID' };
    }
    if (!Number.isInteger(expectedLatestRevision) || expectedLatestRevision < 0) {
      return { accepted: false, code: 'REVISION_EXPECTATION_INVALID' };
    }

    const key = keyFor(manifest.publisher_id, manifest.package_id);
    const current = latestByKey.get(key);
    const currentRevision = current?.manifest?.revision ?? 0;

    if (currentRevision !== expectedLatestRevision) {
      return {
        accepted: false,
        code: 'REVISION_CONFLICT',
        current_revision: currentRevision
      };
    }

    const record = Object.freeze({
      manifest: clone(manifest),
      package_json: packageJson
    });

    const publicationId = manifest.publication_id;
    const history = revisionsByPublication.get(publicationId) ?? new Map();
    if (history.has(manifest.revision)) {
      return { accepted: false, code: 'REVISION_ALREADY_EXISTS' };
    }

    history.set(manifest.revision, record);
    revisionsByPublication.set(publicationId, history);
    latestByKey.set(key, record);

    return { accepted: true };
  }

  async function getRevision(publicationId, revision) {
    const history = revisionsByPublication.get(String(publicationId));
    const record = history?.get(Number(revision));
    return record ? clone(record) : null;
  }

  async function listRevisions(publicationId) {
    const history = revisionsByPublication.get(String(publicationId));
    if (!history) return [];
    return [...history.keys()].sort((a, b) => a - b);
  }

  return Object.freeze({
    getLatest,
    commitRevision,
    getRevision,
    listRevisions
  });
}
