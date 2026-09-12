# Project Status

## Current phase

Milestone 6 — AI-assisted VFX is the current roadmap milestone.

Current active slice: **Issue #70 — M6 Slice 2: Creator prompt/reference AI VFX workflow** on `feature/m6-ai-vfx-creator-workflow`.

Estimated whole-project completion: **66.7%** across the M0–M8 MVP roadmap. Under the repository rule, only formally completed milestones count toward the fixed milestone denominator. M0, M1, M2, M3, M4 and M5 are complete; M6 is in progress.

## Completed milestones

### M0 — Foundation — 100%

- Godot 4.7.2 project foundation.
- GitHub Actions cloud validation.
- Web export and GitHub Pages deployment.
- Browser smoke tests and build-size budget.
- GitHub-only engineering/validation policy.

### M1 — Combat Prototype — 100%

- 2.5D movement, run, jump, dash and guard.
- HP / MP state.
- Three-hit basic attack chain.
- Hitbox / hurtbox, hitstun, knockback, knockdown and recovery.
- Training dummy and browser regressions.

### M2 — Data-driven Skill Engine — 100%

Production-validated data-driven templates:

- `U` — Projectile.
- `I` — Dash Attack.
- `O` — Area Attack.
- `P` — Formation / Rain.
- `B` — Buff.
- `H` — Melee.

### M3 — Character System — 100%

- Versioned validated `CharacterDefinition`.
- Movement, visual, skill-registry and animation-map boundaries.
- Ember Vanguard and Storm Duelist reference characters.
- Safe `?character=<id>` Web selection and fail-closed fallback.
- M3 production validation completed through CI Run #98.

### M4 — Creator Studio — 100%

M4 satisfies its MVP acceptance: a non-programmer can create a basic character and projectile skill, validate both, preview them in Training, cast the authored projectile through the real runtime, and return to Creator without editing repository JSON.

Completed slices:

- Issue #52 / PR #53 — Character Editor.
- Issue #54 / PR #55 — Projectile Skill Editor.
- Issue #56 / PR #57 — validated Creator-to-Training preview session.

PR #57 merged to `main` at `2029de45c3430e1b30b85b87727e58091c246ab4`. Main CI Run #109 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all`, GitHub-hosted Windows Edge, GitHub Pages deployment, public reachability and production Edge real-game flow.

### M5 — VFX Creator — 100%

M5 satisfies its MVP acceptance: a player's own validated PNG / horizontal sprite-strip can become the real Creator Skill 1 projectile effect in Training without changing combat semantics.

Completed slices:

- Issue #60 / PR #63 — safe PNG VFX import and preview foundation.
- Issue #64 / PR #65 — bounded horizontal sprite-strip animation plus authored crop/scale/offset/FPS preview.
- Issue #66 / PR #67 — bind authored VFX to the real Creator projectile Training runtime.

Production functionality:

- PNG-only Web import with browser and Godot-side validation.
- 5 MB in-memory transfer ceiling and 4096 px bounded dimensions.
- Horizontal sprite strips up to the validated VFX frame ceiling.
- Crop, frame count, FPS, scale and offset authoring.
- Creator -> VFX Creator -> Creator state preservation in memory.
- Valid authored VFX binding to Creator Skill 1.
- Real `U` projectile renders authored frames at runtime while damage, MP, cooldown, range, collision, hitstun and knockback remain governed by existing skill runtime data.
- Reset/invalid VFX clears stale bindings fail-closed.
- Normal Training keeps its prototype VFX.

Validation:

- PR #67 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Microsoft Edge `smoke:all` before merge.
- PR #67 merged to `main` at `7208e35f05556e5cb852fa321bb05a2c8fbdff41`.
- Main CI Run #134 passed all five production gates: Godot + Web + Browser, hosted Windows Edge, GitHub Pages deploy, public reachability and production Windows Edge real-game flow.
- Issue #66 is closed completed.

## Completed cross-platform slice — Mobile touch controls

Issue #61 / PR #62 is production-validated and complete.

- Touch-capable Web sessions can use the Training HUD.
- `?mobile_controls=1` forces the HUD on and `?mobile_controls=0` forces it off.
- Left controls dispatch movement/run; right controls dispatch jump/attack/dash/guard and Skill 1–6.
- Layout is landscape-oriented and portrait mode shows a rotate hint.
- Main CI Run #118 passed production validation.

