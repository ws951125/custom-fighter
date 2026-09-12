# Project Status

## Current phase

Milestone 4 — Creator Studio final acceptance/hardening.

Current active slice: Issue #58 — M4 final acceptance: harden production smoke and formally complete Creator Studio.

Estimated whole-project completion: **44.4%** across the M0–M8 MVP roadmap under the repository rule that only formally completed milestones count toward the fixed milestone denominator. M0, M1, M2 and M3 are complete; M4 functionality now satisfies its product acceptance criteria, but formal milestone completion waits for Issue #58 GitHub-only validation and merge.

## Completed milestones

### Milestone 0 — Foundation — 100%

- Godot 4.7.2 project foundation.
- GitHub Actions cloud validation.
- Web release export and GitHub Pages deployment.
- PWA/service-worker caching, startup diagnostics and Web size budgets.
- GitHub-only development and validation rules in `AGENTS.md`, `Agent.md`, `docs/ONLINE_TESTING.md` and `docs/MVP.md`.

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

Shared JSON data controls MP, cooldown, cast timing and template-specific combat parameters. One shared `SkillCoordinator` owns cross-skill exclusivity for U/I/O/P/B/H and prevents same-frame double-casts. M1 movement, guard and basic attacks observe the same busy state.

### Milestone 3 — Character System — 100%

M3 is production-validated and accepted.

- Versioned, validated, data-only `CharacterDefinition` owns character identity, stats, movement tuning, visual profile, animation map and six skill slots.
- `CharacterMovementTuning`, `CharacterVisualProfile`, `SkillRegistry`, `CharacterRegistry` and `CharacterAnimationMap` provide safe data-driven runtime boundaries.
- Two official reference characters are available entirely from content data: `ember_vanguard_001` / Ember Vanguard and `storm_duelist_001` / Storm Duelist.
- Web runtime safely supports `?character=<id>` and fail-closed fallback for invalid selections.
- PR #45 / Slice 4, PR #49 / Slice 5 and PR #51 / Slice 6 all passed GitHub-only validation before merge.
- Main CI Run #98 for merged PR #51 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all`, GitHub-hosted Windows Edge, GitHub Pages deployment, public reachability and production Edge real-game flow.

M3 acceptance is satisfied: a normal character can be added from approved content data without editing core combat code.

## Milestone 4 — completed slices

### Slice 1 — Character Editor

Issue #52 / PR #53 is production-validated and merged to `main` at `5b55a8b14afb4d810770d3dffa0bdc33c2c8d9f6`.

- Default URL remains Training; `?mode=creator` opens Creator Studio.
- Godot-native Character Editor with data-only in-memory `CharacterDraft`.
- Character ID, Display Name, Archetype, Max HP, Max MP and Move Speed editing.
- Validation delegates to the existing `CharacterDefinition` contract.
- Live VALID / INVALID state, Reset Character Draft and Back to Training.
- Main CI Run #100 passed Chromium, hosted Windows Edge, Pages deployment, public reachability and production Edge.
- Issue #52 is closed completed.

### Slice 2 — Projectile Skill Editor

Issue #54 / PR #55 is production-validated and merged to `main` at `1f00ec58e69abae159c6963746683dbb1c0e0ffd`.

- Data-only in-memory `SkillDraft` for the projectile template.
- Editable Skill ID, name, damage, MP cost, cooldown, startup, active, recovery, speed, range, hitstun and knockback.
- Validation delegates to the existing runtime `SkillDefinition` contract.
- Creator Studio navigation switches between Character Editor and Skill Editor.
- Approved starter hitbox/visual identifiers remain explicit; no arbitrary code/path execution.
- Reset Skill Draft and deterministic browser diagnostics are included.
- PR CI Run #101 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Edge.
- Main CI Run #102 first Windows Edge attempt hit a transient `playerRunning` observation timeout while runtime logs already reported `state=RUN`; targeted retry passed. GitHub Pages deployment, public reachability and production Edge then all passed, including `WEB_CREATOR_SKILL_EDITOR_SMOKE_PASSED`.
- Issue #54 is closed completed after production validation.

