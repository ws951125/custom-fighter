# V2-2 Extended Skill Families — Architecture Inventory

Date: 2026-09-17

## Purpose

This inventory is the implementation baseline for V2-2. It records the current V1 family boundaries, Creator/runtime bottlenecks, reusable V2 timeline primitives, existing regression coverage, and safe new-family slices. The goal is to extend the engine without introducing arbitrary code execution or duplicating one editor/controller stack per family.

## Existing V1 skill families

| Family | Runtime/data boundary | Primary parameters | Current character slot |
| --- | --- | --- | --- |
| `projectile` | `SkillDefinition` + root projectile runtime | speed, range, active hitbox | `skill_1` / U |
| `dash` | `SkillDefinition` + root dash-slash runtime | speed, range, active hitbox | `skill_2` / I |
| `area` | `AreaAttackState` + coordinated area controller | active spatial hitbox | `skill_3` / O |
| `formation` | formation state/controller | count, spacing, interval, offset, spatial hitbox | `skill_4` / P |
| `buff` | buff state/controller | duration, movement multiplier, basic-attack multiplier | `skill_5` / B |
| `melee` | melee state/controller | range, active spatial hitbox | `skill_6` / H |

The original six remain required character slots. `SkillRegistry` validates registry type and requires an exact expected-type match when loading a slot.

## Creator inventory

Before V2-2 work unit 1, `SkillDraft` and the visible Skill Editor were projectile-only even though the runtime supported six V1 families:

- `SkillDraft.load_from_dictionary()` rejected every non-projectile `SkillDefinition`.
- `SkillDraft.validate()` enforced the same projectile-only restriction.
- the Skill Editor displayed a fixed PROJECTILE template and exposed no family selector.
- Creator Preview treated `skill_1` as a projectile-only preview path.

Work unit 1 removed the authoring restriction while preserving projectile as the backwards-compatible reset/default family. It was merged by PR #145 as `7c6eb8aebe1797f1c0a14176f7a7721e07f52771`; Main CI #342 (`35190460843`) passed Windows Native, Godot/domain/backend/Web/Chromium, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness and production Microsoft Edge full smoke.

## Runtime routing inventory

The original playable character binds its six required slots to fixed V1 families:

- slot 1 loads `projectile`,
- slot 2 loads `dash`,
- slot 3 loads `area`,
- slot 4 loads `formation`,
- slot 5 loads `buff`,
- slot 6 loads `melee`.

`SkillRegistry.load_skill()` requires callers to provide the expected family. This remains fail-closed. Work unit 2 added a preview-only family→existing-slot mapping for the six original families and was squash-merged by PR #146 as `6b235408bef84783e588e9addeebb57b1b37f7a3`; Main CI #345 (`35200223070`) passed the complete production chain.

Work unit 3 introduces the first new slot extension without breaking existing characters: `skill_7` is optional in `CharacterDefinition`, while slots 1–6 remain required. Beam uses `skill_7` / Y only when present; legacy six-slot characters remain valid and ordinary Training leaves the Beam controller unloaded.

## Reusable V2 timeline primitives

V2-1 already provides safe declarative event composition:

- `animation`,
- `vfx`,
- `audio`,
- `hitbox`,
- `hurtbox`.

The timeline contract enforces deterministic ordering, stable IDs, event-count/duration limits, safe media tokens and bounded spatial payloads. V2-2 reuses those same `SkillCastState` timeline schedulers rather than creating family-specific executable event paths.

## Existing validation coverage

The repository validates:

- `SkillDefinition` / registry fail-closed behavior through Godot domain tests,
- each V1 family through deterministic state/controller tests,
- Creator skill draft validation and timeline round-trip,
- Web Creator editing through Playwright Chromium and hosted Microsoft Edge,
- exported Web runtime skill behavior through the existing smoke suite,
- Windows native export,
- production GitHub Pages and production Edge smoke after merge.

V2-2 additions extend those same online gates.

## Work unit 1 — skill-family authoring foundation — accepted

Acceptance:

1. Creator can select every currently supported V1 family from one safe family selector.
2. switching family applies deterministic safe defaults required by that family's `SkillDefinition` validation.
3. all six families serialize and reload through `SkillDraft` → `SkillDefinition` without code execution.
4. unsupported/unsafe family values fail closed and do not mutate a valid draft through the selector API.
5. projectile remains the reset/default family so existing package, VFX, AI-proposal and Creator Preview flows remain backwards compatible.
6. domain tests and Creator Chromium/Edge smoke cover the family switch path.

