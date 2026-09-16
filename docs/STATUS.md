# Project Status

## Current phase

**V1/MVP is complete; V2 roadmap is now active.**

- V1 completion remains **100% (13/13 phases complete)**.
- V2 completion remains **0% (0/8 phases complete)** until an entire V2 phase meets acceptance.
- Active V2 phase: **V2-1 Advanced Creator Timeline**.

V1 roadmap:
- M0–M8 MVP: 9/9 complete.
- P1 Safe real-provider boundary: complete.
- P2 Async remote AI transport: complete.
- P3 Production AI provider/backend integration: complete.
- P4 Image → skill proposal → Creator → Training production flow: complete.

V2 roadmap is defined in `docs/V2_ROADMAP.md` and captures previously discussed/deferred capabilities outside the V1 acceptance boundary.

## V2 roadmap

1. V2-1 Advanced Creator Timeline — **in progress**.
2. V2-2 Extended Skill Families — pending.
3. V2-3 Character Animation & Audio Authoring — pending.
4. V2-4 AI Opponents & Single-player Gameplay — pending.
5. V2-5 Game Modes, Balance & Competitive Foundation — pending.
6. V2-6 Network PvP — pending.
7. V2-7 Creator Sharing Ecosystem — pending.
8. V2-8 Mobile Targets — pending.

V2-1 includes visual event timeline authoring, startup/active/recovery timing, animation/VFX/audio events, hitbox/hurtbox timing and spatial editing, safe multi-event compositions, validation, and Creator → Training preview.

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

Work unit 4 is synchronized on branch `feat/v2-1-spatial-hitbox-authoring` and PR #139:
- `hitbox` and `hurtbox` timeline events now normalize safe spatial payloads: `half_width`, `half_depth`, `offset_x`, and normalized-arena `offset_depth`.
- Spatial dimensions/offsets are bounded and fail closed when zero/negative or outside safe limits; older V2 spatial events that omitted these payload fields remain backwards compatible through safe defaults.
- Creator Timeline exposes type-specific spatial controls only for hitbox/hurtbox events and removes stale spatial fields when an event changes back to a non-spatial type.
- Creator draft/domain tests cover spatial round-trip, deep-copy isolation, backwards-compatible defaults, invalid dimensions and oversized offsets.
- Browser regression covers hitbox/hurtbox authoring, invalid-dimension fail-closed recovery, stale-payload cleanup, deterministic ordering, removal and clear.

V2-1 is not complete yet: type-specific animation/VFX/audio payload controls, runtime timeline event execution and Creator → Training timeline acceptance remain.

## V1 production acceptance checkpoint

P3 was accepted on 2026-09-16. Production Free Gemini E2E Run #4 (`35061328085`) passed real text and reference-PNG requests on exact revision `c5d36b7c9d6f7befa506d70798b0d00fef526e4e`, with Gemini 3.6 Flash, Free Tier guards, trusted Render credential isolation, structured VFX/skill output and deterministic Sharp PNG rendering.

P4 was accepted on 2026-09-16. Production Free Gemini E2E Run #5 (`35075099182`) completed successfully on exact revision `a572b0a3e60e377ae9152592c6d8c62e574a8554` and emitted `PRODUCTION_CREATOR_GEMINI_E2E_PASSED provider=gemini revision=a572b0a3e60e377ae9152592c6d8c62e574a8554 reference=true proposal=true confirmPreview=true cast=true damage=18`.

The V1 completion documentation was merged by PR #131; the V1 completion checkpoint on `main` is `ff744f643b37cc1947225ef4dbe052108d739a66`.

V2 roadmap activation PR #132 was merged to `main` at `41c047029175e4b1409fcd2f49e023332e5663e7`; Main CI #285 (`35084613478`) completed successfully, including Chromium, Windows Native, Microsoft Edge, Pages deployment, production public-Web checks, Render exact-revision readiness and production Edge smoke.

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

Validate PR #139 in GitHub CI. If it passes, merge the spatial hitbox/hurtbox authoring checkpoint, then add type-specific animation/VFX/audio timeline payload controls before runtime event execution and Creator → Training timeline acceptance.
