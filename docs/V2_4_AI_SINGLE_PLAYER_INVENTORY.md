# V2-4 AI Opponents & Single-player Gameplay — Architecture Inventory

Date: 2026-09-21

## Purpose

This inventory defines the safe implementation boundary for V2-4 before active-opponent runtime code is added. The goal is to reuse the existing combat/match authority instead of creating a second combat engine or allowing AI behavior to mutate combat state directly.

V2 progress remains **37.5% (3/8 phases complete)** until all V2-4 acceptance criteria are satisfied.

## Existing runtime foundations

### Match flow already exists

`game/runtime/main.tscn` uses `match_flow_main.gd` as the runtime root through the existing preview/animation inheritance chain.

`match_flow_main.gd` already:
- detects opponent defeat and player defeat,
- publishes `victory` / `defeat`,
- freezes runtime controllers after match completion,
- shows a result overlay,
- supports **重新開始**,
- supports **返回 Creator**,
- exposes deterministic Web bridges/telemetry for restart/return validation.

The existing `tests/match_restart_web_smoke.mjs` proves victory, restart-state reset and return-to-Creator behavior in the deployed Web runtime. V2-4 should extend this flow rather than replace it.

### Combat authority already exists

`game/runtime/main.gd` owns the current Training combat state:
- player `CombatantState`,
- passive Dummy `CombatantState`,
- movement/jump/dash state,
- basic attack chain,
- skill cast/controller state,
- hit/knockback/knockdown state,
- bounded arena coordinates.

V2-2 Counter work already introduced the formal `receive_player_hit(amount, source_x, source_depth, hitstun)` boundary. An AI opponent must use that authoritative incoming-hit path instead of changing `player_state.hp` directly.

Player attacks and skills currently target the Training Dummy through the existing validated runtime/controller collision paths. V2-4 should generalize target ownership carefully rather than bypass those paths with AI-specific damage shortcuts.

### Current opponent is passive

The current Dummy:
- has HP and recovery/knockdown state,
- can be moved by knockback/grab effects,
- can be damaged by the existing player combat stack,
- does not make movement, guard, attack or skill decisions.

There is currently no gameplay opponent-AI controller or difficulty/behavior profile contract.

### Stage state is currently implicit

The current arena uses fixed/bounded runtime coordinates and drawing logic. There is no authoritative `StageDefinition`, stage registry or stage-selection flow yet.

Therefore stage definitions/selection should be a later bounded V2-4 work unit, not mixed into the first AI decision slice.

## V2-4 architecture rules

1. **AI produces intents, not combat mutations.**
   - Allowed examples: horizontal/depth movement intent, guard intent, basic-attack intent, validated skill-slot intent.
   - AI must not directly set HP/MP, cooldowns, hitstun, knockback or match result.

2. **Existing combat state remains authoritative.**
   - Player damage from an opponent routes through `receive_player_hit(...)`.
   - Opponent damage from player actions continues through validated collision/controller paths.
   - Match completion remains owned by `match_flow_main.gd`.

3. **Behavior profiles are bounded declarative data.**
   - No scripts, callbacks, resource paths, URLs, arbitrary expressions or user executable code.
   - Unknown profile IDs/fields and out-of-range values fail closed.

4. **Decision logic is deterministic under explicit inputs.**
   - Given the same profile, positions, combat readiness and tick input, the core decision layer must return the same intent.
   - Randomness is deferred until a future explicit seeded design requires it.

5. **Difficulty changes policy, not combat authority.**
   - Difficulty may alter bounded reaction interval, preferred distance, guard tendency/policy or which validated actions are eligible.
   - Difficulty must not secretly multiply authored damage, bypass MP/cooldown, or change hit resolution.

6. **Training compatibility remains intact.**
   - Existing passive Training/Creator Preview behavior remains available.
   - AI activation must be mode/profile driven rather than making every existing Training preview active by default.

## V2-4 Work Unit 1 — deterministic opponent behavior foundation

### Scope

Implement the first bounded gameplay-AI foundation without stage selection or full single-player UI:

1. Add a strict `OpponentBehaviorProfile` data contract under the gameplay AI/core boundary.
2. Define a small allow-listed first profile set, initially suitable for deterministic testing.
3. Add a pure decision state that consumes:
   - opponent/player positions,
   - current distance/depth delta,
   - opponent actionable/disabled state,
   - guard/attack/skill readiness supplied by runtime,
   - the validated behavior profile.
4. Return only an allow-listed intent structure such as:
   - `move_x`,
   - `move_depth`,
   - `guard`,
   - `basic_attack`,
   - optional validated `skill_slot`,
   - `idle`.
5. Fail closed when the profile or snapshot is invalid.
6. Add deterministic Godot domain tests for:
   - invalid/unknown profile rejection,
   - distance-band approach/hold/retreat decisions,
   - depth alignment,
   - disabled/non-actionable state,
   - attack-vs-guard eligibility,
   - no direct combat-state mutation.
7. Wire those domain tests into the existing GitHub CI domain-test gate.
8. Do **not** activate the AI in ordinary Training yet. Runtime opponent integration is the next work unit.

### Non-goals for Work Unit 1

- no stage schema or stage selector,
- no new match UI,
- no direct opponent rendering replacement,
- no AI-authored damage/cooldown values,
- no network behavior,
- no arbitrary scripts/callbacks,
- no production AI/LLM dependency,
- no stochastic behavior.

## Planned follow-up sequence

### Work Unit 2 — active opponent runtime adapter
Attach the deterministic decision layer to an active opponent that uses existing movement/combat authority and calls `receive_player_hit(...)` for successful opponent hits. Add Web/Edge regression proving the opponent approaches, attacks and can cause player defeat while existing Training remains passive when AI mode is not selected.

### Work Unit 3 — difficulty profiles
Expose a bounded profile selector and add multiple deterministic behavior profiles without changing combat-authority values.

### Work Unit 4 — stage definition + registry
Introduce safe stage data for arena bounds/spawns/presentation tokens with strict validation.

### Work Unit 5 — stage selection + single-player entry
Add a selectable single-player flow that chooses validated opponent profile + stage before match start.

### Work Unit 6 — full single-player acceptance
Validate win/loss/restart/return across selectable stage content against an active opponent in Chromium, hosted Microsoft Edge and deployed production Web.

## V2-4 acceptance target

V2-4 is complete only when the deployed Web build supports a complete single-player match against an active AI opponent on selectable validated stage content, including win/loss/restart/return flow and repeatable regression coverage.
