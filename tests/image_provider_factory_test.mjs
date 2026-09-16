import assert from 'node:assert/strict';
import { createConfiguredImageProvider, imageProviderReadiness, selectedImageProviderId } from '../backend/image_provider_factory.mjs';
import { DEFAULT_FREE_GEMINI_MODEL, GeminiImageProvider } from '../backend/gemini_image_provider.mjs';

const original = {
  AI_IMAGE_PROVIDER: process.env.AI_IMAGE_PROVIDER,
  GEMINI_API_KEY: process.env.GEMINI_API_KEY,
  GEMINI_MODEL: process.env.GEMINI_MODEL,
  GEMINI_FREE_TIER_ONLY: process.env.GEMINI_FREE_TIER_ONLY,
  GEMINI_FREE_TIER_PROJECT_VERIFIED: process.env.GEMINI_FREE_TIER_PROJECT_VERIFIED
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
  process.env.GEMINI_FREE_TIER_PROJECT_VERIFIED = 'true';
  delete process.env.GEMINI_MODEL;
  assert.equal(selectedImageProviderId(), 'gemini');
  assert.ok(createConfiguredImageProvider() instanceof GeminiImageProvider);
  let readiness = imageProviderReadiness();
  assert.equal(readiness.provider, 'gemini');
  assert.equal(readiness.configured, true);
  assert.deepEqual(readiness.supported_providers, ['gemini']);
  assert.equal(readiness.model, DEFAULT_FREE_GEMINI_MODEL);
  assert.equal(readiness.model, 'gemini-3.6-flash');
  assert.equal(readiness.billing_mode, 'free-tier-only');
  assert.equal(readiness.providers.gemini.billing_mode, 'free-tier-only');
  assert.equal(readiness.providers.gemini.free_tier_policy_asserted, true);
  assert.equal(readiness.providers.gemini.free_tier_project_verified, true);
  assert.equal(readiness.providers.gemini.verification_mode, 'operator-asserted');

  process.env.GEMINI_FREE_TIER_ONLY = 'false';
  readiness = imageProviderReadiness();
  assert.equal(readiness.configured, false);
  assert.equal(readiness.providers.gemini.free_tier_policy_asserted, false);
  assert.equal(readiness.providers.gemini.free_tier_project_verified, true);
  assert.throws(() => createConfiguredImageProvider(), /GEMINI_FREE_TIER_ONLY=true/);
  process.env.GEMINI_FREE_TIER_ONLY = 'true';

  process.env.GEMINI_FREE_TIER_PROJECT_VERIFIED = 'false';
  readiness = imageProviderReadiness();
  assert.equal(readiness.configured, false);
  assert.equal(readiness.providers.gemini.free_tier_policy_asserted, true);
  assert.equal(readiness.providers.gemini.free_tier_project_verified, false);
  assert.throws(() => createConfiguredImageProvider(), /GEMINI_FREE_TIER_PROJECT_VERIFIED=true/);
  process.env.GEMINI_FREE_TIER_PROJECT_VERIFIED = 'true';

  process.env.GEMINI_MODEL = 'gemini-3.6-flash';
  readiness = imageProviderReadiness();
  assert.equal(readiness.configured, true);
  assert.equal(readiness.model, 'gemini-3.6-flash');

  process.env.GEMINI_MODEL = 'gemini-2.5-flash';
  readiness = imageProviderReadiness();
  assert.equal(readiness.configured, false);
  assert.throws(() => createConfiguredImageProvider(), /approved free-tier model/);

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
