import assert from 'node:assert/strict';

const baseUrl = String(process.env.CUSTOM_FIGHTER_AI_BACKEND_URL || 'https://custom-fighter-ai-vfx.onrender.com').replace(/\/$/, '');
const expectedRevision = String(process.env.EXPECTED_BACKEND_REVISION || '').trim();
const origin = 'https://ws951125.github.io';

async function fetchWithRetry(url, options = {}, attempts = 12, delayMs = 5_000) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetch(url, options);
      if (response.ok) return response;
      lastError = new Error(`HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    if (attempt < attempts) await new Promise(resolve => setTimeout(resolve, delayMs));
  }
  throw new Error(`Production backend readiness request failed after ${attempts} attempts: ${lastError?.message || lastError}`);
}

const response = await fetchWithRetry(`${baseUrl}/healthz`, {
  headers: { Origin: origin }
});

assert.equal(response.status, 200);
assert.equal(response.headers.get('access-control-allow-origin'), origin);
assert.equal(response.headers.get('cache-control'), 'no-store');
assert.equal(response.headers.get('x-content-type-options'), 'nosniff');

const body = await response.json();
assert.equal(body.ok, true);
assert.equal(body.service, 'custom-fighter-ai-vfx');
assert.equal(typeof body.revision, 'string');
assert.ok(body.ai && typeof body.ai === 'object');
assert.ok(Array.isArray(body.ai.supported_providers));
assert.ok(body.ai.supported_providers.includes('openai'));
assert.ok(body.ai.supported_providers.includes('gemini'));
assert.ok(body.ai.providers && typeof body.ai.providers === 'object');

for (const provider of ['openai', 'gemini']) {
  assert.equal(typeof body.ai.providers[provider]?.configured, 'boolean');
  assert.equal(typeof body.ai.providers[provider]?.model, 'string');
  assert.ok(body.ai.providers[provider].model.length > 0);
}

assert.ok(body.ai.supported_providers.includes(body.ai.provider));
assert.equal(typeof body.ai.configured, 'boolean');
assert.equal(body.ai.configured, body.ai.providers[body.ai.provider].configured);
assert.equal(body.ai.model, body.ai.providers[body.ai.provider].model);

if (expectedRevision) {
  assert.equal(
    body.revision,
    expectedRevision,
    `Render backend revision mismatch: expected ${expectedRevision}, got ${body.revision || '(empty)'}`,
  );
}

console.log(
  `PRODUCTION_AI_BACKEND_READINESS_PASSED provider=${body.ai.provider} configured=${body.ai.configured} model=${body.ai.model} revision=${body.revision || '(empty)'}`,
);
