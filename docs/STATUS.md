# Project Status

## Current phase

Milestone 7 — Character Packages is the active roadmap milestone.

Current active slice: **Issue #76 — M7 Slice 3: self-contained VFX asset character packages** on `feature/m7-self-contained-vfx-packages` / PR #77.

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

Production includes `CharacterPackageDefinition`, a versioned, data-only package contract for one character plus its six referenced skills.

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
- Main CI Run #148 passed all five production gates.

### Completed Slice 2 — Issue #74 / PR #75 — Creator JSON package export/import

Production includes the first end-user Character Package workflow:
- Creator Studio has `Export Package` and `Import Package` actions.
- Export copies the current Character draft, binds the authored Projectile draft to `skill_1`, loads slots 2–6 through the approved production `SkillRegistry`, and validates the complete package before browser download.
- Import accepts bounded UTF-8 JSON only; parsed data must pass the package contract before any Creator state changes.
- Skill 1 must remain Creator-compatible and slots 2–6 must match approved production definitions.
- Invalid imports fail closed and preserve current drafts.
- A valid import restores Character + Skill 1 and can immediately use `Preview in Training`.

Validation:
- PR #75 implementation-head Run #149 and latest-head Run #150 passed Godot/Web/Chromium and GitHub-hosted Windows Edge gates.
- PR #75 merged to `main` at `7eadf35949996e16cada8bf291dd7027b7e7ab31` and Issue #74 closed completed.
- Main CI Run #151 passed all five production gates: Godot + Web + Browser, hosted Windows Edge, GitHub Pages deploy, public reachability and production Windows Edge real-game flow.

### Active Slice 3 — Issue #76 / PR #77 — self-contained VFX asset character packages

Implemented on `feature/m7-self-contained-vfx-packages`:
- Added a backward-compatible self-contained package contract: schema v1 packages without assets remain importable; current exports use schema v2.
- Schema v2 can carry one optional Skill 1 VFX asset containing validated `VfxDraft` metadata and bounded PNG bytes encoded as base64 inside the JSON package.
- VFX asset fields are allow-listed; Skill slot/id, PNG MIME, safe filename, metadata, encoded size and decoded byte size are validated.
- PNG data is decoded in memory with Godot `Image`; decoded dimensions must match VFX metadata.
- No archive extraction, arbitrary filesystem paths, external URLs, scripts or native binaries are accepted.
- Export includes the currently stored Creator VFX when present; a package without authored VFX remains valid and uses the existing prototype fallback.
- Import validates the complete package before modifying Character/Skill/VFX state, then stores a valid embedded VFX in `CreatorPreviewSession` for the normal Training preview path.
- Added domain coverage for schema-v1 compatibility, schema-v2 VFX round trip, malformed base64, invalid PNG, oversized payload, metadata/dimension mismatch and unknown VFX asset fields.
- Added browser E2E for authored VFX export -> fresh browser context -> package import -> Training -> real Skill 1 projectile VFX.

Validation:
- PR #77 CI Run #152 passed Godot import/boot/domain tests, Web export and size budget, but Chromium failed in the unchanged Slice 2 `creator_package_web_smoke.mjs` because that test still hard-coded export `schema_version === 1` while Slice 3 intentionally makes new exports schema v2.
- The stale assertion has been corrected to require schema v2 for current exports and additionally verify that a no-authored-VFX package does not emit `vfx_asset`.
- Fresh latest-head PR CI Run #153 is in progress. No merge until Godot/Web/Chromium and hosted Windows Edge are green on the latest head.

M7 acceptance from `docs/MVP.md`: one user can create a character package and another can load it safely. Slice 3 is intended to close the remaining authored-VFX transport gap before formally declaring M7 complete.

## Online validation policy

All project engineering validation stays on GitHub-hosted infrastructure and the deployed GitHub Pages build: Godot import/boot, domain tests, Web export/size budget, Chromium smoke coverage, hosted Windows Edge smoke coverage, Pages deployment/public reachability and production Edge real-game flow. If a required gate is unavailable or failing, record it as Blocked / Residual Risk rather than using the user's computer.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

Production currently contains M7 Slice 1 and Slice 2, including JSON `Export Package` / `Import Package`. Self-contained embedded VFX transport from Slice 3 remains PR-only until latest-head validation, merge and main production validation complete.

## Remaining roadmap

- Complete M7 self-contained VFX Character Package transport and production validation.
- M8 — Web/Windows MVP release hardening and final creator-to-training release flow.
