# V2-3 Character Animation & Audio Authoring — Architecture Inventory

Date: 2026-09-19

## Purpose

This inventory is the implementation baseline for V2-3. The phase acceptance target is a Creator-authored character animation/audio configuration that can be exported, imported elsewhere, and preserve the playable result without allowing arbitrary executable/resource paths.

## Existing character animation boundary

The runtime already has a safe declarative animation-map layer:

- `CharacterDefinition.animation_map` stores one safe lowercase reference token.
- `CharacterAnimationMap` resolves that token only under `res://content/character_animations/<id>.animation.json`.
- Animation-map JSON is schema-validated and allow-listed.
- Required semantics currently cover `ready`, `walk`, `run`, `jump`, `dash`, `guard`, `attack_1..3`, and `skill_1..6`.
- Animation IDs are safe tokens, not resource paths.
- Unknown runtime semantics fall back to `ready`.
- Existing reference maps are `ember_vanguard` and `storm_duelist`.
- Runtime/Chromium/Edge coverage already proves those maps resolve and drive Training animation telemetry.

Before V2-3 Work Unit 1, Creator preserved only the starter `animation_map` value. The Character Editor displayed no animation-map authoring control, and `CharacterDraft.validate()` checked only the CharacterDefinition token shape rather than whether the trusted map actually existed.

## Existing package boundary

Character Package already serializes `character.animation_map` in its canonical character shape. Self-contained package schema v2 retains the optional validated PNG VFX asset and, as of WU3, can also carry validated structured `animation_map` data. WU4 extends that same schema additively with optional structured `audio_bindings`; it still does not carry audio bytes.

Legacy schema v1 remains unchanged. Optional schema-v2 fields are validated independently and may be omitted for backwards compatibility. Audio-file bytes require a separate approved asset contract rather than overloading cue/binding metadata.

## Existing audio boundary

V2-1 timeline supports declarative `audio` events with a safe lowercase `cue` token. The default cue is `skill_cast`.

Current safety properties:
- cue values are normalized/validated as safe tokens;
- URL/path/code-like values fail closed;
- runtime Preview exposes timeline audio telemetry;
- no arbitrary filesystem path, URL, script, callback, decoder command, or user executable payload is accepted.

Before Work Unit 4, the remaining audio limitations were:
- no approved audio-file import contract;
- no package audio asset payload;
- no character-level/impact-level binding editor outside the existing skill timeline cue token.

WU4 addresses the semantic binding layer only. Approved audio bytes and real playback remain separate later work so file/codec validation does not get coupled to Creator binding semantics.

## Work Unit 1 — trusted animation-map authoring foundation

Scope:
1. Character Editor exposes the `animation_map` reference.
2. `CharacterDraft` validates both CharacterDefinition syntax and actual trusted-map resolution.
3. Safe but missing map IDs fail closed before Preview/export/import can mutate valid Creator state.
4. Creator Web telemetry exposes the authored animation-map ID.
5. Package export/import preserves the authored map reference using the existing schema.
6. Creator Preview proves the imported map actually loads in Training.
7. No arbitrary resource path or executable field is introduced.

Validation result:
- PR #162 product head `23c673be0fa6a58949849884b3d879b1186174ee` passed CI #413 (`35420773510`).
- Documentation-updated latest PR head `a7952ee28ffafdbfa210908503b62b82f3ff9f2f` passed CI #415 (`35422840793`).
- PR #162 squash-merged as `65489e41d66bed5af2eb44b3c2ad63222b240b78`.
- Main CI #416 (`35431205627`) final attempt passed Windows Native, Godot/domain/backend, Web/Chromium, hosted Edge, Pages/public reachability, Render exact-revision readiness, and production Edge full smoke on that exact SHA.
- Attempt 1 production Edge timed out only in unchanged Creator Preview `timeline-overlap-window` after WU1-specific animation/Creator coverage had passed. Exact-SHA targeted retry succeeded with no runtime changes, consistent with L-007.
- Production evidence includes `WEB_CHARACTER_ANIMATION_SMOKE_PASSED`, `WEB_CREATOR_STUDIO_SMOKE_PASSED ... animationMapAuthoring=true missingMapBlocked=true`, `WEB_CREATOR_PACKAGE_SMOKE_PASSED ... animationMapRoundTrip=true animationPreview=true missingAnimationMapBlocked=true`, and `SMOKE_SUITE_PASSED count=24`.
- Render readiness emitted `PRODUCTION_AI_BACKEND_READY ... revision=65489e41d66bed5af2eb44b3c2ad63222b240b78`.

