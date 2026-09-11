# Project Status

## Current phase

Milestone 2 — Data-driven Skill Engine

Current active slice: Issue #24 — Formation / Rain skill template.

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
- Shared JSON-driven MP, cooldown and cast timing.
- Reusable projectile, dash and area combat states.
- Skill-specific browser evidence while preserving Milestone 1 regressions.

Area Attack tracker #21 is complete.

## Verified online

The current `main` pipeline verifies:

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

Latest fully validated production baseline before Issue #24: `bb8b6eeda8794d3cfdd3d2e63ccab432667ecbc1`.

## Current work

Issue #24 — Formation / Rain:

- JSON-driven `blade_rain_001` sample.
- Skill 4 bound to `P`.
- Multiple timed formation cells / strikes from one cast.
- JSON-driven strike count, spacing, interval and cell dimensions.
- One-hit-per-cell collision semantics.
- Replaceable runtime visuals suitable for later AI-generated sword-rain / magic-circle VFX.
- Domain + Chromium + Windows Edge + production Pages evidence.

## Follow-up

After Formation / Rain, Milestone 2 continues with the Buff template, followed by broader character/package authoring work for Milestones 3–5.
