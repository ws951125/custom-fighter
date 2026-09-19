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

Character Package already serializes `character.animation_map` in its canonical character shape. Self-contained package schema v2 currently adds only an optional validated PNG VFX asset; it does not embed animation-map JSON or audio bytes.

Therefore Work Unit 1 does not require a package-schema version bump. The first safe slice can prove animation-map reference authoring and package round-trip using trusted repository animation maps. Later V2-3 work may extend the self-contained asset schema when creator-imported animation/audio assets are introduced.

## Existing audio boundary

V2-1 timeline supports declarative `audio` events with a safe lowercase `cue` token. The default cue is `skill_cast`.

Current safety properties:
- cue values are normalized/validated as safe tokens;
- URL/path/code-like values fail closed;
- runtime Preview exposes timeline audio telemetry;
- no arbitrary filesystem path, URL, script, callback, decoder command, or user executable payload is accepted.

Current limitation:
- there is no approved audio-file import contract;
- there is no package audio asset payload;
- there is no character-level/impact-level audio binding editor outside the existing skill timeline cue token.

Those remain later V2-3 work and must not be conflated with WU1.

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
- Character Package browser regression proving transient semantic reset on package import;
- standard Windows Native, Godot import/boot/domain/backend and Web export/size-budget gates.

## Deferred after WU2

- Character Package persistence/round-trip for custom semantic animation mappings;
- creator-provided animation asset import;
- animation asset packaging/self-contained transport;
- approved audio-file import;
- skill/impact/character audio binding UX;
- audio asset packaging/runtime playback binding;
- final V2-3 cross-machine/self-contained acceptance.

V2 progress remains **25% (2/8 phases complete)** until the entire V2-3 acceptance criterion is satisfied and synchronized.
