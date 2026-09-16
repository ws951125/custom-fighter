# Project Status

## Current phase

**Post-MVP P3/P4 production image-to-skill integration is in progress.**

Whole-project phase completion remains **84.6% (11/13 roadmap phases fully complete)** because P3 and P4 are not counted until each phase is fully accepted.

Roadmap:
- M0–M8 MVP: 9/9 complete.
- P1 Safe real-provider boundary: complete.
- P2 Async remote AI transport: complete.
- P3 Production AI provider/backend integration: in progress.
- P4 Image → skill proposal → Creator → Training production flow: in progress.

Current work unit (2026-09-16): real Free Tier Gemini production activation reached provider readiness on `main` revision `c3ab7e5dee0a30ef54ceb69ea6e7c23169b2ff96`, but manual **Production Free Gemini E2E** Runs #1 and #2 failed on the first real text-generation request because Google reported `models/gemini-2.5-flash` is no longer available to new users and directed new integrations to `models/gemini-3.6-flash`.

The credential/billing blocker is now resolved: the operator configured the server-side `GEMINI_API_KEY`, explicitly verified the Google project is Free Tier with paid billing disabled, and production readiness proved `provider=gemini`, `billing_mode=free-tier-only`, both Free Tier guards true, and exact deployed revision alignment. The active blocker is therefore model lifecycle/API availability, not credentials or billing.

Feature branch `fix/gemini-3-6-flash` updates the production default and allow-list to `gemini-3.6-flash`, explicitly rejects retired `gemini-2.5-flash`, aligns browser readiness fixtures, updates the production AI policy/acceptance documentation, and records this production failure. Google official documentation/pricing was rechecked before the allow-list change: Gemini 3.6 Flash is a current stable multimodal model and its Gemini Developer API Free Tier lists input/output/context-caching as free. Production Render remains on `GEMINI_MODEL=gemini-2.5-flash` until the code migration is validated and merged; real generation is therefore not accepted yet.

## Completed milestones

### M0 — Foundation — 100%
Godot 4.7.2 foundation, automated validation, Web export, deployment support and browser smoke coverage.

### M1 — Combat Prototype — 100%
2.5D movement, run/jump/dash/guard, HP/MP, three-hit basic attack chain, hit/hurt boxes, hitstun, knockback, knockdown and training dummy.

### M2 — Skill Engine — 100%
Data-driven melee, projectile, area, dash, formation and buff templates with startup/active/recovery, MP and cooldown handling.

### M3 — Character System — 100%
Validated CharacterDefinition, movement/visual/animation/loadout boundaries and multiple reference characters.

### M4 — Creator Studio — 100%
Character Editor, Projectile Skill Editor and validated Creator-to-Training preview flow.

### M5 — VFX Creator — 100%
Validated PNG/sprite-strip import, crop/frame/FPS/scale/offset authoring, preview and Skill 1 projectile binding.

### M6 — AI-assisted VFX — 100%
Provider-neutral AI VFX request/result/provider boundary plus Creator prompt/reference Generate/Regenerate workflow.

### M7 — Character Packages — 100%
Versioned character package import/export with schema-v2 self-contained validated Skill 1 PNG/sprite-strip VFX and fail-closed package boundaries.

### M8 — MVP Release — 100%
Web release, Windows x86_64 release flow, release documentation and Creator → package → fresh-session import → Training acceptance.

### P1 — Safe real-provider boundary — 100%
Completed through PR #85. Includes validated provider configuration, `remote_ai_vfx`, HTTPS-only endpoints, embedded credential rejection, provider-neutral architecture and no secrets in Git.

### P2 — Async remote AI transport — 100%
Completed through PR #86. Includes Godot `HTTPRequest`, strict JSON/PNG response decoding, request/result matching, malformed/oversized/invalid output rejection and deterministic mock fallback.

## P3 — Production provider/backend integration — IN PROGRESS

Relevant merged history:
- PR #121 **`P3: enforce free-tier Gemini AI only`** merged as `9fe7f3d3f72e779fa050d1b2cff734dc999f1510`.
- PR #122 **`P3: verify Free Tier project before Gemini activation`** merged as `e1ae9933fa4943af80ff7b7ab4a0ff4ae97d78cb`.
- PR #123 **`Test: stabilize production match-restart positioning`** merged as `6902f7e475c30e90689e4bdab887a8a660b19501`.
- PR #124 **`Docs: sync Run #264 production validation`** merged as `eb1087c0089ca00190a37b7265ee9b0b91870082`.
- PR #125 **`Docs: require GitHub sync before progress reports`** merged as `1a6c79fa81c9bd711079abf40009a728591b2237`.
- PR #126 **`Docs: sync Run #271 production validation`** merged as current `main` revision `c3ab7e5dee0a30ef54ceb69ea6e7c23169b2ff96`; main CI Run #273 completed successfully across Windows Native, Chromium, hosted Edge, Pages, public reachability, Render readiness, and production Edge full smoke.

Production activation evidence on 2026-09-16:
- operator configured `GEMINI_API_KEY` directly in Render; the secret never entered Git,
- operator explicitly verified the associated Google project is Free Tier / paid billing disabled,
- Render was configured with `AI_IMAGE_PROVIDER=gemini`, `GEMINI_FREE_TIER_ONLY=true`, and `GEMINI_FREE_TIER_PROJECT_VERIFIED=true`,
- Render deployment `dep-dakvm20ae00c73f1nda0` reached `live` on exact `main` revision `c3ab7e5dee0a30ef54ceb69ea6e7c23169b2ff96`,
- GitHub Production AI Backend Readiness printed `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-2.5-flash billing_mode=free-tier-only revision=c3ab7e5dee0a30ef54ceb69ea6e7c23169b2ff96`, proving the credential and Free Tier guards were effective,
- manual Production Free Gemini E2E Runs #1 (`35051497128`) and #2 (`35051504664`) both passed readiness but failed the first real provider call with HTTP 500 because Google rejected `gemini-2.5-flash` as unavailable to new users and recommended `gemini-3.6-flash`,
- this failure is model lifecycle/API availability, not an API-key, CORS, Render readiness, revision-alignment, or billing-guard failure.

