# V2-5 Game Modes, Balance & Competitive Foundation — Architecture Inventory

Date: 2026-09-22

## Purpose

V2-5 establishes the safety, balance and authority boundary required before V2-6 Network PvP. It does **not** add networking. The phase must ensure that competitive gameplay never trusts player-authored combat values merely because a character package passed the existing structural/schema checks.

V2 progress remains **50% (4/8 phases complete)** until all V2-5 acceptance criteria are satisfied.

## Existing foundations

### Router and current modes

`game/app/main_router.gd` currently recognizes:
- `training`,
- `creator`,
- `vfx`,
- `single_player`.

There is no authoritative `GameModeDefinition`, game-mode registry, competitive ruleset, rules version, or compatibility handshake yet. Unknown mode input currently normalizes to `training`.

### Existing combat authority

The runtime already has useful authority boundaries that V2-5 should preserve rather than duplicate:
- player state and combat resolution remain owned by the runtime;
- `receive_player_hit(...)` is the formal opponent→player damage boundary;
- player attacks/skills resolve through validated runtime/controller paths;
- `match_flow_main.gd` owns victory/defeat/restart/return;
- AI difficulty changes decision policy rather than authoritative damage values.

These are strong single-process foundations, but they are not yet sufficient for competitive client/server trust.

### Existing character validation

`CharacterDefinition` already:
- rejects unknown top-level/stat/skill-slot fields;
- requires schema version 1;
- validates safe IDs/tokens;
- bounds character stats:
  - `max_hp`: 1–10000,
  - `max_mp`: 0–10000,
  - `move_speed`: >0–2000,
  - `depth_speed`: >0–5,
  - `run_multiplier`: 1–3,
  - `guard_move_multiplier`: 0–1;
- validates required/optional skill slot IDs.

These are **safety/shape bounds**, not competitive balance bounds. A structurally valid character can still be far too strong for competitive play.

### Existing skill validation

`SkillDefinition` already:
- supports the bounded declarative skill families;
- rejects unsupported schema/type/timeline structures;
- requires non-negative `damage`, `mp_cost`, `cooldown`, timing, hitstun and knockback values;
- applies family-specific geometry/lifetime constraints;
- forbids arbitrary executable timeline behavior.

These checks protect runtime safety and data integrity. They do **not** currently impose a competitive upper power budget on authored damage, cooldown efficiency, MP efficiency, movement/displacement, hitbox coverage, status duration, or aggregate loadout strength.

### Existing package validation

Character package loaders already:
- enforce schema versions;
- reject unknown/unsafe package content;
- preserve backward compatibility where explicitly supported;
- transport bounded declarative assets/data;
- reject arbitrary executable content.

Package validity must remain distinct from competitive eligibility:
- **package valid** = safe to parse/load;
- **competitive eligible** = also passes the active competitive ruleset and power budget.

A valid package must never automatically imply competitive eligibility.

## V2-5 architecture rules

1. **Mode policy is declarative and allow-listed.**
   - Introduce a strict `GameModeDefinition` plus registry.
   - Unknown IDs/fields fail closed.
   - Mode definitions may select only allow-listed ruleset/power-budget IDs.
   - No callbacks, scripts, arbitrary resource paths, URLs or executable payloads.

2. **Sandbox and competitive validation are separate.**
   - Sandbox/single-player may continue to use the existing broad safe schema limits.
   - Competitive mode applies an additional deterministic eligibility layer.
   - Competitive normalization must not silently rewrite the user's stored Creator/package source data.

3. **Competitive content is admitted through a derived authoritative snapshot.**
   - Input package/character/skill data is treated as a proposal.
   - Authority validates schemas, resolves registries, applies the competitive ruleset and builds an immutable/derived `CompetitiveLoadoutSnapshot` (name may change during implementation).
   - Runtime combat uses the admitted authoritative values, never raw client-authored values.

4. **Clients provide intents, not combat facts.**
   - Future V2-6 clients may submit inputs/intents.
   - They must not submit accepted damage, cooldown expiry, HP/MP, hit confirmation, knockback, victory result or authoritative timestamps as trusted facts.
   - Host/server authority computes those outcomes from the validated ruleset and loadout snapshot.

5. **Power-budget decisions are deterministic.**
   - Same content + same ruleset/version must return the same normalized eligibility result and diagnostics.
   - No random coefficients, network-dependent values, wall-clock dependence or AI/LLM calls.
   - Floating-point comparisons require explicit deterministic rounding/tolerance policy.

6. **Competitive rejection is explainable.**
   - Validation returns stable error codes/fields, not only free-form text.
   - Diagnostics identify which character stat, skill field, aggregate metric or incompatibility failed.
   - Creator UX can later surface these diagnostics without duplicating policy logic.

