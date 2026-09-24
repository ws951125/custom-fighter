# Project Status

## Current phase

**V1/MVP is complete; V2 roadmap is now active.**

- V1 completion remains **100% (13/13 phases complete)**.
- V2 completion is **62.5% (5/8 phases complete)**.
- Completed V2 phases: **V2-1 Advanced Creator Timeline**, **V2-2 Extended Skill Families**, **V2-3 Character Animation & Audio Authoring**, **V2-4 AI Opponents & Single-player Gameplay**, and **V2-5 Game Modes, Balance & Competitive Foundation**.
- Active V2 phase: **V2-6 Network PvP**.

V1 roadmap:
- M0–M8 MVP: 9/9 complete.
- P1 Safe real-provider boundary: complete.
- P2 Async remote AI transport: complete.
- P3 Production AI provider/backend integration: complete.
- P4 Image → skill proposal → Creator → Training production flow: complete.

V2 roadmap is defined in `docs/V2_ROADMAP.md` and captures previously discussed/deferred capabilities outside the V1 acceptance boundary.

## V2 roadmap

1. V2-1 Advanced Creator Timeline — **complete**.
2. V2-2 Extended Skill Families — **complete**.
3. V2-3 Character Animation & Audio Authoring — **complete**.
4. V2-4 AI Opponents & Single-player Gameplay — **complete**.
5. V2-5 Game Modes, Balance & Competitive Foundation — **complete**.
6. V2-6 Network PvP — **in progress**.
7. V2-7 Creator Sharing Ecosystem — pending.
8. V2-8 Mobile Targets — pending.

V2-1 delivered visual event timeline authoring, startup/active/recovery timing, animation/VFX/audio events, hitbox/hurtbox timing and spatial editing, safe multi-event compositions, validation, and Creator → Training preview round trip. V2-2 extended the data-driven skill engine beyond the six V1 families and is accepted complete with bounded Beam/Trap/Aura/Teleport/Counter/Grab/Summon families plus safe declarative scripted compositions. V2-3 is accepted complete with safe animation/audio authoring, self-contained package transport, fresh-session restore, runtime Animation PNG rendering, and packaged WAV playback. V2-4 AI Opponents & Single-player Gameplay is accepted complete with deterministic active opponents, bounded difficulty profiles, validated selectable stages, and deployed win/loss/restart/return single-player acceptance. V2-5 Game Modes, Balance & Competitive Foundation is accepted complete with frozen competitive rules, power-budget enforcement, deterministic authority snapshots/fingerprints, local competitive authority runtime, and Chromium/hosted-Edge acceptance. V2-6 Network PvP is now active.

### V2-6 implementation checkpoints

Work Unit 1 — **session/lobby + authority admission contract implemented; required PR validation passed on implementation head**:
- New `backend/pvp/protocol.mjs` defines protocol v1, `server_authoritative` policy, exact client loadout-claim fields, strict IDs/fingerprint/schema validation, authority-summary validation and compatibility keys.
- New `backend/pvp/session_service.mjs` provides a transport-neutral two-player lobby: host/create, join, server-owned async loadout admission, ready, host-only start, immutable public snapshots and authority-contract compatibility gating.
- Client loadout negotiation is intentionally limited to `character_id`, `content_fingerprint`, and `package_schema_version`; direct or disguised top-level client combat fields such as `damage` / `cooldown` are rejected before the server-owned admission adapter is called.
- A match cannot start until exactly two participants have server-admitted loadouts, are both ready, and share protocol/authority/schema/ruleset/version/power-budget compatibility.
- Authority-adapter exceptions fail closed as `AUTHORITY_ADMISSION_ERROR`; the participant remains without authority and cannot become ready.
- New `tests/pvp_session_service_test.mjs` covers lobby capacity, pre-admission ready rejection, forged combat-field rejection, authority callback isolation, fingerprint mismatch fail-closed, host-only start, compatibility mismatch, immutable returned state, post-start mutation rejection, and authority-adapter exception fail-closed behavior.
- `package.json test:backend` now runs the new PvP session contract test, so the existing required backend CI gate validates WU1 without adding a new browser/process job.
- PR #197 implementation head `c0831496552bd95104333b19abd60643103777f5` passed CI #566 (`35862684985`): Windows Native, Godot import/boot/domain/AI, trusted-backend tests including `PVP_SESSION_SERVICE_TESTS_PASSED`, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- New `docs/V2_6_NETWORK_PVP_INVENTORY.md` freezes the six-work-unit V2-6 sequence through two-client online acceptance.
- V2 remains **62.5% (5/8 phases complete)** until all V2-6 acceptance criteria pass.

### V2-5 implementation checkpoints

Work Unit 6 — **full V2-5 acceptance regression implemented; required PR validation passed on implementation head**:
- New `tests/v2_5_competitive_acceptance_test_runner.gd` treats the acceptance target as one contract: schema-safe sandbox content remains loadable, the same over-budget values are rejected by `competitive_standard_v1`, ruleset version mismatch emits no authority snapshot, frozen reference fingerprints are exact, and runtime materialization replaces forged HP/damage/MP/cooldown with admitted authority values.
- The overspec acceptance fixture intentionally stays inside the existing schema/safety envelope while exceeding competitive bounds: HP `222`, Skill 1 damage `41`, MP cost `4`, cooldown `0.25s`.
- `tests/competitive_local_web_smoke.mjs` now uses the normal Creator preview bridge to prove those overspec values remain usable in Training/sandbox behavior, then verifies Competitive Local uses authority-owned Ember values HP `100`, damage `18`, MP cost `25`, cooldown `1.8s`.
- Cross-browser acceptance freezes the exact known-good authority fingerprints observed identically in prior Chromium/Edge validation: Ember `56451d3bdf1c7bf74852a3620894667730ddb088f350eb598badfa74c6d3c28e`; Storm `5822c6cfb4737c29007f2450a598c501b79c17d8ed9a432e4327976cc6a7026e`.
- Competitive runtime publishes diagnostic-only admitted Skill 1 ID/damage/MP/cooldown telemetry so browser acceptance can verify authority values directly without timing-dependent combat inference.
- The existing `smoke:competitive-local` stage is strengthened in place rather than adding another browser stage, preserving the current Chromium/hosted-Edge CI call budget.
- Required CI now runs the WU6 acceptance domain runner. PR #195 implementation head `e0a65026ea5cafb9561e9650f7c9c33254746a76` passed CI #561 (`35823214802`): Windows Native, Godot import/boot/domain/backend including `V2_5_COMPETITIVE_ACCEPTANCE_TESTS_PASSED`, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`. Hosted Edge attempt 1 timed out only in unchanged `match_restart_web_smoke.mjs:100`; a targeted same-SHA retry of only the failed Edge job passed the complete Edge suite in attempt 2 with no product/test change, consistent with L-037/L-043.
- Final docs-sync head `a939a102e4a70e8cd667c73119bd85d0361d600c` passed CI #562 (`35830131868`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- PR #195 was explicitly approved and squash-merged to `main` as `d2fa89d7d20cf9f98917b6e57e38057751c9bd1a`. Exact-main CI #563 (`35834994468`) passed all V2-5 product gates, Chromium/hosted Edge, GitHub Pages deployment and public reachability. Overall workflow conclusion was failure only because the pre-existing external Render AI backend returned HTTP 503 for all 18 readiness attempts; production Edge full smoke was skipped behind that external dependency.
- V2-5 is accepted complete; V2 progress is **62.5% (5/8 phases complete)**.

Work Unit 5 — **local competitive authority runtime implemented; required PR validation passed on implementation head**:
- New `CompetitiveRuntimeAuthority` resolves only `competitive_local`, requires its frozen `competitive_standard@1` / `competitive_standard_v1` contract, consumes the WU4 authority snapshot, re-validates its SHA-256 fingerprint before runtime materialization, and fails closed on mode/policy/snapshot mismatch.
- `main_router.gd` now recognizes `?mode=competitive_local` and mounts the existing combat runtime without adding network PvP.
- Competitive runtime character HP/MP/mobility and skill damage/MP/cooldown/timing/range/hitbox-family values are materialized through the admitted authority snapshot path; runtime targets are first reloaded through authority registries and then overwritten with admitted snapshot combat values.
- Creator Preview may continue to provide presentation preview state, but its raw character/skill combat payload is blocked from replacing competitive runtime combat definitions.
- Admission failure leaves the character unloaded, disables root combat input and all skill controllers (including Grab/Summon), publishes diagnostics, and never falls back to sandbox/training combat authority.
- Restart now preserves the active router mode, so `competitive_local` restarts remain competitive instead of silently returning to Training.
- New `tests/competitive_runtime_authority_test_runner.gd` proves forged pre-existing character/skill values cannot bypass the authority snapshot, wrong authority modes and unknown characters fail closed, and post-admission snapshot tampering is rejected.
- New `tests/competitive_local_web_smoke.mjs` covers accepted Ember/Storm authority state, deterministic ruleset/budget/fingerprint exposure, authority-owned runtime skill sources and invalid-character fail-closed behavior in Chromium/hosted Edge. It is included in `smoke:all`.
- Required CI now executes the WU5 domain runner. PR #193 implementation head `9a4c13905fa4307de929f94de952c1896ddb11a0` passed CI #556 (`35815833880`), and docs-sync head `e3999e785a9d540c5a1e032474a9fe40ac0ca3ae` passed CI #557 (`35817088723`), across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- PR #193 was explicitly approved and squash-merged to `main` as `5204a3f8a04beada0e21eac1a238ee2286bfbc66`. Exact-main CI #558 (`35818795131`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Edge `smoke:all`, GitHub Pages deployment and public reachability. Only the external Render AI backend readiness failed after 18 HTTP 503 responses, so production Edge full smoke was skipped as the existing provider residual risk.
- V2 remains **50% (4/8 phases complete)** until WU6 completes the full V2-5 cross-browser acceptance.

Work Unit 4 — **authoritative loadout snapshot + deterministic content fingerprint implemented; required PR validation passed**:
- `CompetitiveLoadoutSnapshotBuilder` mints competitive snapshots only by authority-side resolution of `competitive_standard@1`, the default Character/Skill registries, schema-valid definitions and the WU3 `competitive_standard_v1` budget validator.
- Client-supplied snapshot data is not accepted. Ruleset/version mismatch, noncompetitive rulesets, unknown registry characters/skills, registry load failures and budget rejection fail closed before any snapshot is emitted.
- The derived snapshot freezes ruleset/determinism/budget versions, normalized authoritative character stats, sorted resolved skill slots, normalized gameplay skill values, gameplay-relevant hitbox/hurtbox timeline events and the accepted power-budget result.
- Presentation-only skill values such as VFX/impact visuals are excluded from the authority fingerprint payload; authoritative combat-value changes remain fingerprint-significant.
- The content fingerprint uses versioned SHA-256 over a recursively canonicalized payload with deterministic dictionary-key ordering, so equivalent content is stable independent of insertion order.
- New `tests/competitive_loadout_snapshot_test_runner.gd` covers deterministic Ember/Storm snapshots, SHA-256 stability, ruleset/version and unknown-character fail-closed behavior, canonical dictionary ordering, presentation-only exclusion and authoritative-value sensitivity.
- Required GitHub CI now executes the new snapshot/fingerprint domain runner.
- PR #192 initial head `2699f8f1e2a7dffc50710a783e80c51cf478ca52` passed Windows Native, Godot import/boot/domain/backend including `COMPETITIVE_LOADOUT_SNAPSHOT_TESTS_PASSED`, Web export/size budget and Chromium `smoke:all` in CI #547 (`35809096254`). Hosted Edge attempt 1 timed out only in unchanged `creator_package_vfx_web_smoke.mjs:252` while waiting for the existing frame-polled U/MP acknowledgement; a targeted same-SHA retry of only the failed Edge job passed the complete Microsoft Edge `smoke:all` suite in attempt 2 without code/test changes, consistent with L-037/L-043 hosted-Edge timing-transient policy.
- PR #192 was explicitly approved and squash-merged to `main` as `75ae1d0444c0b89f180370b0f417edda23cf796c`.
- Exact-main CI #555 (`35813442860`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment and public-Web reachability. The external Render AI backend returned HTTP 503 for all 18 readiness attempts, so backend-dependent production Edge full smoke was skipped; this remains the existing provider/backend residual risk rather than a WU4 product regression.
- WU4 is merged; runtime admission through the authoritative snapshot is implemented by WU5 on its feature branch.
- V2 remains **50% (4/8 phases complete)** until the full V2-5 acceptance criterion is complete.

