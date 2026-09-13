import assert from 'node:assert/strict';
import { createServer } from '../backend/server.mjs';

const service = async request => ({
  ok: true,
  request_id: request.request_id,
  frame_count: request.frame_count,
  fps: request.fps,
  png_base64: 'dGVzdA=='
});

const server = createServer({ service });
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const { port } = server.address();
const base = `http://127.0.0.1:${port}`;

try {
  const health = await fetch(`${base}/healthz`);
  assert.equal(health.status, 200);
  assert.equal((await health.json()).ok, true);

  const blocked = await fetch(`${base}/v1/vfx/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Origin': 'https://evil.example' },
    body: '{}'
  });
  assert.equal(blocked.status, 403);

  const allowedOrigin = 'https://ws951125.github.io';
  const generated = await fetch(`${base}/v1/vfx/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Origin': allowedOrigin },
    body: JSON.stringify({ request_id: 'req_http_001', frame_count: 4, fps: 12 })
  });
  assert.equal(generated.status, 200);
  assert.equal(generated.headers.get('access-control-allow-origin'), allowedOrigin);
  const body = await generated.json();
  assert.equal(body.request_id, 'req_http_001');

  const missing = await fetch(`${base}/missing`);
  assert.equal(missing.status, 404);
  console.log('BACKEND_SERVER_TESTS_PASSED');
} finally {
  await new Promise(resolve => server.close(resolve));
}