## Work Unit 2 — per-semantic animation-map authoring + in-memory Preview

Scope:
1. `CharacterAnimationDraft` edits only the fixed required semantic vocabulary and safe animation ID tokens.
2. Character Editor exposes semantic selection + animation ID editing with live validation.
3. Creator Preview stages the validated map dictionary only when its ID matches `CharacterDraft.animation_map`.
4. Training Preview consumes the in-memory map through the existing `CharacterAnimationMap` parser and exposes runtime animation-ID telemetry.
5. Preview return preserves the semantic draft in session memory.
6. Failed map-ID or unsafe-token staging clears stale active override state.
7. Character Package schema remains unchanged in WU2; importing a package resets transient semantic edits to the package's trusted map reference so stale memory state cannot leak across package boundaries.
8. Character Package export reuses combined Character + animation-draft validation; invalid semantic animation state blocks export until corrected.

Safety:
- no arbitrary animation file/resource path;
- no URL or filesystem path;
- no script/callback/executable field;
- semantic names are fixed by `CharacterAnimationMap.REQUIRED_SEMANTICS`;
- animation IDs remain validated safe lowercase tokens.

Validation target:
- `CREATOR_CHARACTER_ANIMATION_DRAFT_TESTS_PASSED`;
- Creator Preview session domain coverage for valid override, map-ID mismatch and unsafe-token fail-closed cases;
- Chromium/hosted Edge Creator Studio semantic authoring regression;
- Chromium/hosted Edge Creator Preview runtime override + return regression;
- Character Package browser regression proving invalid semantic animation blocks export and transient semantic state resets on package import;
- standard Windows Native, Godot import/boot/domain/backend and Web export/size-budget gates.

## Work Unit 2 production validation

- PR #163 head `4183aa45eac248365c3efeab8f814965d1dac09c` passed PR CI #417 (`35444063803`).
- PR #163 squash-merged as `2111f3b27dfbd3fa0de8380fc72f3167ff4be461`.
- Main CI #418 (`35444847516`) attempt 3 passed the complete exact-SHA production chain, including hosted Edge, Pages/public reachability, Render revision readiness and production Edge `SMOKE_SUITE_PASSED count=24`.
- Attempts 1 and 2 exposed different unchanged hosted-Edge observation-window timeouts after feature-specific semantic animation coverage had passed; the same SHA passed without product changes on attempt 3, consistent with L-007.
- Render readiness confirmed `PRODUCTION_AI_BACKEND_READY provider=gemini model=gemini-3.6-flash billing_mode=free-tier-only revision=2111f3b27dfbd3fa0de8380fc72f3167ff4be461`.

## Work Unit 3 — self-contained package persistence for semantic animation mappings

Scope:
1. Keep legacy Character Package schema v1 unchanged.
2. Extend self-contained schema v2 with optional `animation_map` structured data.
3. Validate the payload exclusively through the existing `CharacterAnimationMap` contract and require its ID to match `character.animation_map`.
4. Canonicalize only the fixed required semantics and safe animation-ID tokens; reject unknown fields, paths, URLs and executable metadata.
5. Include the current validated semantic draft in Creator schema-v2 export.
6. On import, complete existing legacy character/skill compatibility first, then restore the packaged semantic map into Creator + Preview session state.
7. Preserve schema-v2 packages without `animation_map` and all legacy-v1 packages.
8. Prove domain round-trip/fail-closed behavior and Creator export → mutate → import → Training playable preservation in Chromium/Edge.

Validation target:
- `SELF_CONTAINED_CHARACTER_PACKAGE_TESTS_PASSED` with semantic animation package cases;
- Godot import/boot/domain suite;
- Creator Package Chromium/hosted-Edge regression with `semanticPackageRoundTrip=true`;
- full Web export/size budget and `smoke:all`;
- Windows Native export.

## Work Unit 3 production validation

- PR #165 latest head `48900734c095e5de0dc35690cebb9458f698ff76` passed PR CI #420 (`35446574026`).
- PR #165 squash-merged as `930e6bed3bdfaabc26495b2c6264f05ae14e201a`.
- Main CI #421 (`35452686079`) passed the complete production chain on that exact SHA: Windows Native, Godot/domain/backend/Web/Chromium, hosted Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Edge full smoke.

## Work Unit 4 — safe audio cue binding semantics