Work Unit 3 — **deterministic competitive power-budget validator merged; exact-main Web validated, backend-dependent production completion blocked**:
- `CompetitivePowerBudgetValidator` adds the first executable `competitive_standard_v1` eligibility layer without mutating stored Character/Skill definitions.
- Competitive hard caps are materially narrower than the outer schema/safety envelope for character HP/MP/mobility and skill damage, MP floor, cooldown/startup/recovery, active time, speed/range, hitstun/knockback, hitbox coverage and family-specific Formation/Buff/Trap/Aura/Teleport/Counter/Grab/Summon dimensions.
- The policy uses deterministic integer scores with frozen limits: character score `<= 3200`, per-skill score `<= 4500`, and occupied-slot aggregate loadout score `<= 18000`. Reusing one skill in multiple slots counts once per occupied slot, while its diagnostic is emitted only once.
- Stable diagnostic codes distinguish hard-cap, missing/unreferenced/duplicate-skill, unsupported-budget, per-character, per-skill and aggregate-loadout failures.
- The built-in reference characters remain eligible under the frozen v1 policy: Ember Vanguard character score `2683` / total `15649`; Storm Duelist character score `2787` / total `15426`.
- `tests/competitive_power_budget_test_runner.gd` covers reference fixtures, same-input/order determinism, no authored-data mutation, unsupported budget, missing/unreferenced skills, hard caps, one-code-per-skill stability, repeated-slot aggregate pressure, inclusive boundary behavior and monotonic damage/cooldown/MP-cost scoring.
- Required GitHub CI now executes the new competitive power-budget domain runner.
- PR #190 final head `3624eed4a1b166f44975a146d06dd14a827342b1` passed required PR CI #544 (`35743432893`) and was explicitly approved/squash-merged to `main` as `ec68a7ef73464846594b7447c9b447c7917ed253`.
- Exact-main CI #545 (`35808407510`) on merge revision `ec68a7ef73464846594b7447c9b447c7917ed253` passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment and public-Web reachability. The external Render AI backend returned HTTP 503 for all 18 readiness attempts, so backend-dependent production Edge full smoke was skipped; this remains the existing provider/backend residual risk and is not a WU3 product regression.
- WU3 remains domain-only: no competitive UI/router mode is exposed yet, and current Training/Creator/VFX/Single-player controls remain unchanged.
- V2 remains **50% (4/8 phases complete)** until the full V2-5 acceptance criterion is complete.

Work Unit 2 — **bounded game-mode + versioned ruleset contracts accepted; exact-main Web validated**:
- `GameModeDefinition` introduces a strict schema-v1 declarative contract for mode ID/display name, mode family, ruleset ID/version, power-budget ID, authority policy and custom-content policy. Unknown/missing fields fail closed.
- Mode policy references are allow-listed rather than accepting arbitrary safe-looking tokens. Sandbox must use `sandbox_default` + `sandbox_safe_limits` and remain `local_authoritative`; single-player must use `single_player_default` + `sandbox_safe_limits` and remain local-authoritative; competitive modes must use `competitive_standard` + `competitive_standard_v1` and may declare only local- or host-authoritative policy.
- `CompetitiveRulesetDefinition` adds a strict versioned contract for power-budget, character-constraint, skill-constraint and determinism-policy IDs. Unknown executable-style fields, unsupported policy IDs and invalid versions fail closed.
- `CompetitiveRulesetRegistry` exposes deterministic allow-listed `sandbox_default@1`, `single_player_default@1` and `competitive_standard@1` contracts. Unknown IDs and version mismatches fail closed without partially loading the target.
- `GameModeRegistry` exposes deterministic `sandbox`, `single_player`, `competitive_local` and `competitive_hosted` contracts and cross-checks the referenced ruleset/version plus power-budget agreement before loading the target.
- Existing `main_router.gd` is intentionally unchanged in WU2. Current Training/Creator/VFX/Single-player behavior and controls are preserved; the new policy layer is not yet a user-selectable competitive mode.
- `tests/game_mode_ruleset_test_runner.gd` covers registry ordering, canonical round trips, family/authority constraints, executable/unknown fields, external/unsafe references, competitive→sandbox budget downgrade rejection, ruleset-policy allow-lists, version mismatch, unloaded-on-failure behavior and same-input deterministic output.
- CI now executes the new domain runner before existing timeline/character/skill tests.
- PR #189 latest-head CI #539 (`35728595324`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all` on head `3249164d205b7614a057c293c7e824a8748d07d4`; PR #189 was explicitly approved and squash-merged to `main` as `b939a3380a535511648d97af2056ec39b1eba246`.
- Exact-main CI #540 (`35733671081`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment, and public-Web reachability. The external Render AI backend again returned HTTP 503 for all 18 readiness attempts, so backend-dependent production Edge full smoke was skipped as the existing provider/backend residual risk.
- WU2 is accepted. V2 remains **50% (4/8 phases complete)** until the full V2-5 acceptance criterion is complete.

Work Unit 1 — **competitive-foundation architecture inventory accepted; exact-main Web validated**:
- `docs/V2_5_GAME_MODES_BALANCE_COMPETITIVE_INVENTORY.md` inventories the current router modes, combat authority, character/skill/package validators and the missing competitive trust boundary.
- Existing `CharacterDefinition` and `SkillDefinition` checks are explicitly classified as safety/schema bounds rather than competitive balance guarantees; a safe package does not automatically become competitive-eligible.
- The proposed architecture separates sandbox/single-player from competitive admission through strict `GameModeDefinition` / versioned ruleset contracts, deterministic competitive eligibility, and a derived authority-owned loadout snapshot.
- Future clients are limited to content/input proposals; damage, HP/MP, cooldowns, hit confirmation, state transitions and match result remain authority-computed and are never accepted as trusted client facts.
- WU1 defines the V2-5 sequence: bounded game-mode/ruleset contracts → deterministic power-budget validator → authoritative loadout snapshot/fingerprint → local competitive authority path → cross-browser phase acceptance.
- Numeric power-budget weights are intentionally deferred until deterministic reference fixtures and monotonicity/boundary tests exist; WU1 does not introduce arbitrary tuning constants.
- This work unit has **no product functionality change**.
- Previous closeout PR #187 merged V2-4 status to `main` as `c4203dd25d0144c1ee7a7b53bdaf24ab813e72aa`. Exact-main CI #535 (`35718915645`) passed Windows Native, Godot/domain/backend tests, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment and public-Web reachability. The external Render AI backend again returned HTTP 503 for all 18 readiness attempts, so backend-dependent production Edge full smoke was skipped; this remains an independent provider/backend residual risk.
- PR #188 latest-head CI #537 (`35722359456`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all` on head `00c4cfca869b26b09f17a7b2cc9fd3940a73a94d`.
- PR #188 was explicitly approved and squash-merged to `main` as `c829175a4e84e0ee2b6cceef7f360e380444eefd`.
- Exact-main CI #538 (`35726723857`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment and public-Web reachability. The external Render backend returned HTTP 503 for all 18 readiness attempts, so backend-dependent production Edge full smoke was skipped as the existing provider/backend residual risk.
- WU1 is accepted. V2 remains **50% (4/8 phases complete)** until the full V2-5 acceptance criterion is complete.

### V2-4 implementation checkpoints

Work Unit 1 — **deterministic opponent behavior foundation accepted and production-validated**:
- `OpponentBehaviorProfile` defines a strict bounded declarative contract for reaction interval, preferred distance band, depth tolerance, basic-attack range, guard policy and one optional validated skill-slot preference. Unknown fields, executable-style fields, unsafe IDs, invalid ranges and unsupported slots fail closed.
- `OpponentBehaviorProfiles` exposes the first allow-listed profiles: `training_balanced` and `training_pressure`.
- `OpponentDecisionState` is a pure deterministic intent layer. It consumes explicit position/readiness/threat/snapshot data and returns only bounded movement, guard, basic-attack, validated-skill or idle intents. It does not mutate HP, MP, cooldowns, hitstun, knockback or match result.
- Domain regression covers profile allow-listing, unknown/unsafe profile rejection, approach/retreat/hold/depth alignment, disabled state, guard-vs-attack priority, validated skill eligibility, invalid-snapshot fail-closed behavior, same-input determinism and no combat-state mutation.
- Initial PR CI #500 exposed only a GDScript test-fixture type-inference parser error. Commit `9ade45c95059bca3c22eeda5f3714d951603435d` added explicit fixture return/local types without changing decision behavior.
- PR #181 CI #501 (`35591729594`) passed Windows Native Release, Godot import/boot/domain/AI contracts including `OPPONENT_BEHAVIOR_TESTS_PASSED`, trusted backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`.
- PR #181 was explicitly approved and squash-merged to `main` as `323e86a5445f6049f2b20ba788af2d373abc7b5b`.
- Exact-main CI #503 (`35602570478`) passed the complete production chain: Windows Native, Godot/domain/AI contracts, backend, Web export/size budget, Chromium `smoke:all`, hosted Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- WU1 is therefore accepted and production-validated.
- V2 remains **37.5% (3/8 phases complete)** until the full V2-4 phase acceptance criteria are complete.

Work Unit 2 — **active deterministic single-player opponent merged; exact-main Web validated, backend-dependent production completion blocked**:
- Router mode `single_player` now mounts the existing Training scene with opponent AI explicitly enabled; ordinary `training` remains passive by default.
- The runtime adapter consumes WU1 deterministic intents, moves the Dummy within existing arena bounds, reuses `AttackChainState` attack timing/damage/hitstun, and routes every successful opponent hit through the existing authoritative `receive_player_hit(...)` boundary.
- Match defeat remains owned by `match_flow_main.gd`; restart preserves `single_player` mode, while return-to-Creator remains unchanged.
- The WU1 decision layer now explicitly closes from the wider preferred-spacing band into the configured basic-attack range when a basic attack is eligible; domain coverage proves this deterministic close-in behavior.
- `tests/opponent_ai_web_smoke.mjs` proves single-player mode approaches, attacks, damages and defeats the player, then restarts into a fresh AI match; the same regression separately reloads ordinary Training and proves the Dummy remains passive with no opponent attacks.
- Initial PR #182 CI #504 passed Windows Native, Godot/domain/backend and Web export, then Chromium timed out at the first new opponent-hit observation. Commit `3524ae4cbc1c98a51f3def27ca453f086b9c3096` added failure-only state diagnostics without changing runtime, timeout or acceptance conditions.
- PR #182 CI #506 (`35605738012`) then passed Windows Native, Godot/domain/AI contracts, backend, Web export/size budget, Chromium `smoke:all` and hosted Microsoft Edge `smoke:all` on that same runtime implementation.
- PR #182 was explicitly approved and squash-merged to `main` as `c548cfb3c0e53d2b1170205c1f1948889845db22`.
- Exact-main CI #508 attempt 1 passed Windows Native, Godot/domain/AI/backend, Web export and the new opponent-AI regression, then hit an unchanged `creator_package_vfx_web_smoke.mjs` U/MP observation timeout already covered by L-037. Same-SHA attempt 2 passed Chromium `smoke:all`, Windows Native, hosted Edge `smoke:all`, GitHub Pages deployment and public-Web reachability.
- The remaining exact-main production chain is externally blocked: `https://custom-fighter-ai-vfx.onrender.com` returned HTTP 503 for all 18 readiness attempts, so the dependent production Edge full smoke was skipped. The currently connected Render workspace does not contain that backend service, so it cannot be restarted/redeployed from the available Render connector. WU2 gameplay/Web behavior is validated; full backend-dependent production acceptance remains `Blocked / Residual Risk`.
- V2 remains **37.5% (3/8 phases complete)**.

Work Unit 3 — **bounded difficulty/profile selector merged; exact-main Web validated, backend-dependent production completion blocked**:
- Add third allow-listed profile `training_cautious` and stable user-facing labels: Easy/Cautious, Normal/Balanced and Hard/Pressure.
- Profile selection is bounded to the existing allow-list. Invalid runtime selection requests are ignored; invalid URL profile input normalizes to the bounded default `training_balanced`.
- Web single-player supports `?mode=single_player&opponent_profile=<allow-listed-id>`; the router owns the selected profile so restart/remount preserves it.
- Single-player now exposes an on-canvas `AI Difficulty` selector. Ordinary `training` does not create or expose the selector and keeps the Dummy passive.
- Difficulty changes only declarative decision policy (reaction interval, spacing, guard policy and validated eligible action preference). It does not modify `AttackChainState` damage/hitstun, player/opponent HP/MP, skill cooldowns or hit resolution.
- Domain regression proves the deterministic profile allow-list/default/labels and a concrete policy difference: at the same 140px attack-ready snapshot, Balanced attacks while Pressure closes farther because its bounded basic-attack range is 120px.
- Browser regression now changes profiles through the same runtime selection path, proves Balanced → Pressure → Cautious telemetry, rejects an unsafe profile token without changing the active profile, verifies authoritative opponent damage remains identical across Balanced and Pressure, and re-proves ordinary Training remains passive.
- PR #183 CI #509 (`35680419513`) passed Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, Windows Native Release, and GitHub-hosted Microsoft Edge `smoke:all` on head `4571f15e5620662c5f6fa80e87a625d1dc5b3723`.
- PR #183 was explicitly approved and squash-merged to `main` as `1ae941dec82788a219073c831ebd36b657fd058d`.
- Exact-main CI #511 attempt 1 passed Windows Native, Godot/domain/AI/backend, Web export/size budget and Chromium `smoke:all`, then hosted Edge timed out in unchanged `creator_package_vfx_web_smoke.mjs:252`. A same-SHA failed-chain retry passed hosted Edge `smoke:all`; GitHub Pages deployment and public-Web reachability then passed.
- Render exact-revision readiness still returned HTTP 503, so backend-dependent production Edge full smoke remained skipped. WU3 gameplay/Web behavior is therefore exact-main validated while backend-dependent production acceptance remains `Blocked / Residual Risk`.
- V2 remains **37.5% (3/8 phases complete)** until the entire V2-4 phase is accepted.

