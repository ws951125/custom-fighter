import assert from 'node:assert/strict';

const baseUrl = String(process.env.CUSTOM_FIGHTER_AI_BACKEND_URL || 'https://custom-fighter-ai-vfx.onrender.com').replace(/\/$/, '');
const expectedRevision = String(process.env.EXPECTED_BACKEND_REVISION || '').trim();
const origin = 'https://ws951125.github.io';
const attempts = Number(process.env.BACKEND_READINESS_ATTEMPTS || 18);
const delayMs = Number(process.env.BACKEND_READINESS_DELAY_MS || 5_000);

async function fetchReadiness() {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetch(`${baseUrl}/healthz`, { headers: { Origin: origin } });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const body = await response.json();
      if (expectedRevision && body.revision !== expectedRevision) {
        throw new Error(`revision mismatch: expected ${expectedRevision}, got ${body.revision || '(empty)'}`);
      }
      return { response, body };
    } catch (error) {
      lastError = error;
      console.log(`PRODUCTION_AI_BACKEND_READINESS_RETRY attempt=${attempt}/${attempts} reason=${error?.message || error}`);
      if (attempt < attempts) await new Promise(resolve => setTimeout(resolve, delayMs));
    }
  }
  throw new Error(`Production backend readiness failed after ${attempts} attempts: ${lastError?.message || lastError}`);
}

const { response, body } = await fetchReadiness();
assert.equal(response.status, 200);
assert.equal(response.headers.get('access-control-allow-origin'), origin);
assert.equal(response.headers.get('cache-control'), 'no-store');
assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
assert.equal(body.ok, true);
assert.equal(body.service, 'custom-fighter-ai-vfx');
assert.equal(typeof body.revision, 'string');
assert.ok(body.ai && typeof body.ai === 'object');
assert.deepEqual(body.ai.supported_providers, ['gemini']);
assert.equal(body.ai.provider, 'gemini');
assert.equal(body.ai.billing_mode, 'free-tier-only');
assert.equal(body.ai.providers?.gemini?.free_tier_policy_asserted, true);
assert.equal(body.ai.providers?.gemini?.free_tier_project_verified, true);
assert.equal(body.ai.providers?.gemini?.verification_mode, 'operator-asserted');
assert.ok(body.ai.providers && typeof body.ai.providers === 'object');
assert.deepEqual(Object.keys(body.ai.providers), ['gemini']);
assert.equal(typeof body.ai.providers.gemini?.configured, 'boolean');
assert.equal(typeof body.ai.providers.gemini?.model, 'string');
assert.ok(body.ai.providers.gemini.model.length > 0);
assert.equal(body.ai.providers.gemini.billing_mode, 'free-tier-only');
assert.equal(body.ai.configured, body.ai.providers.gemini.configured);
assert.equal(body.ai.model, body.ai.providers.gemini.model);

console.log(
  `PRODUCTION_AI_BACKEND_READINESS_PASSED provider=gemini configured=${body.ai.configured} model=${body.ai.model} billing_mode=${body.ai.billing_mode} revision=${body.revision || '(empty)'}`,
);
