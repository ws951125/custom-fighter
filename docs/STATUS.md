# Project Status

## Current phase

**Milestone 8 — MVP Release is complete.**

Estimated whole-project completion: **100% (9/9 roadmap milestones)**. M0–M8 are formally complete and the MVP is production-validated on Web and Windows x86_64.

There is no active MVP milestone slice. Future work is post-MVP roadmap expansion rather than unfinished M0–M8 scope.

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
Character Editor, Projectile Skill Editor and validated Creator-to-Training preview flow. A non-programmer can create a basic character and skill and test them in Training.

### M5 — VFX Creator — 100%
Validated PNG/sprite-strip import, crop/frame/FPS/scale/offset authoring, preview and real Skill 1 projectile binding. Main CI Run #134 passed production gates.

### M6 — AI-assisted VFX — 100%
A reference PNG plus prompt/skill description can produce usable generated skill VFX through a replaceable provider boundary without coupling the combat runtime to a specific AI service.

Completed slices:
- Issue #68 / PR #69 — provider-neutral AI VFX request/result/provider boundary.
- Issue #70 / PR #71 — Creator prompt/reference Generate/Regenerate workflow.

Validation:
- PR #69 latest-head CI Run #138 passed required PR gates; Slice 1 reached production through main Runs #139/#140.
- PR #71 latest head passed PR CI Run #143 and merged at `a5b6d869541c8bcb5255e6b243e8a2782faade0a`.
- Main CI Run #144 and follow-up status Run #145 passed production gates.

### M7 — Character Packages — 100%
A user can create a character package and another browser session can load it safely, including authored Skill 1 PNG/sprite-strip VFX.

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
- PR #77 latest-head CI Run #155 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Edge `smoke:all`.
- PR #77 squash-merged to `main` at `24caf509aa6a87b856f652856f41725a1d865083`; Issue #76 closed completed.
- Main CI Run #156 passed production validation.

### M8 — MVP Release — 100%
Roadmap requirements from `docs/MVP.md` are satisfied:
- Web release,
- Windows x86_64 build,
- basic release/use documentation,
- stable Creator → package → fresh-session import → Training loop.

#### Slice 1 — Issue #78 / PR #79 — Windows native release artifact and CI smoke — complete
Implemented and production-validated:
- Godot `Windows Desktop` x86_64 release export preset with deterministic output under `build/windows`,
- GitHub-hosted `Windows Native Release` job using Godot 4.7.2 plus official export templates,
- validation of both `CustomFighter.exe` and `CustomFighter.pck`,
- bounded native smoke requiring a clean exit without script/fatal diagnostics,
- uploaded `custom-fighter-windows-x86_64` release bundle,
- Pages deployment gated on successful Windows native release,
- existing Web/Chromium/hosted Edge/Pages/public/production Edge gates preserved.

Validation:
- PR #79 final latest-head CI Run #166 passed Windows Native Release, Godot + Web + Browser and Windows + Microsoft Edge on head `e8d4fca97f2b0db068f7d3fcfaea76934c8d066a`.
- PR #79 squash-merged to `main` at `b575a17cb69f06f162e4a6c800db693c2aaebdde`.
- Main CI Run #167 passed all six production jobs.
- Windows PowerShell process-exit and spaced-preset argument issues discovered during the slice are recorded in `docs/LESSONS_LEARNED.md`.

#### Slice 2 — Issue #80 / PR #81 — release documentation and final Creator-to-Training acceptance — complete
Implemented and production-validated:
- refreshed README from stale M0-era text to the current release state,
- added `docs/RELEASE.md` for Web/Windows usage, Creator/package/Training flow, controls and package safety boundaries,
- added `smoke:creator-package-vfx` to required `smoke:all`,
- final acceptance now proves schema-v2 export, embedded VFX, second-session import, Training transition, runtime VFX load and actual skill cast,
- all existing validation and production gates remain intact.

Validation:
- PR #81 latest-head CI Run #168 passed Windows Native Release, Godot + Web + Browser with expanded Chromium `smoke:all`, and Windows + Microsoft Edge with expanded `smoke:all` on head `b8a5ccf4bb95d327134ccf7de80a9975f28d1d62`.
- PR #81 squash-merged to `main` at `e831b788dfaf28bcf1ebb4772f64845f47a090a0`.
- Main CI Run #169 passed all six production jobs:
  - Windows Native Release,
  - Godot + Web + Browser,
  - Windows + Microsoft Edge,
  - Deploy Web Demo,
  - Verify Public Web Demo,
  - Windows Edge Production Game.
- GitHub Pages deployment succeeded, the public production URL was reachable, and the real game flow against production passed in Microsoft Edge.
- Issue #80 is closed completed.

## Completed cross-platform slice — Mobile touch controls

Issue #61 / PR #62 is production-validated. Touch-capable Web sessions can use movement/run, jump/attack/dash/guard and Skill 1–6 controls; `?mobile_controls=1` forces the HUD on and `?mobile_controls=0` forces it off. Main CI Run #118 passed production validation.

## Online validation policy

All project engineering validation remains on GitHub-hosted infrastructure and the deployed GitHub Pages build: Godot import/boot, domain tests, Web export/size budget, Chromium smoke coverage, hosted Windows Edge smoke coverage, Windows native export/smoke, Pages deployment/public reachability and production Edge real-game flow. The user's local computer and Remote Desktop Commander are not used for project validation.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

Production contains the completed M0–M8 MVP roadmap, including the Windows native release pipeline, release documentation and expanded Creator package VFX acceptance gate.

## Remaining roadmap

The defined M0–M8 MVP roadmap has no remaining incomplete milestone. Further work is post-MVP scope such as additional platforms, content, networking, distribution/signing and production provider integrations.