Work Unit 4 — **bounded stage definition + registry merged; exact-main validation running**:
- `StageDefinition` introduces a strict schema-v1 declarative stage contract for arena horizontal margin, normalized player/opponent spawn coordinates, normalized depth, display name and allow-listed presentation tokens.
- Unknown fields fail closed, including executable-style fields such as `script` or `callback`. Stage IDs reject path traversal / URL-like values; presentation fields accept only allow-listed semantic tokens and never resource paths or URLs.
- Arena margin is bounded to 60–240px; spawn X ratios must remain within 0.08–0.92 with at least 0.15 horizontal separation; depths are normalized to 0–1.
- `StageRegistry` exposes two deterministic built-ins: `training_arena` (legacy-compatible defaults) and `sunset_court`, with `training_arena` as the bounded fallback/default.
- `stage_definition_test_runner.gd` covers deterministic registry ordering, canonical round-trip, unknown/executable fields, unsafe IDs, external/resource presentation tokens, arena-margin bounds, depth bounds and spawn-separation rules.
- PR #184 latest-head CI #513 (`35692725368`) passed Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, Windows Native Release and GitHub-hosted Microsoft Edge `smoke:all` on head `63cf37adbe2519ae41a473c6a55b87196fe68967`.
- PR #184 was explicitly approved and squash-merged to `main` as `681f4ee8d84567ad963c669b90b0f1f92a11df21`.
- Exact-main CI #514 (`35698779914`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment and public-Web reachability on exact merge revision `681f4ee8d84567ad963c669b90b0f1f92a11df21`. Render readiness remained externally blocked by HTTP 503 for all 18 attempts, so backend-dependent production Edge full smoke was skipped.
- V2 remains **37.5% (3/8 phases complete)**.

Work Unit 5 — **bounded stage selection + runtime application merged; exact-main validation running**:
- `main_router.gd` owns a validated `stage_id` beside the opponent profile, accepts bounded `?stage=<id>` startup selection and preserves the selected stage across single-player remount/restart and profile changes.
- Single-player exposes a Stage selector for the two built-ins; ordinary Training exposes no Stage selector and remains passive.
- Runtime applies the selected stage's arena margin, player/opponent spawn positions/depths and semantic presentation tokens. `training_arena` preserves the existing visual baseline while `sunset_court` applies its distinct bounded presentation.
- Player movement, opponent movement, Teleport, Grab and Summon consume the selected arena bounds instead of assuming a fixed 90px margin.
- Stage selection remains non-authoritative for combat values: damage, HP/MP, hit resolution, cooldowns and AI policy values are unchanged.
- Initial PR #185 CI #518 exposed invalid GDScript constructor-based `const` arrays; commit `3fdc15f871b11c1b3bdb3431a597fd88020008bd` corrected them to literal constant arrays without semantic change and L-040 records the rule.
- PR #185 CI #520 (`35699591932`) and final latest-head CI #524 (`35700904620`) passed Windows Native, Godot/domain/backend, Web/Chromium and hosted Microsoft Edge. Browser evidence includes `stageSelection=true stageCount=2 stagePreservedAcrossProfileChange=true` and `SMOKE_SUITE_PASSED count=25`.
- PR #185 was explicitly approved and squash-merged to `main` as `26bf2a7ac845b90b715f216e9c207cd1e8e3b3af`.
- Exact-main CI #525 (`35708039807`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment and public-Web reachability on merge revision `26bf2a7ac845b90b715f216e9c207cd1e8e3b3af`. The external Render AI backend again returned HTTP 503 for all 18 readiness attempts, so backend-dependent production Edge full smoke was skipped.
- V2 remains **37.5% (3/8 phases complete)** until WU6 completes the V2-4 acceptance criterion.

Work Unit 6 — **full single-player acceptance accepted; exact-main Web production validated**:
- This work unit has **no product functionality change**; it strengthens the required acceptance regression and phase-closeout documentation.
- `opponent_ai_web_smoke.mjs` keeps the existing active-AI defeat/restart proof on `training_arena`, then runs a real player victory flow on selectable `sunset_court` against `training_cautious`.
- The victory flow uses only normal J basic-attack inputs and the existing authoritative player→opponent combat path. It does not add a test-only damage bridge or bypass match authority.
- The regression proves active AI remains enabled during the victory match, requires non-zero player HP at victory, verifies `dummyHp=0`, then restarts and proves `sunset_court` + `training_cautious` remain selected with full HP and clean opponent attack counters.
- The same flow then invokes the existing Return-to-Creator path and requires Creator Studio readiness, before re-proving ordinary Training remains passive.
- Together with the earlier default-stage defeat path, WU6 covers loss, restart, selectable stage/profile persistence, active-opponent victory, second restart and return-to-Creator across the two built-in stage configurations.
- PR #186 CI #526 exposed one acceptance-test defect: the first player-victory range predicate referenced unpublished `dataset.dummyDepth`, so `Number(undefined)` became `NaN` and the wait could never pass. Commit `0b649b307352494b94b8fe5321d12a2666903081` removed the unpublished-field dependency and added a diagnostic timeout snapshot; L-041 records the durable rule.
- PR #186 CI #528 (`35709409604`) passed Windows Native, Godot import/boot/domain/backend, Web export/size budget, Chromium `smoke:all` and hosted Microsoft Edge `smoke:all` on head `d8803fb533cc6dcd2182bddb39c974be9c148bd6`.
- Chromium and Edge both emitted `playerDefeat=true playerVictory=true victoryStage=sunset_court victoryRestartPreserved=true returnCreator=true` and `SMOKE_SUITE_PASSED count=25`.
- PR #186 latest-head CI #532 (`35711354905`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all` on head `184b6caf2447550bf4e8c28426a48f100830c890`.
- PR #186 was explicitly approved and squash-merged to `main` as `e6ce72c4ed675b519808a05184089c19edc0500b`.
- Exact-main CI #533 (`35714388530`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment, and public-Web reachability on the exact merge revision.
- The deployed artifact is therefore the same exact-main Web build that passed the complete single-player acceptance path. The external Render AI backend remained independently unavailable: all 18 readiness attempts returned HTTP 503, so the backend-dependent production Edge full-smoke job was skipped. This remains a provider/backend residual risk and does not reopen the backend-independent V2-4 single-player acceptance.
- V2-4 is accepted complete. V2 advances to **50% (4/8 phases complete)** and V2-5 is now active.

### V2-2 implementation checkpoints

Work unit 1 — **skill-family authoring foundation — accepted and production-validated**:
- PR #145 was squash-merged to `main` at `7c6eb8aebe1797f1c0a14176f7a7721e07f52771`.
- `SkillDraft` and Creator Skill Editor support all six existing V1 families through one validated family selector while preserving projectile as the backwards-compatible reset/default family.
- Family-specific safe defaults, serialization/reload, unsupported-family fail-closed behavior, and Chromium/hosted Edge Creator regression coverage are synchronized.
- Main CI #342 (`35190460843`) passed the complete production chain on the merge revision: Windows Native, Godot import/boot/domain/backend tests, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Initial PR CI #337 exposed a Creator inheritance member collision; commit `31973ef2f1d51ad66a2f5f4b7a7dee748dad4a7f` fixed it and the recurrence is recorded as L-027.
- A hosted Edge Heavy Strike cooldown observation race was hardened by `f90d38701ff1f7c58a9bf2b4fd6dd2483a92d797`; gameplay behavior did not change and the recurrence is recorded as L-028.

Work unit 2 — **Creator Preview family dispatch — accepted and production-validated**:
- PR #146 was squash-merged to `main` at `6b235408bef84783e588e9addeebb57b1b37f7a3`.
- `CreatorPreviewSession` maps each validated original family to its existing runtime slot: projectile→`skill_1`, dash→`skill_2`, area→`skill_3`, formation→`skill_4`, buff→`skill_5`, melee→`skill_6`.
- Preview staging rewrites only the mapped temporary preview slot; the stored editable CharacterDraft and all unrelated skill slots remain unchanged.
- `preview_selectable_main.gd` injects the authored skill only for the mapped slot and still requires exact expected-type and skill-ID matching, so mismatches fail closed.
- `preview_family_animation_main.gd` routes V2 timeline transition/event reads through the selected family's existing `SkillCastState`; no second executable timeline path was introduced.
- Projectile-only imported VFX remains active only for projectile preview. Non-projectile preview keeps the stored VFX draft but does not mis-bind it to another family.
- The six-family Creator Preview smoke authors family/MP/cooldown/audio timeline data, launches Preview, verifies runtime slot/type/source, casts through U/I/O/P/B/H, verifies authored MP consumption and timeline execution, then round-trips back to Creator.
- Implementation head PR CI #343 (`35197783830`) passed Windows Native, Godot import/boot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge.
- Main CI #345 (`35200223070`) passed the complete production chain on the merge revision: Windows Native, Godot import/boot/domain/backend tests, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.

Work unit 3 — **first genuinely new family: `beam` — accepted and production-validated**:
- `SkillDefinition.SUPPORTED_TYPES` now includes `beam` with fail-closed bounds for range, active duration and spatial width/depth; `training_beam_001` is registered through the authoritative skill registry.
- `SkillDraft` reuses the shared family selector and safe default path for Beam; no family-specific executable Creator code or arbitrary callbacks are introduced.
- `BeamAttackState` defines deterministic origin→endpoint geometry, bounded collision volume, active lifetime and a single-hit-per-activation policy.
- `BeamSkillController` + `coordinated_beam_skill_controller.gd` run Beam through the shared `SkillCastState`, MP/cooldown rules and `SkillCoordinator` ownership as `skill_7` / Y.
- `CharacterDefinition` accepts `skill_7` as an optional backwards-compatible extension while `skill_1`–`skill_6` remain required; legacy six-slot characters remain valid without migration.
- Ordinary six-slot Training keeps Beam unloaded. Creator Preview injects Beam only into the temporary preview character's `skill_7`; the stored editable CharacterDraft remains unchanged.
- `CreatorPreviewSession` maps `beam`→`skill_7`, and `preview_family_animation_main.gd` consumes Beam timeline transitions from the Beam controller's existing `SkillCastState`.
- Browser telemetry exposes Preview `skill_7` identity/type/source plus Beam loaded/phase/cooldown/active/hit-count/endpoint state for deterministic regression checks.
- `beam_test_runner.gd` covers Beam schema bounds, exact registry type checking, shared cast activation, deterministic geometry, out-of-range misses, one-hit consumption, optional-character-slot backwards compatibility, and Creator Preview routing/isolation.
- `creator_preview_family_web_smoke.mjs` now covers seven families. For Beam it authors the family plus MP/cooldown/audio timeline event, launches Preview, verifies `skill_7` source/type, presses Y, verifies MP consumption and timeline execution, verifies exact dummy damage and `beamSkillHitCount == 1`, then round-trips to Creator.
- Implementation head `4fa2215d840fdbb43e8e3eed1269237ff4e51eec` passed PR CI #346 (`35207985135`): Windows Native Release, Godot import/boot/domain/AI contracts including Beam, backend tests, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all` all passed.
- PR #147 was merged to `main` at `ed35ff4685173826ec015ac86a48480704a77d7b`.
- Main CI #349 (`35210660845`) passed the complete production chain on that exact revision: Windows Native, Godot import/boot/domain/backend tests, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.

Work unit 4 — **second genuinely new family: `trap` — accepted and production-validated**:
- `SkillDefinition.SUPPORTED_TYPES` includes `trap` with bounded placement range, trigger volume and lifetime; `training_trap_001` is registered through the authoritative skill registry.
- `TrapAttackState` implements deterministic place → armed → single trigger/expire behavior, while cast timing/MP/cooldown/coordinator ownership stays on the shared `SkillCastState` / `SkillCoordinator` path.
- `CharacterDefinition` accepts `skill_8` as an optional backwards-compatible slot; legacy six-slot characters and optional Beam `skill_7` remain valid. Runtime binds Trap to `skill_8` / T.
- Creator Preview maps `trap`→`skill_8`, injects it only into the temporary preview character, dispatches authored timeline data through the existing cast state, and exposes deterministic Trap loaded/phase/armed/active/hit-count telemetry.
- `creator_preview_family_web_smoke.mjs` covers all eight families and verifies Trap authored MP/cooldown/timeline data, T cast routing, one-trigger/one-damage semantics and Creator round-trip.
- Trap initially exposed two package-contract regressions. `SkillDraft.to_dictionary()` began emitting `trap_duration`, while the strict Character Package allowlist did not accept it; commit `8e14face377ffa7421f54e782e22f723a5ed3ea7` added the field to the package schema and preserved it through package normalization. That first fix then exposed canonical-shape pollution because non-Trap skills were also serialized with `trap_duration`; commit `f31a54bb735eeeb166fa9709768d120e65095066` scopes serialized `trap_duration` to Trap skills only.
- Targeted PR148 Browser Diagnostic #3 (`35254414363`) passed Creator Preview family, Creator package, Creator package VFX and mobile smoke on `f31a54bb735eeeb166fa9709768d120e65095066`.
- Formal PR CI #359 exposed an independent Windows runner defect before the first Edge smoke: Node 24 returned `spawnSync npm.cmd EINVAL`. Commit `8e4a2fabd08da51e413f90f5607b00c9c89354d1` routes Windows npm script execution through `ComSpec /d /s /c`, keeps direct `npm` execution on non-Windows platforms, and removes the now-completed temporary diagnostic workflow.
- PR CI #360 (`35283860574`) passed Windows Native Release, Godot import/boot/domain/backend tests, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all` on implementation head `8e4a2fabd08da51e413f90f5607b00c9c89354d1`.
- Final PR head `4d969054fa06571f2d3f975f89aa65edb0a6c5c5` passed PR CI #361 (`35284784577`): Windows Native, Godot import/boot/domain/AI contracts including the direct Trap package round-trip regression, backend tests, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- PR #148 was squash-merged to `main` at `f1631eaa3f2828765ab898e7f5ebe55637671422`.
- Main CI #362 (`35289237781`) completed successfully on that exact merge revision after hosted Edge timing retries. Attempt #1 timed out in unchanged `smoke:melee` cooldown observation; attempt #2 timed out in unchanged `smoke:match-restart`; no runtime/product code changed between attempts. Attempt #3 passed the complete production chain: Windows Native, Godot import/boot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- The varying same-SHA Edge timeout locations plus the successful third attempt confirm runner/observation timing instability rather than a deterministic Trap regression; existing browser-timing lessons remain the governing prevention guidance.


