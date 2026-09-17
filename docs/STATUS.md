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

Work unit 1 — **skill-family authoring foundation — PR validation complete, merge pending** on PR #145 / branch `feat/v2-2-skill-family-authoring-foundation`:
- `docs/V2_2_SKILL_FAMILY_INVENTORY.md` inventories the six V1 families, fixed slot/type routing, Creator projectile-only bottleneck, reusable V2 timeline primitives and existing online regression boundaries.
- `SkillDraft` is no longer hard-locked to projectile. It accepts every family currently declared by `SkillDefinition.SUPPORTED_TYPES`, serializes/reloads family-specific formation and buff fields, and applies deterministic safe defaults on explicit family changes.
- Projectile remains the reset/default family so existing Creator Preview, package, VFX and AI-proposal flows remain backwards compatible.
- Creator Skill Editor now exposes one safe Skill Family selector instead of a fixed PROJECTILE label. Unsupported family values are not accepted by the selector path and direct invalid draft values still fail closed through `SkillDefinition`.
- Creator Web telemetry includes formation/buff family defaults so browser regressions can assert the validated data contract.
- `creator_skill_draft_test_runner.gd` covers all six V1 family round-trips, family-specific invalid formation/buff parameters, unsafe/unsupported family rejection and the existing timeline fail-closed contract.
- `creator_skill_editor_web_smoke.mjs` switches through melee/projectile/area/dash/formation/buff in the real Creator UI bridge and verifies each draft remains valid before re-running the existing projectile invalid/valid/reset regression.
- Initial PR CI #337 exposed a Creator inheritance member collision: adding `SkillDefinition` to the base `creator_studio.gd` conflicted with the descendant `timeline_creator_studio.gd`. Commit `31973ef2f1d51ad66a2f5f4b7a7dee748dad4a7f` removed the redundant base preload and retained the globally registered class reference. This recurrence is recorded as L-027.
- A later hosted Edge observation exposed a transient Heavy Strike cooldown sampling race. Commit `f90d38701ff1f7c58a9bf2b4fd6dd2483a92d797` captures positive cooldown and READY+cooldown evidence atomically from the successful browser predicate instead of re-reading after the transient condition. This recurrence is recorded as L-028; gameplay behavior did not change.
- PR #145 latest-head CI #339 (`35186404303`) passed Windows Native Release, Godot import/boot/domain/backend tests, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Windows Microsoft Edge `smoke:all` on head `f90d38701ff1f7c58a9bf2b4fd6dd2483a92d797` before the final documentation-only synchronization commits.
- This work unit deliberately does **not** claim non-projectile Creator Preview support yet; preview/runtime family dispatch is the next architecture step.
- The first planned genuinely new V2 family is `beam`, selected because it can reuse declarative range/active/spatial/timeline primitives without introducing autonomous actors, target grabs, reactive code or player relocation.

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

Merge PR #145 only after the final documentation-only latest-head CI is green, then monitor the resulting `main` production chain through GitHub Pages/public reachability/Render readiness/production Edge. After production validation, begin V2-2 work unit 2: data-driven Creator Preview/runtime family dispatch and the first new family, `beam`, without weakening exact registry/type validation or allowing arbitrary user code.
