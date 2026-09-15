import assert from 'node:assert/strict';
import sharp from 'sharp';
import { DEFAULT_FREE_GEMINI_MODEL, GeminiImageProvider } from '../backend/gemini_image_provider.mjs';

const requests = [];
const spec = {
  primary: '#33aaff',
  secondary: '#112244',
  accent: '#ffffff',
  shape: 'slash',
  glow: 0.7,
  particles: 6
};
const fetchImpl = async (url, options) => {
  requests.push({ url, options, body: JSON.parse(options.body) });
  return new Response(JSON.stringify({ output_text: JSON.stringify(spec) }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  });
};

const provider = new GeminiImageProvider({ apiKey: 'test-gemini-key', fetchImpl, freeTierOnly: true });
const generated = await provider.generate('blue energy slash');
const metadata = await sharp(generated).metadata();
assert.equal(metadata.format, 'png');
assert.equal(metadata.width, 256);
assert.equal(metadata.height, 256);
assert.equal(requests[0].url, 'https://generativelanguage.googleapis.com/v1/interactions');
assert.equal(requests[0].options.headers['x-goog-api-key'], 'test-gemini-key');
assert.equal(requests[0].body.model, DEFAULT_FREE_GEMINI_MODEL);
assert.equal(requests[0].body.store, false);
assert.ok(Array.isArray(requests[0].body.response_format));
assert.equal(requests[0].body.response_format[0].type, 'text');
assert.equal(requests[0].body.response_format[0].mime_type, 'application/json');
assert.ok(requests[0].body.response_format[0].schema);

const reference = Buffer.from('reference-png');
await provider.generate('preserve silhouette, add lightning', { referencePng: reference });
assert.equal(requests[1].body.input.length, 2);
assert.equal(requests[1].body.input[0].type, 'image');
assert.equal(requests[1].body.input[0].mime_type, 'image/png');
assert.equal(requests[1].body.input[0].data, reference.toString('base64'));
assert.equal(requests[1].body.input[1].type, 'text');

await assert.rejects(
  () => new GeminiImageProvider({ apiKey: '', fetchImpl, freeTierOnly: true }).generate('test'),
  /GEMINI_API_KEY is not configured/
);
assert.throws(
  () => new GeminiImageProvider({ apiKey: 'x', model: 'gemini-3.1-flash-image', fetchImpl, freeTierOnly: true }),
  /approved free-tier model/
);
assert.throws(
  () => new GeminiImageProvider({ apiKey: 'x', model: 'gpt-image-2', fetchImpl, freeTierOnly: true }),
  /approved free-tier model/
);
assert.throws(
  () => new GeminiImageProvider({ apiKey: 'x', fetchImpl, freeTierOnly: false }),
  /GEMINI_FREE_TIER_ONLY=true/
);

console.log('GEMINI_FREE_TIER_PROVIDER_TESTS_PASSED');
