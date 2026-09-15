import assert from 'node:assert/strict';
import { createConfiguredImageProvider, imageProviderReadiness, selectedImageProviderId } from '../backend/image_provider_factory.mjs';
import { DEFAULT_FREE_GEMINI_MODEL, GeminiImageProvider } from '../backend/gemini_image_provider.mjs';

const original = {
  AI_IMAGE_PROVIDER: process.env.AI_IMAGE_PROVIDER,
  GEMINI_API_KEY: process.env.GEMINI_API_KEY,
  GEMINI_MODEL: process.env.GEMINI_MODEL,
  GEMINI_FREE_TIER_ONLY: process.env.GEMINI_FREE_TIER_ONLY
};

function restore() {
  for (const [key, value] of Object.entries(original)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
}

try {
  delete process.env.AI_IMAGE_PROVIDER;
  process.env.GEMINI_API_KEY = 'gemini-test';
  process.env.GEMINI_FREE_TIER_ONLY = 'true';
  delete process.env.GEMINI_MODEL;
  assert.equal(selectedImageProviderId(), 'gemini');
  assert.ok(createConfiguredImageProvider() instanceof GeminiImageProvider);
  let readiness = imageProviderReadiness();
  assert.equal(readiness.provider, 'gemini');
  assert.equal(readiness.configured, true);
  assert.deepEqual(readiness.supported_providers, ['gemini']);
  assert.equal(readiness.model, DEFAULT_FREE_GEMINI_MODEL);
  assert.equal(readiness.billing_mode, 'free-tier-only');
  assert.equal(readiness.providers.gemini.billing_mode, 'free-tier-only');
  assert.equal(readiness.providers.gemini.free_tier_confirmed, true);
  process.env.GEMINI_FREE_TIER_ONLY = 'false';
  readiness = imageProviderReadiness();
  assert.equal(readiness.configured, false);
  assert.equal(readiness.providers.gemini.free_tier_confirmed, false);
  assert.throws(() => createConfiguredImageProvider(), /GEMINI_FREE_TIER_ONLY=true/);
  process.env.GEMINI_FREE_TIER_ONLY = 'true';

  process.env.GEMINI_MODEL = 'gemini-2.5-flash-lite';
  readiness = imageProviderReadiness();
  assert.equal(readiness.configured, true);
  assert.equal(readiness.model, 'gemini-2.5-flash-lite');

  process.env.GEMINI_MODEL = 'gemini-3.1-flash-image';
  readiness = imageProviderReadiness();
  assert.equal(readiness.configured, false);
  assert.throws(() => createConfiguredImageProvider(), /approved free-tier model/);

  process.env.AI_IMAGE_PROVIDER = 'openai';
  assert.throws(() => selectedImageProviderId(), /free-Gemini-only/);
  readiness = imageProviderReadiness();
  assert.equal(readiness.provider, 'openai');
  assert.equal(readiness.configured, false);
} finally {
  restore();
}

console.log('IMAGE_PROVIDER_FACTORY_TESTS_PASSED');