Work unit 5 — **third genuinely new family: `aura` — accepted and production-validated**:
- Aura is a safe declarative/deterministic family: a bounded volume follows the caster for a finite `aura_duration`; one activation can damage the training target at most once.
- `SkillDefinition` accepts `aura` with bounded active duration, aura lifetime and spatial dimensions; `training_aura_001` is registered through the exact-type skill registry.
- `CharacterDefinition` extends the backwards-compatible optional slots with `skill_9`; the original six required slots plus optional Beam/Trap slots remain unchanged. Runtime binds Aura to `skill_9` / G.
- `AuraAttackState` owns deterministic follow/lifetime/single-hit state. `AuraSkillController` and its coordinated wrapper reuse `SkillCastState`, MP/cooldown and `SkillCoordinator`; no autonomous actor, arbitrary path, callback, script or new executable timeline event is introduced.
- Creator `SkillDraft` supplies safe Aura defaults and conditionally serializes `aura_duration`; Character Package validation allows/preserves that field only for Aura so non-Aura canonical shapes remain unchanged.
- Creator Preview maps `aura`→`skill_9`, exposes slot/runtime telemetry and dispatches authored V2 timeline events through Aura's existing shared cast state.
- Deterministic Aura domain tests, optional-slot compatibility, Creator routing, package round-trip shape regression and nine-family Chromium/Edge Creator Preview smoke are synchronized on branch `feat/v2-2-aura-family-wu5`.
- PR #150 implementation head `da9808d46eadadcb79bd0356b45953365236940a` passed CI #365 (`35295253734`) on attempt #2: Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all` and GitHub-hosted Microsoft Edge `smoke:all`.
- CI #365 attempt #1 stopped in unchanged `smoke:web` before Aura coverage because the existing K dash sampled 119.66px against a >120px browser threshold; authored dash distance remains 190px and the same SHA passed on attempt #2 without product/test changes. This is treated as existing runner/frame-sampling timing behavior rather than an Aura regression.
- Chromium and hosted Edge both emitted `WEB_CREATOR_PREVIEW_FAMILY_SMOKE_PASSED families=9 ... auraHitPolicy=single`; Aura domain, Character Package, Creator SkillDraft and Creator Preview session regressions also passed.
- Latest PR head `8d1f801ff13053473fc8412a914703bd5d46335f` passed PR CI #367 (`35296370356`): Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`.
- PR #150 was squash-merged to `main` at `f2ce5d0efe99d807be09190fa02e26b95d2325d5`.
- Main CI #368 (`35298311326`) passed the complete production chain on that exact merge revision: Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment, public-Web reachability, Render health/provider-schema/exact-revision readiness, and production Microsoft Edge full smoke.
- Aura Work Unit 5 is therefore accepted and production-validated. V2 remains **12.5% (1/8 phases complete)** because V2-2 still requires summon, grab, counter, teleport and safe scripted event compositions.



Work unit 6 — **fourth genuinely new family: `teleport` — accepted and production-validated**:
- `SkillDefinition.SUPPORTED_TYPES` includes `teleport` with a bounded positive `range`; no executable callback/path or arbitrary destination payload is introduced.
- `TeleportState` deterministically resolves current X + facing × authored range and clamps the destination to the arena safety margins; it records actual traveled distance for validation/telemetry.
- `CharacterDefinition` adds optional `skill_10`; legacy six-slot characters plus optional Beam/Trap/Aura slots remain valid. Runtime binds Teleport to `skill_10` / R.
- `TeleportSkillController` and its coordinated wrapper reuse `SkillCastState`, MP/cooldown and `SkillCoordinator`. Teleport itself does not apply target damage; authored declarative timeline events still run through the shared preview timeline scheduler.
- Creator family selection exposes Teleport safe defaults with bounded displacement, and Creator Preview maps `teleport`→`skill_10` without mutating the stored CharacterDraft.
- Deterministic Teleport definition/registry/state/optional-slot/Creator routing tests are wired into CI. The ten-family Creator Preview browser smoke verifies authored range, R input, MP/timeline execution, bounded displacement and unchanged Dummy HP.
- PR #152 implementation head `b77b5efbe07aea2bb9f5be69bdf8aab00d6a3af7` passed CI #371 (`35302926489`): Windows Native, Godot import/boot/domain/AI contracts including `TELEPORT_TESTS_PASSED`, trusted backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`.
- Chromium and hosted Edge both emitted `WEB_CREATOR_PREVIEW_FAMILY_SMOKE_PASSED families=10 ... teleportPolicy=bounded ... timelineDispatch=true roundTrip=true`; the full smoke suite reported 24/24 stages passed.
- Latest PR head `499adee3404bfb39febf0d69878b940676712099` passed PR CI #373 (`35303697245`): Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`.
- PR #152 was squash-merged to `main` at `5cc30c274c4a61b5b37b5d4099ac4cf7a0e72d1f`.
- Main CI #374 (`35304620553`) attempt #1 passed Windows Native, Godot/domain/backend and Chromium but the unchanged hosted Edge `smoke:melee` missed the short positive-cooldown observation window at `tests/melee_web_smoke.mjs:74`; the failure occurred before Teleport coverage and no product/test code changed.
- Main CI #374 attempt #2 on the exact same merge revision passed the complete production chain: Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment, public-Web reachability, Render health/provider-schema/exact-revision readiness, and production Microsoft Edge full smoke.
- The same-SHA retry confirms the first hosted-Edge result as runner/observation timing instability rather than a deterministic Teleport regression. Teleport Work Unit 6 is therefore accepted and production-validated.
- V2 remains **12.5% (1/8 phases complete)** because V2-2 still requires summon, grab, counter and safe scripted event compositions.



Work unit 7 — **fifth genuinely new family: `counter` — accepted and production-validated**:
- `SkillDefinition.SUPPORTED_TYPES` includes `counter` with a bounded positive source `range`, finite active window (maximum 2.0 seconds), and bounded depth tolerance. Creator/training defaults use a 1.50-second window for stable hosted-browser observation without widening the safety cap.
- `CharacterDefinition` adds optional `skill_11`; the original six required slots plus optional Beam/Trap/Aura/Teleport slots remain backwards-compatible. Runtime binds Counter to `skill_11` / F.
- `CounterState` is deterministic and single-trigger: start → finite armed window → actual incoming-hit intercept or expire. Expiration never auto-retaliates, out-of-range/depth sources are rejected, and a consumed window cannot trigger twice.
- Training runtime now exposes one formal `receive_player_hit(...)` boundary. Counter gets first chance to intercept an actual incoming hit; otherwise the same hit flows to `player_state.apply_damage(...)`. This is the reusable boundary future AI opponents can call rather than Counter inventing its own fake damage path.
- Browser-only training probe `customFighterTrainingIncomingHit(amount)` is intentionally constrained to the current Dummy coordinates. It supplies a deterministic real hit event for regression coverage but cannot choose arbitrary source/path/callback behavior.
- `CounterSkillController` and coordinated wrapper reuse `SkillCastState`, MP/cooldown, `SkillCoordinator`, exact-type registry loading and the existing declarative timeline scheduler. Successful training retaliation is limited to the validated Dummy source and occurs once per armed window.
- Creator Preview maps `counter`→`skill_11` without mutating stored CharacterDraft data. Domain coverage checks schema bounds, exact registry type, finite-window semantics, source bounds, single-trigger behavior, expiration-without-retaliation, optional-slot compatibility and Creator routing.
- The eleven-family Creator Preview smoke validates F input, MP/timeline execution, first real incoming hit countered with one retaliation and no player HP loss, then a second real incoming hit bypassing the consumed counter and dealing exactly 9 player damage.
- PR #154 implementation head `e9606b473c8150fc9eba27fe598bd7fb86414def` passed CI #377 (`35309792577`): Windows Native, Godot import/boot/domain/AI contracts including `COUNTER_TESTS_PASSED`, trusted backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`.
- Chromium and hosted Edge both emitted `WEB_CREATOR_PREVIEW_FAMILY_SMOKE_PASSED families=11 ... counterPolicy=actual-hit-once ... timelineDispatch=true roundTrip=true`; the full smoke suite reported `SMOKE_SUITE_PASSED count=24`.
- Latest PR head `5841591c10fc60bd5cf815e6d8a96fcc7548924a` passed PR CI #379 (`35310681623`): Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`.
- PR #154 was squash-merged to `main` at `aad1e3f2787d32d4b09bec96a8509471fb0b574e`.
- Main CI #380 (`35311711648`) attempt #1 passed Windows Native, Godot/domain/backend, Chromium, hosted Edge, Pages deployment/public reachability and Render exact-revision readiness. The production Edge full smoke also passed the eleven-family Counter flow, then the unchanged `smoke:creator-ai-skill-proposal` missed the second proposal-valid 5-second observation window at `tests/creator_ai_skill_proposal_web_smoke.mjs:81`.
- The same AI-skill-proposal smoke had passed on the exact PR implementation in hosted Edge, and no code changed before Main CI #380 attempt #2.
- Main CI #380 attempt #2 on the exact same merge revision passed the complete production chain: Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment, public-Web reachability, Render health/provider-schema/exact-revision readiness, and production Microsoft Edge full smoke.
- The same-SHA retry confirms attempt #1 as hosted production-Edge timing/observation instability rather than a deterministic Counter regression. Counter Work Unit 7 is therefore accepted and production-validated.
- V2 remains **12.5% (1/8 phases complete)** because V2-2 still requires summon, grab and safe scripted event compositions.
- Counter production-validation docs checkpoint PR #155 was squash-merged to `main` at `069803c8aa295d3d097daa64294660d913ff5325`; Main CI #382 (`35328182117`) passed the complete production chain on that exact docs-only revision.




