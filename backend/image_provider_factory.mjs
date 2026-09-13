import { OpenAiImageProvider } from './openai_image_provider.mjs';
import { GeminiImageProvider } from './gemini_image_provider.mjs';

export const SUPPORTED_IMAGE_PROVIDERS = ['openai', 'gemini'];

export function selectedImageProviderId() {
  const raw = String(process.env.AI_IMAGE_PROVIDER || 'openai').trim().toLowerCase();
  if (!SUPPORTED_IMAGE_PROVIDERS.includes(raw)) {
    throw new Error(`unsupported AI_IMAGE_PROVIDER: ${raw || '(empty)'}`);
  }
  return raw;
}

export function createConfiguredImageProvider() {
  const providerId = selectedImageProviderId();
  if (providerId === 'gemini') return new GeminiImageProvider();
  return new OpenAiImageProvider();
}

export function imageProviderReadiness() {
  const providerId = (() => {
    try {
      return selectedImageProviderId();
    } catch {
      return String(process.env.AI_IMAGE_PROVIDER || '').trim().toLowerCase() || 'invalid';
    }
  })();

  const providers = {
    openai: {
      configured: Boolean(String(process.env.OPENAI_API_KEY || '').trim()),
      model: process.env.OPENAI_IMAGE_MODEL || 'gpt-image-2'
    },
    gemini: {
      configured: Boolean(String(process.env.GEMINI_API_KEY || '').trim()),
      model: process.env.GEMINI_IMAGE_MODEL || 'gemini-3.1-flash-image'
    }
  };

  const selected = providers[providerId];
  return {
    configured: Boolean(selected?.configured),
    provider: providerId,
    model: selected?.model || '',
    supported_providers: [...SUPPORTED_IMAGE_PROVIDERS],
    providers
  };
}