## M6 — AI-assisted VFX

### Completed Slice 1 — Issue #68 / PR #69 — provider-neutral AI VFX boundary

Production now includes:

- Versioned `AiVfxRequest` data contract for prompt, generation kind, optional validated reference PNG, requested frame count/size and FPS.
- Versioned `AiVfxResult` data contract for provider identity, request identity, status, generated PNG bytes/metadata and VFX-compatible output metadata.
- Replaceable `AiVfxProvider` adapter boundary with capability discovery.
- `AiVfxProviderRegistry` for provider registration and active-provider swapping without runtime/combat edits.
- Deterministic `MockAiVfxProvider` that creates an in-memory horizontal PNG sprite strip using Godot Image APIs only; it requires no network, secret or user-local machine.
- Provider output revalidation against the originating request and through existing `VfxDraft` rules before it is considered usable.
- Domain regression coverage for request validation, reference PNG validation, deterministic mock generation, provider swapping and tampered-result rejection.

Validation:

- PR #69 head `3f483b63083f7c79643c732e4811cb068e78b91c` passed PR CI Run #138, including Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and hosted Windows Edge `smoke:all`.
- PR #69 merged to `main` at `d1e15e473ce1f847e61f206b9af2e8b60424e4fd` and closed Issue #68 completed.
- Main CI Run #139 passed all five production gates.
- Follow-up documentation commit `7779f19a38910bcc8218e1af9debd7002af88428` also passed full main CI Run #140, including Pages/public/production Edge validation.

### Active Slice 2 — Issue #70 — Creator prompt/reference AI VFX workflow

Implementation underway on `feature/m6-ai-vfx-creator-workflow`:

- `ai_vfx_studio.gd` extends the existing VFX Creator without changing combat/runtime code.
- VFX Creator gains prompt / skill-description authoring.
- Optional reference PNG is limited to 5 MB, decoded by Godot, bounded to 4096 px and kept in memory only.
- Output controls are bounded to the active deterministic mock provider: Frames 1–8, frame width/height 8–128 and FPS 1–60.
- Generate / Regenerate constructs the production `AiVfxRequest`, uses `AiVfxProviderRegistry`, and rejects invalid provider results fail-closed.
- Generated PNG bytes are decoded again, converted through the existing `VfxDraft`, then enter the same preview/session binding pipeline used by player-imported M5 VFX.
- Web diagnostics expose provider, prompt/reference state, requested output geometry, generation count/request id/status and generated-valid state.
- New browser regression covers empty-prompt rejection, real reference-PNG decoding, generation, regeneration, VFX preview animation, Creator binding and real Skill 1 projectile rendering/hit behavior.
- The VFX scene is now wired through the derived AI studio script on this feature branch.

A real cloud provider remains out of scope for this slice; the UI depends only on the provider-neutral adapter and must continue to work without network or secrets.

## Online validation policy

All project validation remains on GitHub-hosted infrastructure and the deployed GitHub Pages build:

- Godot import and main-scene boot.
- Domain/data tests.
- Web release export and build-size budget.
- Chromium `smoke:all`.
- GitHub-hosted Windows Microsoft Edge `smoke:all`.
- GitHub Pages deployment and public reachability after merge.
- Production Edge real-game flow after deployment.

If a required GitHub gate is unavailable or failing, record it as Blocked / Residual Risk rather than falling back to the user's computer.

## Production links

Training:

`https://ws951125.github.io/custom-fighter/`

Creator Studio:

`https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator:

`https://ws951125.github.io/custom-fighter/?mode=vfx`

Production currently contains the completed M0–M5 scope, mobile touch controls, and M6 Slice 1 provider boundary. Issue #70 Slice 2 AI authoring UI is feature-branch-only until PR validation, merge and production deployment complete.

## Remaining roadmap

- Complete Issue #70 prompt/reference generation workflow and production validation.
- Formally evaluate M6 acceptance after Slice 2: reference image + prompt -> usable skill VFX through a replaceable provider boundary.
- M7 — safe character package import/export.
- M8 — Web/Windows MVP release hardening, including final mobile usability/polish.
