import assert from 'node:assert/strict';
import { GeminiImageProvider } from '../backend/gemini_image_provider.mjs';

const output = Buffer.from('gemini-image-bytes');
const requests = [];
const fetchImpl = async (url, options) => {
  requests.push({ url, options, body: JSON.parse(options.body) });
  return new Response(JSON.stringify({
    steps: [{
      type: 'model_output',
      content: [{ type: 'image', data: output.toString('base64'), mime_type: 'image/png' }]
    }]
  }), { status: 200, headers: { 'Content-Type': 'application/json' } });
};

const provider = new GeminiImageProvider({
  apiKey: 'test-gemini-key',
  model: 'gemini-3.1-flash-image',
  fetchImpl
});

const generated = await provider.generate('blue energy slash');
assert.deepEqual(generated, output);
assert.equal(requests[0].url, 'https://generativelanguage.googleapis.com/v1beta/interactions');
assert.equal(requests[0].options.headers['x-goog-api-key'], 'test-gemini-key');
assert.equal(requests[0].body.model, 'gemini-3.1-flash-image');
assert.deepEqual(requests[0].body.input, [{ type: 'text', text: 'blue energy slash' }]);
assert.deepEqual(requests[0].body.response_format, { type: 'image', aspect_ratio: '1:1' });

const reference = Buffer.from('reference-png');
const edited = await provider.generate('preserve silhouette, add lightning', { referencePng: reference });
assert.deepEqual(edited, output);
assert.equal(requests[1].body.input.length, 2);
assert.equal(requests[1].body.input[1].type, 'image');
assert.equal(requests[1].body.input[1].mime_type, 'image/png');
assert.equal(requests[1].body.input[1].data, reference.toString('base64'));

await assert.rejects(
  () => new GeminiImageProvider({ apiKey: '', fetchImpl }).generate('test'),
  /GEMINI_API_KEY is not configured/
);

console.log('GEMINI_IMAGE_PROVIDER_TESTS_PASSED');
