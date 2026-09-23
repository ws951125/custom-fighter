# Custom Fighter — V2 Roadmap

## Baseline

V1/MVP remains complete at **100% (13/13 phases)**. V2 does not reopen or reduce that completion percentage.

V2 captures previously discussed or explicitly deferred product capabilities that were not part of the V1 acceptance boundary. V2 progress is tracked independently.

## V2 progress

**50% (4/8 phases complete)** as of 2026-09-22.

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

## V2-3 — Character Animation & Audio Authoring — complete

Goal: make a complete character package authorable inside Creator.

Scope:
- character animation mapping/editor UX,
- animation preview and validation,
- approved audio import,
- skill/impact/character audio binding,
- package-safe asset validation,
- package import/export round-trip for the new assets.

Acceptance: a creator can author character animation/audio mappings, export them, import the package elsewhere and preserve the playable result.

Acceptance evidence:
- Work Units 1–14 established safe semantic animation authoring, strict audio cue bindings, bounded Animation PNG and PCM WAV import, schema-v2 package transport, runtime Animation PNG rendering, timeline/basic-attack/skill-impact/hit-received WAV triggers, and browser-autoplay-safe `ready` WAV playback.
- PR #178 merged WU14 to `main` as `831f3ec7f322e7b023cca0c0874b1f217d355a24`; exact-main CI #486 (`35563876523`) passed the complete production chain and Render exact-revision readiness.
- Final acceptance PR #179 extends the fresh-session package regression so one schema-v2 package carries VFX PNG + character Animation PNG + validated basic-attack WAV.
- PR #179 CI #487 (`35566219175`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- Hosted Edge proved `embeddedWav=true secondSessionWavRestored=true wavRuntimePlaybackAfterImport=true` together with `secondSessionAnimationPngRestored=true animationPngRuntimeRendering=true animationPngRuntimeFrameAdvance=true`, existing VFX cast/damage behavior, and `SMOKE_SUITE_PASSED count=24`.
- PR #179 latest head `3ef6df3f97c91cfb558ac2ab890c036931276d9e` passed PR CI #490 (`35568941052`) and squash-merged to `main` as `f4910ba1357157d41d371926cf75e61a94f0be00`.
- Exact-main CI #491 (`35572244642`) attempt 2 passed the complete production chain on that revision: Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Edge `smoke:all`, GitHub Pages deployment/public reachability, Render exact-revision readiness, and production Microsoft Edge full smoke. Attempt 1's production-Edge-only timeout occurred after the new fresh-session Animation PNG/WAV acceptance assertions and passed on same-revision retry without code changes.
- No arbitrary executable/resource path was added; all imported assets remain bounded, validated and declarative.

## V2-4 — AI Opponents & Single-player Gameplay — complete

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

