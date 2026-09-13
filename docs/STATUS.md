# Project Status

## Current phase

**Post-MVP P2 — Async remote AI VFX transport is complete.**

Estimated whole-project completion: **84.6% (11/13 roadmap phases)**.

The roadmap is now tracked as 13 phases:
- M0–M8 MVP: 9/9 complete.
- P1 Safe real-provider boundary: complete.
- P2 Async remote AI transport: complete.
- P3 Production AI provider/backend integration: not complete.
- P4 Image → skill proposal → Creator → Training end-to-end production flow: not complete.

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
Provider-neutral AI VFX request/result/provider boundary plus Creator prompt/reference Generate/Regenerate workflow. The production implementation remains provider-neutral and originally used deterministic mock generation.

### M7 — Character Packages — 100%
Versioned character package import/export with schema-v2 self-contained validated Skill 1 PNG/sprite-strip VFX and fail-closed package boundaries.

### M8 — MVP Release — 100%
Web release, Windows x86_64 release flow, release documentation and Creator → package → fresh-session import → Training acceptance.

## Post-MVP AI image-to-skill roadmap

### P1 — Safe real-provider boundary — 100%
Completed through Issue #84 / PR #85:
- validated provider configuration,
- `remote_ai_vfx` provider boundary,
- HTTPS-only endpoint validation,
- embedded URL credentials rejected,
- no provider secrets committed,
- mock provider preserved as deterministic fallback.

### P2 — Async remote AI transport — 100%
Completed through PR #86 and squash-merged to `main` at `7b193023221f6533339922c3bf7e5a31d94475af`.

Implemented:
- async Godot `HTTPRequest` transport for trusted backends,
- JSON request/response boundary,
- strict remote response decoding,
- Base64 PNG decoding and validation back into `AiVfxResult`,
- request/result matching and VFX draft revalidation,
- malformed/oversized/non-JSON/invalid-PNG output fails closed,
- synchronous mock path remains unchanged.

Local validation on the connected Windows machine using Godot 4.7.2:
- project import: PASS,
- main scene headless boot: PASS,
- core domain suite: PASS,
- character/registry/animation suites: PASS,
- Creator character/skill/preview/VFX draft suites: PASS,
- AI VFX provider suite: PASS,
- remote AI config/response codec suite: PASS,
- character package/self-contained package suites: PASS,
- formation/buff/melee regression suites: PASS.

The intentional invalid-input tests emit expected Godot PNG/Base64 decode diagnostics while still finishing with the corresponding `*_TESTS_PASSED` markers and overall exit code 0.

### P3 — Production provider/backend integration — 0%
Remaining:
- choose/configure the real backend/provider implementation behind the trusted endpoint,
- keep provider credentials outside browser/Git,
- wire Creator to select/use the remote provider,
- define production error/retry/timeout UX,
- validate real generated assets through the existing fail-closed data boundary.

### P4 — Image → skill production E2E — 0%
Remaining:
- reference image + optional description → generated animated VFX,
- propose validated skill parameters such as template/type, timing, damage, MP, cooldown, speed/range and visual binding,
- user preview/edit/accept step,
- bind to Creator character,
- enter Training and cast the generated skill,
- production end-to-end acceptance.

## Validation policy

Primary engineering validation is now **local-first** through Remote Desktop Commander on the connected Windows machine.

The local validation hierarchy is:
1. logic/unit tests,
2. Godot headless import/parse,
3. Godot integration/domain tests,
4. Web export when relevant,
5. local Chromium/Edge smoke when relevant,
6. Windows native export/smoke when relevant,
7. optional GitHub Pages deployment/public reachability when intentionally publishing.

GitHub Actions is now **manual-only** (`workflow_dispatch`) and is no longer a required gate for normal development unless the user explicitly requests cloud CI evidence.

Previously queued GitHub Actions runs may remain visible until GitHub terminates or completes them; they are no longer used as the blocking validation path.

## Completed cross-platform slice — Mobile touch controls

Issue #61 / PR #62 remains complete. Touch-capable Web sessions can use movement/run, jump/attack/dash/guard and Skill 1–6 controls; `?mobile_controls=1` forces the HUD on and `?mobile_controls=0` forces it off.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

The currently deployed production build contains the completed M0–M8 MVP. Post-MVP P1/P2 are merged in source; a new production deployment is not implied until intentionally published.

## Remaining roadmap

Whole-project roadmap remaining after P2:
- P3 Production AI provider/backend integration.
- P4 Image → skill → Creator → Training production end-to-end flow.
