# Project Status

## Current phase

Milestone 8 — MVP Release is the active roadmap milestone.

Next work unit: **M8 Slice 1 — Windows native release artifact and release hardening**.

Estimated whole-project completion: **88.9% (8/9 milestones)**. M0–M7 are formally complete; M8 is in progress.

## Completed milestones

### M0 — Foundation — 100%
Godot 4.7.2 foundation, GitHub Actions validation, Web export, GitHub Pages deployment and browser smoke coverage.

### M1 — Combat Prototype — 100%
2.5D movement, run/jump/dash/guard, HP/MP, three-hit basic attack chain, hit/hurt boxes, hitstun, knockback, knockdown and training dummy.

### M2 — Skill Engine — 100%
Data-driven melee, projectile, area, dash, formation and buff templates with startup/active/recovery, MP and cooldown handling.

### M3 — Character System — 100%
Validated CharacterDefinition, movement/visual/animation/loadout boundaries and multiple reference characters. Production validation completed through CI Run #98.

### M4 — Creator Studio — 100%
Character Editor, Projectile Skill Editor and validated Creator-to-Training preview flow. M4 acceptance is satisfied: a non-programmer can create a basic character and skill and test them in Training.

### M5 — VFX Creator — 100%
Validated PNG/sprite-strip import, crop/frame/FPS/scale/offset authoring, preview and real Skill 1 projectile binding. Main CI Run #134 passed all production gates.

### M6 — AI-assisted VFX — 100%
M6 acceptance is satisfied: a reference PNG plus prompt/skill description can produce usable generated skill VFX through a replaceable provider boundary without coupling the combat runtime to a specific AI service.

Completed slices:
- Issue #68 / PR #69 — provider-neutral AI VFX request/result/provider boundary.
- Issue #70 / PR #71 — Creator prompt/reference Generate/Regenerate workflow.

Validation:
- PR #69 latest-head CI Run #138 passed required PR gates; Slice 1 reached production through main Runs #139/#140.
- PR #71 latest head passed PR CI Run #143 and merged at `a5b6d869541c8bcb5255e6b243e8a2782faade0a`.
- Main CI Run #144 and follow-up status Run #145 passed all production gates.

### M7 — Character Packages — 100%
M7 acceptance is satisfied: one user can create a character package and another browser session can load it safely, including the authored Skill 1 PNG/sprite-strip VFX.

Completed slices:
- Issue #72 / PR #73 — versioned safe character package data boundary.
- Issue #74 / PR #75 — Creator JSON package export/import.
- Issue #76 / PR #77 — self-contained VFX asset character packages.

Production package behavior:
- schema-v1 packages without embedded VFX remain importable,
- current exports use schema v2,
- schema v2 can carry one optional validated Skill 1 VFX asset containing `VfxDraft` metadata plus bounded PNG bytes encoded as base64,
- top-level/package/VFX fields are allow-listed and revalidated,
- embedded PNG bytes are decoded in memory and dimensions must match validated metadata,
- scripts, native binaries, arbitrary resource paths, external URLs, ZIP/archive extraction and arbitrary filesystem writes are rejected/out of contract,
- invalid package imports fail closed before Creator Character/Skill/VFX state is mutated,
- a valid self-contained package can be imported in another browser session and use the normal Creator → Training preview path.

Validation:
- PR #77 encountered one stale browser regression in Run #152 after the intentional schema-v2 export change; the old hard-coded schema-v1 assertion was corrected and recorded in `docs/LESSONS_LEARNED.md`.
- PR #77 latest-head CI Run #155 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Edge `smoke:all`.
- PR #77 squash-merged to `main` at `24caf509aa6a87b856f652856f41725a1d865083`; Issue #76 is closed completed.
- Main CI Run #156 passed all five production gates: Godot + Web + Browser, hosted Windows Edge, GitHub Pages deploy, public reachability and production Windows Edge real-game flow.

## Completed cross-platform slice — Mobile touch controls

Issue #61 / PR #62 is production-validated. Touch-capable Web sessions can use movement/run, jump/attack/dash/guard and Skill 1–6 controls; `?mobile_controls=1` forces the HUD on and `?mobile_controls=0` forces it off. Main CI Run #118 passed production validation.

## M8 — MVP Release

M8 is now active. Roadmap requirements from `docs/MVP.md`:
- Web release,
- Windows build,
- basic documentation,
- stable Creator-to-Training loop.

Planned first work unit:
- add a reproducible Windows native export artifact on GitHub-hosted CI,
- validate the native build without using the user's local computer,
- preserve the already-green Web/Chromium/Edge gates,
- then complete release documentation and a final end-to-end Creator → package → Training release acceptance flow.

## Online validation policy

All project engineering validation stays on GitHub-hosted infrastructure and the deployed GitHub Pages build: Godot import/boot, domain tests, Web export/size budget, Chromium smoke coverage, hosted Windows Edge smoke coverage, Pages deployment/public reachability, production Edge real-game flow, and M8 Windows native build validation. If a required gate is unavailable or failing, record it as Blocked / Residual Risk rather than using the user's computer.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

Production now contains M0–M7, including schema-v2 self-contained Character Package export/import with optional authored Skill 1 VFX transport.

## Remaining roadmap

- M8 — Web/Windows MVP release hardening, basic documentation and final stable creator-to-training release flow.
