import assert from 'node:assert/strict';

const baseUrl = String(process.env.CUSTOM_FIGHTER_AI_BACKEND_URL || 'https://custom-fighter-ai-vfx.onrender.com').replace(/\/$/, '');
const origin = 'https://ws951125.github.io';
const allowBillable = String(process.env.ALLOW_BILLABLE_AI_E2E || '') === '1';

if (!allowBillable) {
  console.log('PRODUCTION_AI_GENERATION_E2E_BLOCKED reason=explicit_billable_approval_required set_ALLOW_BILLABLE_AI_E2E=1');
  process.exit(0);
}

const healthResponse = await fetch(`${baseUrl}/healthz`, { headers: { Origin: origin } });
assert.equal(healthResponse.status, 200);
const health = await healthResponse.json();
assert.equal(health.ok, true);
assert.ok(health.ai && typeof health.ai === 'object');
assert.equal(typeof health.ai.provider, 'string');
assert.equal(typeof health.ai.configured, 'boolean');

if (!health.ai.configured) {
  throw new Error(`Selected production provider '${health.ai.provider}' is not configured; configure its server-side credential before running billable E2E.`);
}

const requestId = `prod_e2e_${Date.now()}`;
const request = {
  request_id: requestId,
  prompt: 'A single compact electric-blue energy orb projectile on a transparent background, game VFX sprite, centered, no text.',
  frame_count: 1,
  frame_width: 32,
  frame_height: 32,
  fps: 8
};

const response = await fetch(`${baseUrl}/v1/vfx/generate`, {
  method: 'POST',
  headers: {
    Origin: origin,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(request)
});

const body = await response.json();
if (!response.ok) {
  throw new Error(`Production generation failed HTTP ${response.status}: ${body?.error || JSON.stringify(body)}`);
}

assert.equal(body.ok, true);
assert.equal(body.request_id, requestId);
assert.equal(body.frame_count, 1);
assert.equal(body.fps, 8);
assert.equal(typeof body.png_base64, 'string');
assert.ok(body.png_base64.length > 0);

const png = Buffer.from(body.png_base64, 'base64');
assert.ok(png.length > 8);
assert.deepEqual([...png.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);

assert.ok(body.skill_proposal && typeof body.skill_proposal === 'object');
assert.equal(body.skill_proposal.source_request_id, requestId);
assert.equal(body.skill_proposal.skill_type, 'projectile');
assert.ok(Number(body.skill_proposal.damage) > 0);
assert.ok(Number(body.skill_proposal.mp_cost) >= 0);

console.log(
  `PRODUCTION_AI_GENERATION_E2E_PASSED provider=${health.ai.provider} model=${health.ai.model} request_id=${requestId} png_bytes=${png.length} skill_type=${body.skill_proposal.skill_type}`,
);
