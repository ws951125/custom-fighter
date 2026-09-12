# Project Status

## Current phase

Milestone 3 — Data-driven Character System.

Current active slice: Issue #41 — data-driven visual and body profiles.

Estimated whole-project completion: **38%** across the M0–M8 MVP roadmap. This is an engineering progress estimate based on completed milestone scope, not elapsed time.

## Completed

### Milestone 0 — Foundation — 100%

- Godot 4.7.2 project foundation.
- GitHub Actions cloud validation.
- Web release export and GitHub Pages deployment.
- PWA/service-worker caching, startup diagnostics and Web size budgets.
- Cloud-first development rules in `AGENTS.md`.

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

Issue #36 / M3 Slice 1 is production-validated on main commit `cef8db2d036e4137e626108e3c59c4a0ed73dc71`:

- Versioned, validated, data-only `CharacterDefinition`.
- First official balanced fighter: `ember_vanguard_001` / Ember Vanguard.
- Player max HP/MP initialize from character data.
- Character JSON contains validated movement tuning, visual profile and six skill-slot references.
- Unsafe script/code-style fields and unsafe skill-reference tokens are rejected.
- Character identity/stats/loadout are exposed through Web diagnostics.

Issue #37 / M3 Slice 2 is production-validated on main commit `31452cbdff76a44ed94d6e5444816bc9b73f3eb8`:

- `CharacterMovementTuning` converts the established M1 balanced movement baseline into CharacterDefinition-backed final displacement without duplicating the runtime.
- Normal horizontal movement, depth movement, run multiplier and guard movement multiplier are sourced from the loaded character definition.
- K standard dash and I Dash Slash keep fixed-distance semantics.
- Battle Focus composes on top of character movement through one runtime movement path.
- Windows Edge regression proves 360 px/s baseline movement and 522 px/s while the 1.45x Battle Focus multiplier is active.
- Godot domain tests, Chromium, Windows Edge, GitHub Pages, public URL and production Edge all pass.

## Current work

Issue #41 adds data-driven visual/body profiles:

- `CharacterVisualProfile` is a versioned, validated, data-only profile format resolved by safe token id.
- `training_blue.profile.json` preserves the current Ember Vanguard baseline look while moving palette and body measurements out of hard-coded runtime drawing values.
- Player rendering uses the loaded profile for body/accent/weapon/guard colors, head and torso size, arms, legs, shadow and weapon dimensions.
- Training dummy stays on the legacy renderer so this slice only changes the playable-character profile boundary.
- Unsafe profile references, executable-style fields, malformed colors and out-of-range body values are covered by domain regression.
- Browser diagnostics expose the resolved profile identity and measurements and record profile-backed renderer calls.

## Online validation

The production pipeline verifies:

- Godot import and main-scene boot.
- Domain/data tests.
- Web release export and build-size budget.
- Chromium `smoke:all`.
- Windows Microsoft Edge `smoke:all` against the same artifact.
- GitHub Pages deployment and public reachability.
- Windows Edge `smoke:all` directly against the deployed production game.

Live demo:

`https://ws951125.github.io/custom-fighter/`

## Remaining roadmap

- M3 — finish Character System after visual/body profiles: character selection/loadout binding and authoring-readiness pass.
- M4 — Creator Studio basics.
- M5 — User VFX import/processing and VFX Creator.
- M6 — AI-assisted VFX provider layer.
- M7 — Character package import/export with safe data-only packages.
- M8 — Web MVP release and release hardening.
