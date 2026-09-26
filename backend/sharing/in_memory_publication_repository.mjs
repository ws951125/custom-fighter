function clone(value) {
  return structuredClone(value);
}

function keyFor(publisherId, packageId) {
  return String(publisherId) + '|' + String(packageId);
}

function searchableManifestText(manifest) {
  return [
    manifest.package_id,
    manifest.title,
    manifest.description,
    ...(Array.isArray(manifest.tags) ? manifest.tags : [])
  ].map(value => String(value || '').toLowerCase()).join('\n');
}

export function createInMemoryPublicationRepository() {
  const latestByKey = new Map();
  const latestByPublication = new Map();
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
    latestByPublication.set(publicationId, record);

    return { accepted: true };
  }

  async function getPublication(publicationId) {
    const record = latestByPublication.get(String(publicationId));
    return record ? clone(record) : null;
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

  async function listPublications({ query = '', tags = [], limit = 20, offset = 0 } = {}) {
    const normalizedQuery = String(query || '').toLowerCase();
    const normalizedTags = Array.isArray(tags) ? tags.map(tag => String(tag)) : [];

    const matches = [...latestByPublication.values()]
      .filter(record => {
        const manifest = record.manifest;
        const manifestTags = Array.isArray(manifest.tags) ? manifest.tags : [];
        if (!normalizedTags.every(tag => manifestTags.includes(tag))) return false;
        if (!normalizedQuery) return true;
        return searchableManifestText(manifest).includes(normalizedQuery);
      })
      .sort((a, b) => {
        const updated = String(b.manifest.updated_at).localeCompare(String(a.manifest.updated_at));
        if (updated !== 0) return updated;
        return String(a.manifest.publication_id).localeCompare(String(b.manifest.publication_id));
      });

    const slice = matches.slice(offset, offset + limit);
    return {
      items: slice.map(record => clone(record.manifest)),
      has_more: offset + slice.length < matches.length
    };
  }

  return Object.freeze({
    getLatest,
    commitRevision,
    getPublication,
    getRevision,
    listRevisions,
    listPublications
  });
}