Work unit 8 — **safe scripted event compositions — accepted and production-validated**:
- Composition is deliberately **not** a new executable skill/event language. `SkillTimelineComposition` exposes only the explicit recipes `cast_burst` and `guarded_impact`, and expands them into the existing allow-listed `animation`, `vfx`, `audio`, `hitbox` and `hurtbox` timeline event vocabulary.
- Recipe expansion validates safe lowercase IDs/asset tokens, may only append at or after the existing timeline tail, rejects duplicate IDs, enforces the existing 64-event/30-second caps, and returns the original timeline unchanged on failure. No arbitrary event JSON, callback, path, script or user code is accepted.
- Creator Timeline adds a Composition row with recipe selection, start time and `+ Safe Composition`; Web automation exposes only `customFighterCreatorTimelineApplyComposition(recipe, start)` and publishes recipe/error diagnostics. The persisted skill remains ordinary `timeline.events`; composition recipe UI state is not executable package metadata.
- `guarded_impact` intentionally reproduces the already-validated Creator Preview overlap sequence (skill_3 animation, impact VFX, bounded hitbox, audio cue and bounded hurtbox), so the existing runtime consumes the expanded events through `SkillDefinition`, `SkillCastState` and `SkillTimelineRuntime` with no new runtime dispatcher.
- Direct domain/runtime coverage checks recipe allow-listing, deterministic expansion/order, safe IDs, unsafe token rejection, append-only chronology, duplicate-ID rejection, event-count and 30-second bounds, runtime transitions/cleanup, and confirms no `script` event can appear.
- Creator Chromium/Edge regression now authors both safe recipes, verifies unsupported/backwards compositions fail without mutation, then uses `guarded_impact` to drive the existing Creator → Training runtime timeline flow.
- Character Package previously rejected/omitted the optional `timeline` object, which would have discarded an expanded composition on export. WU8 adds `timeline` to the strict allowed skill shape and serializes it **only when present**, so legacy non-timeline package skills retain their historical canonical shape. Unsafe timeline event types still fail through `SkillDefinition`.
- Package domain and browser regression verify the five expanded declarative events survive schema-v2 Creator export/import and Preview, while no composition recipe/script metadata is serialized.
- PR #156 initial implementation head `da3a0d0299d206fa1d4df05653c7a1aab035a66f` reached CI #383 (`35331218793`): Windows Native, Godot import/boot, composition/domain/package/backend, Web export and all Creator composition/preview-family browser stages before `smoke:creator-package` passed. Creator Package then timed out after a valid package re-import because the ancestor package flow replaced the full `SkillDraft` but the derived Timeline editor Web/UI telemetry still reflected the previously cleared draft.
- Fix commit `80009e350cfa76f29c424b25e918a5b16a6fcb4a` added a successful package-import refresh hook at the Timeline Creator layer. An overlapping follow-up hook temporarily created a duplicate `_import_package_json` declaration and CI #386 (`35332142038`) correctly failed the Godot import/Windows export parse gates; reconciliation commit `ad146a380de165002d33212014f25c51cb4ef446` consolidated the logic into one override and preserved composition UI-state reset/next-start recalculation.
- Reconciled head `ad146a380de165002d33212014f25c51cb4ef446` passed CI #387 (`35332342095`): Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`.
- Explicit WU8 evidence includes `SKILL_TIMELINE_COMPOSITION_TESTS_PASSED`, Character Package and self-contained package PASS, Chromium/Edge `WEB_CREATOR_TIMELINE_EDITOR_SMOKE_PASSED safeComposition=true allowList=true compositionFailClosed=true`, `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... safeComposition=true timelineRoundTrip=true`, and `WEB_CREATOR_PACKAGE_SMOKE_PASSED ... timelineRoundTrip=true compositionExpanded=true`; both complete browser suites emitted `SMOKE_SUITE_PASSED count=24`.
- Latest PR head `c8c582d975627379b5b9eb59eb8085f6347cf728` passed PR CI #390 (`35333626916`): Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`.
- PR #156 was squash-merged to `main` at `38d9545ef16f00143e7b2991a8dd608dc85d7156`.
- Main CI #391 (`35336811313`) attempt #1 passed Windows Native, Godot/domain/backend, Chromium, hosted Edge, Pages deployment/public reachability and Render exact-revision readiness. Production Edge then stopped in unchanged `smoke:melee` at `waitForPositiveCooldown`'s 2.5-second transient cooldown observation window before WU8 composition coverage.
- No code changed. Main CI #391 attempt #2 on the exact same merge revision passed the complete production chain: Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment, public-Web reachability, Render health/provider-schema/exact-revision readiness, and production Microsoft Edge full smoke.
- The same-SHA retry confirms attempt #1 as the already-documented hosted Edge transient cooldown observation instability rather than a deterministic WU8 regression. Safe Scripted Event Compositions Work Unit 8 is therefore accepted and production-validated.
- V2 remains **12.5% (1/8 phases complete)** because V2-2 still requires Grab and Summon.


Work unit 9 — **sixth genuinely new family: `grab` — accepted and production-validated**:
- Grab reuses the existing bounded common skill fields rather than expanding the package schema: `range` positions the forward capture source volume, `hitbox_half_width` / `hitbox_half_depth` bound overlap, `active` is the finite hold window, and `knockback` is reused as the finite target anchor offset.
- `GrabState` performs no displacement unless the actual eligible target hurtbox overlaps the authored source volume. Invalid target/source geometry, non-positive hold/offset values, or invalid arena bounds fail closed. A single activation can capture at most once.
- Runtime uses optional `skill_12` / E and the existing state + controller + coordinated-wrapper pattern. Creator Preview injects only the temporary preview slot; stored CharacterDraft data remains unchanged.
- Exact-type registry loading, Creator family authoring, timeline dispatch, deterministic package round-trip, Grab domain tests, and Chromium/Edge Creator Preview coverage are synchronized without arbitrary target selectors, callbacks, paths, scripts, user code, or autonomous actors.
- PR #158 latest head `42eeddf2f8c9ca542194734052bb2ac2121a1cf8` passed CI #399 (`35348193780`): Windows Native Release, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`.
- PR #158 was explicitly approved and squash-merged to `main` at `d0b4dc9529a81466e03afe74511819efe14152d7`.
- Main CI #400 (`35349720100`) on that exact revision passed Windows Native, Godot/domain/backend, Chromium, hosted Edge, GitHub Pages deployment/public reachability, and Render exact-revision readiness. The readiness gate emitted `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=d0b4dc9529a81466e03afe74511819efe14152d7`.
- Production Edge attempt #1 passed the twelve-family Creator Preview/Grab flow, then timed out in unchanged `smoke:creator-vfx` while waiting five seconds for a revision observation. No product code changed; targeted retry attempt #2 on the same SHA passed Creator VFX, Creator VFX runtime, the rest of the suite, and `SMOKE_SUITE_PASSED count=24`.
- Production evidence includes `WEB_CREATOR_PREVIEW_FAMILY_SMOKE_PASSED families=12 ... grabPolicy=overlap-hold-once ... timelineDispatch=true roundTrip=true`. Grab Work Unit 9 is therefore accepted and production-validated.
- V2 remains **12.5% (1/8 phases complete)** because V2-2 still requires its final family, **Summon**.

Work unit 10 — **final V2-2 family: `summon` — accepted and production-validated**:
- Summon reuses existing common fields only: `range` is bounded forward spawn offset, `speed` is deterministic horizontal actor speed, `active` is finite actor lifetime, and the existing hitbox dimensions bound collision volume. No package schema field was added.
- `SummonState` owns exactly one actor instance per activation. Spawn and arena geometry fail closed, movement is deterministic toward only the runtime-provided designated target, lifetime is finite, and one actor can consume at most one eligible overlap hit before deterministic cleanup.
- Runtime routing is optional `skill_13` / Q. The coordinated controller reuses `SkillCastState`, MP/cooldown, `SkillCoordinator`, exact-type registry loading and the existing declarative timeline scheduler.
- Creator authoring, Creator Preview temporary slot injection, Character Package common-field round trip, deterministic domain coverage and thirteen-family Chromium/Edge smoke coverage are synchronized.
- CI #403 (`35368837252`) and diagnostic CI #404 (`35369547182`) exposed one GDScript parse defect before domain/browser execution: `target_eligible := ...` depended on dynamic `host` members, so Godot 4.7 could not infer a static type. A temporary `--check-only` diagnostic identified `summon_skill_controller.gd:104`; commit `88b671bd85437ff8fa354d95c2d340ffb0302fb1` changed it to explicit `bool`, and the diagnostic step was removed in `12930f7ac5cbe903e206358e2cca4d774ab7783c`.
- Latest PR head `23eff68188dca878877209ffe92d3fd3e1e40938` passed CI #409 (`35407714816`) across Windows Native, Godot import/boot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- PR #160 was explicitly approved and squash-merged to `main` at `5502bbc9b31725488d34e3614c495fe2ad47d85d`.
- Main CI #410 (`35410123320`) passed the complete production chain on that exact revision: Windows Native, Godot import/boot/domain/backend, Web export/size budget, Chromium, hosted Microsoft Edge, GitHub Pages deployment, public-Web reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production evidence includes `SUMMON_TESTS_PASSED`, `WEB_CREATOR_PREVIEW_FAMILY_SMOKE_PASSED families=13 ... summonPolicy=bounded-actor-single-hit ... timelineDispatch=true roundTrip=true`, and `SMOKE_SUITE_PASSED count=24`. Render readiness emitted `PRODUCTION_AI_BACKEND_READY ... revision=5502bbc9b31725488d34e3614c495fe2ad47d85d`.
- Summon data contains no arbitrary scene/resource path, callback, script, target selector, user code or unbounded actor list.

### V2-2 acceptance

V2-2 Extended Skill Families is **accepted complete** on 2026-09-19. The roadmap acceptance criterion is satisfied: Beam, Trap, Aura, Teleport, Counter, Grab, and Summon each have validated data definitions, runtime implementations, Creator authoring/Preview paths, deterministic tests, and Chromium/hosted-Edge coverage; safe scripted event compositions expand only into the existing allow-listed declarative timeline events; no arbitrary user code is executed.

Final production evidence is PR #160 merged to `main` as `5502bbc9b31725488d34e3614c495fe2ad47d85d` and Main CI #410 (`35410123320`), which passed the full production chain including GitHub Pages/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke. The deployed thirteen-family regression reports `summonPolicy=bounded-actor-single-hit` and all 24 smoke stages passing.

V2 progress therefore advances to **25% (2/8 phases complete)**, and **V2-3 Character Animation & Audio Authoring** becomes the active phase.

### V2-3 implementation checkpoints

Work unit 1 — **trusted animation-map authoring foundation — accepted and production-validated**:
- V2-3 architecture inventory is recorded in `docs/V2_3_CHARACTER_ANIMATION_AUDIO_INVENTORY.md`.
- Existing runtime `CharacterAnimationMap` remains authoritative and resolves only trusted `res://content/character_animations/<id>.animation.json` data with safe-token animation IDs.
- Character Editor exposes an Animation Map field and Web bridge/telemetry.
- `CharacterDraft` requires the authored map to actually resolve through `CharacterAnimationMap`; a safe-looking but missing token fails closed rather than reaching Preview with a broken runtime reference.
- Existing Character Package schema is intentionally unchanged because `character.animation_map` already round-trips. Browser regression proves authored `storm_duelist` survives export/import and Preview loads the Storm map; a package referencing a missing map is rejected without mutating the valid draft.
- Product head `23c673be0fa6a58949849884b3d879b1186174ee` passed CI #413 (`35420773510`), and documentation-updated latest PR head `a7952ee28ffafdbfa210908503b62b82f3ff9f2f` passed CI #415 (`35422840793`).
- PR #162 squash-merged to `main` as `65489e41d66bed5af2eb44b3c2ad63222b240b78`.
- Main CI #416 (`35431205627`) completed successfully on exact `main` revision `65489e41d66bed5af2eb44b3c2ad63222b240b78`. Attempt 1 reached production Edge after Pages/public/Render success but timed out in unchanged Creator Preview `timeline-overlap-window`; feature-specific character-animation and Creator animation-map coverage had already passed. Per L-007, no unrelated runtime code changed; the exact-SHA targeted retry passed the full chain.
- Final production evidence includes `WEB_CHARACTER_ANIMATION_SMOKE_PASSED`, `WEB_CREATOR_STUDIO_SMOKE_PASSED ... animationMapAuthoring=true missingMapBlocked=true`, `WEB_CREATOR_PACKAGE_SMOKE_PASSED ... animationMapRoundTrip=true animationPreview=true missingAnimationMapBlocked=true`, `SMOKE_SUITE_PASSED count=24`, and `PRODUCTION_AI_BACKEND_READY ... revision=65489e41d66bed5af2eb44b3c2ad63222b240b78`.
- No arbitrary resource path, URL, script, callback, or executable payload is introduced.
- Existing timeline audio remains a safe cue-token boundary only. Audio-file import and package audio assets are deferred to later V2-3 work.
- V2 remains **25% (2/8 phases complete)** until the complete V2-3 acceptance criterion is met.

Work unit 2 — **per-semantic animation-map authoring + in-memory Preview — accepted and production-validated**:
- `CharacterAnimationDraft` edits only fixed `CharacterAnimationMap.REQUIRED_SEMANTICS` entries and safe lowercase animation-ID tokens; unsafe/path-like values fail closed.
- Creator Preview stages only a validated in-memory map whose ID matches `CharacterDraft.animation_map`, Training applies it through the existing `CharacterAnimationMap` parser, and Preview → Creator preserves the transient draft.
- Package export is blocked while semantic animation state is invalid; WU2 intentionally kept package persistence unchanged and package import reset transient animation state to its trusted repository map.
- PR #163 latest head `4183aa45eac248365c3efeab8f814965d1dac09c` passed PR CI #417 (`35444063803`) across Windows Native, Godot/domain/backend/Web/Chromium and hosted Microsoft Edge.
- PR #163 squash-merged to `main` as `2111f3b27dfbd3fa0de8380fc72f3167ff4be461`.
- Main CI #418 (`35444847516`) passed the complete production chain on that exact SHA on attempt 3: Windows Native, Godot/domain/backend/Web/Chromium, hosted Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Edge full smoke.
- Main CI #418 attempts 1 and 2 failed only in different unchanged hosted-Edge observation windows: `web_smoke.mjs` missed the short Dummy `RECOVERING` state, then `creator_vfx_runtime_binding_web_smoke.mjs` missed a 5-second Creator dataset synchronization window. WU2-specific semantic animation stages passed before the second timeout; attempt 3 passed the same SHA without product changes. This recurrence is tracked under L-007.
- Final production evidence includes `WEB_CHARACTER_ANIMATION_SMOKE_PASSED`, `WEB_CREATOR_STUDIO_SMOKE_PASSED ... semanticAuthoring=true unsafeSemanticTokenBlocked=true`, `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... semanticAnimationOverride=true semanticAnimationRoundTrip=true`, `SMOKE_SUITE_PASSED count=24`, and `PRODUCTION_AI_BACKEND_READY ... revision=2111f3b27dfbd3fa0de8380fc72f3167ff4be461`.
- V2 remains **25% (2/8 phases complete)** until the full V2-3 phase acceptance criterion is satisfied.