Scope:
1. Introduce a strict `CharacterAudioBindings` schema with exactly `ready`, `basic_attack`, `hit_received`, `skill_cast`, and `skill_impact`.
2. Restrict values to safe lowercase cue tokens; reject missing/unknown fields and path/URL/code-like values.
3. Add Creator fixed-binding + cue-token editing with live validation.
4. Stage validated bindings through Creator Preview and resolve semantic timeline cues such as `skill_cast` through the authored map.
5. Persist optional `audio_bindings` in self-contained schema-v2 packages without changing legacy schema v1.
6. Reset to safe defaults when importing older packages that contain no audio-binding payload.
7. Prove Creator authoring, Preview runtime resolution, package round-trip and tamper rejection in domain/Chromium/hosted-Edge coverage.
8. Keep raw audio files, decoders, URLs, filesystem paths and executable callbacks out of WU4.

Validation result:
- PR #166 head `22c41b662a5753d59f47a3cd44bd20e63cfc975c` passed PR CI #425 (`35457465896`).
- Windows Native, Godot import/boot/domain/backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all` all passed.
- Creator Studio proved safe/unsafe audio binding authoring; Creator Preview proved runtime `skill_cast` resolution plus serialized draft round-trip; Creator Package proved schema-v2 export/import, tamper rejection, and Training preservation.
- CI #422/#424 failures were limited to the browser test treating a transient selector row as persisted model state. The product/runtime state was already correct; L-034 records the correction and CI #425 validates it cross-browser.

## Work Unit 4 production closeout

- PR #166 squash-merged as `c326608f691129207d708cffbd339850308fedd6`.
- Main CI #428 hit two different unchanged hosted-Edge timing windows after the WU4 product coverage had already passed in Chromium.
- Test-only PR #167 hardened browser-side transient-state capture plus bounded Timeline observation timeouts; PR CI #429 passed Chromium + hosted Edge with no runtime/product changes.
- PR #167 squash-merged as `66190eff50b60d4a11a57a702fc175accaf58634`.
- Exact-main CI #430 (`35482812184`) passed the full production chain. Render reported exact revision `66190eff50b60d4a11a57a702fc175accaf58634`, and production Microsoft Edge finished `SMOKE_SUITE_PASSED count=24`.

## Work Unit 5 — bounded PCM WAV import + memory-only persistence

Scope:
1. Accept one Creator WAV asset bound to one existing fixed character-audio binding + safe cue token.
2. Require a safe `.wav` filename and canonicalize approved WAV MIME aliases to `audio/wav`.
3. Accept only RIFF/WAVE uncompressed PCM, mono/stereo, 8/16-bit, 8–48 kHz, ≤3 seconds, and ≤512 KB.
4. Validate RIFF length, chunk bounds, `fmt` and data chunks, PCM format code, byte rate, block alignment, complete PCM frames and derived duration.
5. Transfer browser-selected bytes as a bounded base64 data URL only; do not persist a local path, URL, decoder command, callback or script.
6. Store validated metadata + bytes only in `CreatorPreviewSession` memory and preserve them across Creator → Training Preview → Creator navigation.
7. Clear the stored WAV if its bound Cue ID changes, on Character reset, or after a successful Character Package import.
8. Keep invalid package imports non-mutating: an existing valid WAV remains intact when import validation fails.
9. Keep WU5 intentionally memory-only: do not add WAV bytes to Character Package schema v2 and do not play audio yet.

Validation result:
- PR #168 head `133633cc8491049d83a43fdd30fe6335b939bbfa` passed PR CI #431 (`35485169214`).
- Windows Native, Godot import/boot/domain/AI contracts, backend tests, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all` all passed.
- Domain tests emitted `CHARACTER_AUDIO_ASSET_DRAFT_TESTS_PASSED`; CreatorPreviewSession coverage proved valid WAV storage and tampered-byte fail-closed clearing.
- Creator Studio proved real base64 PCM WAV import, cue-change stale clearing and reset clearing. Creator Preview proved Creator → Training → Creator memory round-trip. Creator Package proved WU5 remains memory-only, invalid imports preserve the current WAV, and successful package import clears it.

## Work Unit 5 production closeout

- PR #168 latest head `a8d9ca8c2f264c97b2120943ce622c7c7d7ef716` passed PR CI #433 (`35485758758`).
- PR #168 squash-merged as `c5f7e68e919aa0be111c167696757722bf061c80`.
- Exact-main CI #434 (`35493570174`) passed Windows Native, Godot/domain/backend/Web/Chromium, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.

## Work Unit 6 — bounded WAV Character Package transport

