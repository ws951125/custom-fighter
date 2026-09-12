# Project Status

## Current phase

Milestone 4 — Creator Studio.

Current active slice: Issue #54 / M4 Slice 2 — validated projectile SkillDraft editor.

Estimated whole-project completion: **44.4%** across the M0–M8 MVP roadmap under the repository rule that only formally completed milestones count toward the fixed milestone denominator. M0, M1, M2 and M3 are complete; M4 is in progress.

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
- PR #45 / Slice 4, PR #49 / Slice 5 and PR #51 / Slice 6 all passed GitHub-only validation before merge.
- Main CI Run #98 for merged PR #51 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all`, GitHub-hosted Windows Edge, GitHub Pages deployment, public reachability and production Edge real-game flow.

M3 acceptance is satisfied: a normal character can be added from approved content data without editing core combat code.

## Milestone 4 — completed slices

Issue #52 / PR #53 / M4 Slice 1 is production-validated and merged to `main` at `5b55a8b14afb4d810770d3dffa0bdc33c2c8d9f6`:

- Adds application-level routing. The default URL remains Training; `?mode=creator` opens Creator Studio.
- Adds a Godot-native Creator Studio Character Editor shell.
- Adds data-only in-memory `CharacterDraft`, validated through the existing `CharacterDefinition` contract.
- Editable fields include Character ID, Display Name, Archetype, Max HP, Max MP and Move Speed.
- Shows live VALID / INVALID state and readable errors.
- Adds Reset Character Draft and Back to Training.
- Keeps this authoring path data-only and non-persistent; no package export or arbitrary user code execution.
- PR CI Run #99 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Edge.
- Main CI Run #100 passed the same gates plus GitHub Pages deployment, public reachability and production Microsoft Edge real-game flow, including the Creator Studio browser regression.
- Issue #52 is closed completed after production validation.

## Current work — Issue #54 / M4 Slice 2

Goal: establish the first non-programmer skill-authoring path using the same runtime `SkillDefinition` contract.

Implemented on `feature/m4-projectile-skill-editor`:

- Adds data-only in-memory `SkillDraft` for the projectile template.
- Starter projectile serializes to the existing SkillDefinition schema and validates through `SkillDefinition`.
- Creator Studio now switches between Character Editor and Skill Editor while the default application route remains Training.
- Projectile fields include Skill ID, Display Name, Damage, MP Cost, Cooldown, Startup, Active, Recovery, Projectile Speed, Range, Hitstun and Knockback.
- Approved starter hitbox/visual identifiers remain explicit and are not treated as arbitrary paths or executable content.
- Adds live VALID / INVALID state and readable SkillDefinition validation errors.
- Adds Reset Skill Draft; Slice 2 remains in-memory/non-persistent.
- Extends the narrow Web automation bridge and diagnostics for deterministic hosted-browser validation.
- Adds `creator_skill_draft_test_runner.gd` domain regression and `creator_skill_editor_web_smoke.mjs` browser regression.
- Adds the SkillDraft runner to GitHub Actions and the Skill Editor smoke to `smoke:all`.

Validation status:

- Slice 2 implementation and CI wiring are committed on the feature branch.
- PR creation and GitHub Actions validation are the next gate.
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

Live Creator Studio:

`https://ws951125.github.io/custom-fighter/?mode=creator`

Production currently contains M4 Slice 1 / PR #53. Slice 2 is not in production until its PR is validated, merged and the main deployment completes.

## Remaining roadmap

- M4 — finish Creator Studio basics: broaden skill templates, parameter validation and preview/training workflow.
- M5 — User VFX import/processing and VFX Creator.
- M6 — AI-assisted VFX provider layer.
- M7 — Character package import/export with safe data-only packages.
- M8 — Web MVP release and release hardening.
