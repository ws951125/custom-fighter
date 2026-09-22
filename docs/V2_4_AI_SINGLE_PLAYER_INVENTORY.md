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

## Work Unit 1 implementation result

Implementation branch: `feat/v2-4-wu1-opponent-decision-foundation`

- `game/core/ai/opponent_behavior_profile.gd` provides the strict bounded profile contract.
- `game/core/ai/opponent_behavior_profiles.gd` provides the initial allow-list: `training_balanced` and `training_pressure`.
- `game/core/ai/opponent_decision_state.gd` converts validated profile + explicit runtime snapshot data into inert intents only.
- Invalid profile/snapshot data returns idle; no runtime combat object is mutated by the decision layer.
- `tests/opponent_behavior_test_runner.gd` proves fail-closed validation, distance/depth policy, disabled state, guard/attack/skill eligibility, determinism and no HP/MP mutation.
- CI #500 caught a GDScript fixture return-type inference parser issue; explicit typing fixed it without changing the decision policy.
- PR #181 head `9ade45c95059bca3c22eeda5f3714d951603435d` passed CI #501 (`35591729594`) across Windows Native, Godot/domain/AI contracts, backend, Web/Chromium and hosted Edge.
- WU1 does **not** activate gameplay AI. Exact-main merge/production validation remains required before WU2 begins.

## Planned follow-up sequence

### Work Unit 2 — active opponent runtime adapter
Attach the deterministic decision layer to an active opponent that uses existing movement/combat authority and calls `receive_player_hit(...)` for successful opponent hits. Add Web/Edge regression proving the opponent approaches, attacks and can cause player defeat while existing Training remains passive when AI mode is not selected.

Implementation result:
- Added explicit router mode `single_player`; the existing Training scene is reused, but opponent AI activates only when this mode is selected.
- Ordinary `training` remains the backwards-compatible passive Dummy mode.
- Runtime AI movement consumes WU1 movement intents and remains bounded by the existing arena coordinates.
- Opponent basic attacks reuse `AttackChainState` timing/damage/hitstun data and must pass the existing combat-box overlap test before calling `receive_player_hit(...)`.
- AI never writes player HP directly; `receive_player_hit(...)` remains the single opponent→player damage authority, including Counter/Guard handling.
- Match defeat remains owned by `match_flow_main.gd`; restart remounts `single_player` when AI is active.
- Domain coverage proves an attack-ready opponent deterministically closes from preferred spacing into basic-attack range.
- `opponent_ai_web_smoke.mjs` proves approach → attack → player damage → defeat → restart and separately proves passive ordinary Training.
- PR #182 CI #506 (`35605738012`) passed Windows Native, Godot/domain/AI contracts, backend, Web export/size budget, Chromium `smoke:all` and hosted Edge `smoke:all`.
- PR #182 was explicitly approved and squash-merged to `main` as `c548cfb3c0e53d2b1170205c1f1948889845db22`.
- Exact-main CI #508 attempt 2 passed Chromium `smoke:all`, Windows Native, hosted Edge `smoke:all`, GitHub Pages deployment and public reachability. The Render AI backend returned HTTP 503 for all readiness attempts, so backend-dependent production Edge full smoke remained blocked/skipped.

### Work Unit 3 — difficulty profiles
Expose a bounded profile selector and add multiple deterministic behavior profiles without changing combat-authority values.