7. **Compatibility is explicit and versioned.**
   - Competitive admission must bind to an allow-listed `ruleset_id` + integer `ruleset_version`.
   - Package schema version and ruleset version are separate concepts.
   - Same schema version may be evaluated differently by a newer competitive ruleset, but the active match uses one frozen ruleset version from start to finish.
   - Unsupported/newer ruleset versions fail closed rather than silently downgrading.

8. **One authority path for all competitive combat.**
   - Local competitive simulation, future hosted match authority and V2-6 network authority should share the same deterministic rules/eligibility core.
   - Do not create separate "browser balance" and "server balance" implementations.

## Proposed bounded data contracts

### GameModeDefinition

Initial contract should contain only policy selection, not combat values:

```text
schema_version
id
display_name
mode_family
ruleset_id
ruleset_version
power_budget_id
authority_policy
allows_custom_content
```

Initial allow-listed semantic values:
- `mode_family`: `sandbox`, `single_player`, `competitive`;
- `authority_policy`: `local_authoritative`, `host_authoritative`.

For V2-5, `competitive` may still run locally for deterministic validation/simulation. `host_authoritative` is an architecture contract for V2-6, not a claim that networking exists.

### CompetitiveRulesetDefinition

Proposed fields:

```text
schema_version
id
version
power_budget_id
character_constraints_id
skill_constraints_id
determinism_policy_id
```

Rulesets reference allow-listed policy IDs rather than embedding arbitrary expressions.

### CompetitiveLoadoutSnapshot

Derived output, never accepted directly from a client:

```text
ruleset_id
ruleset_version
character_id
normalized_character_stats
resolved_skill_slots
normalized_skill_values
power_budget_result
content_fingerprint
```

The exact serialized shape can be finalized when implementation begins. The critical invariant is that this snapshot is built by authority from validated source data.

## Power-budget policy inventory

V2-5 needs two layers:

### Layer A — hard competitive caps

These protect the ruleset from extreme-but-schema-valid values. Candidate dimensions include:
- HP / MP;
- movement and run multiplier;
- per-skill damage;
- MP cost;
- cooldown;
- startup / active / recovery;
- range;
- hitbox width/depth;
- hitstun / knockback;
- projectile/summon speed and lifetime;
- teleport/grab/counter reach/window;
- formation count/coverage;
- buff duration and multipliers.

The existing schema limits remain the outer safety envelope; competitive caps will be materially narrower.

### Layer B — aggregate power budget

Hard caps alone cannot catch combinations such as high damage + low cooldown + low MP cost + huge coverage.

A deterministic aggregate score/budget should therefore account for:
- character durability/mobility;
- skill burst damage;
- sustained damage efficiency;
- resource efficiency;
- startup/recovery risk;
- spatial coverage/reach;
- control/hitstun/knockback;
- movement/displacement utility;
- buff uptime/multipliers;
- multi-actor/multi-strike potential.

**WU1 intentionally does not lock numeric weights yet.** Numeric coefficients should be introduced only with deterministic fixtures that include baseline reference characters/skills, obvious over-budget examples, boundary cases and monotonicity checks. This prevents arbitrary tuning constants from becoming architecture by accident.

## Normalization policy

Competitive validation should prefer:
1. reject unsafe/invalid source data through existing schema validators;
2. resolve exact registry/type compatibility;
3. apply competitive hard caps and aggregate budget;
4. either:
   - reject over-budget content with diagnostics; or
   - apply an explicitly versioned normalization policy when the active mode/ruleset says normalization is allowed.

Default competitive policy should be **reject, not silently nerf**, until a normalization UX is intentionally designed. Silent rewriting would make Creator/package values differ from what the user authored and complicate deterministic debugging.

Sandbox remains unaffected.

## Content fingerprint and compatibility

Before V2-6, V2-5 should define a deterministic content fingerprint over:
- canonical character definition;
- canonical resolved skills;
- active competitive ruleset ID/version;
- active power-budget policy ID/version (if separately versioned).

The fingerprint is for compatibility/equality checks, not security authentication. V2-6 may later bind it into session negotiation.

Canonicalization must:
- use deterministic field ordering/representation;
- exclude presentation-only runtime telemetry;
- exclude non-authoritative client state;
- avoid locale/time-dependent serialization.

## Host/server-authoritative boundary for V2-6

V2-5 must leave V2-6 with this explicit contract:

Trusted by authority:
- validated game mode/ruleset;
- authoritative loadout snapshot;
- authoritative combat clock/tick;
- accepted player input sequence;
- authority-computed HP/MP/cooldowns;
- authority-computed hit/collision/damage/state transitions;
- match result.

Untrusted client proposals:
- raw package content;
- selected character/package ID;
- inputs/intents;
- cosmetic preferences that do not affect authority.

