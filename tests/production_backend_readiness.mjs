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

const openAi = body.ai.providers.openai;
const gemini = body.ai.providers.gemini;
console.log(
  `PRODUCTION_AI_BACKEND_READINESS_PASSED provider=${body.ai.provider} configured=${body.ai.configured} model=${body.ai.model} openai_configured=${openAi.configured} openai_model=${openAi.model} gemini_configured=${gemini.configured} gemini_model=${gemini.model} revision=${body.revision || '(empty)'}`,
);