Work unit 3 — **self-contained Character Package persistence for semantic animation mappings — accepted and production-validated**:
- Self-contained package schema v2 accepts an optional `animation_map` payload containing only the existing schema-v1 `CharacterAnimationMap` shape.
- Package validation reuses `CharacterAnimationMap.load_from_dictionary()`, canonicalizes only fixed required semantics, rejects unknown/path/code-like fields and unsafe animation IDs, and requires the payload ID to equal `character.animation_map`.
- Legacy Character Package schema v1 remains unchanged and import-compatible; schema-v2 packages that omit `animation_map` remain valid.
- Creator schema-v2 export includes the currently validated semantic animation draft. Import first completes the existing legacy character/skill compatibility path, then restores the validated packaged map into Creator/session state so stale transient edits cannot win.
- Domain regressions cover deterministic map round-trip, ID mismatch, unsafe animation token and unknown-field rejection. Creator Package browser regression exports a custom `ready` mapping, verifies package JSON, blocks a tampered unsafe mapping without mutating valid drafts, imports the original package, and proves Training runs the packaged custom semantic mapping.
- PR #165 latest head `48900734c095e5de0dc35690cebb9458f698ff76` passed PR CI #420 (`35446574026`) across Windows Native, Godot/domain/backend/Web/Chromium and hosted Microsoft Edge.
- PR #165 squash-merged to `main` as `930e6bed3bdfaabc26495b2c6264f05ae14e201a`.
- Main CI #421 (`35452686079`) passed the complete exact-SHA production chain on the first attempt: Windows Native, Godot/domain/backend/Web/Chromium, hosted Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Edge full smoke.
- No arbitrary animation resource/file path, URL, script, callback or executable payload is introduced.
- V2 remains **25% (2/8 phases complete)** until the full V2-3 phase acceptance criterion is satisfied.

Work unit 4 — **safe character/skill audio cue bindings — implementation complete; PR validation passed**:
- A new `CharacterAudioBindings` contract defines exactly five fixed semantic binding slots: `ready`, `basic_attack`, `hit_received`, `skill_cast`, and `skill_impact`.
- Each binding resolves only to a safe lowercase cue token. Unknown binding names, missing required bindings, path/URL/code-like values and arbitrary executable metadata fail closed.
- Creator Character Editor exposes fixed binding selection + Cue ID editing through `CharacterAudioDraft`; combined Character validation blocks Preview/package export while the audio draft is invalid.
- Creator Preview stages validated audio bindings in memory. Existing timeline `audio` events remain declarative; when their cue is one of the fixed semantic binding names, Preview resolves it through the authored binding map before publishing runtime audio telemetry.
- Self-contained Character Package schema v2 adds optional structured `audio_bindings` data. Legacy schema v1 and schema-v2 packages without this field remain compatible; imports without authored bindings reset to safe defaults.
- Browser/domain regressions cover safe/unsafe Creator editing, PreviewSession fail-closed behavior, runtime `skill_cast` resolution, deterministic package round-trip, tampered package rejection and import → Training preservation.
- PR #166 head `22c41b662a5753d59f47a3cd44bd20e63cfc975c` passed PR CI #425 (`35457465896`) across Windows Native, Godot import/boot/domain/backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all`.
- CI #422/#424 exposed only a browser-regression assertion that confused persisted draft data with transient editor selection. No runtime behavior change was required; L-034 records the prevention rule, and the corrected latest head passed both Chromium and hosted Edge.
- WU4 deliberately does **not** accept or decode audio files yet. Audio bytes, approved MIME/codec import, package asset transport and real playback binding remain later V2-3 slices.
- PR #166 squash-merged to `main` as `c326608f691129207d708cffbd339850308fedd6`.
- Main CI #428 exposed two different unchanged hosted-Edge timing windows after Chromium/WU4 feature coverage had passed. PR #167 added test-only state-capture/timeout hardening, then passed CI #429 without changing runtime behavior.
- PR #167 squash-merged as `66190eff50b60d4a11a57a702fc175accaf58634`; exact-main CI #430 (`35482812184`) passed Windows Native, Godot/domain/backend, Web/Chromium, hosted Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Edge `SMOKE_SUITE_PASSED count=24`.
- Render readiness confirmed `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=66190eff50b60d4a11a57a702fc175accaf58634`.
- V2 remains **25% (2/8 phases complete)** until the full V2-3 phase acceptance criterion is satisfied.

Work unit 5 — **bounded PCM WAV import + memory-only Creator persistence — accepted and production-validated**:
- `CharacterAudioAssetDraft` accepts one short WAV asset bound to one existing fixed audio binding + safe cue token.
- Accepted files are limited to safe `.wav` filenames, canonical `audio/wav`, RIFF/WAVE framing, uncompressed PCM, mono/stereo, 8/16-bit, 8–48 kHz, ≤3 seconds, and ≤512 KB.
- The parser validates RIFF/chunk bounds, `fmt`/data presence, PCM format, byte rate, block alignment, complete PCM frames, payload length and derived duration. Compressed/non-PCM, malformed, oversized, path-like, or metadata-mismatched files fail closed.
- Creator Character Editor adds `Choose WAV` / `Clear WAV` for the currently selected Audio Binding/Cue ID. The browser transfers bytes through a bounded base64 data URL; no filesystem path or remote URL is retained.
- Validated metadata + bytes live only in `CreatorPreviewSession` memory and survive Creator → Training Preview → Creator navigation. WU5 does **not** play the WAV.
- If the bound Cue ID changes, the stale WAV is cleared immediately. Character reset and successful package import clear the WU5 memory-only WAV.
- WU5 deliberately does **not** serialize WAV bytes into Character Package schema v2. Invalid package imports preserve the current WAV; a successful package import clears it so state cannot leak across package boundaries.
- Domain/session/browser regressions cover valid PCM parsing, unsafe filename/non-PCM/duration rejection, metadata round-trip, tampered-byte fail-closed clearing, Creator import/stale-clear/reset, Preview memory round-trip, and package workflow isolation.
- PR #168 latest head `a8d9ca8c2f264c97b2120943ce622c7c7d7ef716` passed PR CI #433 (`35485758758`) after the earlier product head had already passed CI #431.
- PR #168 was explicitly approved and squash-merged to `main` as `c5f7e68e919aa0be111c167696757722bf061c80`.
- Exact-main CI #434 (`35493570174`) passed the complete production chain on that revision: Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.

Work unit 6 — **bounded WAV Character Package transport — accepted and production-validated**:
- Schema-v2 self-contained packages may carry one optional `audio_asset`: validated `CharacterAudioAssetDraft` metadata plus bounded WAV bytes encoded as base64. Legacy schema v1 and schema-v2 packages without the field remain compatible.
- Package validation reuses the WU5 PCM parser and byte/metadata contract; no second codec/parser path is introduced.
- A packaged WAV is accepted only when its fixed binding exists in packaged `audio_bindings` and its Cue ID exactly matches that binding. Missing/mismatched bindings, malformed base64, tampered RIFF/WAVE bytes, unknown fields and oversized payloads fail closed.
- Creator export/import transports the one validated WAV and restores it through `CreatorPreviewSession.store_audio_asset_draft()`; failed package imports remain non-mutating.
- Creator package JSON remains bounded at 8 MB so the existing bounded VFX payload plus one ≤512 KB WAV can coexist without making package input unbounded.
- PR #169 latest head `a6886daa27519346fd8d4f10f342e1939ccac50a` passed CI #436 after a same-SHA hosted-Edge retry of one unchanged Buff timing observation.
- PR #169 was explicitly approved and squash-merged to `main` as `2335ef2351409d8e023f0884a2e55b176d45781c`.
- Exact-main CI #437 (`35497667643`) passed the complete production chain: Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.

Work unit 7 — **Creator Preview runtime WAV playback — accepted and production-validated**:
- `CreatorPreviewSession` stages the stored WAV into active Preview only when its validated binding/Cue ID exactly matches active `audio_bindings`; mismatch fails closed before Training Preview activates.
- Training runtime revalidates staged metadata + bytes, loads the bounded WAV through Godot `AudioStreamWAV.load_from_buffer()`, and plays it through an in-memory `AudioStreamPlayer`. No filesystem/resource path, URL, script, callback, external decoder, native library, compressed user audio, or second executable media path is introduced.
- Existing timeline `audio` events resolve through `CharacterAudioBindings`; playback occurs only when the resolved Cue ID exactly matches the one staged WAV.
- PR #170 was explicitly approved and squash-merged as `0ecbbcdd5b6439bf8d4ae50d184b349cd1fea495`. Its WU7 Creator Preview regression proved `wavRuntimePlayback=true`.
- Main CI #441 exposed two different unchanged hosted-Edge short observation failures after WU7-specific coverage had already passed. Per L-007, blind retries stopped and PR #171 hardened only the browser observations: atomic jump-state/offset capture and a bounded persistent Creator VFX revision window, with no product/runtime change.
- PR #171 latest head `7ff377a4b759933286c8bb69d88f2da0efc051b0` passed PR CI #443 (`35507350929`) on attempt 1 across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all` with all 24 stages.
- PR #171 was explicitly approved and squash-merged to `main` as `6d1c40878cd8988a6d27e8438c402ba706c020cd`.
- Exact-main CI #444 (`35509107038`) passed the complete production chain on that exact revision: Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production Edge emitted `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... wavRuntimePlayback=true`, `WEB_CREATOR_VFX_EDITOR_SMOKE_PASSED`, and `SMOKE_SUITE_PASSED count=24`. Render readiness emitted `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=6d1c40878cd8988a6d27e8438c402ba706c020cd`.
- WU7 is therefore accepted and production-validated. Its deliberate scope remains the timeline-driven `skill_cast` playback path.

Work unit 8 — **basic-attack WAV runtime trigger — accepted and production-validated**:
- WU8 extends the already-approved single-WAV runtime path to the fixed `basic_attack` semantic only; it does not add another asset slot, collection, decoder, resource path, URL, script, callback, or executable event vocabulary.
- Creator Preview observes each newly-started normal attack step after the authoritative combat state accepts it, resolves `basic_attack` through `CharacterAudioBindings`, and reuses the exact-Cue-matching WU7 playback boundary.
- PR #172 implementation head `35715e9437983cea55b6a2014b16a4210630a541` passed PR CI #445 (`35510295745`) on attempt 1. Latest documentation-sync head `df0fe77a625dce634cb538d44df0289c10400d3f` then passed PR CI #447 (`35511016768`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- Chromium and hosted Edge emitted `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... wavRuntimePlayback=true basicAttackWavRuntimePlayback=true` and `SMOKE_SUITE_PASSED count=24`, proving WU7 skill-cast playback remained intact and J triggered the newly bound `basic_attack` WAV.
- PR #172 was explicitly approved and squash-merged to `main` as `a2e348c83c2db03c0bd2cef0466382854e3a097a`.
- Exact-main CI #448 (`35512384893`) passed the complete production chain: Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production Edge again emitted `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... wavRuntimePlayback=true basicAttackWavRuntimePlayback=true` and `SMOKE_SUITE_PASSED count=24`. Render readiness emitted `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=a2e348c83c2db03c0bd2cef0466382854e3a097a`.
- WU8 is therefore accepted and production-validated.

Work unit 9 — **skill-impact WAV runtime trigger — accepted and production-validated**:
- WU9 extends the same one-WAV safe runtime path to the fixed `skill_impact` semantic only. It adds no second asset, unbounded collection, path/URL loading, external decoder, script, callback, native library, or new executable event language.
- Creator Preview observes only authoritative skill-hit counter increases after parent collision/damage processing, then resolves `skill_impact` through the existing `CharacterAudioBindings` and exact-Cue playback boundary.
- PR #173 implementation head `44f3101ff66524b39ce26eb955c4a2f1dee900c1` passed PR CI #449 (`35516777928`). Latest docs-sync head `63bacdf39b44fad51f1ba64fe5d7542ec209f1ac` passed PR CI #451 (`35517485178`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- Both browsers emitted `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... wavRuntimePlayback=true basicAttackWavRuntimePlayback=true skillImpactWavRuntimePlayback=true` and `SMOKE_SUITE_PASSED count=24`.
- PR #173 was explicitly approved and squash-merged to `main` as `920ca4a237999856b8e06cf5fbb28b4c88cd4521`.
- Exact-main CI #452 (`35518658940`) passed the complete production chain: Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production Edge emitted `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... wavRuntimePlayback=true basicAttackWavRuntimePlayback=true skillImpactWavRuntimePlayback=true` and `SMOKE_SUITE_PASSED count=24`. Render readiness emitted `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=920ca4a237999856b8e06cf5fbb28b4c88cd4521`.
- WU9 is therefore accepted and production-validated.

