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

## Deferred after WU4

- creator-provided animation asset import;
- animation asset packaging/self-contained transport;
- approved audio-file import with bounded MIME/codec/size validation;
- audio asset packaging and runtime playback;
- broader character/basic-attack/hit/impact playback triggers backed by approved assets;
- final V2-3 cross-machine/self-contained acceptance.

V2 progress remains **25% (2/8 phases complete)** until the entire V2-3 acceptance criterion is satisfied and synchronized.
