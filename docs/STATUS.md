# Project Status

## Current phase

Milestone 3 — Data-driven Character System.

Current active slice: Issue #36 — CharacterDefinition + first data-driven fighter.

Estimated whole-project completion: **36%** across the M0–M8 MVP roadmap. This is an engineering progress estimate based on completed milestone scope, not elapsed time.

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

Shared JSON data controls MP, cooldown, cast timing and template-specific combat parameters. One shared `SkillCoordinator` owns cross-skill exclusivity for U/I/O/P/B/H and prevents same-frame double-casts. M1 movement, guard and basic attacks observe the same busy state. Chromium, Windows Edge, GitHub Pages deployment and production Edge gameplay are green on main commit `491536cac6b8a80b02e097874be77b91bbe2df92`.

## Current work

Issue #36 starts M3 with a versioned, validated `CharacterDefinition`:

- Data-only character schema under `game/core/character/`.
- First official balanced fighter definition: `ember_vanguard_001`.
- Base resources and movement tuning fields stored in character JSON.
- Six skill-slot references point at the completed M2 skill ids.
- Player max HP/MP are initialized from CharacterDefinition.
- Web diagnostics expose character identity, resources, movement tuning and skill slots.
- Dedicated Godot domain tests and browser regression protect the data boundary.

Issue #37 is the next M3 slice and will route the remaining hard-coded movement constants through CharacterDefinition after Slice 1 is green.

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

- M3 — finish Character System: CharacterDefinition integration, movement tuning, visual/body profiles, character selection/loadout binding and authoring-readiness pass.
- M4 — Creator Studio basics.
- M5 — User VFX import/processing and VFX Creator.
- M6 — AI-assisted VFX provider layer.
- M7 — Character package import/export with safe data-only packages.
- M8 — Web MVP release and release hardening.
