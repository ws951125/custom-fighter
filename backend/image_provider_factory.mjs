import { DEFAULT_FREE_GEMINI_MODEL, FREE_GEMINI_MODELS, GeminiImageProvider } from './gemini_image_provider.mjs';

export const SUPPORTED_IMAGE_PROVIDERS = ['gemini'];

export function selectedImageProviderId() {
  const raw = String(process.env.AI_IMAGE_PROVIDER || 'gemini').trim().toLowerCase();
  if (!SUPPORTED_IMAGE_PROVIDERS.includes(raw)) {
    throw new Error(`unsupported AI_IMAGE_PROVIDER: ${raw || '(empty)'}; custom-fighter is free-Gemini-only`);
  }
  return raw;
}

export function createConfiguredImageProvider() {
  selectedImageProviderId();
  return new GeminiImageProvider();
}

export function imageProviderReadiness() {
  const providerId = (() => {
    try {
      return selectedImageProviderId();
    } catch {
      return String(process.env.AI_IMAGE_PROVIDER || '').trim().toLowerCase() || 'invalid';
    }
  })();
  const model = String(process.env.GEMINI_MODEL || DEFAULT_FREE_GEMINI_MODEL).trim();
  const freeTierOnly = String(process.env.GEMINI_FREE_TIER_ONLY || '').trim().toLowerCase() === 'true';
  const freeTierProjectVerified = String(process.env.GEMINI_FREE_TIER_PROJECT_VERIFIED || '').trim().toLowerCase() === 'true';
  const gemini = {
    configured: Boolean(String(process.env.GEMINI_API_KEY || '').trim()) && FREE_GEMINI_MODELS.has(model) && freeTierOnly && freeTierProjectVerified,
    model,
    billing_mode: 'free-tier-only',
    free_tier_policy_asserted: freeTierOnly,
    free_tier_project_verified: freeTierProjectVerified,
    verification_mode: 'operator-asserted'
  };
  const providers = { gemini };
  const selected = providers[providerId];
  const configured = Boolean(selected?.configured);
  const readinessProvider = providerId === 'gemini' && !configured ? 'disabled' : providerId;
  return {
    configured,
    provider: readinessProvider,
    model: configured ? (selected?.model || '') : '',
    billing_mode: configured ? (selected?.billing_mode || '') : '',
    supported_providers: [...SUPPORTED_IMAGE_PROVIDERS],
    providers
  };
}
