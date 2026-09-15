# Project Status

## Current phase

**Post-MVP P3/P4 production image-to-skill integration is in progress.**

Whole-project phase completion remains **84.6% (11/13 roadmap phases fully complete)** because P3 and P4 are not counted until each phase is fully accepted.

Roadmap:
- M0–M8 MVP: 9/9 complete.
- P1 Safe real-provider boundary: complete.
- P2 Async remote AI transport: complete.
- P3 Production AI provider/backend integration: in progress; source/backend integration and deterministic cloud acceptance are substantially complete, while real-provider production acceptance is blocked until at least one server-side production provider credential is configured.
- P4 Image → skill proposal → Creator → Training production flow: in progress; source flow and deterministic cloud E2E are substantially complete, while final real-provider production acceptance remains.

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

Implemented and production-hardened:
- trusted Node backend with `/healthz` and `/v1/vfx/generate`,
- provider-neutral server-side image provider factory,
- OpenAI image provider adapter,
- Gemini / Nano Banana image provider adapter using the Gemini Interactions API,
- `AI_IMAGE_PROVIDER=openai|gemini` server-side selection,
- OpenAI model override through `OPENAI_IMAGE_MODEL`,
- Gemini model override through `GEMINI_IMAGE_MODEL`,
- provider/model readiness reporting without exposing secrets,
- `/healthz` reports the selected provider plus readiness for all supported providers,
- `/healthz` also exposes the non-secret deployed Git revision so cloud acceptance can verify Render is serving the same `main` commit under test,
- Render service deployment at `https://custom-fighter-ai-vfx.onrender.com`, service ID `srv-daj3urfqj5pc73c5n9og`, Singapore, auto-deploy from `main`,
- main-push CI verifies Render reachability, GitHub Pages CORS, provider schema, supported OpenAI/Gemini readiness fields, and exact deployed revision alignment before final production browser acceptance,
- Creator remote-provider selection via validated HTTPS endpoint,
- Creator preflight readiness check before Generate,
- Generate is disabled while the backend is checking, unavailable, or selected provider credentials are not configured,
- async remote request path,
- strict CORS/body/output bounds,
- generation response revalidation,
- browser/runtime contains no provider credential,
- reference-image requests use the selected provider image-edit boundary,
- Godot request serialization matches the trusted backend contract,
- production errors fail closed,
- Render runtime uses `NODE_ENV=production`,
- production image pipeline dependency upgraded to `sharp 0.35.4`,
- Render production install audit: 0 vulnerabilities,
- GitHub Pages deployment/public reachability/production Edge full-smoke gates restored and accepted on main.

Current external blocker:
- a real production provider credential must be configured server-side on Render.
- For OpenAI: set `AI_IMAGE_PROVIDER=openai` and `OPENAI_API_KEY`.
- For Gemini: set `AI_IMAGE_PROVIDER=gemini` and `GEMINI_API_KEY`.
- Therefore a real provider generation request cannot yet be truthfully accepted as production E2E until one provider is configured.

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
- configure one real production provider secret,
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
10. verify the Render production backend is healthy, exposes the expected provider-readiness contract, permits the GitHub Pages origin, and is serving the exact `main` revision under acceptance,
11. run the full `smoke:all` suite against the real GitHub Pages deployment in Microsoft Edge.

Do not use Remote Desktop Commander, the user's local machine, local Godot/npm/browser caches, or user-device storage for validation unless the user explicitly reverses this policy.

Latest accepted cloud evidence:
- PR #117 latest-head CI Run #233: SUCCESS,
- PR #117 merged as `581c4fc77a715cedcb5450c8f7cefc4038293ab9`,
- main CI Run #234: SUCCESS,
- `Windows Native Release`: SUCCESS,
- `Godot + Backend + Web + Chromium`: SUCCESS,
- `Windows + Microsoft Edge`: SUCCESS,
- `Deploy Web Demo`: SUCCESS,
- `Verify Production AI Backend Readiness`: SUCCESS; Render health/provider schema/deployed revision matched the accepted `main` revision,
- `Verify Public Web Demo`: SUCCESS,
- `Windows Edge Production Full Smoke`: SUCCESS against the real GitHub Pages deployment,
- production provider credential remains an external blocker; readiness validation does not count as a real-provider generation acceptance.

## Execution policy

Once a roadmap phase is started, continue through all non-blocked implementation, regression, cloud validation, fixes, merge and documentation work for that phase. Do not stop merely because a slice, commit, PR or test group completed. Stop only at a genuine external blocker or a decision requiring explicit user approval. If one item is externally blocked, finish the other non-blocked work in the same phase first.

When continuous monitoring is requested, keep polling every required CI, deployment and production gate through terminal state. A completed sub-job or an `in_progress` run is not a stopping point. If a required validation fails, inspect the online evidence, fix it when permitted, and follow the replacement run through terminal state. Report only after the requested validation scope is complete or a genuine explicit-approval blocker is reached.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

AI VFX backend: `https://custom-fighter-ai-vfx.onrender.com`

## Remaining roadmap

To reach 13/13:
- finish P3 by configuring at least one real production provider secret and completing real-provider acceptance,
- finish P4 with real reference-image → VFX + skill proposal → explicit confirmation → Training cast production E2E.
