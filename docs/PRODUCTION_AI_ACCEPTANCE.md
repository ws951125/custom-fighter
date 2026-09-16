# Production Free Gemini Acceptance

Production AI is **Gemini free-tier only**. Paid AI providers and Gemini native image-generation models are not valid production configurations for custom-fighter.

## Cost policy

As of 2026-09-16, the production default and only allow-listed model is `gemini-3.6-flash`. Google’s official Gemini API documentation identifies Gemini 3.6 Flash as a current stable multimodal model, and the official pricing table exposes Free Tier input, output, and context caching for this model.

`gemini-2.5-flash` and `gemini-2.5-flash-lite` are no longer allow-listed. Real production acceptance on 2026-09-16 showed that `gemini-2.5-flash` is no longer available to new users and the provider explicitly directed new integrations to `gemini-3.6-flash`.

Native Gemini image-generation models remain intentionally rejected when Google does not expose them through the API free tier. OpenAI image generation is not a supported production provider.

The free Gemini model analyzes the prompt and optional PNG reference through the stable Interactions API `v1` endpoint, with `store=false`, and returns a strictly validated structured VFX design. The trusted backend then renders the PNG deterministically with Sharp. This preserves the AI-assisted workflow without making paid image-generation calls.

## Preconditions

The Render service at `https://custom-fighter-ai-vfx.onrender.com` must report through `/healthz`:

- `provider=gemini`,
- `billing_mode=free-tier-only`,
- `model=gemini-3.6-flash`,
- `free_tier_policy_asserted=true`,
- `free_tier_project_verified=true`,
- `verification_mode=operator-asserted`,
- `configured=true` only when a server-side `GEMINI_API_KEY` is present and all free-tier guards pass.

A production operator must first verify in Google AI Studio / the associated Google Cloud project that the API key belongs to a project that remains on the Gemini Developer API Free Tier and has not enabled paid billing. Only after that verification may `GEMINI_FREE_TIER_PROJECT_VERIFIED=true` be set. This is an operator attestation; the application cannot infer Google billing state from the API key itself.

`GEMINI_FREE_TIER_ONLY=true` is the application cost policy. It is not billing proof. `GEMINI_FREE_TIER_PROJECT_VERIFIED=true` is a separate deployment assertion that the project billing state was checked before enabling production AI.

Recommended Render variables after that verification:

- `AI_IMAGE_PROVIDER=gemini`
- `GEMINI_MODEL=gemini-3.6-flash`
- `GEMINI_API_KEY=<server-side secret from the verified Free Tier project>`
- `GEMINI_FREE_TIER_ONLY=true`
- `GEMINI_FREE_TIER_PROJECT_VERIFIED=true`

If the credential or project verification is unavailable, production must remain non-generating/fail-closed. `/healthz` may pass deployment-health validation only as an explicit safe-disabled state; that is **not** real Gemini readiness or production AI acceptance.

Never put the API key in GitHub source, Pages query parameters, browser storage, Creator configuration, or test fixtures.

## Manual production workflow

GitHub Actions workflow: **Production Free Gemini E2E** (`.github/workflows/production-ai-e2e.yml`).

The workflow remains manual-only so real external quota is not consumed on every push. Before invoking it, the operator must confirm that the configured key belongs to the verified Free Tier project. The workflow then verifies Render readiness and performs two production requests.

## Acceptance coverage

1. Text-only prompt → free Gemini structured VFX design → deterministic PNG renderer.
2. Reference PNG + prompt → free Gemini multimodal structured VFX design → deterministic PNG renderer.

For each response the workflow verifies:

- HTTP success and GitHub Pages CORS,
- `no-store` and `nosniff` protections,
- exact deployed revision alignment,
- provider is `gemini` and `billing_mode=free-tier-only`,
- both free-tier policy and project-verification assertions are true,
- request/result ID matching,
- frame count/FPS and valid PNG sprite-strip dimensions,
- structured `skill_proposal` presence and typed gameplay fields.

A successful run prints `PRODUCTION_AI_PROVIDER_E2E_PASSED` with provider/model/revision.

## Guardrails

- Any `AI_IMAGE_PROVIDER` other than `gemini` fails closed in generation; `disabled` is permitted only as an explicit non-generating deployment-health state.
- Any `GEMINI_MODEL` outside the free-tier allow-list fails closed.
- Missing `GEMINI_FREE_TIER_ONLY=true` fails closed.
- Missing `GEMINI_FREE_TIER_PROJECT_VERIFIED=true` fails closed.
- Pricing eligibility and API/model availability are separate checks; verify both against current official Google documentation before changing the allow-list or activating production.
- Real provider E2E remains the authoritative acceptance gate after any model-lifecycle change.
- Paid provider fallback is prohibited unless the user explicitly reverses the project cost policy.
