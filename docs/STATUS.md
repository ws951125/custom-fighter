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

Current work unit (2026-09-15): PR #125 **`Docs: require GitHub sync before progress reports`** merged to `main` as `1a6c79fa81c9bd711079abf40009a728591b2237`. The new `Agent.md` rule requires every program/test/document/config progress claim to already be committed to GitHub before it is counted as completed, with remote branch/head/PR state re-checked before reporting.

Main CI Run #271 validated that exact merge revision. The first GitHub-hosted Microsoft Edge attempt failed only in `tests/melee_web_smoke.mjs` when Heavy Strike setup landed at `playerX=847.04`, `dummyX=860`, `gap=12.96`, below the geometry-derived 18 px test corridor. The same SHA had already passed PR #125 Run #270 Edge and Run #271 Chromium, so only the failed Edge job was retried. The targeted retry passed without code changes. GitHub Pages deployment, public reachability, Production AI Backend Readiness, and the final Microsoft Edge production `smoke:all` then all passed. Production Heavy Strike passed with `hitGap=88.89`, confirming the first 12.96 px event was an isolated hosted-runner positioning excursion rather than a gameplay regression.

All currently inferable/non-blocked engineering work for the Free Tier safety boundary and deterministic production validation is complete. P3/P4 remain open only because real Gemini Free Tier production acceptance requires an external credential and billing-state verification that cannot be inferred or performed from the repository.

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

PR #121 **`P3: enforce free-tier Gemini AI only`** merged to `main` as `9fe7f3d3f72e779fa050d1b2cff734dc999f1510` after latest-head PR CI Run #256 passed Windows Native Release, Godot/backend/Web/Chromium and GitHub-hosted Microsoft Edge.

PR #122 **`P3: verify Free Tier project before Gemini activation`** merged to `main` as `e1ae9933fa4943af80ff7b7ab4a0ff4ae97d78cb` after latest-head PR CI Run #259 passed Windows Native Release, Godot/backend/Web/Chromium and GitHub-hosted Microsoft Edge.

PR #123 **`Test: stabilize production match-restart positioning`** merged to `main` as `6902f7e475c30e90689e4bdab887a8a660b19501` after latest-head PR CI Run #263 passed Windows Native Release, Godot/backend/Web/Chromium and GitHub-hosted Microsoft Edge.

PR #124 **`Docs: sync Run #264 production validation`** merged to `main` as `eb1087c0089ca00190a37b7265ee9b0b91870082`; post-merge main Run #266 passed all production gates.

PR #125 **`Docs: require GitHub sync before progress reports`** merged to `main` as `1a6c79fa81c9bd711079abf40009a728591b2237`; post-merge main Run #271 passed the complete production chain after one isolated hosted Edge positioning retry.

Render / production backend status:
- main Run #271 verified the backend is serving exact revision `1a6c79fa81c9bd711079abf40009a728591b2237`,
- `/healthz` remains compatible with `supported_providers=[gemini]`,
- production is deliberately `AI_IMAGE_PROVIDER=disabled`, so no AI provider can be called while credential / billing verification is unresolved,
- `GEMINI_MODEL=gemini-2.5-flash` and `GEMINI_FREE_TIER_ONLY=true` remain the intended model/policy configuration,
- main Run #271 Production AI Backend Readiness printed `PRODUCTION_AI_BACKEND_SAFE_DISABLED model=gemini-2.5-flash project_verified=false revision=1a6c79fa81c9bd711079abf40009a728591b2237`,
- `providers.gemini.configured=false`; real Gemini production acceptance is intentionally unavailable until a server-side key and external project verification are supplied.

Implemented and production-hardened:
- trusted Node backend with `/healthz` and `/v1/vfx/generate`,
- production provider factory constrained to Gemini only,
- `gemini-2.5-flash` / `gemini-2.5-flash-lite` free-tier model allow-list,
- stable Gemini Interactions API `v1` with `store=false`,
- Gemini text/reference understanding → strict structured VFX design → deterministic Sharp PNG rendering,
- no OpenAI production adapter and no paid/native-image fallback,
- strict CORS/body/output bounds and response revalidation,
- browser/runtime contains no provider credential,
- Creator preflight readiness disables Generate while backend/provider is unavailable,
- deployed revision is exposed without secrets for cloud acceptance,
- `GEMINI_FREE_TIER_ONLY=true` represents only the application cost policy,
- `GEMINI_FREE_TIER_PROJECT_VERIFIED=true` is required after an operator verifies the AI Studio / associated Google Cloud project has paid billing disabled,
- provider `configured=true` requires API key + allow-listed model + both guards,
- readiness fields are split into `free_tier_policy_asserted`, `free_tier_project_verified`, and `verification_mode=operator-asserted`,
- deployment-health validation accepts `provider=disabled` only as an explicit safe fail-closed state; this is not counted as real Gemini acceptance,
- manual production AI E2E remains strict and requires an actually configured/verified Gemini provider,
- Render runtime uses `NODE_ENV=production` and Sharp 0.35.4.

Main post-merge Run #271 evidence for `1a6c79fa81c9bd711079abf40009a728591b2237`:
- Windows Native Release: PASS,
- Godot + Backend + Web + Chromium: PASS,
- first GitHub-hosted Windows + Microsoft Edge attempt: FAIL only in Heavy Strike positioning setup at `gap=12.96`,
- targeted retry of only the failed Edge job on the same SHA: PASS with no code or gameplay changes,
- Deploy Web Demo: PASS,
- Verify Public Web Demo: PASS,
- Verify Production AI Backend Readiness: PASS in explicit safe-disabled mode with exact deployed revision,
- Windows Edge Production Full Smoke: PASS against `https://ws951125.github.io/custom-fighter/`,
- production logs include `WEB_MATCH_RESTART_SMOKE_PASSED victory=true restart=true returnCreator=true`,
- production Heavy Strike logs include `WEB_MELEE_SKILL_SMOKE_PASSED ... hitGap=88.89 ...`, proving valid authored geometry and gameplay outcome on the real Pages deployment,
- the same production Edge suite passed multi-skill, area, formation, buff, melee, coordination, character/profile/loadout/selection/animation, Creator, skill editor, preview, VFX/runtime, AI VFX, remote/reference AI VFX, AI skill proposal, package/package VFX and mobile-control regressions.

Current external blocker:
- obtain/configure a server-side `GEMINI_API_KEY` from a Gemini Developer API Free Tier project,
- verify in Google AI Studio / the associated Google Cloud project that paid billing is disabled,
- only then set `GEMINI_FREE_TIER_PROJECT_VERIFIED=true` and switch `AI_IMAGE_PROVIDER=gemini`,
- run the manual real Free Tier production E2E before declaring P3 complete.

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
- configure and verify the server-side Free Tier Gemini credential,
- real reference image + prompt → production backend → generated VFX + skill proposal,
- explicit user confirmation,
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
10. verify the Render backend is healthy, serving the expected revision, and either safely disabled or fully verified/configured for free Gemini,
11. run the full `smoke:all` suite against the real GitHub Pages deployment in Microsoft Edge,
12. real Gemini generation is a separate manual acceptance gate and must never be inferred from safe-disabled deployment health.

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
- finish P3 by configuring and verifying the real Free Tier Gemini credential and completing real-provider acceptance,
- finish P4 with real reference-image → VFX + skill proposal → explicit confirmation → Training cast production E2E.