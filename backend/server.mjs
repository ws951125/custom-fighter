import http from 'node:http';
import { pathToFileURL } from 'node:url';
import { createVfxResponse } from './vfx_service.mjs';
import { imageProviderReadiness } from './image_provider_factory.mjs';
import { createServerPackageAuthorityStore } from './pvp/package_authority.mjs';
import { createPvpSessionService } from './pvp/session_service.mjs';
import { createAuthoritativeMatch } from './pvp/authoritative_match.mjs';
import { attachPvpWebSocketTransport } from './pvp/websocket_transport.mjs';
import { PVP_PROTOCOL_VERSION } from './pvp/protocol.mjs';
import { resolveTrustedCompetitivePackage } from './pvp/trusted_package_catalog.mjs';
import { createPublicationService } from './sharing/publication_service.mjs';
import { createCatalogService } from './sharing/catalog_service.mjs';
import {
  createSharingHttpApi,
  DEFAULT_MAX_PUBLICATION_REQUEST_BYTES,
  SHARING_API_PREFIX
} from './sharing/http_api.mjs';
import { createSupabaseSharingIntegration } from './sharing/supabase_integration.mjs';

const PORT = Number(process.env.PORT || 8787);
const DEFAULT_ALLOWED_ORIGIN = process.env.CUSTOM_FIGHTER_ALLOWED_ORIGIN || 'https://ws951125.github.io';
const MAX_VFX_BODY_BYTES = 8 * 1024 * 1024;
const PVP_WS_PATH = '/v1/pvp/ws';
const DEFAULT_SHARING_INTEGRATION = createSupabaseSharingIntegration();

function deployedRevision() {
  return String(process.env.RENDER_GIT_COMMIT || process.env.CUSTOM_FIGHTER_REVISION || '').trim();
}

function applyCommonResponseHeaders(res, origin = '', allowedOrigin = DEFAULT_ALLOWED_ORIGIN) {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  if (origin && origin === allowedOrigin) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
}

function sendJson(res, status, body, origin = '', allowedOrigin = DEFAULT_ALLOWED_ORIGIN) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  applyCommonResponseHeaders(res, origin, allowedOrigin);
  res.end(JSON.stringify(body));
}

function sendRawJson(res, status, json, headers = {}, origin = '', allowedOrigin = DEFAULT_ALLOWED_ORIGIN) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  applyCommonResponseHeaders(res, origin, allowedOrigin);
  for (const [name, value] of Object.entries(headers)) {
    res.setHeader(name, value);
  }
  res.end(json);
}

async function readJson(req, maxBytes = MAX_VFX_BODY_BYTES) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) throw new Error('request body exceeds 8 MB limit');
    chunks.push(chunk);
  }
  const text = Buffer.concat(chunks).toString('utf8');
  return JSON.parse(text || '{}');
}

