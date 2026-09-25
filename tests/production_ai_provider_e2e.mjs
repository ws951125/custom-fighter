import assert from 'node:assert/strict';
import sharp from 'sharp';

const baseUrl = String(process.env.CUSTOM_FIGHTER_AI_BACKEND_URL || 'https://custom-fighter-ai-vfx-6899.onrender.com').replace(/\/$/, '');
const expectedProvider = String(process.env.EXPECTED_AI_PROVIDER || '').trim().toLowerCase();
const expectedRevision = String(process.env.EXPECTED_BACKEND_REVISION || '').trim();
const origin = 'https://ws951125.github.io';

async function readJson(response, label) {
  const text = await response.text();
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`${label} returned non-JSON HTTP ${response.status}: ${text.slice(0, 240)}`);
  }
}

async function assertGeneratedStrip(body, request) {
  assert.equal(body.ok, true, body.error || 'generation response was not ok');
  assert.equal(body.request_id, request.request_id);
  assert.equal(body.frame_count, request.frame_count);
  assert.equal(body.fps, request.fps);
  assert.equal(typeof body.png_base64, 'string');
  assert.ok(body.png_base64.length > 0);

  const png = Buffer.from(body.png_base64, 'base64');
  const metadata = await sharp(png).metadata();
  assert.equal(metadata.format, 'png');
  assert.equal(metadata.width, request.frame_width * request.frame_count);
  assert.equal(metadata.height, request.frame_height);

  assert.ok(body.skill_proposal && typeof body.skill_proposal === 'object');
  assert.equal(body.skill_proposal.source_request_id, request.request_id);
  assert.equal(typeof body.skill_proposal.skill_id, 'string');
  assert.ok(body.skill_proposal.skill_id.length > 0);
  assert.equal(typeof body.skill_proposal.damage, 'number');
  assert.equal(typeof body.skill_proposal.mp_cost, 'number');
  assert.equal(typeof body.skill_proposal.cooldown, 'number');
}

async function generate(request, label) {
  const response = await fetch(`${baseUrl}/v1/vfx/generate`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      Origin: origin,
    },
    body: JSON.stringify(request),
  });
  const body = await readJson(response, label);
  if (!response.ok) throw new Error(`${label} failed HTTP ${response.status}: ${body.error || JSON.stringify(body)}`);
  assert.equal(response.headers.get('access-control-allow-origin'), origin);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
  await assertGeneratedStrip(body, request);
  console.log(`${label}_PASSED request=${request.request_id} frames=${body.frame_count}`);
}

const healthResponse = await fetch(`${baseUrl}/healthz`, { headers: { Origin: origin } });
assert.equal(healthResponse.status, 200);
const health = await readJson(healthResponse, 'healthz');
assert.equal(health.ok, true);
assert.ok(health.ai && typeof health.ai === 'object');
if (expectedRevision) assert.equal(health.revision, expectedRevision, `Render revision mismatch: expected ${expectedRevision}, got ${health.revision || '(empty)'}`);
assert.equal(health.ai.configured, true, `Selected production provider '${health.ai.provider}' is not configured`);
assert.deepEqual(health.ai.supported_providers, ['gemini']);
assert.equal(health.ai.provider, 'gemini');
assert.equal(health.ai.billing_mode, 'free-tier-only');
assert.equal(health.ai.providers?.gemini?.free_tier_policy_asserted, true);
assert.equal(health.ai.providers?.gemini?.free_tier_project_verified, true);
assert.equal(health.ai.providers?.gemini?.verification_mode, 'operator-asserted');
if (expectedProvider) assert.equal(health.ai.provider, expectedProvider);
console.log(`PRODUCTION_AI_PROVIDER_READY provider=${health.ai.provider} model=${health.ai.model} billing_mode=${health.ai.billing_mode} revision=${health.revision || '(empty)'}`);

const textRequest = {
  request_id: `prod_text_${Date.now()}`,
  prompt: 'A clean stylized blue energy projectile VFX on a transparent-looking dark-neutral background, centered, no text',
  frame_count: 4,
  frame_width: 64,
  frame_height: 64,
  fps: 12,
};
await generate(textRequest, 'PRODUCTION_AI_TEXT_GENERATION');

const reference = await sharp({
  create: {
    width: 64,
    height: 64,
    channels: 4,
    background: { r: 24, g: 96, b: 220, alpha: 1 },
  },
})
  .composite([
    {
      input: Buffer.from('<svg width="64" height="64"><circle cx="32" cy="32" r="20" fill="#ffffff"/><circle cx="32" cy="32" r="10" fill="#55aaff"/></svg>'),
      top: 0,
      left: 0,
    },
  ])
  .png()
  .toBuffer();

const referenceRequest = {
  request_id: `prod_ref_${Date.now()}`,
  prompt: 'Transform the reference orb into a polished animated projectile VFX while preserving the blue circular energy identity, no text',
  frame_count: 4,
  frame_width: 64,
  frame_height: 64,
  fps: 12,
  reference_png_base64: reference.toString('base64'),
  reference_mime_type: 'image/png',
  reference_width: 64,
  reference_height: 64,
};
await generate(referenceRequest, 'PRODUCTION_AI_REFERENCE_GENERATION');

console.log(`PRODUCTION_AI_PROVIDER_E2E_PASSED provider=${health.ai.provider} model=${health.ai.model} revision=${health.revision || '(empty)'}`);
