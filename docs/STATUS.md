# Project Status

## Current phase

Milestone 5 — VFX Creator.

Current active slice: Issue #60 / M5 Slice 1 — safe PNG VFX import and preview foundation.

Estimated whole-project completion: **55.6%** across the M0–M8 MVP roadmap under the repository rule that only formally completed milestones count toward the fixed milestone denominator. M0, M1, M2, M3 and M4 are complete; M5 is in progress.

## Completed milestones

### Milestone 0 — Foundation — 100%

- Godot 4.7.2 project foundation.
- GitHub Actions cloud validation.
- Web release export and GitHub Pages deployment.
- PWA/service-worker caching, startup diagnostics and Web size budgets.
- GitHub-only development and validation rules in `AGENTS.md`, `Agent.md`, `docs/ONLINE_TESTING.md` and `docs/MVP.md`.

### Milestone 1 — Combat Prototype — 100%

- 2.5D movement, run, jump, dash and guard.
- HP / MP state.
- Three-hit basic attack chain with input buffering.
- Hitbox / hurtbox, hitstun, knockback, knockdown and recovery.
- Browser-hitch-resistant combo timing.
- Training dummy and Chromium / Windows Edge regressions.
- Production GitHub Pages validation in Windows Edge.

### Milestone 2 — Data-driven Skill Engine — 100%

All six planned data-driven templates are implemented and production-validated:

- `U` — Projectile: `fireball_001`.
- `I` — Dash Attack: `dash_slash_001`.
- `O` — Area Attack: `arc_burst_001`.
- `P` — Formation / Rain: `blade_rain_001`.
- `B` — Buff: `battle_focus_001`.
- `H` — Melee: `heavy_strike_001`.

Shared JSON data controls MP, cooldown, cast timing and template-specific combat parameters. One shared `SkillCoordinator` owns cross-skill exclusivity for U/I/O/P/B/H and prevents same-frame double-casts. M1 movement, guard and basic attacks observe the same busy state.

### Milestone 3 — Character System — 100%

M3 is production-validated and accepted.

- Versioned, validated, data-only `CharacterDefinition` owns character identity, stats, movement tuning, visual profile, animation map and six skill slots.
- `CharacterMovementTuning`, `CharacterVisualProfile`, `SkillRegistry`, `CharacterRegistry` and `CharacterAnimationMap` provide safe data-driven runtime boundaries.
- Two official reference characters are available entirely from content data: `ember_vanguard_001` / Ember Vanguard and `storm_duelist_001` / Storm Duelist.
- Web runtime safely supports `?character=<id>` and fail-closed fallback for invalid selections.
- Main CI Run #98 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all`, GitHub-hosted Windows Edge, GitHub Pages deployment, public reachability and production Edge.

### Milestone 4 — Creator Studio — 100%

M4 acceptance is production-validated: a non-programmer can create a basic character and projectile skill, validate both, preview the authored data in Training, cast it through the real runtime, then return to Creator without editing repository JSON.

- Slice 1 / Issue #52 / PR #53: Character Editor with validated `CharacterDraft`.
- Slice 2 / Issue #54 / PR #55: Projectile Skill Editor with validated `SkillDraft`.
- Slice 3 / Issue #56 / PR #57: validated in-memory Creator → Training preview session and return-to-Creator loop.
- Preview uses the existing `CharacterDefinition` and `SkillDefinition` contracts and remains data-only; it does not execute player code or write repository content.
- PR #57 latest-head pre-merge CI passed Godot import/boot/domain tests, Web export/size budget, Chromium and GitHub-hosted Windows Edge.
- PR #57 merged to `main` at `2029de45c3430e1b30b85b87727e58091c246ab4`.
- Main CI Run #109 passed Godot + Web + Chromium, hosted Windows Edge, GitHub Pages deployment, public reachability and production Windows Edge real-game flow.
- Issue #56 is closed completed after production validation.

## Current work — Issue #60 / M5 Slice 1

Goal: establish the first safe PNG-based VFX authoring path while preserving the data-only security boundary.

Started on `feature/m5-png-vfx-import-preview`:

- Adds a versioned `VfxDraft` data model for imported PNG metadata and preview parameters.
- Validates PNG MIME type, image dimensions, single-frame Slice 1 scope, crop bounds, scale, offset and FPS.
- Rejects unsupported file types and unsafe/out-of-bounds metadata fail-closed.
- Adds `creator_vfx_draft_test_runner.gd` covering valid PNG metadata, unsupported MIME, unsafe crop, bad scale/FPS and oversized images.
- Adds the VFX draft domain test to the GitHub Actions domain gate.
- Image bytes/import UI and Creator preview rendering are the next implementation step; this slice remains in-memory and non-persistent.

## Online validation

The production pipeline verifies entirely on GitHub infrastructure:

- Godot import and main-scene boot on GitHub-hosted runners.
- Domain/data tests.
- Web release export and build-size budget.
- Chromium `smoke:all` against the exported artifact.
- Windows Microsoft Edge `smoke:all` on a GitHub-hosted Windows runner.
- GitHub Pages deployment and public reachability.
- Production browser smoke directly against the deployed game after merge.

If any required GitHub gate is unavailable, failing or blocked, the project records that state as `Blocked` / `Residual Risk`; it does not fall back to the user's local machine.

Live Training demo:

`https://ws951125.github.io/custom-fighter/`

Live Creator Studio:

`https://ws951125.github.io/custom-fighter/?mode=creator`

Production currently contains completed M4 Creator Studio, including the validated Creator → Training preview loop. M5 Slice 1 remains on its feature branch until its own PR validation, merge and production deployment complete.

## Remaining roadmap

- M5 — PNG/sprite-sheet import, crop/scale/offset/FPS, preview and VFX binding to skills.
- M6 — AI-assisted VFX provider layer.
- M7 — Character package import/export with safe data-only packages.
- M8 — Web MVP release and release hardening.