Architecture checkpoint:
- `docs/V2_4_AI_SINGLE_PLAYER_INVENTORY.md` inventories the existing Training/Match authority and defines the bounded implementation sequence.
- Existing `match_flow_main.gd` remains authoritative for victory/defeat/restart/return.
- Existing `receive_player_hit(...)` remains the formal opponent→player damage boundary.
- Work Unit 1 implements the bounded `OpponentBehaviorProfile`, allow-listed built-in profiles and pure deterministic `OpponentDecisionState` intent layer. PR #181 merged as `323e86a5445f6049f2b20ba788af2d373abc7b5b`; exact-main CI #503 (`35602570478`) passed the complete production chain.
- Work Unit 2 adds explicit router mode `single_player`, activates the deterministic opponent only in that mode, reuses existing movement/combat authority, routes successful opponent damage through `receive_player_hit(...)`, preserves passive ordinary Training, and keeps match defeat/restart/return authority in the existing match flow.
- PR #182 CI #506 (`35605738012`) passed Windows Native, Godot/domain/AI contracts, backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`; PR #182 then squash-merged to `main` as `c548cfb3c0e53d2b1170205c1f1948889845db22`.
- Exact-main CI #508 attempt 2 passed Chromium `smoke:all`, Windows Native, hosted Edge `smoke:all`, GitHub Pages deployment and public reachability. Full backend-dependent production acceptance remains blocked because the external Render AI backend returned HTTP 503 for all readiness attempts; production Edge full smoke was therefore skipped.
- Work Unit 3 adds a third bounded `training_cautious` profile plus stable Easy/Normal/Hard labels, a user-facing single-player `AI Difficulty` selector, allow-listed URL/runtime profile selection, deterministic policy-difference coverage and browser proof that difficulty does not change authoritative opponent damage. PR #183 merged to `main` as `1ae941dec82788a219073c831ebd36b657fd058d`; exact-main CI #511 validated Windows Native, Chromium, hosted Edge (same-SHA retry), Pages deployment and public reachability, while the external Render backend remained HTTP 503.
- Work Unit 4 adds a strict declarative `StageDefinition` and built-in `StageRegistry` for bounded arena margin, normalized spawns/depth and allow-listed presentation tokens. Unknown/executable-style fields, unsafe IDs and arbitrary paths/URLs fail closed. PR #184 passed latest-head CI #513 and merged to `main` as `681f4ee8d84567ad963c669b90b0f1f92a11df21`; exact-main CI #514 then passed Windows Native, Chromium, hosted Edge, Pages deployment and public reachability, while external Render readiness remained HTTP 503.
- Work Unit 5 wires validated stage selection into single-player: router-owned `stage_id`, bounded Stage selector, stage-specific arena/spawn/presentation runtime application, dynamic arena bounds for movement/Teleport/Grab/Summon, and Chromium/Edge regression for selection/fail-closed/persistence/passive-Training isolation. PR #185 CI #520 and final latest-head CI #524 passed the required PR gates; PR #185 then squash-merged to `main` as `26bf2a7ac845b90b715f216e9c207cd1e8e3b3af`. Exact-main CI #525 passed Windows Native, Chromium, hosted Edge, Pages deployment and public reachability while external Render readiness remained HTTP 503.
- Work Unit 6 extends the active-opponent regression into the final acceptance path: default-stage loss/restart, selectable Sunset Court + Cautious active-AI victory using normal J inputs, restart with stage/profile/spawn persistence, return-to-Creator, and passive ordinary-Training isolation. CI #526 exposed an unpublished-Web-telemetry predicate defect; commit `0b649b307352494b94b8fe5321d12a2666903081` fixed the acceptance test only. PR #186 CI #528 then passed Windows Native, Godot/domain/backend, Chromium and hosted Edge with `playerDefeat=true playerVictory=true victoryStage=sunset_court victoryRestartPreserved=true returnCreator=true` and `SMOKE_SUITE_PASSED count=25`.
- PR #186 latest-head CI #532 (`35711354905`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge on head `184b6caf2447550bf4e8c28426a48f100830c890`; PR #186 then squash-merged to `main` as `e6ce72c4ed675b519808a05184089c19edc0500b`.
- Exact-main CI #533 (`35714388530`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, hosted Microsoft Edge `smoke:all`, GitHub Pages deployment, and public-Web reachability on the exact merge revision. The external Render AI backend independently remained HTTP 503 for all 18 readiness attempts, so backend-dependent production Edge full smoke was skipped.
- V2-4 is accepted complete on the deployed exact-main Web artifact. The Render provider/backend outage remains a residual risk outside the backend-independent single-player acceptance. V2 advances to **50% (4/8)** and V2-5 becomes active.

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

