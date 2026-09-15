import assert from 'node:assert/strict';
import sharp from 'sharp';
import { createVfxResponse } from '../backend/vfx_service.mjs';

const ref = await sharp({
  create: { width: 20, height: 18, channels: 4, background: { r: 1, g: 2, b: 3, alpha: 1 } }
}).png().toBuffer();
const out = await sharp({
  create: { width: 64, height: 64, channels: 4, background: { r: 9, g: 8, b: 7, alpha: 1 } }
}).png().toBuffer();

let seenReference = null;
const provider = {
  generate: async (_prompt, options) => {
    seenReference = options.referencePng;
    return out;
  }
};

const serviceResult = await createVfxResponse({
  request_id: 'ref_001',
  prompt: 'use this reference',
  frame_count: 4,
  frame_width: 32,
  frame_height: 24,
  fps: 12,
  reference_png_base64: ref.toString('base64'),
  reference_mime_type: 'image/png',
  reference_width: 20,
  reference_height: 18
}, { provider });
assert.equal(serviceResult.ok, true);
assert.deepEqual(seenReference, ref);

const badDims = await createVfxResponse({
  request_id: 'ref_002',
  prompt: 'bad dimensions',
  frame_count: 4,
  frame_width: 32,
  frame_height: 24,
  fps: 12,
  reference_png_base64: ref.toString('base64'),
  reference_mime_type: 'image/png',
  reference_width: 99,
  reference_height: 18
}, { provider });
assert.equal(badDims.ok, false);
assert.match(badDims.error, /dimensions/);

console.log('REFERENCE_IMAGE_BACKEND_TESTS_PASSED');
