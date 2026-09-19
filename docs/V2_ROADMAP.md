# Custom Fighter — V2 Roadmap

## Baseline

V1/MVP remains complete at **100% (13/13 phases)**. V2 does not reopen or reduce that completion percentage.

V2 captures previously discussed or explicitly deferred product capabilities that were not part of the V1 acceptance boundary. V2 progress is tracked independently.

## V2 progress

**25% (2/8 phases complete)** as of 2026-09-19.

## V2-1 — Advanced Creator Timeline — complete

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

Acceptance evidence:
- Work units 1–7 were merged through PRs #133, #134, #135, #139, #141, #142, and #143.
- PR #143 merged to `main` as `383c5969697c323c368ca80d13c61b4595ed3978` after latest-head PR CI #333 (`35170327643`) passed Godot import/boot/domain/backend tests, Web export/size budget, Chromium `smoke:all`, Windows Native Release, and GitHub-hosted Microsoft Edge `smoke:all`.
- Main CI #334 (`35171731664`) then passed the complete production chain on that exact revision: Windows Native, Godot/domain/backend/Web/Chromium, hosted Microsoft Edge, GitHub Pages deployment, public-Web reachability, Render exact-revision readiness, and production Microsoft Edge full smoke.
- The Creator browser regression authors animation, VFX, audio, hitbox, and hurtbox timeline events without code, launches Training, validates timed runtime/media/spatial behavior and legacy projectile damage, waits for timeline cleanup, and round-trips back to Creator with the authored events preserved.

## V2-2 — Extended Skill Families — complete

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

Acceptance evidence:
- Creator authoring/Preview foundation was production-validated through PRs #145 and #146.
- Beam, Trap, Aura, Teleport, Counter, safe scripted event compositions, Grab, and Summon were completed through PRs #147, #148, #150, #152, #154, #156, #158, and #160.
- Final PR #160 latest head `23eff68188dca878877209ffe92d3fd3e1e40938` passed PR CI #409 (`35407714816`), including Windows Native, Godot/domain/backend/Web/Chromium and hosted Microsoft Edge.
- PR #160 squash-merged to `main` as `5502bbc9b31725488d34e3614c495fe2ad47d85d`.
- Main CI #410 (`35410123320`) passed the complete production chain on that exact revision: Windows Native, Godot/domain/backend/Web/Chromium, hosted Edge, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Edge full smoke.
- The final deployed regression covers thirteen families and reports `summonPolicy=bounded-actor-single-hit`, timeline dispatch/round-trip success, and `SMOKE_SUITE_PASSED count=24`.
- All added families remain data-driven and bounded; safe compositions expand only into allow-listed declarative events, and no arbitrary user code/runtime callback/path is executed.

## V2-3 — Character Animation & Audio Authoring — active

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

## Next implementation target

Start **V2-2 Extended Skill Families**. Begin with a repository/architecture inventory of the existing six V1 skill families and the shared V2 timeline/event primitives, then define the first safe declarative family slice and its acceptance tests before implementation.
