# Production AI Provider Acceptance

This acceptance is intentionally **manual-only** because it makes real calls to the selected OpenAI or Gemini production provider and may incur provider charges.

## Preconditions

The Render service at `https://custom-fighter-ai-vfx.onrender.com` must report the selected provider as configured through `/healthz`.

Supported production configurations:

- OpenAI: `AI_IMAGE_PROVIDER=openai` + server-side `OPENAI_API_KEY`.
- Gemini: `AI_IMAGE_PROVIDER=gemini` + server-side `GEMINI_API_KEY`.

Provider credentials must remain server-side on Render. Never put them in GitHub source, Pages query parameters, browser storage, Creator configuration, or test fixtures.

## Manual workflow

GitHub Actions workflow: **Production AI Provider E2E** (`.github/workflows/production-ai-e2e.yml`).

The workflow has no `push`, `pull_request`, or schedule trigger. It only runs through `workflow_dispatch` and requires the operator to explicitly confirm that real billable provider calls are understood.

Optional `expected_provider` can be set to `openai` or `gemini`. Leaving it empty accepts whichever selected provider `/healthz` reports as configured.

## Acceptance coverage

The workflow performs two real production generations through the trusted Render backend:

1. Text-only prompt → `/v1/vfx/generate`.
2. Generated PNG reference image + prompt → `/v1/vfx/generate`.

For each response it verifies:

- HTTP success and GitHub Pages CORS,
- `no-store` and `nosniff` response protections,
- request/result ID matching,
- expected frame count and FPS,
- Base64 payload decodes as PNG,
- output sprite-strip dimensions are `frame_width × frame_count` by `frame_height`,
- a structured `skill_proposal` is returned,
- proposal source request ID matches,
- skill ID, damage, MP cost and cooldown fields are present and typed.

A successful run prints `PRODUCTION_AI_PROVIDER_E2E_PASSED` together with the selected provider and model.

## Cost safety

Normal CI only syntax-checks `tests/production_ai_provider_e2e.mjs`; it does **not** invoke a real model. Do not add automatic push/PR/scheduled triggers to the billable workflow without explicit user approval.
