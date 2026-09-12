# Project Status

## Current phase

Milestone 5 — VFX Creator is the current roadmap milestone.

Current active slice: **Issue #60 — M5 Slice 1: safe PNG VFX import and preview foundation** on `feature/m5-png-vfx-import-preview-resume`.

Estimated whole-project completion: **55.6%** across the M0–M8 MVP roadmap. Under the repository rule, only formally completed milestones count toward the fixed milestone denominator. M0, M1, M2, M3 and M4 are complete; M5 is in progress.

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

PR #57 merged to `main` at `2029de45c3430e1b30b85b87727e58091c246ab4`. Main CI Run #109 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all`, GitHub-hosted Windows Edge, GitHub Pages deployment, public reachability and production Edge real-game flow. Issue #56 is closed completed.

## Completed cross-platform slice — Mobile touch controls

Issue #61 / PR #62 is production-validated and complete.

- Adds `MobileControls` as a Training HUD layer for touch-capable Web sessions.
- Normal phone sessions auto-enable the touch HUD; `?mobile_controls=1` forces it on and `?mobile_controls=0` forces it off.
- Left-side controls dispatch existing `move_left`, `move_right`, `move_up`, `move_down` and `run` actions.
- Right-side controls dispatch existing `jump`, `attack`, `dash`, `guard` and `skill_1` through `skill_6` actions.
- Held controls use `Input.action_press()` / `Input.action_release()` and therefore reuse the existing gameplay path rather than creating mobile-only combat logic.
- Layout is landscape-oriented and portrait mode shows a rotate hint.
- Browser diagnostics and deterministic automation cover touch auto-detection, sustained movement, guard, jump, attack, Skill 1 and desktop-hidden behavior.
- PR #62 latest-head CI Run #117 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` including mobile touch flow, and GitHub-hosted Microsoft Edge `smoke:all`.
- PR #62 merged to `main` at `2c4ed4faf5689f20ba1871311451d417e5c60b64`.
- Main CI Run #118 passed Godot/Web/Chromium, hosted Windows Edge, GitHub Pages deployment, public reachability and production Windows Edge real-game flow.
- Issue #61 is closed completed.
- The mobile capability-testing lesson is recorded as `L-006` in `docs/LESSONS_LEARNED.md`.

## M5 — VFX Creator

### Issue #60 — safe PNG VFX import and preview foundation

The original work started on `feature/m5-png-vfx-import-preview` before mobile playability was prioritized. After Mobile Slice 1 reached production, M5 work resumed from current `main` on `feature/m5-png-vfx-import-preview-resume` so it includes the production mobile controls and does not fork from stale pre-mobile state.

Restored on the resumed branch:

- Versioned data-only `VfxDraft`.
- PNG MIME and dimension validation.
- Crop, scale, offset and FPS validation.
- Single-frame PNG Slice 1 constraint.
- Oversized/unsupported input rejection.
- `creator_vfx_draft_test_runner.gd` domain coverage.
- GitHub Actions wiring for the VFX draft test.

Next implementation target:

- Creator VFX Editor navigation and UI.
- Safe Web PNG file-input boundary.
- Decode/validate PNG dimensions before preview.
- In-memory Texture preview only; no repository writes or executable player content.
- Editable crop / scale / offset / FPS controls with live validation.
- Deterministic Web diagnostics and Chromium / hosted Edge regressions.

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

Production includes completed M4 and the production-validated Mobile Slice 1 touch HUD. M5 VFX Creator remains feature-branch-only until Issue #60 validation, merge and production deployment complete.

## Remaining roadmap

- Continue M5 Issue #60: PNG/image-sequence VFX import, crop/scale/offset/FPS authoring, preview and skill VFX binding.
- M6 — AI-assisted VFX provider layer.
- M7 — safe character package import/export.
- M8 — Web/Windows MVP release hardening, including final mobile usability/polish.