Implemented and production-hardened:
- trusted Node backend with `/healthz` and `/v1/vfx/generate`,
- production provider factory constrained to Gemini only,
- stable Gemini Interactions API `v1` with `store=false`,
- Gemini text/reference understanding → strict structured VFX design → deterministic Sharp PNG rendering,
- no OpenAI production adapter and no paid/native-image fallback,
- strict CORS/body/output bounds and response revalidation,
- browser/runtime contains no provider credential,
- Creator preflight readiness disables Generate while backend/provider is unavailable,
- deployed revision is exposed without secrets for cloud acceptance,
- `GEMINI_FREE_TIER_ONLY=true` represents the application cost policy,
- `GEMINI_FREE_TIER_PROJECT_VERIFIED=true` represents operator verification that paid billing is disabled,
- provider `configured=true` requires API key + allow-listed model + both guards,
- readiness fields remain split into `free_tier_policy_asserted`, `free_tier_project_verified`, and `verification_mode=operator-asserted`,
- real Gemini generation remains a separate acceptance gate and is not inferred from readiness alone,
- Render runtime uses `NODE_ENV=production` and Sharp 0.35.4.

Active migration on `fix/gemini-3-6-flash`:
- production default: `gemini-3.6-flash`,
- free-model allow-list: `gemini-3.6-flash` only,
- retired `gemini-2.5-flash` explicitly fails closed in the provider factory regression test,
- remote AI and reference-AI browser readiness mocks report `gemini-3.6-flash`,
- production AI cost policy and acceptance documentation updated to current Google model/pricing state.

Remaining P3 acceptance:
- validate the migration branch in GitHub Actions,
- merge after required PR gates are green,
- let Render deploy the new exact `main` revision,
- change Render `GEMINI_MODEL` from `gemini-2.5-flash` to `gemini-3.6-flash` without touching the server-side API key,
- verify `PRODUCTION_AI_BACKEND_READY` on exact merged revision with model 3.6,
- rerun the manual real text + reference-image Production Free Gemini E2E,
- declare P3 complete only after that real-provider E2E passes.

## P4 — Image → skill → Creator → Training — IN PROGRESS

Implemented in source and deterministic cloud E2E:
- validated `AiSkillProposal` model,
- AI proposal includes type/name, damage, MP, cooldown, startup/active/recovery, speed/range, hitstun, knockback, hitbox and visual binding,
- proposal is never auto-applied,
- explicit Review / Confirm & Apply / Discard,
- Confirm & Preview validates and enters Training,
- backend can return VFX + `skill_proposal` in one response,
- Godot response codec validates proposal/request matching,
- proposal handoff through `CreatorPreviewSession`,
- reference PNG metadata/Base64 contract with strict PNG/size/dimension checks,
- Web reference-image remote E2E against a fake trusted backend,
- AI proposal → Training parameter handoff,
- AI proposal → actual Training skill cast regression,
- Training match-end victory/defeat state,
- result overlay with Restart and Return Creator actions,
- Restart remounts a fresh Training instance to reset HP/MP/positions/cooldowns/projectiles/buffs/controllers/hit counters.

Remaining P4 acceptance:
- complete the real `gemini-3.6-flash` provider acceptance,
- real reference image + prompt → production backend → generated VFX + skill proposal,
- explicit confirmation in Creator,
- real generated asset cast in Training,
- final real-provider production acceptance.

## Validation policy

Validation is **100% online-only**.

Required path:
1. GitHub-hosted Godot import/parse and headless boot,
2. Godot domain/AI contract tests,
3. trusted-backend tests,
4. Web export and size budget,
5. Chromium full `smoke:all`,
6. Windows x86_64 release cross-export,
7. Microsoft Edge full browser smoke on a GitHub-hosted Windows runner,
8. after a successful `main` push, deploy the validated Web artifact to GitHub Pages,
9. verify public Training / Creator / VFX URLs are reachable,
10. verify the Render backend is healthy, serving the expected revision, and fully verified/configured for free Gemini,
11. run the full `smoke:all` suite against the real GitHub Pages deployment in Microsoft Edge,
12. run the manual real Gemini text + reference-image production acceptance after any provider/model lifecycle change.

Do not use Remote Desktop Commander, the user's local machine, local Godot/npm/browser caches, or user-device storage for project validation or Git synchronization.

## Execution policy

Once a roadmap phase is started, continue through all non-blocked implementation, regression, cloud validation, fixes, merge and documentation work for that phase. Do not stop merely because a slice, commit, PR or test group completed. Stop only at a genuine external blocker or a decision requiring explicit user approval. If one item is externally blocked, finish the other non-blocked work in the same phase first.

When continuous monitoring is requested, keep polling every required CI, deployment and production gate through terminal state. A completed sub-job or an `in_progress` run is not a stopping point. If a required validation fails, inspect the online evidence, fix it when permitted, and follow the replacement run through terminal state.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

AI VFX backend: `https://custom-fighter-ai-vfx.onrender.com`

## Remaining roadmap

To reach 13/13:
- finish P3 by merging the Gemini 3.6 migration and passing the real Free Tier provider E2E,
- finish P4 with real reference-image → VFX + skill proposal → explicit confirmation → Training cast production acceptance.