export function createServer({
  service = createVfxResponse,
  allowedOrigin = DEFAULT_ALLOWED_ORIGIN,
  pvpPackageResolver = resolveTrustedCompetitivePackage,
  pvpTickIntervalMs = 1000 / 60,
  pvpReconnectWindowMs = 10_000,
  pvpHeartbeatTimeoutMs = 15_000,
  pvpHeartbeatCheckMs = 1_000,
  sharingRepository = DEFAULT_SHARING_INTEGRATION.repository,
  sharingRepositoryDurable = DEFAULT_SHARING_INTEGRATION.repositoryDurable,
  sharingValidatePackage = null,
  sharingResolvePublisher = DEFAULT_SHARING_INTEGRATION.resolvePublisher,
  sharingProvider = DEFAULT_SHARING_INTEGRATION.provider,
  sharingProviderConfigured = DEFAULT_SHARING_INTEGRATION.configured,
  sharingProviderReason = DEFAULT_SHARING_INTEGRATION.reason,
  sharingMaxPublicationRequestBytes = DEFAULT_MAX_PUBLICATION_REQUEST_BYTES
} = {}) {
  const authorityStore = createServerPackageAuthorityStore({ packageResolver:pvpPackageResolver });
  const pvpSessionService = createPvpSessionService({ admitLoadout:authorityStore.admitLoadout });

  const publicationService = createPublicationService({
    repository: sharingRepository,
    validatePackage: sharingValidatePackage
  });
  const catalogService = createCatalogService({ repository: sharingRepository });
  const sharingApi = createSharingHttpApi({
    publicationService,
    catalogService,
    resolvePublisher: sharingResolvePublisher,
    repositoryDurable: sharingRepositoryDurable,
    maxPublicationRequestBytes: sharingMaxPublicationRequestBytes
  });

  const server = http.createServer(async (req, res) => {
    const origin = String(req.headers.origin || '');
    if (origin && origin !== allowedOrigin) {
      sendJson(res, 403, { ok: false, error: 'origin is not allowed' }, '', allowedOrigin);
      return;
    }
    if (req.method === 'OPTIONS') {
      if (origin === allowedOrigin) {
        res.statusCode = 204;
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.setHeader('Vary', 'Origin');
        res.end();
      } else {
        sendJson(res, 403, { ok: false, error: 'origin is not allowed' }, '', allowedOrigin);
      }
      return;
    }
    if (req.method === 'GET' && req.url === '/healthz') {
      sendJson(
        res,
        200,
        {
          ok: true,
          service: 'custom-fighter-ai-vfx',
          revision: deployedRevision(),
          ai: imageProviderReadiness(),
          pvp: {
            protocol_version: PVP_PROTOCOL_VERSION,
            websocket_path: PVP_WS_PATH,
            authority: 'server_authoritative',
            reconnect_window_ms: pvpReconnectWindowMs,
            heartbeat_timeout_ms: pvpHeartbeatTimeoutMs
          },
          sharing: {
            api_version: 1,
            publications_path: SHARING_API_PREFIX,
            persistence_provider: String(sharingProvider || 'none'),
            provider_configured: sharingProviderConfigured === true || Boolean(sharingRepository),
            provider_reason: String(sharingProviderReason || ''),
            repository_configured: Boolean(sharingRepository),
            durable_repository: sharingRepositoryDurable === true,
            publisher_auth_configured: typeof sharingResolvePublisher === 'function',
            package_validator_configured: typeof sharingValidatePackage === 'function',
            max_publication_request_bytes: sharingMaxPublicationRequestBytes
          }
        },
        origin,
        allowedOrigin
      );
      return;
    }

    const sharingResult = await sharingApi.handle(req);
    if (sharingResult.handled) {
      if (typeof sharingResult.raw_json === 'string') {
        sendRawJson(
          res,
          sharingResult.status,
          sharingResult.raw_json,
          sharingResult.headers || {},
          origin,
          allowedOrigin
        );
      } else {
        sendJson(res, sharingResult.status, sharingResult.body, origin, allowedOrigin);
      }
      return;
    }

    if (req.method !== 'POST' || req.url !== '/v1/vfx/generate') {
      sendJson(res, 404, { ok: false, error: 'not found' }, origin, allowedOrigin);
      return;
    }
    try {
      const request = await readJson(req);
      const result = await service(request);
      sendJson(res, result.ok ? 200 : 400, result, origin, allowedOrigin);
    } catch (error) {
      const message = error instanceof SyntaxError ? 'request body must be valid JSON' : String(error?.message || 'backend error');
      sendJson(res, 500, { ok: false, error: message }, origin, allowedOrigin);
    }
  });

  attachPvpWebSocketTransport(server, {
    sessionService:pvpSessionService,
    createMatch:createAuthoritativeMatch,
    resolveLoadout:authorityStore.resolveLoadout,
    allowedOrigin,
    path:PVP_WS_PATH,
    tickIntervalMs:pvpTickIntervalMs,
    reconnectWindowMs:pvpReconnectWindowMs,
    heartbeatTimeoutMs:pvpHeartbeatTimeoutMs,
    heartbeatCheckMs:pvpHeartbeatCheckMs
  });

  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  createServer().listen(PORT, '0.0.0.0', () => {
    console.log(`CUSTOM_FIGHTER_BACKEND_READY port=${PORT} pvp_ws=${PVP_WS_PATH}`);
  });
}
