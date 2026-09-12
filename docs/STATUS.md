# Project Status

## Current phase

Milestone 5 — User VFX import/processing and VFX Creator is next.

Milestone 4 — Creator Studio is formally accepted on Issue #58 / PR #59 after the hardened acceptance head passed GitHub-only CI Run #110. The final documentation-only acceptance head still requires one fresh PR validation before merge; production remains on the already production-green M4 Slice 3 build until PR #59 merges.

Estimated whole-project completion: **55.6% (5/9 milestones)** across the fixed M0–M8 MVP roadmap. M0, M1, M2, M3 and M4 satisfy their acceptance criteria; M5 is next.

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

- Versioned, validated, data-only `CharacterDefinition` owns identity, stats, movement tuning, visual profile, animation map and six skill slots.
- `CharacterMovementTuning`, `CharacterVisualProfile`, `SkillRegistry`, `CharacterRegistry` and `CharacterAnimationMap` provide safe data-driven runtime boundaries.
- Two official reference characters are data-driven: `ember_vanguard_001` and `storm_duelist_001`.
- Web runtime supports safe `?character=<id>` selection with fail-closed fallback.
- Main CI Run #98 passed Godot import/boot/domain tests, Web export/size budget, Chromium, hosted Windows Edge, Pages deployment, public reachability and production Edge.

M3 acceptance is satisfied: a normal character can be added from approved content data without editing core combat code.

### Milestone 4 — Creator Studio — 100%

M4 is formally accepted. A non-programmer can create a basic character and Projectile skill, validate the data using the same runtime contracts, preview it in the real Training runtime, cast the authored skill against the dummy, and return to Creator with the drafts preserved — without writing code or editing repository JSON.

#### Slice 1 — Character Editor

Issue #52 / PR #53 is production-validated and merged at `5b55a8b14afb4d810770d3dffa0bdc33c2c8d9f6`.

- `?mode=creator` opens Creator Studio while the default URL remains Training.
- Data-only in-memory `CharacterDraft` exposes Character ID, Display Name, Archetype, Max HP, Max MP and Move Speed.
- Validation delegates to the existing `CharacterDefinition` contract.
- Live VALID / INVALID state, Reset Character Draft and Back to Training are available.
- Main CI Run #100 passed Chromium, hosted Windows Edge, Pages deployment, public reachability and production Edge.

#### Slice 2 — Projectile Skill Editor

Issue #54 / PR #55 is production-validated and merged at `1f00ec58e69abae159c6963746683dbb1c0e0ffd`.

- Data-only in-memory `SkillDraft` edits Projectile ID/name, damage, MP cost, cooldown, startup, active, recovery, speed, range, hitstun and knockback.
- Validation delegates to `SkillDefinition`; approved visual identifiers remain explicit and no arbitrary code/path execution is accepted.
- Creator navigation switches between Character Editor and Projectile Skill Editor.
- Main CI Run #102 ultimately passed Pages/public/production Edge, including `WEB_CREATOR_SKILL_EDITOR_SMOKE_PASSED`.

#### Slice 3 — Creator-to-Training Preview

Issue #56 / PR #57 is production-validated and merged at `2029de45c3430e1b30b85b87727e58091c246ab4`.

- `CreatorPreviewSession` provides a data-only, in-memory, fail-closed handoff.
- CharacterDraft and Projectile SkillDraft are revalidated through runtime schemas before preview.
- Approved visual/animation references are resolved before handoff; invalid IDs/types/visuals are rejected.
- Authored Projectile is bound to `skill_1`/`U` without modifying repository content; I/O/P/B/H remain normal registered skills.
- Creator → Training switches in-app without page reload; Return to Creator restores the same drafts.
- PR #57 Run #108 passed all pre-merge gates.
- Main Run #109 passed Godot/Chromium, hosted Windows Edge, GitHub Pages and public reachability. The first production Edge attempt exposed a transient cooldown-observation assertion; a targeted retry passed complete production `smoke:all`, including `WEB_CREATOR_PREVIEW_SMOKE_PASSED invalidBlocked=true authoredHp=180 authoredDamage=33 authoredMpCost=17 authoredCooldown=2.4 cast=true draftsRestored=true`.
- Issue #56 is closed completed.

#### Final acceptance / regression hardening

Issue #58 / PR #59 hardens the SkillCoordinator regression identified by Run #109:

- The test no longer treats a naturally expiring `skillCooldown > 0` sample as durable proof of a cast.
- Durable proof is MP `100 -> 75`, persistent `lastClaimed=skill_1`, exactly one coordinator claim, and Area Skill remaining rejected/READY.
- L-006 records this reusable testing rule.
- PR #59 CI Run #110 passed Godot import/boot/domain tests, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Windows Edge `smoke:all` with the hardened assertion.

This satisfies the `docs/MVP.md` M4 acceptance criterion: **a non-programmer can create a basic character and skill**. Formal roadmap progress is therefore **55.6% (5/9)**. The final docs-only acceptance commit must still pass the same PR gates before PR #59 is merged and the main production pipeline is run.

## Online validation

The pipeline verifies entirely on GitHub infrastructure:

- Godot import and main-scene boot.
- Domain/data tests.
- Web release export and build-size budget.
- Chromium `smoke:all` against the exported artifact.
- Microsoft Edge `smoke:all` on a GitHub-hosted Windows runner.
- GitHub Pages deployment and public reachability after merge.
- Production Microsoft Edge `smoke:all` against the deployed game.

If a required GitHub gate is unavailable or failing, the project records Blocked / Residual Risk; it does not fall back to the user's local machine.

Live Training demo:

`https://ws951125.github.io/custom-fighter/`

Live Creator Studio:

`https://ws951125.github.io/custom-fighter/?mode=creator`

Production currently contains all M4 user-visible functionality through PR #57. PR #59 changes only regression evidence and project-status documentation.

## Remaining roadmap

- M5 — User VFX import/processing and VFX Creator.
- M6 — AI-assisted VFX provider layer.
- M7 — Character package import/export with safe data-only packages.
- M8 — Web MVP release and release hardening.
