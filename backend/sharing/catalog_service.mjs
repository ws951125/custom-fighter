const PUBLICATION_ID_RE = /^pub_[a-f0-9]{32}$/;
const TAG_RE = /^[a-z0-9][a-z0-9_-]{0,23}$/;
const CURSOR_RE = /^[A-Za-z0-9_-]{0,32}$/;
const CONTROL_RE = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/;

export const DEFAULT_CATALOG_PAGE_SIZE = 20;
export const MAX_CATALOG_PAGE_SIZE = 50;
export const MAX_SEARCH_QUERY_LENGTH = 80;
export const MAX_CATALOG_OFFSET = 100_000;

function reject(code, details = {}) {
  return { ok: false, code, ...details };
}

function clone(value) {
  return structuredClone(value);
}

function repositoryReady(repository) {
  return Boolean(
    repository &&
    typeof repository.listPublications === 'function' &&
    typeof repository.getPublication === 'function' &&
    typeof repository.getRevision === 'function' &&
    typeof repository.listRevisions === 'function'
  );
}

function normalizeTags(value) {
  if (value === undefined) return { ok: true, tags: [] };
  if (!Array.isArray(value) || value.length > 8) return reject('CATALOG_TAGS_INVALID');

  const tags = [];
  const seen = new Set();
  for (const raw of value) {
    if (typeof raw !== 'string') return reject('CATALOG_TAG_INVALID');
    const tag = raw.trim();
    if (!TAG_RE.test(tag)) return reject('CATALOG_TAG_INVALID', { tag });
    if (seen.has(tag)) return reject('CATALOG_TAG_DUPLICATE', { tag });
    seen.add(tag);
    tags.push(tag);
  }
  return { ok: true, tags };
}

function encodeCursor(offset) {
  return Buffer.from(`o:${offset}`, 'utf8').toString('base64url');
}

function decodeCursor(cursor) {
  if (cursor === '') return { ok: true, offset: 0 };
  if (!CURSOR_RE.test(cursor)) return reject('CATALOG_CURSOR_INVALID');

  let text = '';
  try {
    text = Buffer.from(cursor, 'base64url').toString('utf8');
  } catch {
    return reject('CATALOG_CURSOR_INVALID');
  }
  const match = text.match(/^o:(\d+)$/);
  if (!match || encodeCursor(Number(match[1])) !== cursor) return reject('CATALOG_CURSOR_INVALID');

  const offset = Number(match[1]);
  if (!Number.isSafeInteger(offset) || offset < 0 || offset > MAX_CATALOG_OFFSET) {
    return reject('CATALOG_CURSOR_INVALID');
  }
  return { ok: true, offset };
}

export function normalizeCatalogQuery(input = {}) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    return reject('CATALOG_QUERY_INVALID');
  }

  const allowed = new Set(['query', 'tags', 'limit', 'cursor']);
  if (Object.keys(input).some(key => !allowed.has(key))) {
    return reject('CATALOG_QUERY_FIELDS_INVALID');
  }

  const query = input.query === undefined ? '' : input.query;
  if (
    typeof query !== 'string' ||
    query.length > MAX_SEARCH_QUERY_LENGTH ||
    CONTROL_RE.test(query)
  ) {
    return reject('CATALOG_QUERY_INVALID');
  }

  const tagsResult = normalizeTags(input.tags);
  if (!tagsResult.ok) return tagsResult;

  const limit = input.limit === undefined ? DEFAULT_CATALOG_PAGE_SIZE : input.limit;
  if (!Number.isInteger(limit) || limit < 1 || limit > MAX_CATALOG_PAGE_SIZE) {
    return reject('CATALOG_LIMIT_INVALID');
  }

  const cursor = input.cursor === undefined ? '' : input.cursor;
  if (typeof cursor !== 'string') return reject('CATALOG_CURSOR_INVALID');
  const cursorResult = decodeCursor(cursor);
  if (!cursorResult.ok) return cursorResult;

  return {
    ok: true,
    query: query.trim().toLowerCase(),
    tags: tagsResult.tags,
    limit,
    offset: cursorResult.offset
  };
}

export function validatePublicationId(value) {
  return typeof value === 'string' && PUBLICATION_ID_RE.test(value);
}

export function validateRevision(value) {
  return Number.isSafeInteger(value) && value >= 1;
}

export function createCatalogService({ repository } = {}) {
  async function browse(input = {}) {
    const normalized = normalizeCatalogQuery(input);
    if (!normalized.ok) return normalized;
    if (!repositoryReady(repository)) return reject('REPOSITORY_UNAVAILABLE');

    try {
      const result = await repository.listPublications({
        query: normalized.query,
        tags: normalized.tags,
        limit: normalized.limit,
        offset: normalized.offset
      });
      if (!result || !Array.isArray(result.items) || typeof result.has_more !== 'boolean') {
        return reject('REPOSITORY_RESULT_INVALID');
      }
      if (result.items.length > normalized.limit) return reject('REPOSITORY_RESULT_INVALID');

      const nextOffset = normalized.offset + result.items.length;
      return {
        ok: true,
        items: clone(result.items),
        next_cursor: result.has_more ? encodeCursor(nextOffset) : null
      };
    } catch {
      return reject('REPOSITORY_ERROR');
    }
  }

  async function getPublication(publicationId) {
    if (!validatePublicationId(publicationId)) return reject('PUBLICATION_ID_INVALID');
    if (!repositoryReady(repository)) return reject('REPOSITORY_UNAVAILABLE');

    try {
      const [record, revisions] = await Promise.all([
        repository.getPublication(publicationId),
        repository.listRevisions(publicationId)
      ]);
      if (!record) return reject('PUBLICATION_NOT_FOUND');
      if (!record.manifest || !Array.isArray(revisions)) return reject('REPOSITORY_RESULT_INVALID');
      return {
        ok: true,
        manifest: clone(record.manifest),
        revisions: [...revisions]
      };
    } catch {
      return reject('REPOSITORY_ERROR');
    }
  }

  async function getRevision(publicationId, revision) {
    if (!validatePublicationId(publicationId)) return reject('PUBLICATION_ID_INVALID');
    if (!validateRevision(revision)) return reject('REVISION_INVALID');
    if (!repositoryReady(repository)) return reject('REPOSITORY_UNAVAILABLE');

    try {
      const record = await repository.getRevision(publicationId, revision);
      if (!record) return reject('REVISION_NOT_FOUND');
      if (!record.manifest) return reject('REPOSITORY_RESULT_INVALID');
      return { ok: true, manifest: clone(record.manifest) };
    } catch {
      return reject('REPOSITORY_ERROR');
    }
  }

  async function downloadRevision(publicationId, revision) {
    if (!validatePublicationId(publicationId)) return reject('PUBLICATION_ID_INVALID');
    if (!validateRevision(revision)) return reject('REVISION_INVALID');
    if (!repositoryReady(repository)) return reject('REPOSITORY_UNAVAILABLE');

    try {
      const record = await repository.getRevision(publicationId, revision);
      if (!record) return reject('REVISION_NOT_FOUND');
      if (!record.manifest || typeof record.package_json !== 'string' || record.package_json.length === 0) {
        return reject('REPOSITORY_RESULT_INVALID');
      }
      return {
        ok: true,
        manifest: clone(record.manifest),
        package_json: record.package_json
      };
    } catch {
      return reject('REPOSITORY_ERROR');
    }
  }

  return Object.freeze({
    browse,
    getPublication,
    getRevision,
    downloadRevision
  });
}

export const _test = Object.freeze({ encodeCursor, decodeCursor });