Architecture checkpoint:
- `docs/V2_5_GAME_MODES_BALANCE_COMPETITIVE_INVENTORY.md` defines the V2-5 trust boundary before runtime implementation.
- Existing character/skill/package validation remains the safety/schema layer; competitive eligibility is an additional deterministic ruleset/power-budget decision.
- Proposed competitive admission derives an authority-owned loadout snapshot from validated content rather than trusting raw authored/client values.
- Future clients may propose packages and input intents, but authority computes damage, HP/MP, cooldowns, hit results, state transitions and match result.
- Ruleset ID/version and deterministic content compatibility/fingerprinting are explicit foundations for V2-6.
- WU1 intentionally defers numeric balance weights until deterministic fixtures, hard-cap boundaries and monotonicity tests are defined.
- PR #188 latest-head CI #537 passed Windows Native, Godot/domain/backend, Web/Chromium and hosted Microsoft Edge on head `00c4cfca869b26b09f17a7b2cc9fd3940a73a94d`; PR #188 then squash-merged to `main` as `c829175a4e84e0ee2b6cceef7f360e380444eefd`.
- Exact-main CI #538 (`35726723857`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium, hosted Edge, Pages deployment and public reachability. External Render readiness remained HTTP 503 for all 18 attempts, so backend-dependent production Edge full smoke was skipped as the existing provider/backend residual risk.
- WU2 implements strict declarative `GameModeDefinition` / `CompetitiveRulesetDefinition` contracts plus deterministic allow-listed registries. Sandbox/single-player policy remains local-authoritative and separate from competitive `competitive_standard_v1`; unknown fields, unsafe/unknown policy references and ruleset-version mismatches fail closed.
- WU2 intentionally does not wire the new policy layer into `main_router.gd`, so current user-facing Training/Creator/VFX/Single-player behavior remains unchanged while the competitive authority contract is established.
- PR #189 latest-head CI #539 (`35728595324`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium and hosted Microsoft Edge on head `3249164d205b7614a057c293c7e824a8748d07d4`; PR #189 then squash-merged to `main` as `b939a3380a535511648d97af2056ec39b1eba246`.
- Exact-main CI #540 (`35733671081`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium, hosted Edge, GitHub Pages deployment and public reachability. External Render readiness remained HTTP 503 for all 18 attempts, so backend-dependent production Edge full smoke was skipped as the existing provider/backend residual risk.
- WU3 implements `CompetitivePowerBudgetValidator` for `competitive_standard_v1` with narrower hard caps plus deterministic integer character/skill/loadout scores, stable diagnostics, repeated-slot aggregate accounting and no authored-data mutation.
- Reference fixtures freeze Ember Vanguard at character score `2683` / total `15649` and Storm Duelist at `2787` / `15426`; boundary and monotonicity regressions guard future policy edits.
- PR #190 final head `3624eed4a1b166f44975a146d06dd14a827342b1` passed required PR CI #544 (`35743432893`) and was explicitly approved/squash-merged to `main` as `ec68a7ef73464846594b7447c9b447c7917ed253`. Exact-main CI #545 (`35808407510`) passed Windows Native, Godot/domain/backend, Web export/size budget, Chromium, hosted Edge, GitHub Pages deployment and public reachability; the external Render AI backend returned HTTP 503 for all 18 readiness attempts, so backend-dependent production Edge full smoke was skipped as the existing provider/backend residual risk.
- WU4 implements `CompetitiveLoadoutSnapshotBuilder`: authority-side ruleset + registry resolution, WU3 budget admission, normalized authoritative character/skill values, gameplay-only timeline spatial events and a versioned SHA-256 compatibility fingerprint over recursively canonicalized content.
- WU4 fails closed on ruleset/version mismatch, noncompetitive rulesets, registry resolution failures and budget rejection; it never accepts a client-authored authoritative snapshot.
- WU4 tests freeze deterministic reference snapshots/fingerprints, canonical key-order independence, presentation-only exclusion and combat-value fingerprint sensitivity; required CI executes the new runner.
- PR #192 initial head `2699f8f1e2a7dffc50710a783e80c51cf478ca52` passed Windows Native, Godot/domain/backend, Web export/size budget and Chromium in CI #547 (`35809096254`). Hosted Edge attempt 1 hit the existing `creator_package_vfx_web_smoke.mjs:252` U/MP observation timeout; targeted same-SHA Edge retry passed the complete suite in attempt 2 without product/test changes.
- Planned sequence after WU4: WU5 local competitive authority path; WU6 cross-browser phase acceptance.
- WU5 implements the local competitive authority path: `competitive_local` router support, fingerprint-validated authority snapshot materialization, authority-registry reload, raw Creator combat-override blocking, fail-closed rejection and competitive-mode restart preservation.
- WU5 domain regression proves forged runtime targets cannot bypass admitted HP/MP/damage/cooldown values, wrong local/host authority mode fails closed, unknown characters are rejected, and post-admission snapshot tampering invalidates runtime materialization.
- WU5 browser regression is part of shared Chromium/hosted-Edge `smoke:all`; PR #193 implementation head `9a4c13905fa4307de929f94de952c1896ddb11a0` passed CI #556 (`35815833880`) and docs-sync head `e3999e785a9d540c5a1e032474a9fe40ac0ca3ae` passed CI #557 (`35817088723`). PR #193 was explicitly approved and squash-merged to `main` as `5204a3f8a04beada0e21eac1a238ee2286bfbc66`.
- Exact-main CI #558 (`35818795131`) passed all backend-independent product gates, Chromium/hosted Edge, Pages deployment and public reachability; only the existing external Render AI backend readiness failed after 18 HTTP 503 responses.
- WU6 adds the final V2-5 acceptance contract: sandbox-safe/competitive-over-budget separation, frozen ruleset/version fail-closed checks, exact deterministic reference fingerprints, direct authority HP/damage/MP/cooldown materialization, and the same acceptance assertions in the shared Chromium/hosted-Edge browser stage. PR validation is pending.
- V2 remains **50% (4/8)** until the complete V2-5 acceptance criterion is satisfied.

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

Validate **V2-5 Work Unit 6 — full cross-browser phase acceptance**. If required PR gates pass, accept V2-5 and advance to **V2-6 — Network PvP**.
