const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const BEARER_RE = /^Bearer\s+([^\s]+)$/i;
const MAX_ACCESS_TOKEN_CHARS = 16 * 1024;

function normalizeUrl(value) {
  if (typeof value !== 'string' || value.length === 0) return '';
  let url;
  try {
    url = new URL(value);
  } catch {
    return '';
  }
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) return '';
  return url.origin;
}

function hasSafeKey(value) {
  return typeof value === 'string' && value.length >= 16 && value.length <= 4096 && !/\s/.test(value);
}

function clone(value) {
  return structuredClone(value);
}

async function parseJsonResponse(response) {
  const text = await response.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    throw new Error('SUPABASE_RESPONSE_INVALID');
  }
}

function createAdminRequest({ baseUrl, secretKey, fetchImpl }) {
  return async function adminRequest(path, { method = 'GET', body } = {}) {
    const response = await fetchImpl(baseUrl + path, {
      method,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'apikey': secretKey
      },
      body: body === undefined ? undefined : JSON.stringify(body)
    });
    const payload = await parseJsonResponse(response);
    if (!response.ok) {
      throw new Error('SUPABASE_DATA_API_ERROR_' + response.status);
    }
    return payload;
  };
}

export function readSupabaseSharingConfig(env = process.env) {
  const url = normalizeUrl(env.CUSTOM_FIGHTER_SHARING_SUPABASE_URL);
  const publishableKey = String(env.CUSTOM_FIGHTER_SHARING_SUPABASE_PUBLISHABLE_KEY || '');
  const secretKey = String(env.CUSTOM_FIGHTER_SHARING_SUPABASE_SECRET_KEY || '');

  const anySet = Boolean(url || publishableKey || secretKey);
  const complete = Boolean(url && hasSafeKey(publishableKey) && hasSafeKey(secretKey));

  if (!anySet) {
    return Object.freeze({ configured: false, invalid: false });
  }
  if (!complete) {
    return Object.freeze({ configured: false, invalid: true });
  }

  return Object.freeze({
    configured: true,
    invalid: false,
    url,
    publishable_key: publishableKey,
    secret_key: secretKey
  });
}

export function createSupabasePublisherResolver({
  url,
  publishableKey,
  fetchImpl = globalThis.fetch
} = {}) {
  const baseUrl = normalizeUrl(url);
  if (!baseUrl || !hasSafeKey(publishableKey) || typeof fetchImpl !== 'function') {
    return null;
  }

  return async function resolvePublisher(req) {
    const authorization = String(req?.headers?.authorization || '');
    const match = authorization.match(BEARER_RE);
    if (!match || match[1].length === 0 || match[1].length > MAX_ACCESS_TOKEN_CHARS) {
      return { authenticated: false };
    }

    const response = await fetchImpl(baseUrl + '/auth/v1/user', {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'apikey': publishableKey,
        'Authorization': 'Bearer ' + match[1]
      }
    });

    if (response.status === 401 || response.status === 403) {
      return { authenticated: false };
    }
    if (!response.ok) {
      throw new Error('SUPABASE_AUTH_ERROR_' + response.status);
    }

    const user = await parseJsonResponse(response);
    const userId = String(user?.id || '');
    if (!UUID_RE.test(userId)) {
      throw new Error('SUPABASE_AUTH_IDENTITY_INVALID');
    }

    return {
      authenticated: true,
      publisher_id: userId.toLowerCase()
    };
  };
}

