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

Before V2-2 work unit 1, `SkillDraft` and the visible Skill Editor were projectile-only even though the runtime supported six V1 families:

- `SkillDraft.load_from_dictionary()` rejected every non-projectile `SkillDefinition`.
- `SkillDraft.validate()` enforced the same projectile-only restriction.
- the Skill Editor displayed a fixed PROJECTILE template and exposed no family selector.
- Creator Preview treated `skill_1` as a projectile-only preview path.

Work unit 1 removed the authoring restriction while preserving projectile as the backwards-compatible reset/default family. It was merged by PR #145 as `7c6eb8aebe1797f1c0a14176f7a7721e07f52771`; Main CI #342 (`35190460843`) passed Windows Native, Godot/domain/backend/Web/Chromium, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness and production Microsoft Edge full smoke.

## Runtime routing inventory

The current playable character binds each of its six slots to a fixed family:

- slot 1 loads `projectile`,
- slot 2 loads `dash`,
- slot 3 loads `area`,
- slot 4 loads `formation`,
- slot 5 loads `buff`,
- slot 6 loads `melee`.

`SkillRegistry.load_skill()` also requires callers to provide the expected family. This is safe and fail-closed. V2-2 preserves that exact type check and adds a preview-only mapping from validated family → existing validated slot/controller instead of pretending every authored skill is a projectile.

## Reusable V2 timeline primitives

V2-1 already provides safe declarative event composition:

- `animation`,
- `vfx`,
- `audio`,
- `hitbox`,
- `hurtbox`.

The timeline contract enforces deterministic ordering, stable IDs, event-count/duration limits, safe media tokens and bounded spatial payloads. V2-2 reuses those same `SkillCastState` timeline schedulers for every previewed family rather than creating family-specific executable event paths.

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

## Work unit 2 — Creator Preview family dispatch — implementation target

The preview session maps validated V1 family types onto the existing runtime slots/controllers:

| Family | Preview slot | Input |
| --- | --- | --- |
| `projectile` | `skill_1` | U |
| `dash` | `skill_2` | I |
| `area` | `skill_3` | O |
| `formation` | `skill_4` | P |
| `buff` | `skill_5` | B |
| `melee` | `skill_6` | H |

Acceptance for this work unit:

1. Creator Preview accepts all six currently supported V1 families after normal `SkillDefinition` validation.
2. only the mapped preview slot is replaced with the authored skill ID; the stored editable `CharacterDraft` and all other slots remain unchanged.
3. the selected slot loads the authored definition through the existing exact expected-type contract; mismatches fail closed.
4. projectile retains the existing custom VFX runtime binding; non-projectile preview does not mis-bind projectile-only VFX and does not delete the stored VFX draft.
5. V2 timeline transitions/events are consumed from the active family's `SkillCastState`, so animation/VFX/audio/hitbox/hurtbox composition does not remain projectile-only.
6. Godot domain regression covers all family→slot mappings and failure boundaries.
7. Chromium and hosted Edge smoke each author, preview, cast and round-trip all six families, including a declarative timeline event.
8. ordinary Training remains on the same six existing runtime controllers with no alternate executable path and no arbitrary user code.

## First new V2 family selection: `beam`

`beam` remains the first planned genuinely new family after the shared authoring and preview-routing foundation.

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