Implementation result:
- Added `training_cautious` beside `training_balanced` and `training_pressure`, with bounded Easy/Cautious, Normal/Balanced and Hard/Pressure labels.
- Profile IDs remain allow-listed declarative data. Invalid runtime selections are ignored; invalid startup query values normalize to the bounded Balanced default.
- `main_router.gd` owns `opponent_profile_id`, accepts `opponent_profile` only through the allow-list, and preserves the selected profile when the single-player scene remounts/restarts.
- `match_flow_main.gd` loads the router-selected profile and exposes a single-player-only on-canvas `AI Difficulty` `OptionButton`; ordinary Training creates no selector and activates no opponent AI.
- Web telemetry publishes the active profile, reaction interval, basic-attack policy range and selector state. A bounded bridge mirrors the selector path for cross-browser automation.
- Difficulty changes only decision policy. Opponent basic attacks still use the same `AttackChainState` damage/hitstun data and the same authoritative `receive_player_hit(...)` path.
- Domain coverage proves profile ordering/default/labels and a deterministic same-snapshot policy difference between Balanced and Pressure.
- Browser coverage switches Balanced → Pressure → Cautious, rejects an unsafe profile token, verifies Balanced and Pressure deal identical authoritative basic-attack damage, and re-proves passive ordinary Training.
- PR #183 CI #509 (`35680419513`) passed Godot import/boot/domain/AI contracts, backend, Web export/size budget, Chromium `smoke:all`, Windows Native Release and hosted Microsoft Edge `smoke:all` on head `4571f15e5620662c5f6fa80e87a625d1dc5b3723`.
- PR #183 was explicitly approved and squash-merged to `main` as `1ae941dec82788a219073c831ebd36b657fd058d`.
- Exact-main CI #511 passed Windows Native, Godot/domain/AI/backend, Web export/size budget and Chromium `smoke:all`; hosted Edge passed on a same-SHA failed-chain retry after an unchanged `creator_package_vfx_web_smoke.mjs:252` observation timeout. Pages deployment/public reachability passed. Render exact-revision readiness still returned HTTP 503, so backend-dependent production Edge full smoke remained blocked/skipped.

### Work Unit 4 — stage definition + registry
Introduce safe stage data for arena bounds/spawns/presentation tokens with strict validation.

Implementation result:
- `StageDefinition` is a strict schema-v1 declarative contract. It accepts only stage ID/display name, bounded horizontal arena margin, normalized player/opponent spawn X/depth values, and allow-listed background/floor semantic tokens.
- Unknown fields fail closed, including executable-style `script` / `callback` fields. Stage IDs reject traversal/URL-like syntax. Presentation data cannot contain arbitrary resource paths, URLs or executable references.
- Horizontal margin is bounded to 60–240px; spawn X ratios stay within 0.08–0.92 with at least 0.15 separation; depth stays within 0–1.
- `StageRegistry` supplies deterministic built-ins `training_arena` and `sunset_court`, with `training_arena` as the bounded default/fallback.
- The Training preset preserves the current runtime's effective 90px arena margin and corresponding normalized legacy spawn positions; WU4 itself does not mutate runtime placement.
- `stage_definition_test_runner.gd` proves canonical load/round-trip, deterministic registry behavior, fail-closed executable/unknown fields, unsafe IDs, path/URL presentation rejection, arena/spawn bounds and minimum separation.
- The new domain runner is part of the required GitHub CI domain-test gate.
- Runtime application and stage-selection UI remain intentionally deferred to Work Unit 5.
- PR #184 CI #512 (`35691723517`) passed the stage domain runner, Godot import/boot/domain/backend gates, Web export/size budget, Chromium `smoke:all`, Windows Native Release and hosted Microsoft Edge `smoke:all` on head `649d225f3399d3878a474c97697bc1bb5b9ba237`.
- PR #184 is open and mergeable; merge remains gated on explicit user approval.

### Work Unit 5 — stage selection + single-player entry
Add a selectable single-player flow that chooses validated opponent profile + stage before match start.

### Work Unit 6 — full single-player acceptance
Validate win/loss/restart/return across selectable stage content against an active opponent in Chromium, hosted Microsoft Edge and deployed production Web.

## V2-4 acceptance target

V2-4 is complete only when the deployed Web build supports a complete single-player match against an active AI opponent on selectable validated stage content, including win/loss/restart/return flow and repeatable regression coverage.
