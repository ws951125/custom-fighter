# Project Status

## Current phase

Milestone 2 — Data-driven Skill Engine finalization.

Current active slice: Issue #34 — shared SkillCoordinator + authoring readiness.

Estimated whole-project completion: **35%** across the M0–M8 MVP roadmap. This is an engineering progress estimate based on completed milestone scope, not elapsed time.

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

### Milestone 2 — implemented skill templates

All six planned data-driven templates are implemented and production-validated individually:

- `U` — Projectile: `fireball_001`.
- `I` — Dash Attack: `dash_slash_001`.
- `O` — Area Attack: `arc_burst_001`.
- `P` — Formation / Rain: `blade_rain_001`.
- `B` — Buff: `battle_focus_001`.
- `H` — Melee: `heavy_strike_001`.

Shared JSON data controls MP, cooldown, cast timing and template-specific combat parameters. Existing skill and M1 gameplay regressions run in both Chromium and Windows Edge.

## Current work

Issue #34 finalizes M2 with a shared `SkillCoordinator`:

- U/I/O/P/B/H use one cross-skill exclusivity coordinator.
- M1 movement, guard and basic attacks observe the same skill-busy state.
- Same-frame simultaneous skill requests cannot double-spend MP or start two casts.
- Domain tests cover claim/reject/release ownership rules.
- Browser regression holds U + O together and verifies only one skill acquires the coordinator.
- PR validation has passed in Chromium and Windows Edge; production Pages validation is still required before M2 is declared complete.

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

- Finish Issue #34 production validation and close Milestone 2.
- M3 — Data-driven Character System.
- M4 — Creator Studio basics.
- M5 — User VFX import/processing and VFX Creator.
- M6 — AI-assisted VFX provider layer.
- M7 — Character package import/export with safe data-only packages.
- M8 — Web MVP release and release hardening.
