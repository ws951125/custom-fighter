const RPC = Object.freeze({
  getLatest: 'custom_fighter_sharing_get_latest',
  commitRevision: 'custom_fighter_sharing_commit_revision',
  getPublication: 'custom_fighter_sharing_get_publication',
  getRevision: 'custom_fighter_sharing_get_revision',
  listRevisions: 'custom_fighter_sharing_list_revisions',
  listPublications: 'custom_fighter_sharing_list_publications'
});

function normalizeProjectUrl(value) {
  if (typeof value !== 'string' || value.trim() === '') return '';
  let url;
  try {
    url = new URL(value.trim());
  } catch {
    return '';
  }
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) return '';
  if (url.pathname !== '/' || !/^[a-z0-9-]+\.supabase\.co$/i.test(url.hostname)) return '';
  return url.origin;
}

function validSecretKey(value) {
  return typeof value === 'string' && /^sb_secret_[A-Za-z0-9_-]{16,}$/.test(value.trim());
}

function clone(value) {
  return structuredClone(value);
}

function safeJson(value) {
  return JSON.stringify(value);
}

function postgresConflict(body, status) {
  const code = String(body?.code || '');
  return status === 409 || code === '23505' || code === '40001';
}

export function createSupabasePublicationRepository({
  projectUrl,
  secretKey,
  fetchImpl = globalThis.fetch
} = {}) {
  const baseUrl = normalizeProjectUrl(projectUrl);
  const serverKey = typeof secretKey === 'string' ? secretKey.trim() : '';
  if (!baseUrl || !validSecretKey(serverKey) || typeof fetchImpl !== 'function') {
    return null;
  }

  async function rpc(name, payload) {
    const response = await fetchImpl(`${baseUrl}/rest/v1/rpc/${name}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // New sb_secret_ keys are API keys, not JWTs. Never send them as Bearer tokens.
        'apikey': serverKey
      },
      body: safeJson(payload)
    });

    let body = null;
    try {
      body = await response.json();
    } catch {
      body = null;
    }

    return { response, body };
  }

  async function getLatest(publisherId, packageId) {
    const { response, body } = await rpc(RPC.getLatest, {
      p_publisher_id: String(publisherId),
      p_package_id: String(packageId)
    });
    if (!response.ok) throw new Error('SUPABASE_REPOSITORY_READ_FAILED');
    if (body === null) return null;
    const record = body?.record ?? body;
    if (!record) return null;
    if (!record.manifest || typeof record.package_json !== 'string') {
      throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    }
    return clone(record);
  }

  async function commitRevision({
    expected_latest_revision: expectedLatestRevision,
    manifest,
    package_json: packageJson
  } = {}) {
    const { response, body } = await rpc(RPC.commitRevision, {
      p_expected_latest_revision: expectedLatestRevision,
      p_manifest: manifest,
      p_package_json: packageJson
    });
    if (!response.ok) {
      if (postgresConflict(body, response.status)) return { accepted: false, code: 'REVISION_CONFLICT' };
      throw new Error('SUPABASE_REPOSITORY_WRITE_FAILED');
    }
    if (!body || typeof body !== 'object') throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    if (body.accepted === true) return { accepted: true };
    return {
      accepted: false,
      code: String(body.code || 'REVISION_COMMIT_FAILED'),
      ...(Number.isInteger(body.current_revision) ? { current_revision: body.current_revision } : {})
    };
  }

  async function getPublication(publicationId) {
    const { response, body } = await rpc(RPC.getPublication, {
      p_publication_id: String(publicationId)
    });
    if (!response.ok) throw new Error('SUPABASE_REPOSITORY_READ_FAILED');
    const record = body?.record ?? body;
    if (!record) return null;
    if (!record.manifest) throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    return clone(record);
  }

  async function getRevision(publicationId, revision) {
    const { response, body } = await rpc(RPC.getRevision, {
      p_publication_id: String(publicationId),
      p_revision: revision
    });
    if (!response.ok) throw new Error('SUPABASE_REPOSITORY_READ_FAILED');
    const record = body?.record ?? body;
    if (!record) return null;
    if (!record.manifest || typeof record.package_json !== 'string') {
      throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    }
    return clone(record);
  }

  async function listRevisions(publicationId) {
    const { response, body } = await rpc(RPC.listRevisions, {
      p_publication_id: String(publicationId)
    });
    if (!response.ok) throw new Error('SUPABASE_REPOSITORY_READ_FAILED');
    const revisions = body?.revisions ?? body;
    if (!Array.isArray(revisions) || revisions.some(value => !Number.isSafeInteger(value) || value < 1)) {
      throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    }
    return [...revisions];
  }

  async function listPublications({ query = '', tags = [], limit = 20, offset = 0 } = {}) {
    const { response, body } = await rpc(RPC.listPublications, {
      p_query: String(query),
      p_tags: Array.isArray(tags) ? tags : [],
      p_limit: limit,
      p_offset: offset
    });
    if (!response.ok) throw new Error('SUPABASE_REPOSITORY_READ_FAILED');
    if (!body || !Array.isArray(body.items) || typeof body.has_more !== 'boolean') {
      throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    }
    return {
      items: clone(body.items),
      has_more: body.has_more
    };
  }

  return Object.freeze({
    provider: 'supabase',
    durable: true,
    getLatest,
    commitRevision,
    getPublication,
    getRevision,
    listRevisions,
    listPublications
  });
}

export const _test = Object.freeze({ normalizeProjectUrl, validSecretKey, RPC });
