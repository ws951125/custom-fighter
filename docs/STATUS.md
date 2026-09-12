# Project Status

## Current phase

Milestone 3 — Data-driven Character System.

Current active slice: Issue #50 / M3 Slice 6 — data-driven animation mapping and final M3 acceptance.

Estimated whole-project completion: **33.3%** across the M0–M8 MVP roadmap under the repository rule that only formally completed milestones count toward the fixed milestone denominator. M0, M1 and M2 are complete; M3 is still in progress until Slice 6 is production-validated.

## Completed

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

### Milestone 3 — completed slices

Issue #36 / M3 Slice 1:

- Versioned, validated, data-only `CharacterDefinition`.
- First official fighter: `ember_vanguard_001` / Ember Vanguard.
- Character-backed HP/MP, movement data, visual profile reference and six skill-slot references.
- Unsafe script/code-style fields and unsafe references are rejected.

Issue #37 / M3 Slice 2:

- `CharacterMovementTuning` makes CharacterDefinition the movement source of truth.
- Normal movement, depth movement, run and guard movement use character data.
- K standard dash and I Dash Slash retain fixed-distance semantics.
- Battle Focus composes through the same runtime movement path.

M3 visual/body-profile slice:

- Versioned, validated, data-only `CharacterVisualProfile`.
- `training_blue.profile.json` drives playable-character palette/body/weapon dimensions.
- Unsafe references, executable-style fields, malformed colors and out-of-range values are rejected.

Issue #44 / PR #45 / M3 Slice 4 is production-validated and merged to `main` at `6a83454a66cf23cc1bb3c2e0ef6c630fbf1a50d4`:

- Adds validated `SkillRegistry` plus `content/skills/registry.json` allow-list mapping.
- CharacterDefinition skill slots are the runtime source of truth for all six skills.
- Unsafe ids, unknown ids, arbitrary registry paths/fields and controller/type mismatches fail closed.
- Runtime skill ids/types/sources and loadout-ready state are exposed to Web diagnostics.
- CI Run #93 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Edge.
- Main CI Run #94 passed the same gates, GitHub Pages deployment, public reachability and production Edge real-game flow.
- The frame-polled input regression from Run #87 is fixed and recorded as Verified in `docs/LESSONS_LEARNED.md` L-002.

Issue #46 / PR #49 / M3 Slice 5 is production-validated and merged to `main` at `742767eff3e8bba245b3bfca3eb74b406471321b`:

- Adds validated, data-only `CharacterRegistry` and `content/characters/registry.json`.
- Removes the fixed production character-file selection boundary.
- Adds `storm_duelist_001` / Storm Duelist as the second official reference fighter with distinct stats, `storm_violet` visual profile and `training_bolt_001` in skill slot 1.
- Web builds safely select an approved character using `?character=<id>`; unsafe/unknown ids never become resource paths and fall back to the registered default with diagnostics.
- PR CI Run #95 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Edge.
- Main CI Run #96 passed the same gates plus GitHub Pages deployment, public reachability and production Edge real-game flow.
- Issue #46 is closed as completed after production validation.

## Current work — Issue #50 / M3 Slice 6

Goal: complete the remaining M3 animation-mapping contract and prove the character system is authoring-ready without character-specific core combat edits.

Implemented on `feature/m3-animation-mapping`:

- Adds validated, data-only `CharacterAnimationMap` with a fixed semantic allow-list for ready, walk, run, jump, dash, guard, the three basic-attack steps and all six skill slots.
- Adds `ember_vanguard.animation.json` and `storm_duelist.animation.json` with distinct approved animation ids.
- Adds `animation_map` to CharacterDefinition; official reference characters explicitly select their own animation maps. Legacy/test character data without the field derives a safe token from the character id, while runtime loading still fails closed if no approved map file exists.
- Adds `animation_main.gd` as the production runtime layer above safe character selection. It resolves current movement/combat/skill semantics to the character-owned animation id through CharacterAnimationMap.
- Adds Web diagnostics for CharacterDefinition animation-map reference, loaded map id, current semantic, current animation id and load error.
- Unknown runtime semantics fall back only to the map's validated `ready` id; unsafe animation references/ids and executable-style fields are rejected.
- Adds `character_animation_test_runner.gd` domain regressions and `character_animation_web_smoke.mjs` browser regressions for Ember/Storm mapping plus Storm ready/walk/attack/skill state resolution.
- Adds the new domain runner and browser smoke to the GitHub-only CI gates.

Validation status:

- Implementation is committed on the feature branch.
- Slice 6 PR creation and GitHub Actions validation are the next gate.
- No user-local machine and no Remote Desktop Commander validation is permitted or used.

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

Live demo:

`https://ws951125.github.io/custom-fighter/`

Production currently contains Slice 5 / PR #49. Slice 6 is not in production until its PR is validated, merged and the main deployment completes.

## Remaining roadmap

- M3 — finish Character System: validate/merge Issue #50 animation mapping, complete production acceptance, then mark M3 complete.
- M4 — Creator Studio basics.
- M5 — User VFX import/processing and VFX Creator.
- M6 — AI-assisted VFX provider layer.
- M7 — Character package import/export with safe data-only packages.
- M8 — Web MVP release and release hardening.
