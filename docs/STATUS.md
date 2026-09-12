# Project Status

## Current phase

Milestone 5 — VFX Creator is the current roadmap milestone.

Current active slice: **Issue #64 — M5 Slice 2: horizontal sprite-strip animation preview and authored transforms** on `feature/m5-sprite-strip-animation-preview`.

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
- Held controls reuse the existing gameplay input path.
- Layout is landscape-oriented and portrait mode shows a rotate hint.
- Browser diagnostics and deterministic automation cover touch auto-detection, sustained movement, guard, jump, attack, Skill 1 and desktop-hidden behavior.
- PR #62 merged to `main` at `2c4ed4faf5689f20ba1871311451d417e5c60b64`.
- Main CI Run #118 passed Godot/Web/Chromium, hosted Windows Edge, GitHub Pages deployment, public reachability and production Windows Edge real-game flow.
- Issue #61 is closed completed.

## M5 — VFX Creator

### Completed Slice 1 — Issue #60 / PR #63 — safe PNG VFX import and preview foundation

Production functionality:

- Versioned data-only `VfxDraft` with PNG MIME/dimension validation.
- Crop, scale, offset and FPS authoring metadata with live validation.
- Safe Web `Choose PNG` flow with image-only picker, 5 MB limit and in-memory `FileReader` transfer.
- Godot re-validates a base64 `data:image/png` payload, decodes with `Image.load_png_from_buffer`, derives real dimensions from decoded content and rejects unsupported/invalid input fail-closed.
- Imported bytes and textures remain memory-only; no repository write, arbitrary file path, script or executable player content is accepted.
- Creator `VFX Creator` page and `?mode=vfx` route.
- Cropped in-memory `ImageTexture` preview through `AtlasTexture`.
- Reset VFX Draft and deterministic Web diagnostics.
- Domain and Chromium/Windows Edge regression coverage.

Validation:

- PR #63 latest-head CI Run #128 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Microsoft Edge `smoke:all`.
- PR #63 merged to `main` at `f0c4574f556c1e9ca8b8ed710388da0b5f785900`.
- Main CI Run #129 passed all five production gates: Godot + Web + Browser, hosted Windows Edge, GitHub Pages deploy, public reachability and production Windows Edge real-game flow.
- Issue #60 is closed completed.
- Earlier isolated hosted-browser readiness behavior is recorded in `docs/LESSONS_LEARNED.md`; no production M5 regression remains open from Slice 1.

### Active Slice 2 — Issue #64 — horizontal sprite-strip animation preview and authored transforms

Implementation underway on `feature/m5-sprite-strip-animation-preview`:

- Extend `VfxDraft` from fixed single-frame metadata to a bounded horizontal-strip `frame_count` contract while retaining frame_count=1 compatibility.
- Derive equal frame width from the validated crop rectangle and reject non-divisible strips fail-closed.
- Animate preview frames left-to-right at authored FPS.
- Apply authored Scale and Offset X/Y to the actual Creator preview node instead of keeping them metadata-only.
- Add deterministic diagnostics for frame count, derived frame width, current frame and applied preview transform.
- Add Web automation bridges for frame count, FPS and offset.
- Extend existing VFX domain/browser regressions instead of creating a parallel test path.
- Preserve PNG-only, memory-only, data-only security boundaries.

Current implementation commits on the feature branch include:

- validated frame-count and strip-divisibility model changes;
- domain coverage for valid/invalid horizontal strips;
- animated VFX Studio preview with transform application;
- browser smoke coverage for strip validation, frame progression and applied scale/offset.

PR #65 implementation-head CI Run #130 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Microsoft Edge `smoke:all`. A documentation-sync latest-head CI is pending before merge. No user-local testing is allowed.

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

Production currently includes completed M4, production-validated Mobile Slice 1 controls and production-validated M5 Slice 1 safe PNG VFX import/preview. Issue #64 sprite-strip animation work remains feature-branch-only until PR validation, merge and production deployment complete.

## Remaining roadmap

- Complete Issue #64 horizontal sprite-strip animation preview and authored preview transforms.
- Continue M5 with binding validated authored VFX to Creator skills and the real Training runtime so a player's own visual becomes an in-game skill effect.
- M6 — AI-assisted VFX provider layer.
- M7 — safe character package import/export.
- M8 — Web/Windows MVP release hardening, including final mobile usability/polish.
