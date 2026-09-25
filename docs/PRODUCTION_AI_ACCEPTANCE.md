# Production Free Gemini Acceptance

Production AI is **Gemini free-tier only**. Paid AI providers and Gemini native image-generation models are not valid production configurations for custom-fighter.

## Cost policy

As of 2026-09-16, the production default and only allow-listed model is `gemini-3.6-flash`. `gemini-2.5-flash` and `gemini-2.5-flash-lite` are not allow-listed.

The free Gemini model analyzes the prompt and optional PNG reference through the stable Interactions API `v1` endpoint, with `store=false`, and returns a strictly validated structured VFX design. The trusted backend renders the PNG deterministically with Sharp. Paid/native image-generation fallback remains prohibited.

## Preconditions

The Render service at `https://custom-fighter-ai-vfx-6899.onrender.com` must report through `/healthz`:
- `provider=gemini`,
- `billing_mode=free-tier-only`,
- `model=gemini-3.6-flash`,
- `free_tier_policy_asserted=true`,
- `free_tier_project_verified=true`,
- `verification_mode=operator-asserted`,
- `configured=true` only when a server-side `GEMINI_API_KEY` is present and all free-tier guards pass.

The operator must verify in Google AI Studio / the associated Google Cloud project that the key belongs to the intended Free Tier project with paid billing disabled before setting `GEMINI_FREE_TIER_PROJECT_VERIFIED=true`. This remains an operator attestation; the application does not infer billing state from the API key.

Never put the API key in GitHub source, Pages query parameters, browser storage, Creator configuration, or test fixtures.

## Manual production workflow

GitHub Actions workflow: **Production Free Gemini E2E** (`.github/workflows/production-ai-e2e.yml`). It remains manual-only so real external quota is not consumed on every push.

The workflow verifies Render readiness and exact deployed revision, then performs:
1. text-only prompt → free Gemini structured VFX design → deterministic PNG renderer,
2. reference PNG + prompt → free Gemini multimodal structured VFX design → deterministic PNG renderer,
3. deployed VFX Creator → reference PNG + prompt → Render/Gemini → generated VFX + skill proposal → explicit Confirm & Preview → Training → actual generated-skill cast.

For provider responses it verifies HTTP/CORS/security headers, exact revision, Gemini/free-tier identity, request/result matching, valid PNG sprite-strip dimensions, and structured `skill_proposal` gameplay fields. The browser acceptance additionally requires generated VFX validity, an initially unconfirmed proposal, explicit Creator confirmation, Training entry, MP consumption, dummy HP reduction and a registered skill hit.

## Accepted production evidence — 2026-09-16

### P3 provider/backend acceptance

P3 production provider acceptance completed on `main` revision `c5d36b7c9d6f7befa506d70798b0d00fef526e4e`.

- PR #128 corrected the Gemini 3.6 Interactions request schema after Run #3 rejected the obsolete top-level `input[0].type=text` shape.
- Main CI Run #277 passed the exact-revision production readiness and production browser gates.
- Render readiness reported `provider=gemini`, `model=gemini-3.6-flash`, `billing_mode=free-tier-only`, revision `c5d36b7c9d6f7befa506d70798b0d00fef526e4e`.
- Manual Production Free Gemini E2E Run #4 (`35061328085`) completed successfully on the same revision.
- Both real text-only and real reference-image requests passed.
- The successful run emitted `PRODUCTION_AI_PROVIDER_E2E_PASSED`.

### P4 full Creator → Training acceptance

P4 production acceptance completed on exact `main` revision `a572b0a3e60e377ae9152592c6d8c62e574a8554`.

- PR #130 added the production browser acceptance and was merged to this revision.
- Main CI #281 passed before the quota-gated run, including GitHub Pages deployment, public web verification, Render exact-revision readiness and production browser smoke.
- Manual Production Free Gemini E2E Run #5 (`35075099182`) completed successfully on this exact revision.
- Render readiness emitted `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=a572b0a3e60e377ae9152592c6d8c62e574a8554`.
- Real text generation emitted `PRODUCTION_AI_TEXT_GENERATION_PASSED`.
- Real reference-image generation emitted `PRODUCTION_AI_REFERENCE_GENERATION_PASSED`.
- Provider acceptance emitted `PRODUCTION_AI_PROVIDER_E2E_PASSED provider=gemini model=gemini-3.6-flash revision=a572b0a3e60e377ae9152592c6d8c62e574a8554`.
- The deployed Creator/Training acceptance emitted `PRODUCTION_CREATOR_GEMINI_E2E_PASSED provider=gemini revision=a572b0a3e60e377ae9152592c6d8c62e574a8554 reference=true proposal=true confirmPreview=true cast=true damage=18`.

This closes P4 and the planned roadmap at **13/13 phases complete**.

## Guardrails

- Any `AI_IMAGE_PROVIDER` other than `gemini` fails closed in generation; `disabled` is permitted only as an explicit non-generating deployment-health state.
- Any `GEMINI_MODEL` outside the free-tier allow-list fails closed.
- Missing `GEMINI_FREE_TIER_ONLY=true` fails closed.
- Missing `GEMINI_FREE_TIER_PROJECT_VERIFIED=true` fails closed.
- Pricing eligibility and API/model availability are separate checks; verify both against current official Google documentation before changing the allow-list or activating production.
- Real provider E2E remains the authoritative provider acceptance gate after any model-lifecycle change.
- Paid provider fallback is prohibited unless the user explicitly reverses the project cost policy.

## 2026-09-25 Render service migration

The legacy `https://custom-fighter-ai-vfx.onrender.com` endpoint became unavailable and returned persistent HTTP 503. The connected `6899's workspace` does not own that legacy service.

Replacement production backend:
- URL: `https://custom-fighter-ai-vfx-6899.onrender.com`
- Plan: Render Free
- Region: Singapore
- Branch: `main`
- Auto-deploy: enabled
- Start: `npm run backend:start`
- Allowed browser origin: `https://ws951125.github.io`

The replacement service intentionally starts without `GEMINI_API_KEY`. In this state `/healthz` must report `provider=disabled`, `configured=false`, the Gemini provider metadata, and `free_tier_policy_asserted=true`. This is a safe non-generating production state: the backend and Network PvP remain available, while real Gemini generation remains disabled until an operator verifies a Free Tier project and configures the server-side key plus `GEMINI_FREE_TIER_PROJECT_VERIFIED=true`.

The manual **Production Free Gemini E2E** workflow remains the authoritative acceptance before re-enabling real provider calls.
