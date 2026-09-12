# Project Status

## Current phase

Milestone 2 — Data-driven Skill Engine

Current active slice: Issue #27 — data-driven Buff skill template.

Estimated whole-project completion: **33%** across the M0–M8 MVP roadmap. This is an engineering progress estimate based on completed milestone scope, not elapsed time.

## Completed

### Milestone 0 — Foundation

- Public GitHub repository initialized.
- Godot 4.7.2 project foundation.
- Web-ready runtime and export pipeline.
- Cloud-first development/validation rules in `AGENTS.md`.
- GitHub Actions validation and GitHub Pages deployment.

### Milestone 1 — Combat Prototype

- 2.5D horizontal + depth movement.
- Run, jump and dash.
- Guard.
- HP / MP state.
- Three-hit basic attack chain.
- Explicit hitbox / hurtbox overlap.
- Hitstun and knockback.
- Knockdown, recovery and standing invulnerability.
- Training dummy.
- Keyboard input actions structured for future gamepad/touch mapping.
- Chromium and Windows Edge gameplay regressions.
- Production GitHub Pages gameplay validation in Windows Edge.

Milestone 1 tracker #3 is complete.

### Milestone 2 — completed skill templates

- Projectile: `fireball_001`, bound to `U`.
- Dash Attack: `dash_slash_001`, bound to `I`.
- Area Attack: `arc_burst_001`, bound to `O`.
- Formation / Rain: `blade_rain_001`, bound to `P`.
- Shared JSON-driven MP, cooldown and cast timing.
- Reusable projectile, dash, area and formation combat states.
- Formation strike scheduling and per-cell single-hit semantics.
- Skill-specific browser evidence while preserving Milestone 1 regressions.

Completed trackers:
- Area Attack #21.
- Formation / Rain #24.

Formation production evidence is validated on GitHub Pages in real Windows Edge.

## Verified online

The current production pipeline verifies:

- Godot 4.7.2 setup.
- Headless project import and main-scene boot.
- Domain/data tests.
- Web export and build-size budget.
- Chromium `smoke:all` against the exported build.
- Windows + Microsoft Edge `smoke:all` against the same validated artifact.
- GitHub Pages deployment from `main`.
- Public production URL reachability.
- Windows + Microsoft Edge `smoke:all` directly against the deployed GitHub Pages game.

Live demo:

`https://ws951125.github.io/custom-fighter/`

Latest gameplay baseline with Formation validated in production: `ef00ce3a2dd85694cdb4a6fe13d037d3ee36fb1a`.

## Current work

Issue #27 — Buff:

- JSON-driven `battle_focus_001` sample.
- Skill 5 bound to `B`.
- Timed self-buff with JSON-driven duration.
- JSON-driven movement-speed multiplier.
- JSON-driven basic-attack damage multiplier.
- Automatic restoration to baseline after expiration.
- Runtime aura/HUD feedback and Web diagnostics.
- Domain + Chromium + Windows Edge + production Pages evidence.

## Remaining roadmap

### Milestone 2 — remaining

- Complete and production-validate Buff template (#27).
- Add the data-driven Melee skill template so normal authored melee skills do not rely on the hard-coded basic attack chain.
- Consolidate shared skill cast/exclusivity rules so all templates use one consistent coordination layer.
- Final M2 regression/authoring-readiness pass.

### Milestones 3–8

- M3 — Data-driven Character System.
- M4 — Creator Studio basics.
- M5 — User VFX import/processing and VFX Creator.
- M6 — AI-assisted VFX provider layer.
- M7 — Character package import/export with safe data-only packages.
- M8 — Web MVP release and release hardening.