Work unit 10 — **hit-received WAV runtime trigger — accepted and production-validated**:
- WU10 extends the approved single-WAV runtime path to the fixed `hit_received` semantic only and retains one authoritative synchronous event owner: `animation_main.gd::receive_player_hit(...)`.
- Parent combat resolution runs first; playback is requested only when actual dealt damage is greater than zero. Counter-intercepted hits, zero-damage hits, defeated-state no-ops and rejected hits remain silent.
- PR #174 latest head `ad1802bf7a2a9c22b0a0568c77e6ae4884da2b91` passed final PR CI #458 (`35521524471`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- PR #174 was explicitly approved and squash-merged to `main` as `2b027ee70afc5b5e408c15cddc71ede8f18585fb`.
- Exact-main CI #459 (`35523850244`) passed the complete production chain: Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production Edge emitted `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... wavRuntimePlayback=true basicAttackWavRuntimePlayback=true skillImpactWavRuntimePlayback=true hitReceivedWavRuntimePlayback=true` and `SMOKE_SUITE_PASSED count=24`.
- Render readiness emitted `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=2b027ee70afc5b5e408c15cddc71ede8f18585fb`.
- L-035 records the branch-reconciliation correction that removed the duplicate frame-polling consumer and keeps one semantic event owner.
- WU10 is therefore accepted and production-validated.

Work unit 11 — **bounded character animation PNG import + memory-only Creator persistence — accepted and production-validated**:
- A dedicated `CharacterAnimationAssetDraft` accepts exactly one bounded character animation PNG/sprite strip at a time, bound to one required animation semantic plus the currently authored safe animation ID.
- Safety limits remain `image/png` only, ≤5 MB decoded bytes, ≤4096×4096, 1–64 horizontal frames, FPS 1–60, safe leaf `.png` filename, no path/URL/script/native/executable content, and decoded PNG dimensions must exactly match metadata.
- Creator Character Editor exposes `Choose Animation PNG`, `Clear Animation PNG`, Frames and FPS. Mapping changes clear stale bytes fail-closed; Creator → Training Preview → Creator preserves the validated asset in PreviewSession memory.
- PR #175 latest head `137d7a50527edb53241d0cc7873d53b8615f985d` passed final PR CI #465 (`35527429094`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- PR #175 was explicitly approved and squash-merged to `main` as `44466e43ddef4b6cd7f7dfef74f9c8a63347fd97`.
- Exact-main CI #466 (`35546160109`) passed the complete production chain: Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production Edge emitted `WEB_CREATOR_STUDIO_SMOKE_PASSED ... animationPngImport=true animationPngTiming=true staleAnimationPngCleared=true animationPngResetCleared=true`, `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... animationPngMemoryRoundTrip=true`, `WEB_CREATOR_PACKAGE_SMOKE_PASSED ... animationPngMemoryOnly=true invalidImportPreservesAnimationPng=true validImportClearsAnimationPng=true`, and `SMOKE_SUITE_PASSED count=24`.
- Render readiness emitted `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=44466e43ddef4b6cd7f7dfef74f9c8a63347fd97`.
- WU11 is therefore accepted and production-validated.

Work unit 12 — **self-contained Character Package transport for character Animation PNG — accepted and production-validated**:
- Schema-v2 carries one optional bounded `animation_asset`: validated WU11 metadata plus PNG bytes encoded as base64. Legacy schema v1 and schema-v2 packages without the field remain compatible.
- Package validation reuses `CharacterAnimationAssetDraft`, requires packaged `animation_map`, and requires exact `semantic + animation_id` agreement. Malformed base64, tampered PNG, unknown fields, unsafe metadata or mapping mismatch fail closed.
- Creator export/import transports the one character Animation PNG. Fresh-session regression proves one package can restore both embedded VFX and embedded character Animation PNG.
- The total Creator Package JSON ceiling is fixed at 16 MB; per-asset limits remain unchanged: VFX PNG ≤5 MB, character Animation PNG ≤5 MB, WAV ≤512 KB.
- PR #176 latest head `a5b4d9311320aea5ec7e8cdb9075c3a23944e164` passed final PR CI #469 (`35549426373`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- PR #176 was explicitly approved and squash-merged to `main` as `3975499d5c51297bf314dca3c7ccbc5c5964a977`.
- Exact-main CI #470 (`35550689268`) passed the complete production chain: Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production Edge emitted `WEB_CREATOR_PACKAGE_SMOKE_PASSED ... animationPngPackageRoundTrip=true invalidImportPreservesAnimationPng=true validImportRestoresAnimationPng=true tamperedPackagedAnimationPngBlocked=true`, `WEB_CREATOR_PACKAGE_VFX_SMOKE_PASSED ... embeddedAnimationPng=true secondSessionImport=true secondSessionAnimationPngRestored=true`, and `SMOKE_SUITE_PASSED count=24`.
- Render readiness emitted `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=3975499d5c51297bf314dca3c7ccbc5c5964a977`.
- WU12 is therefore accepted and production-validated.

Work unit 13 — **Creator Preview runtime rendering for the bounded character Animation PNG — accepted and production-validated**:
- Creator Preview revalidates the single bounded Animation PNG at runtime, requires exact active-map `semantic + animation_id` agreement, decodes it in memory with Godot, and renders the authored horizontal sprite strip only for the matching player semantic.
- Ordinary Training, Dummy rendering and unmatched semantics keep the existing procedural fighter fallback. Gameplay position, jump offset, guard overlay, combat boxes, collision authority and combat state remain unchanged.
- Authored FPS drives bounded frame progression. Leaving the bound semantic resets the custom strip; returning resumes from frame 0.
- PR #177 final head `64402e56eef389aee5d36e490b1ff7826b91f092` passed latest-head CI #481 (`35555529407`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- PR #177 was explicitly approved and squash-merged to `main` as `594b9d6a22a136db61f61fab4a6cab1ba69b8228`.
- Exact-main CI #482 (`35559539587`) passed the complete production chain: Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production Edge emitted `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... animationPngRuntimeRendering=true animationPngRuntimeFrameAdvance=true animationPngSemanticFallback=true`, `WEB_CREATOR_PACKAGE_VFX_SMOKE_PASSED ... secondSessionAnimationPngRestored=true animationPngRuntimeRendering=true animationPngRuntimeFrameAdvance=true`, and `SMOKE_SUITE_PASSED count=24`.
- Heavy Strike test-only overshoot recovery also remained green in production with `WEB_MELEE_SKILL_SMOKE_PASSED ... hitGap=89.98 ... finalHp=76 hitCount=1`; no melee gameplay rule was changed.
- Render readiness emitted `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=594b9d6a22a136db61f61fab4a6cab1ba69b8228`.
- WU13 is therefore accepted and production-validated.

Work unit 14 — **browser-autoplay-safe `ready` WAV runtime trigger — accepted and production-validated**:
- Reuse the existing one validated WAV asset and the fixed `ready` binding; no schema/package change and no second audio asset slot are introduced.
- A `ready` WAV loads normally into Creator Preview but starts only as an armed one-shot. It does not autoplay when Training Preview enters.
- The first non-echo keyboard press, mouse-button press or screen touch records the browser audio-unlock gesture. Playback is deferred to the next process tick rather than attempted during scene load.
- After the first successful `ready` cue playback, the one-shot disarms permanently for that Preview session. Later inputs cannot replay it.
- Non-`ready` WAV bindings keep their existing authoritative triggers: timeline/skill-cast, basic attack, skill impact and hit received.
- Runtime telemetry exposes armed/unlock-observed/played state and unlock input kind for deterministic browser verification.
- Creator Preview browser coverage proves: zero playback before user input, first key input unlocks and plays exactly once, and a second key input does not replay the cue.
- PR #178 implementation/docs head `34aaf39eeea886ca3b3eb97c4c9a9ff5d3b00b25` passed PR CI #483 (`35561166681`) across Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- Hosted Edge emitted `WEB_CREATOR_PREVIEW_SMOKE_PASSED ... readyWavAutoplaySafe=true readyWavFirstInputPlayback=true readyWavOneShot=true`.
- The full hosted Edge suite completed `SMOKE_SUITE_PASSED count=24`.
- PR #178 final head `552648d8c05a2a6b79c9aa3a0af0605034c9efdf` passed latest-head CI #485 (`35562239547`) and was explicitly approved and squash-merged to `main` as `831f3ec7f322e7b023cca0c0874b1f217d355a24`.
- Exact-main CI #486 (`35563876523`) passed the complete production chain: Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production Edge emitted `readyWavAutoplaySafe=true readyWavFirstInputPlayback=true readyWavOneShot=true` while all existing WAV runtime trigger flags remained green, then completed `SMOKE_SUITE_PASSED count=24`.
- Render readiness emitted `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=831f3ec7f322e7b023cca0c0874b1f217d355a24`.
- WU14 is therefore accepted and production-validated.
- After WU14, perform final V2-3 self-contained/playable acceptance and phase closeout.
- V2 remains **25% (2/8 phases complete)** until full V2-3 acceptance.


Work unit 15 — **final V2-3 self-contained playable acceptance — accepted; phase closeout synchronized**:
- This is a test/documentation acceptance slice only; **this work unit has no product functionality change**.
- The fresh-session Character Package browser regression authors one safe basic-attack WAV in the same schema-v2 package that already carries bounded VFX + Animation PNG.
- The regression exports the package, reloads Creator to create a fresh browser session, imports the package, verifies the WAV metadata/bytes were restored, enters Training, proves Animation PNG runtime rendering/frame advance, presses J, and requires the restored WAV to play through the authoritative `basic_attack` trigger.
- PR #179 head `8f42a1423a3027655d4090c8d316f5f8ad0fa0e2` passed PR CI #487 (`35566219175`) across Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- Hosted Edge emitted `WEB_CREATOR_PACKAGE_VFX_SMOKE_PASSED ... embeddedVfx=true embeddedAnimationPng=true embeddedWav=true secondSessionImport=true secondSessionAnimationPngRestored=true secondSessionWavRestored=true animationPngRuntimeRendering=true animationPngRuntimeFrameAdvance=true wavRuntimePlaybackAfterImport=true runtimeLoaded=true cast=true`.
- Hosted Edge completed `SMOKE_SUITE_PASSED count=24`.
- This closes the V2-3 roadmap acceptance criterion: a Creator-authored animation/audio package can be exported, imported into a fresh session, and preserve the playable Animation PNG + WAV + VFX result without arbitrary executable/resource paths.
- PR #179 latest head `3ef6df3f97c91cfb558ac2ab890c036931276d9e` passed PR CI #490 (`35568941052`) and was explicitly approved and squash-merged to `main` as `f4910ba1357157d41d371926cf75e61a94f0be00`.
- Exact-main CI #491 (`35572244642`) attempt 1 passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium, hosted Edge, Pages deployment/public reachability and Render exact-revision readiness; production Edge then timed out in the changed fresh-session package smoke at the post-acceptance Skill 1 MP observation window.
- The PR-head and merged-main `creator_package_vfx_web_smoke.mjs` blob SHA were identical, hosted Edge on exact main was already green, and production Edge had passed the new Animation PNG/WAV acceptance assertions before the timeout. A targeted same-revision retry (run attempt 2) then passed the complete production chain, including production Microsoft Edge full smoke, without product/test changes.
- V2-3 is therefore accepted **and production-validated** on exact main revision `f4910ba1357157d41d371926cf75e61a94f0be00`; V2 is **37.5% (3/8 phases complete)** and V2-4 is active.

### V2-1 implementation checkpoints

Work unit 1 was merged by PR #133 to `main` at `bb6d1c68a697958748e4dd9e6d2aac3c03bca414`:
- `SkillDefinition` accepts an optional backwards-compatible `timeline` object while existing V1 skill JSON remains valid without one.
- Timeline schema version 1 supports safe declarative `animation`, `vfx`, `audio`, `hitbox`, and `hurtbox` event types.
- Events have stable IDs, non-negative time/duration, deterministic non-decreasing order, duplicate-ID rejection, a 64-event limit, and a 30-second safety limit.
- Arbitrary event types/code are rejected.
- `has_timeline()` and `total_timeline_duration()` expose parsed timeline data without changing the V1 cast-state timing path.
- Dedicated timeline domain tests are wired into CI.

Work unit 2 was merged by PR #134 to `main` at `543510aef21663f6eb55f7b374d055b0f8c00720`; Main CI #289 (`35094636571`) completed successfully:
- `SkillDraft` owns optional timeline schema/event data and deep-copies authored events.
- Existing Creator drafts remain V1-compatible and omit the timeline object until events are actually authored.
- Creator draft serialization, loading and validation round-trip timeline data through the authoritative `SkillDefinition` contract.
- Reset/clear operations remove authored timeline state without affecting existing projectile defaults.
- Creator draft tests cover valid animation/VFX/hitbox/audio event round-trip, deterministic order, deep-copy isolation, reset compatibility, unsorted-event rejection and arbitrary event-type rejection.

Work unit 3 was merged by PR #135 to `main` at `1f4c167c02a11f390234cf8c4c589a53d0ec5012`; Main CI #293 (`35099330271`) completed successfully:
- Creator Skill Editor exposes a Timeline panel with event list, safe event type selection, time/duration fields, add/remove, explicit up/down ordering and clear controls.
- Event authoring mutates `SkillDraft.timeline_events`; `SkillDefinition` remains the authoritative validator and invalid chronological ordering fails closed instead of silently changing semantics.
- Browser bridge exposes deterministic timeline add/remove/move/update/clear operations and publishes event count, validity, serialized event state and validation error state for regression testing.
- `tests/creator_timeline_editor_web_smoke.mjs` covers empty V1-compatible startup, valid event authoring, invalid ordering detection/recovery, removal and clear.
- The timeline browser regression is wired into `npm run smoke:all` so normal GitHub Chromium/Edge validation exercises it.

