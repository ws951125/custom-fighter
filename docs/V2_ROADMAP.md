# Custom Fighter — V2 Roadmap

## Baseline

V1/MVP remains complete at **100% (13/13 phases)**. V2 does not reopen or reduce that completion percentage.

V2 captures previously discussed or explicitly deferred product capabilities that were not part of the V1 acceptance boundary. V2 progress is tracked independently.

## V2 progress

**0% (0/8 phases complete)** at roadmap creation.

## V2-1 — Advanced Creator Timeline

Goal: turn Creator Studio from basic parameter authoring into a complete no-code combat-content authoring tool.

Scope:
- visual event timeline with ordered/timed events,
- startup / active / recovery editing on the timeline,
- animation event placement,
- VFX spawn / impact events,
- audio events,
- hitbox / hurtbox timing and spatial editing,
- multi-event skill compositions,
- validation for invalid/unsafe timelines,
- Creator → Training preview round trip.

Acceptance: a non-programmer can build and preview a multi-stage skill with animation, hitbox, VFX and audio timing without editing code.

## V2-2 — Extended Skill Families

Goal: extend the data-driven skill engine beyond the six V1 families.

Scope:
- summon,
- grab,
- counter,
- teleport,
- trap,
- beam,
- aura,
- scripted event compositions using safe declarative events only.

Acceptance: each family has a data definition, runtime implementation, Creator authoring path, deterministic tests and Web/Edge smoke coverage; no arbitrary user code is executed.

## V2-3 — Character Animation & Audio Authoring

Goal: make a complete character package authorable inside Creator.

Scope:
- character animation mapping/editor UX,
- animation preview and validation,
- approved audio import,
- skill/impact/character audio binding,
- package-safe asset validation,
- package import/export round-trip for the new assets.

Acceptance: a creator can author character animation/audio mappings, export them, import the package elsewhere and preserve the playable result.

## V2-4 — AI Opponents & Single-player Gameplay

Goal: move beyond Training dummy validation into an actual playable combat loop.

Scope:
- AI opponent controller,
- difficulty/behavior profiles,
- stage definitions,
- stage selection,
- single-player/sandbox match flow,
- win/loss/restart/return flow,
- regression tests for combat against active opponents.

Acceptance: deployed Web build supports a complete single-player match against an active AI opponent on selectable stage content.

## V2-5 — Game Modes, Balance & Competitive Foundation

Goal: provide the safety/balance boundary needed before competitive play.

Scope:
- game-mode definitions,
- sandbox rules,
- validated skill/character power budget,
- authored-stat validation and normalization,
- host/server-authoritative combat design boundary,
- anti-trust boundary for player-authored damage/cooldown values,
- deterministic rules/version compatibility checks.

Acceptance: competitive-mode content cannot bypass the validated power budget and the architecture does not trust client-authored combat authority.

Note: this phase establishes the competitive foundation; full network PvP is V2-6.

## V2-6 — Network PvP

Goal: support player-versus-player matches over the network without trusting player-authored combat state.

Scope:
- session/lobby lifecycle,
- compatible character-package negotiation,
- authoritative match state,
- input/state synchronization,
- reconnect/forfeit handling,
- latency/error handling,
- online match regression coverage.

Acceptance: two supported clients can complete an authoritative online match using validated custom characters without either client controlling authoritative damage/cooldown state.

## V2-7 — Creator Sharing Ecosystem

Goal: complete the original portable/shareable creator vision beyond local package files.

Scope:
- publish character/skill packages,
- browse/search creator content,
- package metadata and versioning,
- download/import flow,
- compatibility/security validation before install,
- creator/gallery view,
- safe update/revision handling.

Acceptance: one user can publish a safe character package and another user can discover, download, validate, import and play it without exchanging files manually.

## V2-8 — Mobile Targets

Goal: extend the platform-neutral runtime to the deferred mobile targets.

Scope:
- Android build/export path,
- iOS/iPadOS build/export path where CI/signing constraints permit,
- mobile/touch combat UX,
- responsive Creator strategy (full editor where practical, reduced workflow where necessary),
- mobile package import/export compatibility,
- platform-specific performance/size validation.

Acceptance: supported mobile targets can run the core combat loop and load compatible V2 character packages; platform limitations and signing/deployment requirements are documented and validated through available online infrastructure.

## Deferred optional provider work

The architecture previously allowed a future local/open-model AI provider such as ComfyUI. It is intentionally **not a required V2 completion phase** because the current product cost policy requires free Gemini production AI and V1 already has a working provider boundary. A local provider can be added later without coupling runtime gameplay to AI availability.

## Progress rules

- V1 stays 100% and is never reduced by V2 work.
- V2 starts at 0/8 and advances only when an entire phase meets its acceptance criteria and its evidence is synchronized to GitHub.
- Partial work is reported inside the active phase but does not count as a completed V2 phase.
- Every implementation work unit must be committed/pushed before being reported as completed.
- Formal validation remains GitHub/online-only under the existing `AGENTS.md` policy.
- Errors and durable fixes continue to be recorded in `docs/LESSONS_LEARNED.md`.
- `docs/STATUS.md` must identify the active V2 phase while preserving the V1 completion checkpoint.

## First implementation target

Start with **V2-1 Advanced Creator Timeline** because it closes the largest remaining Creator-product gap and supplies reusable event/timing infrastructure for several V2-2 skill families.