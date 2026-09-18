# Project Status

## Current phase

**V1/MVP is complete; V2 roadmap is now active.**

- V1 completion remains **100% (13/13 phases complete)**.
- V2 completion is **12.5% (1/8 phases complete)**.
- Completed V2 phase: **V2-1 Advanced Creator Timeline**.
- Active V2 phase: **V2-2 Extended Skill Families**.

V1 roadmap:
- M0–M8 MVP: 9/9 complete.
- P1 Safe real-provider boundary: complete.
- P2 Async remote AI transport: complete.
- P3 Production AI provider/backend integration: complete.
- P4 Image → skill proposal → Creator → Training production flow: complete.

V2 roadmap is defined in `docs/V2_ROADMAP.md` and captures previously discussed/deferred capabilities outside the V1 acceptance boundary.

## V2 roadmap

1. V2-1 Advanced Creator Timeline — **complete**.
2. V2-2 Extended Skill Families — **in progress**.
3. V2-3 Character Animation & Audio Authoring — pending.
4. V2-4 AI Opponents & Single-player Gameplay — pending.
5. V2-5 Game Modes, Balance & Competitive Foundation — pending.
6. V2-6 Network PvP — pending.
7. V2-7 Creator Sharing Ecosystem — pending.
8. V2-8 Mobile Targets — pending.

V2-1 delivered visual event timeline authoring, startup/active/recovery timing, animation/VFX/audio events, hitbox/hurtbox timing and spatial editing, safe multi-event compositions, validation, and Creator → Training preview round trip. V2-2 now extends the data-driven skill engine beyond the six V1 families while preserving safe declarative event boundaries and no arbitrary user code.

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

Begin V2-2 Work Unit 10 with **Summon**, the final V2-2 family. Summon must use a bounded, deterministic actor lifecycle with an explicit finite lifetime, validated spawn location, constrained owner/target relationship, deterministic cleanup, and at-most-bounded active instances. Reuse `SkillCastState`, `SkillCoordinator`, Creator Preview, package round-trip and timeline dispatch; do not permit arbitrary scenes/paths, callbacks, scripts, autonomous user code or unbounded actor spawning. After Summon passes PR and exact-`main` production validation, evaluate and record full V2-2 phase acceptance.
