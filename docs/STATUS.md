# Project Status

## Current phase

Milestone 5 — VFX Creator is the current roadmap milestone.

At the user's request, active implementation is temporarily focused on **Issue #61 / PR #62 — Mobile Slice 1: touch controls for playable phone Web build**. The existing M5 Slice 1 work in Issue #60 / `feature/m5-png-vfx-import-preview` is preserved and paused, not discarded.

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

## M5 — VFX Creator

### Issue #60 — safe PNG VFX import and preview foundation

Work started on `feature/m5-png-vfx-import-preview` before the mobile-control priority change.

Implemented there so far:

- Versioned data-only `VfxDraft`.
- PNG MIME and dimension validation.
- Crop, scale, offset and FPS validation.
- Single-frame PNG Slice 1 constraint.
- Oversized/unsupported input rejection.
- Domain-test runner and CI wiring.

This branch is currently paused while Issue #61 is completed. It will resume after the phone-playability slice is production-safe.

## Active work — Issue #61 / PR #62 / Mobile Slice 1

Goal: make the existing GitHub Pages Training build playable from a phone without a hardware keyboard while leaving desktop keyboard gameplay unchanged.

Implemented on `feature/mobile-touch-controls`:

- Adds `MobileControls` as a Training HUD layer.
- Automatically enables on touch-capable Web sessions.
- Supports deterministic `?mobile_controls=1` enable and `?mobile_controls=0` disable overrides for hosted-browser validation.
- Left movement pad dispatches existing `move_left`, `move_right`, `move_up`, `move_down` and `run` Input actions.
- Right action pad dispatches existing `jump`, `attack`, `dash`, `guard` and `skill_1` through `skill_6` Input actions.
- Held actions use `Input.action_press()` / `Input.action_release()` so mobile does not fork combat logic.
- Adds landscape-oriented layout plus a portrait rotate hint.
- Browser capability results are normalized through a numeric JS→GDScript contract (`1/0`) before deciding touch capability / visibility.
- Adds Web diagnostics and narrow `customFighterMobilePress` / `customFighterMobileRelease` automation bridges.
- Adds `mobile_controls_web_smoke.mjs` covering forced deterministic enablement, touch auto-detection, sustained movement, guard, jump, attack, Skill 1 and desktop-hidden behavior.
- Adds `smoke:mobile` to `smoke:all`, so Chromium and GitHub-hosted Windows Edge both exercise the mobile-control path.

Validation status:

- PR #62 CI Run #113 failed only in the first version of `smoke:mobile`: the initial readiness wait combined Godot startup, Playwright mobile emulation, touch auto-detection, HUD enablement and bridge readiness into one opaque assertion and timed out after all earlier gates/regressions had passed.
- Touch detection and the hosted-browser test were hardened. Functional gameplay now uses `?mobile_controls=1` as a deterministic gate, production auto-detection is validated separately with a touch-enabled browser context, `?mobile_controls=0` proves desktop-hidden behavior, and readiness snapshots/page errors are printed for diagnosis.
- The solved testing issue is recorded as `L-006` in `docs/LESSONS_LEARNED.md`.
- PR #62 CI Run #115 passed Godot import, main boot, domain tests, Web export, size budget, Chromium `smoke:all` including the mobile flow, and GitHub-hosted Windows Microsoft Edge `smoke:all`.
- Documentation sync commits after Run #115 require one fresh latest-head PR CI before merge. No user-local machine, local project execution or Remote Desktop Commander validation is permitted or used.

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

Production currently includes completed M4. Mobile touch controls remain feature-branch-only until PR #62 latest-head validation, merge and production deployment complete.

## Remaining roadmap

- Finish Issue #61 / PR #62 and production-validate mobile touch gameplay.
- Resume M5 Issue #60: PNG/image-sequence VFX import, crop/scale/offset/FPS authoring, preview and skill VFX binding.
- M6 — AI-assisted VFX provider layer.
- M7 — safe character package import/export.
- M8 — Web/Windows MVP release hardening, including final mobile usability/polish.
