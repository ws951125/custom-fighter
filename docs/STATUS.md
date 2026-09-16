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

P3 is accepted on 2026-09-16. Production Free Gemini E2E Run #4 (`35061328085`) passed real text and reference-PNG requests on exact revision `c5d36b7c9d6f7befa506d70798b0d00fef526e4e`, with Gemini 3.6 Flash, Free Tier guards, trusted Render credential isolation, structured VFX/skill output and deterministic Sharp PNG rendering. P3 has no remaining acceptance items.

## P4 — Image → skill → Creator → Training — IN PROGRESS

Already implemented and cloud-tested:
- validated `AiSkillProposal` model and typed gameplay fields,
- prompt/reference PNG request contract with strict PNG/size/dimension validation,
- production backend returns generated VFX plus `skill_proposal`,
- real Gemini reference-image production request accepted by Run #4,
- proposal is never auto-applied,
- explicit Review / Confirm & Apply / Discard,
- Confirm & Preview validates and enters Training,
- proposal handoff through `CreatorPreviewSession`,
- deterministic AI proposal → Training parameter handoff regression,
- deterministic AI proposal → actual Training skill-cast regression,
- Restart and Return Creator match-result paths.

P4 final acceptance implementation added on branch `test/p4-production-creator-e2e`:
- `tests/production_creator_gemini_e2e.mjs` drives the deployed GitHub Pages VFX Creator in Chromium,
- imports a real in-memory PNG reference and prompt,
- calls the real trusted Render/Gemini provider through the browser application,
- requires generated VFX validity and a staged, unconfirmed `skill_proposal`,
- returns to Creator and performs explicit Confirm & Preview,
- enters Training and casts Skill 1, requiring MP consumption, dummy HP reduction and a registered skill hit,
- emits `PRODUCTION_CREATOR_GEMINI_E2E_PASSED` only after the complete chain succeeds,
- `.github/workflows/production-ai-e2e.yml` now runs this browser acceptance after the existing real-provider checks, still behind explicit Free Tier quota confirmation.

Remaining P4 acceptance:
1. merge the P4 production-browser acceptance implementation after normal PR CI passes,
2. wait for the exact merged `main` revision to deploy to GitHub Pages and Render,
3. manually dispatch the quota-gated Production Free Gemini E2E once for that exact revision,
4. require `PRODUCTION_CREATOR_GEMINI_E2E_PASSED` and record the run evidence before declaring P4 complete.

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

To reach 13/13, pass and record the exact-revision production browser path:

`reference PNG + prompt → Gemini/Render → generated VFX + skill proposal → explicit Creator confirmation → Training → actual generated-skill cast`.
