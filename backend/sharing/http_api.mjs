import { DEFAULT_MAX_PACKAGE_BYTES } from './publication_service.mjs';

export const SHARING_API_PREFIX = '/v1/sharing/publications';
export const DEFAULT_MAX_PUBLICATION_REQUEST_BYTES = DEFAULT_MAX_PACKAGE_BYTES;

const WRITE_UNAVAILABLE_CODES = new Set([
  'PACKAGE_VALIDATOR_UNAVAILABLE',
  'REPOSITORY_UNAVAILABLE',
  'REPOSITORY_ERROR'
]);

const CONFLICT_CODES = new Set([
  'PACKAGE_VERSION_ROLLBACK',
  'PACKAGE_VERSION_REUSE',
  'REVISION_CONFLICT',
  'REVISION_ALREADY_EXISTS'
]);

const SIZE_CODES = new Set([
  'PACKAGE_SIZE_LIMIT',
  'REQUEST_BODY_TOO_LARGE'
]);

const NOT_FOUND_CODES = new Set([
  'PUBLICATION_NOT_FOUND',
  'REVISION_NOT_FOUND'
]);

class RequestBodyError extends Error {
  constructor(code, status) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

function failure(status, code) {
  return {
    handled: true,
    status,
    body: { ok: false, code }
  };
}

function mapServiceFailure(result) {
  const code = String(result?.code || 'SHARING_REQUEST_FAILED');
  if (SIZE_CODES.has(code)) return failure(413, code);
  if (CONFLICT_CODES.has(code)) return failure(409, code);
  if (NOT_FOUND_CODES.has(code)) return failure(404, code);
  if (WRITE_UNAVAILABLE_CODES.has(code) || code === 'REPOSITORY_RESULT_INVALID') return failure(503, code);
  return failure(400, code);
}

async function readJsonBody(req, maxBytes) {
  if (!Number.isSafeInteger(maxBytes) || maxBytes < 1) {
    throw new RequestBodyError('PUBLICATION_BODY_LIMIT_INVALID', 503);
  }

  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) throw new RequestBodyError('REQUEST_BODY_TOO_LARGE', 413);
    chunks.push(chunk);
  }

  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
  } catch {
    throw new RequestBodyError('REQUEST_JSON_INVALID', 400);
  }
}

function parseBrowseQuery(searchParams) {
  const allowed = new Set(['q', 'tag', 'limit', 'cursor']);
  for (const key of searchParams.keys()) {
    if (!allowed.has(key)) return { ok: false, code: 'CATALOG_QUERY_FIELDS_INVALID' };
  }

  if (searchParams.getAll('q').length > 1 || searchParams.getAll('limit').length > 1 || searchParams.getAll('cursor').length > 1) {
    return { ok: false, code: 'CATALOG_QUERY_INVALID' };
  }

  const rawLimit = searchParams.get('limit');
  let limit;
  if (rawLimit !== null) {
    if (!/^\d+$/.test(rawLimit)) return { ok: false, code: 'CATALOG_LIMIT_INVALID' };
    limit = Number(rawLimit);
  }

  return {
    ok: true,
    query: searchParams.get('q') ?? '',
    tags: searchParams.getAll('tag'),
    limit,
    cursor: searchParams.get('cursor') ?? ''
  };
}

function parseRoute(pathname) {
  if (pathname === SHARING_API_PREFIX) return { kind: 'collection' };

  const detail = pathname.match(/^\/v1\/sharing\/publications\/(pub_[a-f0-9]{32})$/);
  if (detail) return { kind: 'publication', publication_id: detail[1] };

  const revision = pathname.match(/^\/v1\/sharing\/publications\/(pub_[a-f0-9]{32})\/revisions\/(\d+)$/);
  if (revision) {
    return {
      kind: 'revision',
      publication_id: revision[1],
      revision: Number(revision[2])
    };
  }

  const download = pathname.match(/^\/v1\/sharing\/publications\/(pub_[a-f0-9]{32})\/revisions\/(\d+)\/package$/);
  if (download) {
    return {
      kind: 'download',
      publication_id: download[1],
      revision: Number(download[2])
    };
  }

  if (pathname.startsWith(SHARING_API_PREFIX + '/')) return { kind: 'invalid_sharing_path' };
  return null;
}

function validatePublishBody(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { ok: false, code: 'PUBLISH_REQUEST_INVALID' };
  }
  const allowed = new Set(['metadata', 'package_json']);
  if (Object.keys(body).some(key => !allowed.has(key))) {
    return { ok: false, code: 'PUBLISH_REQUEST_FIELDS_INVALID' };
  }
  if (!body.metadata || typeof body.metadata !== 'object' || Array.isArray(body.metadata)) {
    return { ok: false, code: 'PUBLISH_REQUEST_INVALID' };
  }
  if (typeof body.package_json !== 'string') {
    return { ok: false, code: 'PUBLISH_REQUEST_INVALID' };
  }
  return { ok: true };
}