### Slice 3 — Creator-to-Training Preview

Issue #56 / PR #57 is production-validated and merged to `main` at `2029de45c3430e1b30b85b87727e58091c246ab4`.

- Adds an autoloaded, in-memory `CreatorPreviewSession` boundary.
- Preview staging validates CharacterDraft through `CharacterDefinition` and Projectile SkillDraft through `SkillDefinition` before runtime handoff.
- Invalid/unsafe skill IDs, unsupported skill types and unapproved preview visual identifiers fail closed.
- Character visual profile and animation map references are resolved through approved runtime registries.
- Preview binds the authored Projectile to character `skill_1` without mutating editable drafts or repository content.
- Creator → Training switches inside the running app, retaining in-memory state; Training exposes Return to Creator.
- Preview runtime reflects authored character HP/MP/movement and Projectile damage/MP/cooldown, while I/O/P/B/H remain normal registered skills.
- `creator_preview_session_test_runner.gd` and `creator_preview_web_smoke.mjs` validate the handoff and cast/return loop.
- PR #57 latest-head Run #108 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Edge.
- Main Run #109 passed Godot/Chromium, hosted Windows Edge, GitHub Pages deployment and public reachability. Its first production Edge attempt hit a transient `skillCooldown === 0` observation after durable evidence had already proven U cast/exclusivity; targeted production Edge retry passed the complete `smoke:all`, including `WEB_SKILL_COORDINATION_SMOKE_PASSED` and `WEB_CREATOR_PREVIEW_SMOKE_PASSED invalidBlocked=true authoredHp=180 authoredDamage=33 authoredMpCost=17 authoredCooldown=2.4 cast=true draftsRestored=true`.
- Issue #56 is closed completed after production validation.

## Current work — Issue #58 / M4 final acceptance

The functional M4 acceptance criteria from `docs/MVP.md` are now present in production:

- Character editor: non-programmer editable identity/stats through `CharacterDraft`.
- Skill editor: non-programmer editable Projectile parameters through `SkillDraft`.
- Parameter validation: both drafts delegate to the same safe runtime schemas used by the game.
- Preview/training room: validated drafts enter real Training, authored U can hit the dummy, and Return to Creator restores drafts.

A user can therefore create a basic character and skill without writing code. Issue #58 is the final engineering gate before formally marking M4 complete:

- Harden the SkillCoordinator browser regression so it uses persistent MP/coordinator evidence rather than requiring a transient cooldown value to remain positive.
- Record the reusable telemetry lesson as L-006.
- Re-run the entire PR GitHub-only validation matrix.
- After green PR validation, update this document to formally mark M4 complete / 55.6%, validate that final head once more, then merge and run the normal production pipeline.

No user-local machine, local project execution or Remote Desktop Commander validation is permitted or used.

## Online validation

The production pipeline verifies entirely on GitHub infrastructure:

- Godot import and main-scene boot on GitHub-hosted runners.
- Domain/data tests.
- Web release export and build-size budget.
- Chromium `smoke:all` against the exported artifact.
- Windows Microsoft Edge `smoke:all` on a GitHub-hosted Windows runner.
- GitHub Pages deployment and public reachability.
- Production browser smoke directly against the deployed game after merge.

If any required GitHub gate is unavailable, failing or blocked, the project records that state as `Blocked` / `Residual Risk`; it does not fall back to the user's local machine.

Live Training demo:

`https://ws951125.github.io/custom-fighter/`

Live Creator Studio:

`https://ws951125.github.io/custom-fighter/?mode=creator`

Production currently contains M4 Slice 1, Slice 2 and Slice 3 / PR #57. The user-visible Creator-to-Training preview loop is production-live; Issue #58 changes only regression evidence/documentation before formal M4 milestone closure.

## Remaining roadmap

- M4 — final acceptance/test hardening only (Issue #58).
- M5 — User VFX import/processing and VFX Creator.
- M6 — AI-assisted VFX provider layer.
- M7 — Character package import/export with safe data-only packages.
- M8 — Web MVP release and release hardening.
