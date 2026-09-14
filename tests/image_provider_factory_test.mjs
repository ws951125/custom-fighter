import assert from 'node:assert/strict';
import { createConfiguredImageProvider, imageProviderReadiness, selectedImageProviderId } from '../backend/image_provider_factory.mjs';
import { OpenAiImageProvider } from '../backend/openai_image_provider.mjs';
import { GeminiImageProvider } from '../backend/gemini_image_provider.mjs';

const original = {
  AI_IMAGE_PROVIDER: process.env.AI_IMAGE_PROVIDER,
  OPENAI_API_KEY: process.env.OPENAI_API_KEY,
  GEMINI_API_KEY: process.env.GEMINI_API_KEY,
  OPENAI_IMAGE_MODEL: process.env.OPENAI_IMAGE_MODEL,
  GEMINI_IMAGE_MODEL: process.env.GEMINI_IMAGE_MODEL
};

function restore() {
  for (const [key, value] of Object.entries(original)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
}

try {
  delete process.env.AI_IMAGE_PROVIDER;
  process.env.OPENAI_API_KEY = 'openai-test';
  delete process.env.GEMINI_API_KEY;
  assert.equal(selectedImageProviderId(), 'openai');
  assert.ok(createConfiguredImageProvider() instanceof OpenAiImageProvider);
  let readiness = imageProviderReadiness();
  assert.equal(readiness.provider, 'openai');
  assert.equal(readiness.configured, true);
  assert.deepEqual(readiness.supported_providers, ['openai', 'gemini']);
  assert.equal(readiness.providers.openai.configured, true);
  assert.equal(readiness.providers.gemini.configured, false);

  process.env.AI_IMAGE_PROVIDER = 'gemini';
  process.env.GEMINI_API_KEY = 'gemini-test';
  process.env.GEMINI_IMAGE_MODEL = 'gemini-3.1-flash-image';
  assert.equal(selectedImageProviderId(), 'gemini');
  assert.ok(createConfiguredImageProvider() instanceof GeminiImageProvider);
  readiness = imageProviderReadiness();
  assert.equal(readiness.provider, 'gemini');
  assert.equal(readiness.configured, true);
  assert.equal(readiness.model, 'gemini-3.1-flash-image');

  process.env.AI_IMAGE_PROVIDER = 'unknown-provider';
  assert.throws(() => selectedImageProviderId(), /unsupported AI_IMAGE_PROVIDER/);
  readiness = imageProviderReadiness();
  assert.equal(readiness.provider, 'unknown-provider');
  assert.equal(readiness.configured, false);
} finally {
  restore();
}

console.log('IMAGE_PROVIDER_FACTORY_TESTS_PASSED');
