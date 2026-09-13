# Project Status

## Current phase

Milestone 7 — Character Packages is the active roadmap milestone.

Current active slice: **Issue #74 — M7 Slice 2: Creator JSON character package export/import** on `feature/m7-package-json-export-import` / PR #75.

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
- Issue #68 / PR #69 — provider-neutral AI VFX request/result/provider boundary.
- Issue #70 / PR #71 — Creator prompt/reference Generate/Regenerate workflow.

Validation:
- PR #69 latest-head CI Run #138 passed required PR gates; Slice 1 reached production through main Runs #139/#140.
- PR #71 latest head passed PR CI Run #143 and merged at `a5b6d869541c8bcb5255e6b243e8a2782faade0a`.
- Main CI Run #144 and follow-up status Run #145 passed all production gates.

## Completed cross-platform slice — Mobile touch controls

Issue #61 / PR #62 is production-validated. Touch-capable Web sessions can use movement/run, jump/attack/dash/guard and Skill 1–6 controls; `?mobile_controls=1` forces the HUD on and `?mobile_controls=0` forces it off. Main CI Run #118 passed production validation.

## M7 — Character Packages

### Completed Slice 1 — Issue #72 / PR #73 — versioned safe character package data boundary

Production now includes `CharacterPackageDefinition`, a versioned, data-only package contract for one character plus its six referenced skills.

Safety/validation properties:
- top-level and nested fields are allow-listed,
- package/character ids and versions are validated,
- embedded character data is revalidated through `CharacterDefinition`,
- embedded skill data is revalidated through `SkillDefinition`,
- every character skill slot must resolve to exactly one packaged skill,
- duplicate, missing and unreferenced skills fail closed,
- skill ids and visual references must be safe tokens,
- deterministic `to_dictionary()` serialization sorts skills by id,
- package paths, archives, scripts/binaries and filesystem writes are not part of the data boundary.

Validation:
- PR #73 latest-head CI Run #147 passed Godot import/boot/domain, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Edge `smoke:all`.
- PR #73 merged to `main` at `8959521fbd5781ae6f3f16f5a6a376efa37f6fab` and closed Issue #72 completed.
- Main CI Run #148 passed all five production gates: Godot + Web + Browser, hosted Windows Edge, GitHub Pages deploy, public reachability and production Windows Edge real-game flow.

### Active Slice 2 — Issue #74 / PR #75 — Creator JSON package export/import

Implemented on `feature/m7-package-json-export-import`:
- Creator Studio adds `Export Package` and `Import Package` actions.
- Export copies the current Character draft, binds the authored Projectile draft to `skill_1`, loads slots 2–6 through the approved production `SkillRegistry`, then validates the complete package through `CharacterPackageDefinition` before download.
- Export emits one canonical `<package_id>.custom-fighter.json` document and exposes deterministic Web diagnostics for browser regression coverage.
- Import accepts UTF-8 JSON only and enforces a 256 KB ceiling before parsing.
- Parsed data must pass `CharacterPackageDefinition` before any Creator draft is changed.
- Imported Skill 1 must be a Creator-compatible projectile using the approved preview visual/impact tokens.
- Imported slots 2–6 must resolve to production registry ids and their packaged data must exactly match the approved production definitions.
- Invalid or unsupported imports fail closed and preserve the current drafts.
- A valid import restores Character + Skill 1, clears stale VFX binding, stores validated drafts in `CreatorPreviewSession`, and can use the normal `Preview in Training` path.
- ZIP/archive extraction and embedded binary VFX assets remain out of scope for this slice.

Validation:
- PR #75 implementation-head CI Run #149 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Edge `smoke:all`.
- The new `creator_package_web_smoke.mjs` covers canonical export, rejected-import draft preservation, valid import restoration, and a real imported Skill 1 projectile cast/hit in Training.
- A fresh latest-head PR CI is required after this status sync before merge.

M7 acceptance from `docs/MVP.md`: one user can create a character package and another can load it safely.

Planned next work after Slice 2 production validation:
- package approved VFX assets with strict type/size validation and unsafe-entry rejection,
- complete a second-session package flow that preserves player-authored VFX as well as Character/Skill data,
- formally evaluate M7 acceptance before advancing to M8.

## Online validation policy

All project engineering validation stays on GitHub-hosted infrastructure and the deployed GitHub Pages build: Godot import/boot, domain tests, Web export/size budget, Chromium `smoke:all`, hosted Windows Edge `smoke:all`, Pages deployment/public reachability and production Edge real-game flow. If a required gate is unavailable or failing, record it as Blocked / Residual Risk rather than using the user's computer.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

Production currently contains M7 Slice 1 package validation only. Slice 2 Export/Import UI remains PR-only until latest-head PR validation, merge and main production validation complete.

## Remaining roadmap

- Complete M7 safe Character Package export/import including approved VFX asset transport.
- M8 — Web/Windows MVP release hardening and final creator-to-training release flow.