export function createSupabasePublicationRepository({
  url,
  secretKey,
  fetchImpl = globalThis.fetch
} = {}) {
  const baseUrl = normalizeUrl(url);
  if (!baseUrl || !hasSafeKey(secretKey) || typeof fetchImpl !== 'function') {
    return null;
  }
  const adminRequest = createAdminRequest({ baseUrl, secretKey, fetchImpl });

  async function getLatest(publisherId, packageId) {
    const params = new URLSearchParams();
    params.set('select', 'manifest');
    params.set('publisher_id', 'eq.' + String(publisherId));
    params.set('package_id', 'eq.' + String(packageId));
    params.set('limit', '1');

    const rows = await adminRequest('/rest/v1/cf_sharing_publications?' + params.toString());
    if (!Array.isArray(rows)) throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    if (rows.length === 0) return null;
    if (!rows[0]?.manifest || typeof rows[0].manifest !== 'object') {
      throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    }
    return { manifest: clone(rows[0].manifest) };
  }

  async function commitRevision({
    expected_latest_revision: expectedLatestRevision,
    manifest,
    package_json: packageJson
  } = {}) {
    const result = await adminRequest('/rest/v1/rpc/cf_sharing_commit_revision', {
      method: 'POST',
      body: {
        p_expected_latest_revision: expectedLatestRevision,
        p_manifest: manifest,
        p_package_json: packageJson
      }
    });
    if (!result || typeof result !== 'object' || Array.isArray(result) || typeof result.accepted !== 'boolean') {
      throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    }
    return clone(result);
  }

  async function getPublication(publicationId) {
    const params = new URLSearchParams();
    params.set('select', 'manifest');
    params.set('publication_id', 'eq.' + String(publicationId));
    params.set('limit', '1');

    const rows = await adminRequest('/rest/v1/cf_sharing_publications?' + params.toString());
    if (!Array.isArray(rows)) throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    if (rows.length === 0) return null;
    if (!rows[0]?.manifest || typeof rows[0].manifest !== 'object') {
      throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    }
    return { manifest: clone(rows[0].manifest) };
  }

  async function getRevision(publicationId, revision) {
    const params = new URLSearchParams();
    params.set('select', 'manifest,package_json');
    params.set('publication_id', 'eq.' + String(publicationId));
    params.set('revision', 'eq.' + String(revision));
    params.set('limit', '1');

    const rows = await adminRequest('/rest/v1/cf_sharing_publication_revisions?' + params.toString());
    if (!Array.isArray(rows)) throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    if (rows.length === 0) return null;
    if (!rows[0]?.manifest || typeof rows[0].package_json !== 'string') {
      throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    }
    return {
      manifest: clone(rows[0].manifest),
      package_json: rows[0].package_json
    };
  }

  async function listRevisions(publicationId) {
    const params = new URLSearchParams();
    params.set('select', 'revision');
    params.set('publication_id', 'eq.' + String(publicationId));
    params.set('order', 'revision.asc');

    const rows = await adminRequest('/rest/v1/cf_sharing_publication_revisions?' + params.toString());
    if (!Array.isArray(rows)) throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    const revisions = rows.map(row => Number(row?.revision));
    if (revisions.some(value => !Number.isSafeInteger(value) || value < 1)) {
      throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    }
    return revisions;
  }

  async function listPublications({ query = '', tags = [], limit = 20, offset = 0 } = {}) {
    const result = await adminRequest('/rest/v1/rpc/cf_sharing_list_publications', {
      method: 'POST',
      body: {
        p_query: String(query || ''),
        p_tags: Array.isArray(tags) ? tags.map(tag => String(tag)) : [],
        p_limit: Number(limit),
        p_offset: Number(offset)
      }
    });
    if (
      !result ||
      typeof result !== 'object' ||
      Array.isArray(result) ||
      !Array.isArray(result.items) ||
      typeof result.has_more !== 'boolean'
    ) {
      throw new Error('SUPABASE_REPOSITORY_RESULT_INVALID');
    }
    return {
      items: clone(result.items),
      has_more: result.has_more
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

export function createSupabaseSharingAdapters({
  env = process.env,
  fetchImpl = globalThis.fetch
} = {}) {
  const config = readSupabaseSharingConfig(env);
  if (!config.configured) {
    return Object.freeze({
      configured: false,
      invalid: config.invalid,
      durable: false,
      repository: null,
      resolvePublisher: null
    });
  }

  const repository = createSupabasePublicationRepository({
    url: config.url,
    secretKey: config.secret_key,
    fetchImpl
  });
  const resolvePublisher = createSupabasePublisherResolver({
    url: config.url,
    publishableKey: config.publishable_key,
    fetchImpl
  });

  if (!repository || !resolvePublisher) {
    return Object.freeze({
      configured: false,
      invalid: true,
      durable: false,
      repository: null,
      resolvePublisher: null
    });
  }

  return Object.freeze({
    configured: true,
    invalid: false,
    durable: true,
    repository,
    resolvePublisher
  });
}
