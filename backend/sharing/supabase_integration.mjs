import { createSupabasePublicationRepository } from './supabase_publication_repository.mjs';
import { createSupabasePublisherResolver } from './supabase_publisher_resolver.mjs';

const ENV = Object.freeze({
  projectUrl: 'CUSTOM_FIGHTER_SHARING_SUPABASE_URL',
  secretKey: 'CUSTOM_FIGHTER_SHARING_SUPABASE_SECRET_KEY',
  publishableKey: 'CUSTOM_FIGHTER_SHARING_SUPABASE_PUBLISHABLE_KEY'
});

function read(value) {
  return typeof value === 'string' ? value.trim() : '';
}

export function createSupabaseSharingIntegration({
  env = process.env,
  fetchImpl = globalThis.fetch
} = {}) {
  const projectUrl = read(env?.[ENV.projectUrl]);
  const secretKey = read(env?.[ENV.secretKey]);
  const publishableKey = read(env?.[ENV.publishableKey]);
  const configuredCount = [projectUrl, secretKey, publishableKey].filter(Boolean).length;

  if (configuredCount === 0) {
    return Object.freeze({
      provider: 'supabase',
      configured: false,
      reason: 'unconfigured',
      repository: null,
      repositoryDurable: false,
      resolvePublisher: null
    });
  }

  if (configuredCount !== 3) {
    return Object.freeze({
      provider: 'supabase',
      configured: false,
      reason: 'incomplete_environment',
      repository: null,
      repositoryDurable: false,
      resolvePublisher: null
    });
  }

  const repository = createSupabasePublicationRepository({
    projectUrl,
    secretKey,
    fetchImpl
  });
  const resolvePublisher = createSupabasePublisherResolver({
    projectUrl,
    publishableKey,
    fetchImpl
  });

  if (!repository || !resolvePublisher) {
    return Object.freeze({
      provider: 'supabase',
      configured: false,
      reason: 'invalid_environment',
      repository: null,
      repositoryDurable: false,
      resolvePublisher: null
    });
  }

  return Object.freeze({
    provider: 'supabase',
    configured: true,
    reason: 'configured',
    repository,
    repositoryDurable: true,
    resolvePublisher
  });
}

export const _test = Object.freeze({ ENV });
