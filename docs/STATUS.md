# Project Status

## Current phase

Milestone 7 — Character Packages is the active roadmap milestone.

Current active slice: **Issue #72 — M7 Slice 1: versioned safe character package data boundary** on `feature/m7-character-package-data-boundary` / PR #73.

Estimated whole-project completion: **77.8% (7/9 milestones)**. M0–M6 are formally complete; M7 is in progress.

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
- Issue #68 / PR #69 — provider-neutral AiVfxRequest, AiVfxResult, AiVfxProvider, provider registry and deterministic mock provider.
- Issue #70 / PR #71 — VFX Creator prompt/reference Generate/Regenerate workflow integrated with the existing preview/session/runtime binding path.

Production functionality:
- Prompt / skill-description authoring.
- Optional validated reference PNG.
- Bounded output frame count, dimensions and FPS.
- Generate and Regenerate through AiVfxProviderRegistry.
- Revalidation of provider output, PNG bytes and generated VfxDraft metadata before preview/binding.
- Generated VFX preserved through Creator -> VFX Creator -> Creator -> Training.
- Real `U` Skill 1 projectile renders generated VFX while combat behavior remains data-driven by the existing skill runtime.
- Runtime remains provider-neutral and can continue without AI generation availability.

Validation:
- PR #69 latest-head CI Run #138 passed required PR gates; Slice 1 reached production through main Runs #139/#140.
- PR #71 latest head `e5c2c258c77810fed690f3f39afbb24d4dc895c4` passed PR CI Run #143.
- PR #71 merged to main at `a5b6d869541c8bcb5255e6b243e8a2782faade0a` and closed Issue #70 completed.
- Main CI Run #144 passed all five production gates.
- Follow-up M6 completion/status commit `206b7a40f337873351e4ff057d73eee48e7fb91e` passed full main CI Run #145, including production Edge.

A real cloud/local image-generation provider remains a future replaceable integration rather than an M6 acceptance blocker.

## Completed cross-platform slice — Mobile touch controls

Issue #61 / PR #62 is production-validated. Touch-capable Web sessions can use movement/run, jump/attack/dash/guard and Skill 1–6 controls; `?mobile_controls=1` forces the HUD on and `?mobile_controls=0` forces it off. Main CI Run #118 passed production validation.

## M7 — Character Packages

### Active Slice 1 — Issue #72 / PR #73 — versioned safe character package data boundary

Implemented on `feature/m7-character-package-data-boundary`:

- Added `CharacterPackageDefinition` as a versioned, data-only package contract.
- Top-level package fields are allow-listed and package id/version are validated.
- Embedded character data is revalidated through `CharacterDefinition`.
- Embedded skill data is allow-listed and revalidated through `SkillDefinition`.
- Package/character ids must match; skill ids and visual references must be safe tokens.
- Every character skill slot must resolve to a packaged skill definition; duplicate, missing and unreferenced skills fail closed.
- Canonical `to_dictionary()` output sorts skill definitions by id for deterministic serialization/round-trip behavior.
- Arbitrary package paths, archive extraction, scripts, binaries and filesystem writes remain out of scope for this slice.
- Added `character_package_test_runner.gd` for valid round trip plus schema mismatch, id mismatch, duplicate skill, unresolved slot, unsafe token/path-like reference, unknown nested field and tampered nested skill rejection.
- GitHub Actions domain-test wiring has been added.

Validation:
- PR #73 CI Run #146 passed Godot import, main-scene boot, all domain tests including `CHARACTER_PACKAGE_TESTS_PASSED`, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Edge `smoke:all`.
- A fresh latest-head CI is required after this status sync before merge.

M7 acceptance from `docs/MVP.md`: one user can create a character package and another can load it safely.

Planned next slices after the data boundary is production validated:
- bounded browser export/import UX for the canonical package document,
- approved VFX asset packaging with size/type validation and unsafe-entry rejection,
- end-to-end Creator export -> second-session import -> Training validation.

## Online validation policy

All project engineering validation stays on GitHub-hosted infrastructure and the deployed GitHub Pages build: Godot import/boot, domain tests, Web export/size budget, Chromium smoke:all, hosted Windows Edge smoke:all, Pages deployment/public reachability and production Edge real-game flow. If a required gate is unavailable or failing, record it as Blocked / Residual Risk rather than using the user's computer.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

Production contains completed M0–M6 scope, mobile touch controls, provider-neutral AI VFX contracts and the Prompt / Reference / Generate / Regenerate VFX workflow. M7 Issue #72 remains feature-branch-only until PR and main production validation complete.

## Remaining roadmap

- M7 — safe character package export/import, schema/version validation and unsafe-file rejection.
- M8 — Web/Windows MVP release hardening and final creator-to-training release flow.
