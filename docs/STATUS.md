# Project Status

## Current phase

Milestone 5 — VFX Creator is the current roadmap milestone.

Current active slice: **Issue #60 / PR #63 — M5 Slice 1: safe PNG VFX import and preview foundation** on `feature/m5-png-vfx-import-preview-resume`.

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

### Issue #60 / PR #63 — safe PNG VFX import and preview foundation

The original work started on `feature/m5-png-vfx-import-preview` before mobile playability was prioritized. After Mobile Slice 1 reached production, M5 resumed from current `main` on `feature/m5-png-vfx-import-preview-resume` so the implementation includes the production mobile controls and does not fork from stale pre-mobile state.

Implemented on the resumed branch:

- Versioned data-only `VfxDraft` with PNG MIME/dimension validation.
- Crop, scale, offset and FPS authoring metadata with live validation.
- Single-frame PNG Slice 1 constraint and 4096 px dimension ceiling.
- `VfxStudio` Creator page and `?mode=vfx` app-router mode.
- Creator Studio now has a `VFX Creator` navigation path into the VFX editor.
- Web `Choose PNG` flow uses a browser image-only file picker, 5 MB limit and in-memory `FileReader` transfer.
- Godot re-validates the transfer as a base64 `data:image/png` payload, decodes bytes with `Image.load_png_from_buffer`, derives real dimensions from decoded image content and rejects unsupported/invalid payloads fail-closed.
- Imported image bytes and preview texture remain memory-only; the slice does not write imported files to the repository or execute imported content.
- VFX preview uses the decoded `ImageTexture`; validated crop is applied through `AtlasTexture`.
- Scale, offset and FPS are currently validated authoring metadata and diagnostics; visual application of those properties can be extended in a later M5 slice.
- Editable controls: Crop X/Y/W/H, Scale, Offset X/Y and FPS.
- Reset VFX Draft clears the imported in-memory texture and metadata.
- Web diagnostics expose import state, validation state, filename/MIME/dimensions, crop, scale, offsets, FPS and error state.
- Narrow automation bridges cover Creator→VFX navigation, deterministic PNG import, crop/scale changes and reset.
- `creator_vfx_draft_test_runner.gd` covers the data/safety contract.
- `creator_vfx_editor_web_smoke.mjs` starts from Creator, enters VFX Studio through the real navigation bridge, proves unsupported executable-like input fails closed, imports a deterministic PNG through the real decode boundary, validates crop invalid/valid transitions, validates scale invalid/valid transitions and reset.
- VFX domain/browser tests are wired into the existing GitHub-only CI gates.

Validation status:

- Initial PR #63 CI Run #119 had one isolated hosted Windows Edge readiness timeout in unchanged Character Selection smoke. No M5 VFX failure was present; this is recorded as `L-007` in `docs/LESSONS_LEARNED.md`.
- Latest implementation head CI Run #126 passed Godot import, main boot, all domain tests, Web export, size budget, Chromium `smoke:all` and GitHub-hosted Windows Microsoft Edge `smoke:all`.
- Chromium VFX smoke reported `WEB_CREATOR_VFX_EDITOR_SMOKE_PASSED navigation=true failClosed=true pngDecode=true cropValidation=true scaleValidation=true reset=true`.
- Documentation sync commits after Run #126 require one final latest-head PR CI before PR #63 can be marked ready and merged.
- PR #63 remains feature-branch-only; no M5 VFX functionality is production-deployed yet.

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

- Finish Issue #60 / PR #63 production validation and merge the safe PNG VFX Creator foundation.
- Continue M5 with image-sequence/animation authoring and skill VFX binding, including visual application of authored transform/timing metadata where appropriate.
- M6 — AI-assisted VFX provider layer.
- M7 — safe character package import/export.
- M8 — Web/Windows MVP release hardening, including final mobile usability/polish.
