# Production Free Gemini Acceptance

Production AI is **Gemini free-tier only**. Paid AI providers and Gemini native image-generation models are not valid production configurations for custom-fighter.

## Cost policy

As of 2026-09-15, the project uses `gemini-2.5-flash` by default because the Gemini Developer API exposes a free tier for this text/multimodal model. `gemini-2.5-flash-lite` is the only alternate model currently allow-listed.

Native Gemini image-generation models are intentionally rejected because Google does not expose them through the API free tier. OpenAI image generation is no longer a supported production provider.

The free Gemini model analyzes the prompt and optional PNG reference through the stable Interactions API `v1` endpoint, with `store=false`, and returns a strictly validated structured VFX design. The trusted backend then renders the PNG deterministically with Sharp. This preserves the AI-assisted workflow without making paid image-generation calls.

## Preconditions

The Render service at `https://custom-fighter-ai-vfx.onrender.com` must report through `/healthz`:

- `provider=gemini`,
- `billing_mode=free-tier-only`,
- an allow-listed `model`,
- `configured=true` only when a server-side `GEMINI_API_KEY` is present and `GEMINI_FREE_TIER_ONLY=true`.

The API key must belong to a Google AI Studio project that remains on the Free Tier with paid billing disabled. The environment flag is a fail-closed deployment assertion; it does not convert a paid project back to Free Tier.

Recommended Render variables:

- `AI_IMAGE_PROVIDER=gemini`
- `GEMINI_MODEL=gemini-2.5-flash`
- `GEMINI_API_KEY=<server-side secret from a Free Tier project>`
- `GEMINI_FREE_TIER_ONLY=true`

Never put the API key in GitHub source, Pages query parameters, browser storage, Creator configuration, or test fixtures.
## Manual production workflow

GitHub Actions workflow: **Production Free Gemini E2E** (`.github/workflows/production-ai-e2e.yml`).

The workflow remains manual-only so real external quota is not consumed on every push. The operator confirms use of the configured Gemini free-tier quota, then the workflow verifies Render readiness and performs two production requests.

## Acceptance coverage

1. Text-only prompt → free Gemini structured VFX design → deterministic PNG renderer.
2. Reference PNG + prompt → free Gemini multimodal structured VFX design → deterministic PNG renderer.

For each response the workflow verifies:

- HTTP success and GitHub Pages CORS,
- `no-store` and `nosniff` protections,
- exact deployed revision alignment,
- provider is `gemini` and `billing_mode=free-tier-only`,
- request/result ID matching,
- frame count/FPS and valid PNG sprite-strip dimensions,
- structured `skill_proposal` presence and typed gameplay fields.

A successful run prints `PRODUCTION_AI_PROVIDER_E2E_PASSED` with provider/model/revision.

## Guardrails

- Any `AI_IMAGE_PROVIDER` other than `gemini` fails closed.
- Any `GEMINI_MODEL` outside the free-tier allow-list fails closed.
- Pricing/model availability must be rechecked against official Google documentation before changing the allow-list.
- Paid provider fallback is prohibited unless the user explicitly reverses the project cost policy.