Evidence: PR #145 → main `7c6eb8aebe1797f1c0a14176f7a7721e07f52771`; Main CI #342 (`35190460843`) complete production chain PASS.

## Work unit 2 — Creator Preview family dispatch — accepted

The preview session maps validated original family types onto the existing runtime slots/controllers:

| Family | Preview slot | Input |
| --- | --- | --- |
| `projectile` | `skill_1` | U |
| `dash` | `skill_2` | I |
| `area` | `skill_3` | O |
| `formation` | `skill_4` | P |
| `buff` | `skill_5` | B |
| `melee` | `skill_6` | H |

Acceptance is satisfied: Preview validates each family, rewrites only the mapped temporary slot, preserves editable drafts/unrelated slots, enforces exact runtime type/ID, isolates projectile-only imported VFX, consumes V2 timelines from the active family's existing cast state, and is covered in Chromium/hosted Edge.

Evidence: PR #146 → main `6b235408bef84783e588e9addeebb57b1b37f7a3`; Main CI #345 (`35200223070`) complete production chain PASS.

## Work unit 3 — first new family: `beam` — accepted and production-validated

Beam is the first genuinely new family and intentionally reuses existing safe primitives rather than adding an executable scripting surface.

Implementation:

- `SkillDefinition` recognizes `beam` and fail-closes unsafe range, active duration and hitbox dimensions.
- official `training_beam_001` is registered with exact family type `beam`.
- `SkillDraft` supplies deterministic Beam defaults through the same family selector used by the existing families.
- `BeamAttackState` models a fixed directional origin→endpoint volume and allows at most one hit per activation.
- the coordinated Beam controller uses the shared `SkillCastState`, MP/cooldown rules and `SkillCoordinator` as `skill_7` / Y.
- `skill_7` is an optional character-schema extension; the six original slots remain required and legacy characters require no migration.
- Creator Preview maps Beam to temporary `skill_7`; the stored CharacterDraft remains unchanged.
- V2 timeline transitions for Beam are consumed from the Beam controller's shared `SkillCastState`.
- no autonomous actor, arbitrary path, user script, executable callback or new timeline event type is introduced.

Validation:

- `beam_test_runner.gd` covers definition bounds, registry exact-type mismatch rejection, cast activation, deterministic geometry, range miss, one-hit policy, optional-slot backwards compatibility and Creator Preview routing/isolation.
- `creator_preview_family_web_smoke.mjs` now covers seven families and directly verifies Beam Y input, authored MP cost, audio timeline execution, exact dummy damage, one-hit count and Creator round-trip.
- implementation head `4fa2215d840fdbb43e8e3eed1269237ff4e51eec` passed PR CI #346 (`35207985135`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- PR #147 was squash-merged as `ed35ff4685173826ec015ac86a48480704a77d7b`; Main CI #349 (`35210660845`) passed the complete production chain on that exact revision.

## Work unit 4 — second new family: `trap` — accepted and production-validated

Trap extends the same declarative boundary with optional `skill_8` / T, bounded placement/trigger/lifetime state and a single-trigger damage policy. Creator Preview, package compatibility and deterministic domain coverage are synchronized. PR #148 was squash-merged as `f1631eaa3f2828765ab898e7f5ebe55637671422`; Main CI #362 (`35289237781`) ultimately passed the complete production chain on the exact revision.

## Work unit 5 — third new family: `aura` — accepted and production-validated

Aura uses optional `skill_9` / G. Its bounded combat volume follows the caster for a finite lifetime and can damage a target at most once per activation. It reuses `SkillCastState`, `SkillCoordinator`, Creator family selection, Creator Preview routing and the existing declarative timeline scheduler. `aura_duration` is a validated family-specific package field serialized only for Aura. No autonomous actor, arbitrary callback/path, user code or new executable event type is added.

Implementation head `da9808d46eadadcb79bd0356b45953365236940a` passed PR #150 CI #365 (`35295253734`) on attempt #2 across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all` and hosted Microsoft Edge `smoke:all`. Both browsers exercised the nine-family Creator Preview flow and reported the Aura single-hit policy. Attempt #1 stopped earlier in unchanged K-dash browser sampling at 119.66px versus the existing >120px threshold; the same SHA passed without code changes.

