# Project Status

## Current phase

Milestone 8 — MVP Release is the active roadmap milestone.

Current active slice: **Issue #80 — M8 Slice 2: release documentation and final Creator-to-Training acceptance** on `feature/m8-release-docs-acceptance`.

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

Roadmap requirements from `docs/MVP.md`:
- Web release,
- Windows build,
- basic documentation,
- stable Creator-to-Training loop.

### Completed Slice 1 — Issue #78 / PR #79 — Windows native release artifact and CI smoke

Implemented and production-validated:
- Godot `Windows Desktop` x86_64 release export preset with deterministic output under `build/windows`,
- GitHub-hosted `Windows Native Release` job using Godot 4.7.2 plus official export templates,
- validation of both `CustomFighter.exe` and `CustomFighter.pck`,
- bounded headless native smoke requiring a clean exit without script/fatal diagnostics,
- uploaded `custom-fighter-windows-x86_64` release bundle,
- GitHub Pages deployment waits for the Windows native release gate on main,
- all Web/Chromium/hosted Edge/Pages/public/production Edge gates preserved.

Validation:
- PR #79 final latest-head CI Run #166 passed Windows Native Release, Godot + Web + Browser and Windows + Microsoft Edge on head `e8d4fca97f2b0db068f7d3fcfaea76934c8d066a`.
- PR #79 squash-merged to `main` at `b575a17cb69f06f162e4a6c800db693c2aaebdde`; Issue #78 is closed completed.
- Main CI Run #167 completed with `conclusion=success` and passed all six production jobs: Windows Native Release, Godot + Web + Browser, Windows + Microsoft Edge, Deploy Web Demo, Verify Public Web Demo and Windows Edge Production Game.
- Production Pages was deployed successfully and the public URL was verified reachable.
- Production Edge ran the real game flow against GitHub Pages successfully.
- Earlier Windows PowerShell process-exit and spaced-preset argument issues and their prevention rules are recorded in `docs/LESSONS_LEARNED.md`.

### Active Slice 2 — Issue #80 — release documentation and final Creator-to-Training acceptance

In progress on `feature/m8-release-docs-acceptance`:
- refresh the stale repository README from M0-era text to the current M8 release state,
- add a first-time-user Web/Windows release and usage guide,
- explicitly gate the existing self-contained Creator package VFX browser regression in `smoke:all`,
- use that regression as final release acceptance evidence for Creator → schema-v2 package → second-session import → Training → runtime VFX load/cast,
- preserve all existing CI and production gates.

Acceptance remaining:
- latest-head PR CI must pass the expanded `smoke:all` suite in Chromium and hosted Windows Edge plus Windows native release validation,
- after merge, main CI must pass Windows native, Web/Chromium, hosted Edge, Pages deployment/public reachability and production Edge real-game flow,
- then perform formal M8/MVP completion review.

## Online validation policy

All project engineering validation stays on GitHub-hosted infrastructure and the deployed GitHub Pages build: Godot import/boot, domain tests, Web export/size budget, Chromium smoke coverage, hosted Windows Edge smoke coverage, Windows native export/smoke, Pages deployment/public reachability and production Edge real-game flow. If a required gate is unavailable or failing, record it as Blocked / Residual Risk rather than using the user's computer.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

Production currently contains M0–M7 plus the M8 Windows native release pipeline from Slice 1. Slice 2 documentation and expanded release acceptance remain branch-only until PR validation, merge and main production validation complete.

## Remaining roadmap

- Complete M8 Slice 2 release documentation and final stable Creator-to-package-to-Training acceptance.
- Perform formal M8/MVP completion review once Slice 2 reaches production.
