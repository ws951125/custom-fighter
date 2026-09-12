# Project Status

## Current phase

Milestone 4 — Creator Studio.

Current active slice: Issue #52 / M4 Slice 1 — Creator Studio shell and validated character draft editor.

Estimated whole-project completion: **44.4%** across the M0–M8 MVP roadmap under the repository rule that only formally completed milestones count toward the fixed milestone denominator. M0, M1, M2 and M3 are complete; M4 is in progress.

## Completed milestones

### Milestone 0 — Foundation — 100%

- Godot 4.7.2 project foundation.
- GitHub Actions cloud validation.
- Web release export and GitHub Pages deployment.
- PWA/service-worker caching, startup diagnostics and Web size budgets.
- GitHub-only development and validation rules in `AGENTS.md`, `Agent.md` and `docs/ONLINE_TESTING.md`.

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
- `CharacterMovementTuning` makes CharacterDefinition the movement source of truth while fixed-distance dash semantics remain stable.
- `CharacterVisualProfile` safely owns palette/body/weapon dimensions.
- `SkillRegistry` safely resolves approved data-driven skill ids and rejects unsafe/unknown/type-mismatched references.
- `CharacterRegistry` removes the fixed production character-file selection boundary.
- Two official reference characters are available entirely from content data: `ember_vanguard_001` / Ember Vanguard and `storm_duelist_001` / Storm Duelist.
- Web runtime safely supports `?character=<id>` and fail-closed fallback for invalid selections.
- `CharacterAnimationMap` safely maps runtime semantic states to character-owned animation ids.
- Ember Vanguard and Storm Duelist use distinct approved animation maps without character-specific core-combat edits.
- PR #45 / Slice 4, PR #49 / Slice 5 and PR #51 / Slice 6 all passed GitHub-only validation before merge.
- Main CI Run #98 for merged PR #51 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all`, GitHub-hosted Windows Edge, GitHub Pages deployment, public reachability and production Edge real-game flow.
- Issue #50 is closed completed after production validation.

M3 acceptance is satisfied: a normal character can be added from approved content data without editing core combat code.

## Current work — Issue #52 / M4 Slice 1

Goal: establish the first non-programmer Creator Studio editing path while preserving the existing runtime schemas and security boundaries.

Implemented on `feature/m4-creator-character-editor-shell`:

- Adds application-level routing. The default URL remains Training; `?mode=creator` opens Creator Studio.
- Adds a Godot-native Creator Studio Character Editor shell.
- Adds data-only in-memory `CharacterDraft`, which serializes to the existing `CharacterDefinition` schema and delegates validation to `CharacterDefinition` itself.
- First editable fields: Character ID, Display Name, Archetype, Max HP, Max MP and Move Speed.
- Keeps approved starter defaults explicit for depth/run/guard movement tuning, visual profile, animation map and all six skill slots.
- Shows live VALID / INVALID state and readable validation errors.
- Adds `Reset Draft` and `Back to Training` buttons.
- This slice is deliberately non-persistent: no filesystem save, package export or user-supplied code execution.
- Adds Web diagnostics plus a narrow data-only automation bridge for CI validation of valid → invalid → valid → reset state transitions.
- Adds `creator_character_draft_test_runner.gd` and `creator_studio_web_smoke.mjs`.
- Adds Creator Studio browser smoke to `smoke:all` and the draft domain runner to GitHub Actions.

Validation status:

- Initial implementation and CI wiring are committed on the feature branch.
- M4 Slice 1 PR creation and GitHub Actions validation are the next gate.
- No user-local machine, local project execution or Remote Desktop Commander validation is permitted or used.

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

Creator Studio target URL after M4 Slice 1 reaches production:

`https://ws951125.github.io/custom-fighter/?mode=creator`

Production currently contains completed M3. M4 Slice 1 is not in production until its PR is validated, merged and the main deployment completes.

## Remaining roadmap

- M4 — finish Creator Studio basics: character editor, skill editor, validation and preview/training workflow.
- M5 — User VFX import/processing and VFX Creator.
- M6 — AI-assisted VFX provider layer.
- M7 — Character package import/export with safe data-only packages.
- M8 — Web MVP release and release hardening.