export function createSharingHttpApi({
  publicationService,
  catalogService,
  resolvePublisher,
  repositoryDurable = false,
  maxPublicationRequestBytes = DEFAULT_MAX_PUBLICATION_REQUEST_BYTES
} = {}) {
  async function handle(req) {
    const url = new URL(req.url || '/', 'http://localhost');
    const route = parseRoute(url.pathname);
    if (!route) return { handled: false };
    if (route.kind === 'invalid_sharing_path') return failure(404, 'NOT_FOUND');

    if (route.kind === 'collection' && req.method === 'POST') {
      if (repositoryDurable !== true) return failure(503, 'DURABLE_REPOSITORY_UNAVAILABLE');
      if (typeof resolvePublisher !== 'function') return failure(503, 'PUBLISHER_AUTH_UNAVAILABLE');
      if (!publicationService || typeof publicationService.publish !== 'function') {
        return failure(503, 'SHARING_SERVICE_UNAVAILABLE');
      }

      let publisher;
      try {
        publisher = await resolvePublisher(req);
      } catch {
        return failure(503, 'PUBLISHER_AUTH_ERROR');
      }
      if (!publisher || publisher.authenticated !== true || typeof publisher.publisher_id !== 'string') {
        return failure(401, 'PUBLISHER_UNAUTHENTICATED');
      }

      let body;
      try {
        body = await readJsonBody(req, maxPublicationRequestBytes);
      } catch (error) {
        if (error instanceof RequestBodyError) return failure(error.status, error.code);
        return failure(500, 'SHARING_REQUEST_ERROR');
      }

      const bodyResult = validatePublishBody(body);
      if (!bodyResult.ok) return failure(400, bodyResult.code);

      const result = await publicationService.publish({
        publisher_id: publisher.publisher_id,
        metadata: body.metadata,
        package_json: body.package_json
      });
      if (!result?.accepted) return mapServiceFailure(result);

      return {
        handled: true,
        status: result.idempotent ? 200 : 201,
        body: {
          ok: true,
          idempotent: Boolean(result.idempotent),
          manifest: result.manifest
        }
      };
    }

    if (route.kind === 'collection' && req.method === 'GET') {
      if (!catalogService || typeof catalogService.browse !== 'function') {
        return failure(503, 'CATALOG_SERVICE_UNAVAILABLE');
      }
      const parsed = parseBrowseQuery(url.searchParams);
      if (!parsed.ok) return failure(400, parsed.code);

      const result = await catalogService.browse({
        query: parsed.query,
        tags: parsed.tags,
        limit: parsed.limit,
        cursor: parsed.cursor
      });
      if (!result?.ok) return mapServiceFailure(result);
      return {
        handled: true,
        status: 200,
        body: {
          ok: true,
          items: result.items,
          next_cursor: result.next_cursor
        }
      };
    }

    if (route.kind === 'publication' && req.method === 'GET') {
      if (!catalogService || typeof catalogService.getPublication !== 'function') {
        return failure(503, 'CATALOG_SERVICE_UNAVAILABLE');
      }
      const result = await catalogService.getPublication(route.publication_id);
      if (!result?.ok) return mapServiceFailure(result);
      return {
        handled: true,
        status: 200,
        body: {
          ok: true,
          manifest: result.manifest,
          revisions: result.revisions
        }
      };
    }

    if (route.kind === 'revision' && req.method === 'GET') {
      if (!catalogService || typeof catalogService.getRevision !== 'function') {
        return failure(503, 'CATALOG_SERVICE_UNAVAILABLE');
      }
      const result = await catalogService.getRevision(route.publication_id, route.revision);
      if (!result?.ok) return mapServiceFailure(result);
      return {
        handled: true,
        status: 200,
        body: {
          ok: true,
          manifest: result.manifest
        }
      };
    }

    if (route.kind === 'download' && req.method === 'GET') {
      if (!catalogService || typeof catalogService.downloadRevision !== 'function') {
        return failure(503, 'CATALOG_SERVICE_UNAVAILABLE');
      }
      const result = await catalogService.downloadRevision(route.publication_id, route.revision);
      if (!result?.ok) return mapServiceFailure(result);

      const packageId = String(result.manifest.package_id || 'package');
      return {
        handled: true,
        status: 200,
        raw_json: result.package_json,
        headers: {
          'Content-Disposition': `attachment; filename="${packageId}-r${route.revision}.custom-fighter.json"`,
          'ETag': `"sha256-${result.manifest.content_sha256}"`,
          'X-Custom-Fighter-Content-Sha256': String(result.manifest.content_sha256 || '')
        }
      };
    }

    return failure(405, 'METHOD_NOT_ALLOWED');
  }

  return Object.freeze({ handle });
}