Latest PR head `8d1f801ff13053473fc8412a914703bd5d46335f` then passed PR CI #367 (`35296370356`) across the full PR gate. PR #150 was squash-merged as `f2ce5d0efe99d807be09190fa02e26b95d2325d5`, and Main CI #368 (`35298311326`) passed the complete production chain on that exact revision, including Pages deployment/public reachability, Render exact-revision readiness and production Microsoft Edge full smoke.


## Work unit 6 — fourth new family: `teleport` — accepted and production-validated

Teleport uses optional `skill_10` / R and reuses the established exact-type registry, `SkillCastState`, `SkillCoordinator`, Creator family selector, Creator Preview routing and declarative timeline scheduler. Its authored `range` is the maximum horizontal displacement. `TeleportState` computes a destination only from the current position, facing and validated range, then clamps that destination to the arena safety margins. There is no arbitrary path, destination callback, user code or autonomous actor, and the runtime does not apply damage as part of the teleport itself.

Implementation head `b77b5efbe07aea2bb9f5be69bdf8aab00d6a3af7` passed PR #152 CI #371 (`35302926489`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all` and hosted Microsoft Edge `smoke:all`. Domain validation emitted `TELEPORT_TESTS_PASSED`; both browsers exercised the ten-family Creator Preview flow and reported `teleportPolicy=bounded`, timeline dispatch and round-trip success.

Latest PR head `499adee3404bfb39febf0d69878b940676712099` then passed PR CI #373 (`35303697245`) across the full PR gate. PR #152 was squash-merged as `5cc30c274c4a61b5b37b5d4099ac4cf7a0e72d1f`. Main CI #374 (`35304620553`) attempt #1 stopped in unchanged hosted-Edge `smoke:melee` at the short positive-cooldown observation window before Teleport coverage; without any code change, attempt #2 on the exact same SHA passed the complete production chain including Pages deployment/public reachability, Render exact-revision readiness and production Microsoft Edge full smoke.



## Work unit 7 — fifth new family: `counter` — accepted and production-validated

Counter uses optional `skill_11` / F and reuses the exact-type registry, `SkillCastState`, `SkillCoordinator`, Creator family selection, Creator Preview routing and declarative timeline scheduler. Its `active` field is a finite counter window (hard-capped at 2.0 seconds), `range` bounds the incoming source horizontally, and `hitbox_half_depth` bounds source depth.

Because the Training runtime previously had no formal player incoming-damage path, Work Unit 7 adds a shared `receive_player_hit(...)` boundary. Counter may intercept only when an actual hit arrives during the armed window and its source is within bounds. Otherwise the hit reaches normal player damage. The window is single-consume and expiry never creates retaliation. A constrained browser training probe sends an incoming hit only from the current Dummy coordinates so Chromium/Edge can validate this contract without introducing arbitrary source selection, callbacks, paths, scripts or autonomous actors.

Implementation head `e9606b473c8150fc9eba27fe598bd7fb86414def` passed PR #154 CI #377 (`35309792577`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`. Counter domain validation emitted `COUNTER_TESTS_PASSED`; both browsers exercised the eleven-family Creator Preview flow and emitted `counterPolicy=actual-hit-once`, with the complete browser suite reporting `SMOKE_SUITE_PASSED count=24`.

Latest PR head `5841591c10fc60bd5cf815e6d8a96fcc7548924a` then passed PR CI #379 (`35310681623`) across the full PR gate. PR #154 was squash-merged as `aad1e3f2787d32d4b09bec96a8509471fb0b574e`. Main CI #380 (`35311711648`) attempt #1 reached production Edge and passed the Counter flow, then an unchanged AI-skill-proposal smoke missed its second proposal-valid 5-second observation window. Without any code change, attempt #2 on the exact same SHA passed the complete production chain including Pages deployment/public reachability, Render exact-revision readiness and production Microsoft Edge full smoke.


## Remaining V2-2 families

After Counter production validation, the phase still requires:

- safe scripted event compositions,
- grab,
- summon.

The exact implementation order may change if repository constraints make one family a better dependency, but all remaining V2-2 scope items remain required for phase completion.