Never trusted from the client as final:
- damage dealt;
- hit confirmed;
- current HP/MP;
- cooldown ready;
- status/hitstun/knockback result;
- opponent position as authoritative truth;
- victory/defeat;
- ruleset/budget bypass flags.

## Planned implementation sequence

### Work Unit 1 — architecture/inventory
This document plus STATUS/roadmap synchronization. No product functionality change.

### Work Unit 2 — bounded game-mode + ruleset contracts
Implemented on branch `feat/v2-5-wu2-game-mode-ruleset-contracts`:
- `GameModeDefinition` is schema-v1, unknown-field/missing-field fail-closed, and allow-lists mode families, ruleset IDs, power-budget IDs and authority policies.
- Semantic combinations are fail-closed: sandbox and single-player retain their own bounded rulesets plus `sandbox_safe_limits` and must stay `local_authoritative`; competitive uses `competitive_standard@1` + `competitive_standard_v1` and may be local- or host-authoritative.
- `CompetitiveRulesetDefinition` allow-lists power-budget, character-constraint, skill-constraint and determinism-policy IDs and rejects unsupported versions/policies.
- `CompetitiveRulesetRegistry` exposes deterministic `sandbox_default@1`, `single_player_default@1` and `competitive_standard@1`.
- `GameModeRegistry` exposes deterministic `sandbox`, `single_player`, `competitive_local` and `competitive_hosted` definitions and cross-checks ruleset version + power-budget agreement before loading.
- `tests/game_mode_ruleset_test_runner.gd` proves canonical deterministic round trips, registry ordering, no partial load on failure, executable/unknown field rejection, external/unsafe reference rejection, competitive budget downgrade rejection and version compatibility failure.
- The domain runner is part of the required GitHub CI contract.
- `main_router.gd` is deliberately unchanged; WU2 adds policy contracts only and does not expose competitive mode to users yet.

### Work Unit 3 — competitive power-budget validator
Implemented on branch `feat/v2-5-wu3-competitive-power-budget`:
- `CompetitivePowerBudgetValidator` binds eligibility to exact budget ID `competitive_standard_v1`; sandbox/unknown budget IDs fail closed.
- Character and skill hard caps are intentionally narrower than the outer safety/schema bounds and include family-specific competitive ceilings/floors.
- Deterministic integer scoring freezes character `<= 3200`, per-skill `<= 4500`, and occupied-slot aggregate loadout `<= 18000`.
- Reusing the same strong skill in multiple character slots counts once per occupied slot, preventing duplicate-slot budget bypass while emitting one stable per-skill diagnostic.
- Stable diagnostics distinguish unsupported budget, unloaded/missing/unreferenced/duplicate skills, character hard/score caps, skill hard/score caps and aggregate loadout cap.
- Existing authored definitions are read-only inputs; evaluation never normalizes or rewrites Creator/package source data.
- Reference fixtures freeze Ember Vanguard at `2683 / 15649` and Storm Duelist at `2787 / 15426` (character / total), both eligible.
- Domain tests cover exact-reference scores, skill-order determinism, no mutation, hard caps, aggregate repeated-slot pressure, inclusive boundaries and monotonic score increases for stronger damage, shorter cooldown and cheaper MP cost.
- WU3 remains domain-only; router/UI/runtime combat do not consume the validator until later work units.

### Work Unit 4 — authoritative loadout snapshot + fingerprint
Build the derived competitive snapshot only from schema-valid, registry-resolved, budget-valid content. Add deterministic canonical fingerprint/version compatibility coverage.

### Work Unit 5 — competitive local simulation boundary
Route a local competitive mode through the authoritative snapshot/ruleset path and prove raw authored values cannot bypass admitted values. This remains local/host-authoritative foundation, not network PvP.

### Work Unit 6 — full V2-5 acceptance
Cross-browser regression proves:
- sandbox remains permissive within existing safe schema limits;
- competitive rejects/normalizes only according to the frozen ruleset;
- over-budget packages cannot control authoritative damage/cooldown;
- ruleset/version mismatch fails closed;
- the same accepted content yields deterministic authority values across Chromium and hosted Edge.

## Non-goals for V2-5

- no lobby/session networking;
- no realtime synchronization;
- no reconnect/forfeit protocol;
- no matchmaking;
- no client prediction/rollback;
- no anti-cheat kernel/OS integration;
- no arbitrary user scripts;
- no cryptographic identity/authentication design unless required by a later phase;
- no AI/LLM-driven balance decision at runtime.

Those belong to V2-6 or later.

## V2-5 acceptance target

V2-5 is complete only when competitive-mode content cannot bypass the validated power budget, game/rules versions fail closed deterministically, and the architecture/runtime path does not trust client-authored combat authority. The resulting foundation must be directly reusable by V2-6 Network PvP.
