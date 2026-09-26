const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MAX_BEARER_TOKEN_CHARS = 8192;

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

function validPublishableKey(value) {
  return typeof value === 'string' && /^sb_publishable_[A-Za-z0-9_-]{16,}$/.test(value.trim());
}

function bearerToken(req) {
  const value = String(req?.headers?.authorization || '');
  const match = value.match(/^Bearer ([^\s]+)$/i);
  if (!match) return '';
  const token = match[1];
  if (token.length < 16 || token.length > MAX_BEARER_TOKEN_CHARS) return '';
  return token;
}

export function createSupabasePublisherResolver({
  projectUrl,
  publishableKey,
  fetchImpl = globalThis.fetch
} = {}) {
  const baseUrl = normalizeProjectUrl(projectUrl);
  const publicKey = typeof publishableKey === 'string' ? publishableKey.trim() : '';
  if (!baseUrl || !validPublishableKey(publicKey) || typeof fetchImpl !== 'function') {
    return null;
  }

  return async function resolvePublisher(req) {
    const token = bearerToken(req);
    if (!token) return { authenticated: false };

    const response = await fetchImpl(`${baseUrl}/auth/v1/user`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'apikey': publicKey,
        'Authorization': `Bearer ${token}`
      }
    });

    if (response.status === 401 || response.status === 403) {
      return { authenticated: false };
    }
    if (!response.ok) {
      throw new Error('SUPABASE_AUTH_UNAVAILABLE');
    }

    let user;
    try {
      user = await response.json();
    } catch {
      throw new Error('SUPABASE_AUTH_RESULT_INVALID');
    }

    const userId = String(user?.id || '').toLowerCase();
    if (!UUID_RE.test(userId)) {
      throw new Error('SUPABASE_AUTH_RESULT_INVALID');
    }
    if (user?.is_anonymous === true) {
      return { authenticated: false };
    }

    return {
      authenticated: true,
      publisher_id: userId
    };
  };
}

export const _test = Object.freeze({
  normalizeProjectUrl,
  validPublishableKey,
  bearerToken,
  UUID_RE,
  MAX_BEARER_TOKEN_CHARS
});