Scope:
1. Extend schema-v2 with one optional `audio_asset` containing validated WU5 metadata plus bounded WAV base64; do not create an unbounded audio collection.
2. Reuse `CharacterAudioAssetDraft` metadata and PCM byte validation instead of creating a second decoder/parser path.
3. Require the packaged WAV binding/Cue ID to exactly match packaged `audio_bindings`; reject orphaned or mismatched audio payloads.
4. Keep package transport declarative: no filesystem/resource path, URL, script, callback, decoder command, native library or compressed audio.
5. Raise the Creator JSON package ceiling from 256 KB to a bounded 8 MB so the existing ≤5 MB decoded VFX asset plus one ≤512 KB WAV can coexist after base64 expansion.
6. Export the stored validated WAV and restore it through the existing CreatorPreviewSession validation boundary on successful import; invalid imports must preserve the current valid draft/WAV.
7. Add deterministic package-domain and Chromium/hosted-Edge Creator Package coverage for valid round-trip, malformed/tampered bytes, binding mismatch and unknown-field rejection.
8. Keep WU6 transport-only. Runtime WAV playback is a separate follow-up slice.

Validation result:
- PR #169 implementation head `665d1965a23c9dbe7b33fd7eba8e3cf225e2da1d` passed PR CI #435 (`35494696068`).
- Windows Native, Godot import/boot/domain/AI contracts, trusted backend, Web export/size budget, Chromium `smoke:all`, and GitHub-hosted Microsoft Edge `smoke:all` all passed.
- Character Package domain coverage validates deterministic WAV round-trip, binding dependency/mismatch, tampered RIFF/WAVE bytes, and unknown-field rejection.
- Creator Package browser coverage proves a real authored WAV is serialized into schema-v2, restored after successful import, preserved across invalid imports, and rejected when packaged bytes are tampered.

## Work Unit 6 production closeout

- PR #169 latest head `a6886daa27519346fd8d4f10f342e1939ccac50a` passed CI #436; one unchanged hosted-Edge Buff observation failed on attempt 1 and passed on the exact same SHA when only the failed Edge gate was retried.
- PR #169 squash-merged as `2335ef2351409d8e023f0884a2e55b176d45781c`.
- Exact-main CI #437 (`35497667643`) passed Windows Native, Godot/domain/backend/Web/Chromium, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.

## Work Unit 7 — Creator Preview runtime WAV playback

Scope:
1. Stage one validated stored WAV into active Creator Preview only when its fixed binding/Cue ID exactly matches active authored `audio_bindings`.
2. Revalidate staged metadata + bytes at Training runtime before loading the WAV.
3. Use Godot's in-memory `AudioStreamWAV.load_from_buffer()` and an `AudioStreamPlayer`; do not introduce filesystem/resource paths, URLs, external decoders, scripts, callbacks or native libraries.
4. Preserve the declarative timeline contract: an `audio` event resolves through `CharacterAudioBindings`, and playback occurs only if that resolved Cue ID exactly equals the staged WAV's Cue ID.
5. Expose deterministic runtime telemetry for WAV active/loaded state, Cue ID, byte count, load error, playback count and last-played Cue.
6. Add PreviewSession coverage for valid active staging and binding/Cue mismatch rejection.
7. Extend Creator Preview Chromium/hosted-Edge regression so the imported WAV is runtime-loaded before the cast and the authored `skill_cast` timeline event increments playback telemetry.
8. Keep WU7 narrow: only existing timeline-driven playback is added. Broader ready/basic-attack/hit/skill-impact triggers are deferred.

Validation result:
- PR #170 implementation head `a4289662a94be4423d389f45e5d86c5dad5d6380` passed PR CI #438 (`35498848537`), and latest PR head `f79402ed3d2b94f1d8a47fa67a885b900d074fd3` passed PR CI #440.
- PR #170 was squash-merged as `0ecbbcdd5b6439bf8d4ae50d184b349cd1fea495`.
- Main CI #441 reproduced two different unchanged hosted-Edge observation windows after WU7 playback coverage had passed, so L-007 required a test-only timing-stability correction rather than product changes.
- PR #171 head `7ff377a4b759933286c8bb69d88f2da0efc051b0` passed PR CI #443 (`35507350929`) on attempt 1 and was squash-merged as `6d1c40878cd8988a6d27e8438c402ba706c020cd`.
- Exact-main CI #444 (`35509107038`) passed Windows Native, Godot/domain/backend/Web/Chromium, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production Edge proved `wavRuntimePlayback=true` and completed `SMOKE_SUITE_PASSED count=24`; Render readiness matched exact revision `6d1c40878cd8988a6d27e8438c402ba706c020cd`.
- WU7 is accepted and production-validated.

## Work Unit 8 — basic-attack WAV runtime trigger

