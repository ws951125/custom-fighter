# V2-2 Extended Skill Families — Architecture Inventory

Date: 2026-09-17

## Purpose

This inventory is the implementation baseline for V2-2. It records the current V1 family boundaries, Creator/runtime bottlenecks, reusable V2 timeline primitives, existing regression coverage, and the first safe new-family slice. The goal is to extend the engine without introducing arbitrary code execution or duplicating one editor/controller stack per family.

## Existing V1 skill families

| Family | Runtime/data boundary | Primary parameters | Current character slot |
| --- | --- | --- | --- |
| `projectile` | `SkillDefinition` + root projectile runtime | speed, range, active hitbox | `skill_1` / U |
| `dash` | `SkillDefinition` + root dash-slash runtime | speed, range, active hitbox | `skill_2` / I |
| `area` | `AreaAttackState` + coordinated area controller | active spatial hitbox | `skill_3` / O |
| `formation` | formation state/controller | count, spacing, interval, offset, spatial hitbox | `skill_4` / P |
| `buff` | buff state/controller | duration, movement multiplier, basic-attack multiplier | `skill_5` / B |
| `melee` | melee state/controller | range, active spatial hitbox | `skill_6` / H |

All six are declared in `SkillDefinition.SUPPORTED_TYPES`. `SkillRegistry` validates the registry type and then requires an exact expected-type match when loading a character slot.

## Creator inventory

Before this V2-2 work unit, `SkillDraft` and the visible Skill Editor were projectile-only even though the runtime supported six V1 families:

- `SkillDraft.load_from_dictionary()` rejected every non-projectile `SkillDefinition`.
- `SkillDraft.validate()` enforced the same projectile-only restriction.
- the Skill Editor displayed a fixed PROJECTILE template and exposed no family selector.
- Creator Preview currently treats `skill_1` as a projectile-only preview path.

The first V2-2 foundation work unit removes the first three authoring restrictions while preserving projectile as the backwards-compatible reset/default family. Creator Preview/runtime dispatch remains a separate explicit follow-up so family selection cannot silently claim preview support that does not exist yet.

## Runtime routing inventory

The current playable character binds each of its six slots to a fixed family:

- slot 1 loads `projectile`,
- slot 2 loads `dash`,
- slot 3 loads `area`,
- slot 4 loads `formation`,
- slot 5 loads `buff`,
- slot 6 loads `melee`.

`SkillRegistry.load_skill()` also requires callers to provide the expected family. This is safe and fail-closed, but it means a new V2 family cannot simply replace an arbitrary slot without a routing change. V2-2 should preserve exact registry/file type verification while moving family dispatch to a validated data-driven boundary.

## Reusable V2 timeline primitives

V2-1 already provides safe declarative event composition:

- `animation`,
- `vfx`,
- `audio`,
- `hitbox`,
- `hurtbox`.

The timeline contract enforces deterministic ordering, stable IDs, event-count/duration limits, safe media tokens and bounded spatial payloads. These primitives should be reused by new families rather than adding executable callbacks or user-supplied scripts.

## Existing validation coverage

The repository already validates:

- `SkillDefinition` / registry fail-closed behavior through Godot domain tests,
- each V1 family through deterministic state/controller tests,
- Creator skill draft validation and timeline round-trip,
- Web Creator editing through Playwright Chromium and hosted Microsoft Edge,
- exported Web runtime skill behavior through the existing smoke suite,
- Windows native export,
- production GitHub Pages and production Edge smoke after merge.

V2-2 additions must extend those same online gates.

## Work unit 1 acceptance — skill-family authoring foundation

This work unit is complete only when:

1. Creator can select every currently supported V1 family from one safe family selector.
2. switching family applies deterministic safe defaults required by that family's `SkillDefinition` validation.
3. all six families serialize and reload through `SkillDraft` → `SkillDefinition` without code execution.
4. unsupported/unsafe family values fail closed and do not mutate a valid draft through the selector API.
5. projectile remains the reset/default family so existing package, VFX, AI-proposal and Creator Preview flows remain backwards compatible.
6. domain tests and Creator Chromium/Edge smoke cover the family switch path.

This foundation does **not** claim non-projectile Creator Preview support yet.

## First new V2 family selection: `beam`

`beam` is the first planned new family after the authoring/routing foundation.

Reasons:

- it can reuse existing declarative `range`, `active`, damage/hitstun/knockback and bounded spatial hitbox parameters;
- it can reuse V2 timeline animation/VFX/audio/hitbox events without a new executable event surface;
- it does not require spawning an autonomous actor (`summon`), moving the target (`grab`), reactive interception (`counter`) or relocating the player (`teleport`) in the first expansion slice;
- it provides a clean test of data-driven family dispatch beyond the original six before more stateful families are added.

Planned beam acceptance:

- `SkillDefinition` recognizes `beam` and validates its declarative parameters fail-closed;
- registry/package paths preserve exact family validation;
- runtime beam state/controller executes deterministically and damages at most according to the defined hit policy;
- Creator can author a beam through the shared family editor;
- Creator Preview can route the authored beam without pretending it is a projectile;
- Godot domain tests plus Chromium and hosted Edge smoke validate the full path;
- no arbitrary user code, path or executable callback is introduced.

## Remaining V2-2 families

After beam, the phase still requires:

- summon,
- grab,
- counter,
- teleport,
- trap,
- aura,
- safe scripted event compositions.

The exact implementation order may change if a later repository constraint makes another family a better dependency, but all eight V2-2 scope items remain required for phase completion.
