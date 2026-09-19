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

Validation target:
- Creator CharacterDraft domain tests;
- Creator Studio Chromium/hosted-Edge regression;
- Character Package Chromium/hosted-Edge export/import/Preview regression;
- existing Godot import/boot, package, animation, Web export and browser gates.

## Deferred after WU1

- per-semantic animation mapping editor rather than map-reference selection;
- creator-provided animation asset import;
- animation asset packaging/self-contained transport;
- approved audio-file import;
- skill/impact/character audio binding UX;
- audio asset packaging/runtime playback binding;
- final V2-3 cross-machine/self-contained acceptance.

V2 progress remains **25% (2/8 phases complete)** until the entire V2-3 acceptance criterion is satisfied and synchronized.
