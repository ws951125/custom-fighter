# Project Status

## Current phase

**Post-MVP P4 Image → skill → Creator → Training production acceptance is in progress.**

Whole-project phase completion is now **92.3% (12/13 roadmap phases fully complete)**.

Roadmap:
- M0–M8 MVP: 9/9 complete.
- P1 Safe real-provider boundary: complete.
- P2 Async remote AI transport: complete.
- P3 Production AI provider/backend integration: **complete**.
- P4 Image → skill proposal → Creator → Training production flow: in progress.

## P3 — Production provider/backend integration — 100%

P3 is accepted on 2026-09-16.

Final production evidence:
- PR #127 migrated the only allow-listed production model to `gemini-3.6-flash`.
- PR #128 fixed the Gemini 3.6 stable Interactions API request contract after real E2E #3 exposed the obsolete `type: text` input shape.
- PR #128 merged to `main` as `c5d36b7c9d6f7befa506d70798b0d00fef526e4e`.
- Main CI Run #277 completed successfully across Windows Native, Godot/backend/Web/Chromium, GitHub-hosted Microsoft Edge, GitHub Pages, public reachability, Production AI Backend Readiness, and Production Edge full smoke.
- Production readiness proved `provider=gemini`, `model=gemini-3.6-flash`, `billing_mode=free-tier-only`, and exact deployed revision `c5d36b7c9d6f7befa506d70798b0d00fef526e4e`.
- Manual Production Free Gemini E2E Run #4 (`35061328085`) completed successfully on that exact revision.
- Run #4 passed both real text-only and real reference-PNG Gemini requests and emitted `PRODUCTION_AI_PROVIDER_E2E_PASSED`.
- The production browser never receives the Gemini API key; the trusted Render backend retains the credential and both Free Tier guards remain fail-closed.
- Gemini returns a strictly validated structured VFX/skill design; final PNG rendering remains deterministic through Sharp, with no paid/native-image fallback.

P3 has no remaining acceptance items.

## P4 — Image → skill → Creator → Training — IN PROGRESS

Already implemented and cloud-tested:
- validated `AiSkillProposal` model and typed gameplay fields,
- prompt/reference PNG request contract with strict PNG/size/dimension validation,
- production backend returns generated VFX plus `skill_proposal`,
- real Gemini reference-image production request is now accepted by Run #4,
- proposal is never auto-applied,
- explicit Review / Confirm & Apply / Discard,
- Confirm & Preview validates and enters Training,
- proposal handoff through `CreatorPreviewSession`,
- deterministic AI proposal → Training parameter handoff regression,
- deterministic AI proposal → actual Training skill-cast regression,
- Restart and Return Creator match-result paths.

Remaining P4 acceptance:
1. exercise the deployed Creator against the real Render/Gemini backend with a reference PNG + prompt,
2. verify the returned real generated VFX and `skill_proposal` are presented for review,
3. explicitly confirm the proposal in Creator,
4. enter Training with the confirmed production result,
5. cast the generated skill and verify the production asset/gameplay handoff,
6. record the final production-browser acceptance evidence before declaring P4 complete.

## Validation policy

Validation is **100% online-only**. Formal project validation uses GitHub-hosted Godot/domain/backend tests, Web export, Chromium, GitHub-hosted Microsoft Edge, GitHub Pages, Render exact-revision readiness, production Edge smoke, and the manual real Gemini E2E when real provider quota is required.

Do not use Remote Desktop Commander, the user's local machine, local Godot/npm/browser caches, or user-device storage for formal project validation or Git synchronization.

## Execution policy

Continue through all non-blocked implementation, regression, cloud validation, fixes, merge and documentation work for the active phase. Do not stop at a completed sub-job. If a required validation fails, inspect online evidence, fix it when permitted, and follow the replacement run through terminal state.

Every reported completed code/test/doc/config work unit must already be synchronized to GitHub. Unsynchronized work cannot be counted as Done.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

AI VFX backend: `https://custom-fighter-ai-vfx.onrender.com`

## Remaining roadmap

To reach 13/13, complete P4 with the real production browser path:

`reference PNG + prompt → Gemini/Render → generated VFX + skill proposal → explicit Creator confirmation → Training → actual generated-skill cast`.
