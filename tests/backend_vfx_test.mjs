import assert from 'node:assert/strict';
import sharp from 'sharp';
import { createVfxResponse, validateVfxRequest } from '../backend/vfx_service.mjs';
import { OpenAiImageProvider } from '../backend/openai_image_provider.mjs';

const validRequest = {
  request_id: 'req_backend_001',
  prompt: 'electric blue projectile',
  frame_count: 4,
  frame_width: 32,
  frame_height: 24,
  fps: 12
};

assert.equal(validateVfxRequest(validRequest), '');
assert.match(validateVfxRequest({ ...validRequest, frame_count: 0 }), /frame_count/);
assert.match(validateVfxRequest({ ...validRequest, prompt: '' }), /prompt/);

const sourcePng = await sharp({
  create: { width: 64, height: 64, channels: 4, background: { r: 40, g: 120, b: 255, alpha: 1 } }
}).png().toBuffer();
const fakeProvider = { generate: async () => sourcePng };
const response = await createVfxResponse(validRequest, { provider: fakeProvider });
assert.equal(response.ok, true);
assert.equal(response.frame_count, 4);
assert.equal(response.fps, 12);
const strip = Buffer.from(response.png_base64, 'base64');
const metadata = await sharp(strip).metadata();
assert.equal(metadata.width, 128);
assert.equal(metadata.height, 24);
assert.equal(response.skill_proposal.source_request_id, validRequest.request_id);
assert.equal(response.skill_proposal.skill_type, 'projectile');
assert.equal(response.skill_proposal.visual, 'prototype_fireball');
assert.equal(response.skill_proposal.impact_visual, 'prototype_impact');
assert.equal(response.skill_proposal.damage, 24);
assert.equal(response.skill_proposal.mp_cost, 20);
assert.match(response.skill_proposal.rationale, /review and confirm/i);

const refRejected = await createVfxResponse({ ...validRequest, reference_png_base64: 'abc' }, { provider: fakeProvider });
assert.equal(refRejected.ok, false);
assert.match(refRejected.error, /reference-image/);

let capturedRequest;
const fakeFetch = async (url, options) => {
  capturedRequest = { url, options };
  return {
    ok: true,
    status: 200,
    json: async () => ({ data: [{ b64_json: sourcePng.toString('base64') }] })
  };
};
const openAi = new OpenAiImageProvider({ apiKey: 'test-key', fetchImpl: fakeFetch });
const generated = await openAi.generate('blue arc');
assert.ok(generated.length > 0);
assert.equal(capturedRequest.url, 'https://api.openai.com/v1/images/generations');
const body = JSON.parse(capturedRequest.options.body);
assert.equal(body.model, 'gpt-image-2');
assert.equal(body.output_format, 'png');
assert.equal(body.size, '1024x1024');
assert.equal(capturedRequest.options.headers.Authorization, 'Bearer test-key');

await assert.rejects(() => new OpenAiImageProvider({ apiKey: '' }).generate('x'), /OPENAI_API_KEY/);
console.log('BACKEND_VFX_TESTS_PASSED bundledSkillProposal=true');