Scope:
1. Reuse the one validated/staged WU7 WAV and the existing fixed `CharacterAudioBindings` contract; do not add a second asset, unbounded collection, filesystem/resource path, URL, external decoder, script, callback or native library.
2. Observe only authoritative accepted normal-attack steps in Creator Preview and map them to the fixed `basic_attack` binding.
3. Resolve `basic_attack` through the authored binding map and play only when its Cue ID exactly equals the staged WAV Cue ID.
4. Consume each attack step once so one accepted J attack cannot repeatedly retrigger playback across frames.
5. Preserve WU7 timeline-driven `skill_cast` behavior unchanged.
6. Extend Creator Preview Chromium/hosted-Edge regression to prove both WU7 `skill_cast` WAV playback and a second Preview cycle where J triggers `basic_attack → preview_attack_custom`.
7. Keep `ready`, `hit_received`, and `skill_impact` runtime triggers deferred. Treat `ready` separately because automatic playback can interact with browser autoplay policy.

Validation result:
- PR #172 implementation head `35715e9437983cea55b6a2014b16a4210630a541` passed PR CI #445 (`35510295745`) on attempt 1.
- Latest PR head `df0fe77a625dce634cb538d44df0289c10400d3f` passed PR CI #447 (`35511016768`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium and hosted Edge.
- PR #172 was squash-merged as `a2e348c83c2db03c0bd2cef0466382854e3a097a`.
- Exact-main CI #448 (`35512384893`) passed Windows Native, Godot/domain/backend/Web/Chromium, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production Edge proved `wavRuntimePlayback=true basicAttackWavRuntimePlayback=true` and completed `SMOKE_SUITE_PASSED count=24`; Render readiness matched exact revision `a2e348c83c2db03c0bd2cef0466382854e3a097a`.
- WU8 is accepted and production-validated.

## Work Unit 9 — skill-impact WAV runtime trigger

Validation result:
- PR #173 implementation head `44f3101ff66524b39ce26eb955c4a2f1dee900c1` passed PR CI #449 (`35516777928`).
- Latest PR head `63bacdf39b44fad51f1ba64fe5d7542ec209f1ac` passed PR CI #451 (`35517485178`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium and hosted Edge.
- PR #173 was squash-merged as `920ca4a237999856b8e06cf5fbb28b4c88cd4521`.
- Exact-main CI #452 (`35518658940`) passed Windows Native, Godot/domain/backend/Web/Chromium, hosted Microsoft Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- Production Edge proved `wavRuntimePlayback=true basicAttackWavRuntimePlayback=true skillImpactWavRuntimePlayback=true` and completed `SMOKE_SUITE_PASSED count=24`; Render readiness matched exact revision `920ca4a237999856b8e06cf5fbb28b4c88cd4521`.
- WU9 is accepted and production-validated.

## Work Unit 10 — hit-received WAV runtime trigger

Scope:
1. Reuse the same validated/staged single WAV and fixed audio-binding contract; do not add another asset slot, path/URL loading, external decoder, native library, script, callback or executable payload.
2. Reuse the authoritative `receive_player_hit(...)` boundary rather than inventing a second damage/impact path.
3. Delegate to the parent boundary first and request `hit_received` playback only when the returned dealt damage is greater than zero.
4. Therefore Counter-intercepted, zero-damage, defeated-state and otherwise rejected hits remain silent for the hurt cue.
5. Resolve fixed `hit_received` through the authored binding map and retain exact staged-WAV Cue matching as the final playback gate.
6. Extend Creator Preview Chromium/hosted-Edge regression with a fourth Preview cycle: bind/import `hit_received → preview_hit_custom`, require the constrained Training incoming-hit bridge, deal 9 real damage, verify authoritative incoming-hit/damage telemetry plus WAV playback, then return to Creator.
7. Preserve WU7 `skill_cast`, WU8 `basic_attack` and WU9 `skill_impact` behavior unchanged.
8. Keep `ready` deferred because automatic playback still requires deliberate browser autoplay-policy handling.
9. Use only the synchronous `receive_player_hit(...)` override as the event owner. Do not also poll incoming-hit counters for playback; the duplicate polling path found during branch reconciliation was removed by `d78ede0e93b266e0708f92d3b582d5af01290ef0` to prevent double emission.

## Deferred after WU10

- creator-provided animation asset import;
- animation asset packaging/self-contained transport;
- `ready` playback trigger with browser autoplay-safe semantics;
- final V2-3 cross-machine/self-contained acceptance.

V2 progress remains **25% (2/8 phases complete)** until the entire V2-3 acceptance criterion is satisfied and synchronized.
