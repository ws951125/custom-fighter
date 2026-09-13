import http from 'node:http';
import { createVfxResponse } from './vfx_service.mjs';

const PORT = Number(process.env.PORT || 8787);
const ALLOWED_ORIGIN = process.env.CUSTOM_FIGHTER_ALLOWED_ORIGIN || 'https://ws951125.github.io';
const MAX_BODY_BYTES = 8 * 1024 * 1024;

function sendJson(res, status, body, origin = '') {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  if (origin && origin === ALLOWED_ORIGIN) {
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

function providerReadiness() {
  return {
    configured: Boolean(String(process.env.OPENAI_API_KEY || '').trim()),
    provider: 'openai',
    model: process.env.OPENAI_IMAGE_MODEL || 'gpt-image-2'
  };
}

export function createServer({ service = createVfxResponse } = {}) {
  return http.createServer(async (req, res) => {
    const origin = String(req.headers.origin || '');
    if (origin && origin !== ALLOWED_ORIGIN) {
      sendJson(res, 403, { ok: false, error: 'origin is not allowed' });
      return;
    }
    if (req.method === 'OPTIONS') {
      if (origin === ALLOWED_ORIGIN) {
        res.statusCode = 204;
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
        res.setHeader('Vary', 'Origin');
        res.end();
      } else {
        sendJson(res, 403, { ok: false, error: 'origin is not allowed' });
      }
      return;
    }
    if (req.method === 'GET' && req.url === '/healthz') {
      sendJson(res, 200, { ok: true, service: 'custom-fighter-ai-vfx', ai: providerReadiness() }, origin);
      return;
    }
    if (req.method !== 'POST' || req.url !== '/v1/vfx/generate') {
      sendJson(res, 404, { ok: false, error: 'not found' }, origin);
      return;
    }
    try {
      const request = await readJson(req);
      const result = await service(request);
      sendJson(res, result.ok ? 200 : 400, result, origin);
    } catch (error) {
      const message = error instanceof SyntaxError ? 'request body must be valid JSON' : String(error?.message || 'backend error');
      sendJson(res, 500, { ok: false, error: message }, origin);
    }
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  createServer().listen(PORT, '0.0.0.0', () => {
    console.log(`CUSTOM_FIGHTER_AI_VFX_BACKEND_READY port=${PORT}`);
  });
}