Work unit 4 was merged by PR #139 to `main` at `c84e26f6967883a30fbf1ff0c3f548d2321bda55`; PR CI #306 (`35118913560`) completed successfully:
- `hitbox` and `hurtbox` timeline events normalize safe spatial payloads: `half_width`, `half_depth`, `offset_x`, and normalized-arena `offset_depth`.
- Spatial dimensions/offsets are bounded and fail closed when zero/negative or outside safe limits; older V2 spatial events that omitted these payload fields remain backwards compatible through safe defaults.
- Creator Timeline exposes type-specific spatial controls only for hitbox/hurtbox events and removes stale spatial fields when an event changes back to a non-spatial type.
- Creator draft/domain tests cover spatial round-trip, deep-copy isolation, backwards-compatible defaults, invalid dimensions and oversized offsets.
- Browser regression covers hitbox/hurtbox authoring, invalid-dimension fail-closed recovery, stale-payload cleanup, deterministic ordering, removal and clear.
- Merge Main CI #307 (`35120183809`) passed Windows Native plus Godot/backend/Web/Chromium, but its hosted Windows Edge job timed out in unchanged `character_animation_web_smoke.mjs` while waiting for a short-lived animation observation; downstream production gates were skipped. No unrelated runtime code was changed solely for that isolated timeout, consistent with `docs/LESSONS_LEARNED.md` L-007.
- `main` at `bb42d0aad815ebe41911f2cad82b779ae3748b25` subsequently completed Main CI #309 (`35122183786`) successfully across Godot/backend/Web/Chromium, Windows Native, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render production-backend readiness, and production Microsoft Edge full smoke.

Work unit 5 was merged by PR #141 to `main` at `dfa9232a7746fce940a828b60826d3bfbf3b9382`; PR CI #310 (`35124462507`) and Main CI #311 (`35125601715`) completed successfully:
- `animation`, `vfx`, and `audio` timeline events have type-specific declarative payloads: `animation`, `visual`, and `cue`.
- Media payload values are normalized as safe lowercase reference tokens; path/URL/code-like values such as `../evil.gd`, remote URLs, and filesystem audio paths fail closed instead of becoming runtime references.
- Older V2 media events that omit the new payload remain backwards compatible through safe defaults: `skill_1` for animation, the skill's validated root `visual` (or `projectile`) for VFX, and `skill_cast` for audio.
- Cross-type payload cleanup is explicit: switching an event type removes stale media or spatial fields that no longer belong to that type.
- Creator Timeline exposes a type-specific media payload editor for Animation, VFX, and Audio Cue while keeping the existing spatial controls for hitbox/hurtbox.
- Creator draft/domain regressions cover media serialization, reload, deep-copy isolation, defaults, unsafe-value rejection, and stale-field cleanup.
- Browser regression covers animation/VFX/audio authoring, unsafe media fail-closed recovery, media type switching, spatial-to-media cleanup, deterministic ordering, removal and clear.
- Main CI #311 validated the merged revision across Windows Native, Godot import/boot/domain/backend tests, Web export/size budget, Chromium, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.

Work unit 6 was merged by PR #142 to `main` at `fab821926e73ef3ec1df2de2138d3df5916a6c93`; Main CI #313 (`35128794735`) completed successfully across the full production chain:
- `SkillTimelineRuntime` converts validated declarative timeline events into deterministic runtime start/end boundaries without evaluating code or loading arbitrary paths.
- Time-zero events are emitted immediately when a cast starts; duration events track active windows and emit explicit end transitions; zero-duration events remain one-shot starts.
- Boundary ordering is deterministic across frame hitches and large deltas. If one event ends exactly when another starts, the end transition is emitted first, then starts follow source order.
- `SkillCastState` owns the timeline scheduler. Legacy startup/active/recovery semantics remain intact, while a timeline that extends beyond those phases keeps the skill busy and blocks recast/coordinator release until its final boundary executes.
- Runtime transition consumption is one-shot and deep-copied; active-event queries are read-only data views for Training consumers.
- Dedicated `skill_timeline_runtime_test_runner.gd` regression covers time-zero start, negative-delta safety, large-delta multi-boundary execution, same-time ordering, active windows, late events beyond legacy recovery, recast blocking, and no-timeline backwards compatibility.
- Main CI #313 passed Windows Native, Godot import/boot/domain/backend tests, Web export/size budget, Chromium, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.

Work unit 7 was merged by PR #143 to `main` at `383c5969697c323c368ca80d13c61b4595ed3978`:
- Creator Preview Training consumes validated timeline transitions for `animation`, `vfx`, `audio`, `hitbox`, and `hurtbox` without creating a second unsafe data path.
- Animation events can temporarily override the runtime animation semantic; VFX events have a timed Training overlay; audio cues are consumed as deterministic runtime telemetry; hitbox/hurtbox windows use the authored safe spatial payload and are rendered in Training.
- Runtime Web telemetry exposes transition count, elapsed time, last event/type/phase, media state, audio event count, and active spatial payloads for repeatable browser validation.
- `tests/creator_preview_web_smoke.mjs` authors all five event types, launches Training, casts Skill 1, verifies timing/media/spatial behavior, confirms the legacy projectile hit, waits for timeline cleanup, and returns to Creator with the five authored events preserved.
- Initial Chromium regression exposed a Web telemetry serialization defect: assigning a JavaScript array/object directly to `dataset` coerced the spatial payload to `[object Object]`. Commit `eae4c7847e5c250dd1f6e57dfdcbe47e7b517ddc` fixes this by assigning JSON text to the DOM dataset boundary; targeted Creator Preview Diagnostic Run #4 (`35138056651`) passed the complete directly affected Creator → Training → Creator flow.
- Full regression then exposed a second, separate non-Creator-Preview failure in unchanged `character_animation_web_smoke.mjs`: ordinary Training published the parent `godotReady`/selected-character telemetry but all animation-map telemetry remained empty. A targeted character-animation diagnostic reproduced the same condition.
- Root cause was the false branch of three typed `Array[Dictionary]` ternaries in `_set_web_state()`: Creator Preview used the typed runtime arrays and worked, but normal Training took the bare untyped `[]` branch and failed the typed assignment before `JavaScriptBridge.eval()` could publish animation telemetry. Commit `2d27374103327ed44c6d54df1b2f531c8084c1bf` initializes typed empty arrays first and only queries active timeline events when preview is active.
- Targeted PR Chromium Smoke Diagnostic Run #5 (`35164358167`) passed `smoke:character-animation` after the typed-array fix. Full PR CI #331 (`35164358190`) then passed Windows Native Release, Godot import/boot/domain tests, backend tests, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all` on the product-fix head.
- Temporary diagnostic workflow and character-animation smoke instrumentation were removed in cleanup commit `277d3537bb413f260a85d0e3b41dc6c417d366e1`; the PR returned to five intended changed files.
- Final latest-head PR CI #333 (`35170327643`) passed Windows Native Release, Godot import/boot/domain/backend tests, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all` on head `5b053424bbb1a30c8e9c9f596fb0c0f8009f1c8e`.
- PR #143 was squash-merged as `383c5969697c323c368ca80d13c61b4595ed3978`.
- Main CI #334 (`35171731664`) passed the complete production chain on that exact revision: Windows Native, Godot import/boot/domain/backend tests, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge, GitHub Pages deployment, public-Web reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.

### V2-1 acceptance

V2-1 Advanced Creator Timeline is **accepted complete** on 2026-09-17. The roadmap acceptance criterion is satisfied: a creator can author a multi-stage skill without editing code, including animation, VFX, audio, hitbox and hurtbox timing/spatial events, validate it, launch Training, observe the timed result, and round-trip back to Creator with the authored timeline preserved. Production evidence is main revision `383c5969697c323c368ca80d13c61b4595ed3978` and Main CI #334 (`35171731664`).

## V1 production acceptance checkpoint

P3 was accepted on 2026-09-16. Production Free Gemini E2E Run #4 (`35061328085`) passed real text and reference-PNG requests on exact revision `c5d36b7c9d6f7befa506d70798b0d00fef526e4e`, with Gemini 3.6 Flash, Free Tier guards, trusted Render credential isolation, structured VFX/skill output and deterministic Sharp PNG rendering.

P4 was accepted on 2026-09-16. Production Free Gemini E2E Run #5 (`35075099182`) completed successfully on exact revision `a572b0a3e60e377ae9152592c6d8c62e574a8554` and emitted `PRODUCTION_CREATOR_GEMINI_E2E_PASSED provider=gemini revision=a572b0a3e60e377ae9152592c6d8c62e574a8554 reference=true proposal=true confirmPreview=true cast=true damage=18`.

The V1 completion documentation was merged by PR #131; the V1 completion checkpoint on `main` is `ff744f643b37cc1947225ef4dbe052108d739a66`.

V2 roadmap activation PR #132 was merged to `main` at `41c047029175e4b1409fcd2f49e023332e5663e7`; Main CI #285 (`35084613478`) completed successfully, including Chromium, Windows Native, Microsoft Edge, Pages deployment, production public-Web checks, Render exact-revision readiness and production Edge smoke.

## Agent policy source-of-truth migration

2026-09-17 policy-maintenance PR #140 was merged to `main` at `bb42d0aad815ebe41911f2cad82b779ae3748b25`; Main CI #309 (`35122183786`) completed successfully across the complete production validation chain:
- root `AGENTS.md` is the single active Agent instruction source of truth;
- all still-valid rules from legacy `Agent.md` were consolidated without intentionally weakening the stricter online-only, GitHub truth, CI monitoring, reporting, synchronization, safety, Gemini-free-tier, connector-retry, and documentation rules;
- the roughly-70%-conversation handoff rule is explicitly captured in `AGENTS.md`, including repository checkpoint synchronization and a copyable continuation Prompt with actual GitHub state;
- active V2 roadmap policy references point to `AGENTS.md`;
- legacy root `Agent.md` is removed and must not be recreated;
- historical incident text may retain the old filename only where required to accurately describe the incident and is explicitly non-normative.

## Validation policy

Validation is **100% online-only**. Formal project validation uses GitHub-hosted Godot/domain/backend tests, Web export, Chromium, GitHub-hosted Microsoft Edge, GitHub Pages, Render exact-revision readiness, production Edge smoke, and manual real Gemini E2E only when real provider quota is required.

Do not use Remote Desktop Commander, the user's local machine, local Godot/npm/browser caches, or user-device storage for formal project validation or Git synchronization.

## Execution policy

Continue through all non-blocked implementation, regression, cloud validation, fixes, merge and documentation work for the active phase. Do not stop at a completed sub-job. If a required validation fails, inspect online evidence, fix it when permitted, and follow the replacement run through terminal state.

Every reported completed code/test/doc/config work unit must already be synchronized to GitHub. Unsynchronized work cannot be counted as Done.

V1 stays 100%. V2 progress is independent and advances only when V2 phase acceptance criteria are met and synchronized.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

AI VFX backend: `https://custom-fighter-ai-vfx.onrender.com`

## Next implementation target

Validate and merge **V2-4 Work Unit 4 — stage definition + registry**. After WU4 merge/exact-main validation, begin **Work Unit 5 — stage selection + single-player entry** using only validated stage IDs and existing bounded opponent profiles.


## V2-6 WU2 — server-side package authority admission (2026-09-24)
- Added a server-owned PvP package authority adapter for built-in and bounded custom loadouts.
- Built-in competitive characters are admitted only when the client claim matches the server-frozen V2-5 fingerprint.
- Custom package admission fails closed on unsupported schema/ruleset/budget, unknown fields, unresolved skill slots/types, duplicate skills, and bounded combat-value violations.
- The client fingerprint is equality evidence only: the server resolves and validates trusted package data, computes the authoritative fingerprint, and never accepts client damage/cooldown as authority.
- Backend regression coverage is wired into the existing trusted-backend CI gate; no extra browser process/job is added.
- V2 remains 62.5% (5/8) until full V2-6 acceptance.


## V2-6 WU3 — authoritative input/tick/state model (2026-09-24)
- Added a deterministic 60 Hz server-owned match simulation boundary for exactly two admitted participants.
- Clients submit bounded action intents with monotonic sequence numbers and a small future tick window; unknown fields/actions, stale sequences, and invalid target ticks fail closed.
- Server state owns position, HP, MP, guard state, cooldowns, hit resolution, damage and match winner. Client-provided combat facts are not accepted by the input schema.
- Basic attack/cooldown/guard behavior is intentionally minimal in WU3; it establishes authority semantics before WU4 transport/Web integration and is not yet a claim of full Godot combat parity.
- Deterministic backend regression covers movement, sequence/tick rejection, forged combat fields, server cooldown, server guard mitigation and immutable snapshots.
- CI #574 exposed a WU3 regression-test/authority-order defect: the guard assertion attempted to hit at distance 4 while attack range is 3, and same-tick guard state was resolved after the attacker when client IDs sorted attacker-first.
- WU3 now resolves same-tick movement/guard for all accepted intents before combat actions, and the regression explicitly establishes in-range geometry before validating cooldown and guard mitigation. Corrected head `da3a151491c08b7992c64ae30b76e5478fea2c71` passed PR CI #575 (`35943522365`): Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- V2 remains 62.5% (5/8) until complete V2-6 acceptance.
