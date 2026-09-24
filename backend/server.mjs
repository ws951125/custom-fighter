import http from 'node:http';
import { createVfxResponse } from './vfx_service.mjs';
import { imageProviderReadiness } from './image_provider_factory.mjs';
import { createServerPackageAuthorityStore } from './pvp/package_authority.mjs';
import { createPvpSessionService } from './pvp/session_service.mjs';
import { createAuthoritativeMatch } from './pvp/authoritative_match.mjs';
import { attachPvpWebSocketTransport } from './pvp/websocket_transport.mjs';
import { PVP_PROTOCOL_VERSION } from './pvp/protocol.mjs';

const PORT = Number(process.env.PORT || 8787);
const DEFAULT_ALLOWED_ORIGIN = process.env.CUSTOM_FIGHTER_ALLOWED_ORIGIN || 'https://ws951125.github.io';
const MAX_BODY_BYTES = 8 * 1024 * 1024;
const PVP_WS_PATH = '/v1/pvp/ws';

function deployedRevision() {
  return String(process.env.RENDER_GIT_COMMIT || process.env.CUSTOM_FIGHTER_REVISION || '').trim();
}

function sendJson(res, status, body, origin = '', allowedOrigin = DEFAULT_ALLOWED_ORIGIN) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  if (origin && origin === allowedOrigin) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.end(JSON.stringify(body));
}

async function readJson(req) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) throw new Error('request body exceeds 8 MB limit');
    chunks.push(chunk);
  }
  const text = Buffer.concat(chunks).toString('utf8');
  return JSON.parse(text || '{}');
}

export function createServer({
  service = createVfxResponse,
  allowedOrigin = DEFAULT_ALLOWED_ORIGIN,
  pvpPackageResolver,
  pvpTickIntervalMs = 1000 / 60
} = {}) {
  const authorityStore = createServerPackageAuthorityStore({ packageResolver:pvpPackageResolver });
  const pvpSessionService = createPvpSessionService({ admitLoadout:authorityStore.admitLoadout });

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
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
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
            authority: 'server_authoritative'
          }
        },
        origin,
        allowedOrigin
      );
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
    tickIntervalMs:pvpTickIntervalMs
  });

  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  createServer().listen(PORT, '0.0.0.0', () => {
    console.log(`CUSTOM_FIGHTER_BACKEND_READY port=${PORT} pvp_ws=${PVP_WS_PATH}`);
  });
}
