# V2-6 Network PvP Inventory

## Phase goal

Support player-versus-player matches over the network without trusting player-authored combat state.

Phase acceptance from `docs/V2_ROADMAP.md`:

> Two supported clients can complete an authoritative online match using validated custom characters without either client controlling authoritative damage/cooldown state.

## Authority boundary

The network transport is not the combat authority.

Clients may submit:
- identity/session intent,
- bounded input intent,
- character/package identity,
- package schema version,
- content fingerprint.

Clients must not author authoritative:
- damage,
- MP cost,
- cooldown,
- HP/MP totals,
- hitbox/hurtbox gameplay values,
- match winner/result,
- authoritative tick/state.

Any client message that attempts to smuggle unsupported combat-state fields must fail closed before authority admission.

## Work units

### Work Unit 1 — session/lobby + authority admission contract

Status: **implemented; required PR validation passed on implementation head**.

Deliverables:
- transport-neutral two-player lobby lifecycle;
- host/create/join semantics;
- server-owned loadout admission callback;
- exact allow-list for client loadout claims;
- immutable server authority summaries;
- ready/start gates;
- authority-contract compatibility check before match start;
- no WebSocket/UI yet.

Validation: PR #197 implementation head `c0831496552bd95104333b19abd60643103777f5` passed CI #566 (`35862684985`): Windows Native, Godot/domain/AI, trusted backend including the WU1 session contract test, Web export/size, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.

Current client loadout claim is intentionally narrow:
- `character_id`
- `content_fingerprint`
- `package_schema_version`

The server authority adapter must return the admitted character/fingerprint plus protocol, authority policy, package schema, ruleset/version and power-budget identity. A mismatch fails closed.

### Work Unit 2 — server-side package authority admission

Status: **merged to `main` by PR #198 as `a46e9f253d61e610beee450a7abd82c56a01e214`**.

Delivered:
- validate supported built-in/custom package inputs on the server side;
- mint/resolve the authoritative competitive identity/fingerprint from trusted package data;
- keep gameplay values out of client authority;
- reject unknown schema/registry/type/ruleset/budget combinations.

### Work Unit 3 — authoritative input/tick/state model

Status: **merged to `main` by PR #200 as `110f86fe7490b86f539589861834100c49877db8`**. PR latest-head CI #581 passed all required PR gates; exact-main CI #582 passed all product/Pages gates and was red only on the pre-existing external Render HTTP 503 readiness blocker.

Delivered:
- bounded exact-allow-list input-intent envelope;
- safe monotonic input sequence numbers plus strictly monotonic bounded future target ticks;
- deterministic 60 Hz authoritative server tick;
- trusted server-side loadout resolution for initial HP/MP;
- deterministic detached participant state snapshots with source-object identity isolation;
- server-owned movement, guard, cooldown, hit/damage and terminal winner/draw state;
- phase-ordered same-tick movement/guard plus simultaneous damage application;
- duplicate/out-of-order/stale/unsafe input handling and forged combat-field rejection;
- client state remains presentation/prediction only, never final combat authority.

### Work Unit 4 — network transport + Web client integration

Status: **merged to `main` by PR #201 as `ecb82b34f800d273b9d71fc6c4d295c7acb63e6d`**. Exact-main CI #588 passed all product/Pages gates and was red only on the pre-existing external Render HTTP 503 readiness blocker.

Implementation scope:
- RFC-6455 WebSocket transport at `/v1/pvp/ws` behind the existing session/authority services;
- exact-field allow-listed hello/create/join/admit/ready/start/input/state messages; browser input carries only sequence + actions while the server schedules the bounded authoritative target tick;
- allow-listed browser Origin plus server-issued per-connection token and socket-bound client identity; reconnect identity is deliberately deferred to WU5;
- trusted server loadout resolution for WU3 initial HP/MP using WU2-admitted/fingerprint-matched content;
- `competitive_hosted` Godot Web lobby/client UI for two supported clients;
- two-browser Chromium/hosted-Edge regression covering lobby, authority admission, ready/start, synchronized server state and bounded input;
- transport errors fail closed without creating any client-authored combat-state path.

### Work Unit 5 — reconnect / forfeit / latency handling

Status: **merged to `main` by PR #202 as `0570d53e08950350da6e50d75473aa334fda347c`**. Product behavior was PR-validated by CI #590/#591; exact-main product gates passed in CI #592. The external Render 503 blocker was subsequently closed by PR #203 and exact-main CI #595.

Implementation scope:
- 10-second bounded reconnect window with server-issued reconnect token kept only in client process memory;
- reconnect restores lobby/match binding and rotates the ordinary connection token;
- explicit waiting-lobby leave with deterministic host promotion;
- explicit active-match forfeit plus disconnect-timeout automatic forfeit;
- application heartbeat/pong, authenticated last-seen watchdog and browser RTT telemetry;
- deterministic terminal snapshot fields: winner, forfeited client and result reason;
- Chromium/hosted-Edge regression that disconnects and reconnects the real Godot Web client before completing a forfeit path.

### Work Unit 6 — full two-client online acceptance

Status: **complete — PR #204 merged to `main` as `26563016e986126dde4104f8093d6ec3cbaa9a01`; exact-main CI #598 (`36206515990`) attempt 2 passed the complete GitHub Pages + Render production WSS acceptance suite**.

Acceptance implementation:
- two server-trusted declarative custom packages (`creator_blaze_001`, `creator_frost_001`) resolve through the existing custom-package validator and deterministic fingerprint authority path;
- two supported browser clients join one lobby, negotiate those custom packages, ready and start;
- a diagnostic-only browser bridge attempts to inject client-authored `damage` + `cooldown`; transport must fail closed with `INPUT_INTENT_FIELDS_INVALID` and preserve authoritative HP/cooldown;
- clients synchronize movement into range and complete a real authoritative combat finish rather than ending only by forfeit;
- existing WU5 smoke in the same suite continues to cover disconnect/reconnect + explicit forfeit;
- Chromium and hosted Edge run the combined acceptance on PRs;
- after merge, Windows Edge Production Full Smoke runs the same suite against GitHub Pages + Render production WSS.

## Progress rule

V2-6 is **complete**. V2 is now **75% (6/8 phases complete)**; the next active phase is V2-7 Creator Sharing Ecosystem.

## V2-6 WU6 production acceptance (2026-09-26)
- PR #204 was squash-merged to `main` as `26563016e986126dde4104f8093d6ec3cbaa9a01` after explicit approval.
- Render auto-deploy `dep-darhf8ou01pc73e7526g` reached `live` on that exact revision.
- Main CI #598 attempt 1 passed the WU6 production acceptance itself: two server-trusted custom characters joined one lobby, forged client combat state was rejected with `INPUT_INTENT_FIELDS_INVALID`, movement synchronized and combat finished server-authoritatively with `result_reason=combat`.
- A later unchanged Creator AI skill-proposal smoke missed a 6-second hosted-Edge observation window at line 103. Same-SHA attempt 2 passed the complete workflow without any product/test/timeout change, consistent with L-043.
- Final gates: Windows Native PASS; Godot/domain/backend PASS; Chromium `smoke:all` PASS; hosted Edge `smoke:all` PASS; GitHub Pages deploy/public reachability PASS; Render exact-revision readiness PASS; Windows Edge Production Full Smoke PASS.


## V2-6 WU2 — server-side package authority admission (2026-09-24)
- Added a server-owned PvP package authority adapter for built-in and bounded custom loadouts.
- Built-in competitive characters are admitted only when the client claim matches the server-frozen V2-5 fingerprint.
- Custom package admission fails closed on unsupported schema/ruleset/budget, unknown fields, unresolved skill slots/types, duplicate skills, and bounded combat-value violations.
- The client fingerprint is equality evidence only: the server resolves and validates trusted package data, computes the authoritative fingerprint, and never accepts client damage/cooldown as authority.
- Backend regression coverage is wired into the existing trusted-backend CI gate; no extra browser process/job is added.
- V2 remains 62.5% (5/8) until full V2-6 acceptance.


## V2-6 WU3 — authoritative input/tick/state model (2026-09-24)
- Added a deterministic 60 Hz server-owned match simulation boundary for exactly two admitted participants.
- Client intents require safe monotonic sequence numbers and strictly increasing bounded future target ticks; unknown fields/actions, unsafe sequences and stale/out-of-order target ticks fail closed.
- A required trusted `loadoutResolver` materializes authoritative initial HP/MP from admitted authority data; invalid/out-of-range resolution fails closed and no client-authored HP/MP is accepted.
- Match and participant identity is captured at construction; duplicate/empty participants are rejected and later source-object mutation cannot rewrite authoritative snapshots.
- Server state owns position, HP/MP, guard state, cooldowns, hit resolution, damage, match status and winner/draw result.
- Same-tick resolution is phase-ordered and order-independent: movement/guard for all accepted intents, then hit computation, then simultaneous damage application. Mutual lethal damage produces a draw rather than a client-ID-order winner.
- Basic attack/cooldown/guard behavior remains intentionally minimal in WU3; full duplex transport and Web client integration remain WU4.
- Regression coverage includes trusted stat materialization, resolver fail-closed behavior, identity/source isolation, safe sequence limits, target-tick monotonicity, forged combat fields, movement/range/cooldown, guard mitigation, simultaneous lethal draw and detached snapshots.
- Final WU3 product head `d4ee2560dc08b6a9e4e93120ce5591f42e2768a5` passed PR CI #580 (`35947039184`) across Windows Native, Godot/domain/backend, Web export/size budget, Chromium `smoke:all`, and hosted Microsoft Edge `smoke:all`.
- PR #199 was closed unmerged as superseded by PR #200.
- V2 remains 62.5% (5/8) until complete V2-6 acceptance.


## V2-6 WU4 implementation checkpoint (2026-09-24)
- Branch: `feat/v2-6-wu4-websocket-web-client`, based on WU3 merge `110f86fe7490b86f539589861834100c49877db8`.
- Node backend gains `/v1/pvp/ws` using the MIT `ws` package. HTTP health reports PvP protocol/path/authority metadata without changing the existing AI readiness contract.
- Connection binding is intentionally session-scoped in WU4: validated client ID + server-generated token are bound to the live socket; duplicate live client IDs, wrong tokens, unexpected fields, bad Origin, unsupported message types and wrong lobby/match binding fail closed.
- WU4 does not implement reconnect tokens, forfeit/disconnect timeout or heartbeat/latency policy; those remain WU5.
- Godot `competitive_hosted` exposes a user-visible lobby/client scene and server-authoritative intent controls. It does not reuse the local competitive runtime as combat authority.
- Validation: PR #201 head `b5ecef0bf364e3e629148e12c29621128f1696a0` passed CI #586 (`35970648404`) across Windows Native, Godot/domain/backend, Web export/size, Chromium two-client Network PvP and hosted Edge two-client Network PvP. Production WSS remains a post-merge exact-main gate and is blocked whenever the existing Render service is unavailable.


## V2-6 WU5 implementation checkpoint (2026-09-24)
- Branch: `feat/v2-6-wu5-reconnect-forfeit-latency`, based on WU4 merge `ecb82b34f800d273b9d71fc6c4d295c7acb63e6d`.
- Reconnect identity uses a dedicated random server-issued token distinct from the per-socket connection token. Reconnect tokens are memory-only and are never emitted to browser datasets.
- Server disconnect handling starts the reconnect deadline only when the live socket actually closes. Reconnect within the window restores lobby/match state; timeout finalizes an active match with `disconnect_timeout`.
- Explicit `forfeit` and timeout finalization use the same authoritative match terminal-state method so client ordering cannot determine the winner.
- Heartbeat is application-level because browser WebSocket APIs do not expose protocol control-frame ping/pong. Any authenticated message refreshes last-seen; explicit ping/pong supplies RTT telemetry to the client.
- Waiting-lobby leave is a session-service operation and never mutates active lobbies; active players must use forfeit.
- Validation: PR #202 product head `fe186699a3f0da60312d94811974b0b5ec5b3834` passed CI #590 (`36024400048`) across Windows Native, Godot/domain/backend, Web export/size, Chromium two-client reconnect/forfeit flow and hosted Edge equivalent.
- CI #589 failed only on the intentional browser close code 1001; L-051 records the correction to browser-valid application code 3001 and #590 verifies it.


## V2-6 WU6 implementation checkpoint (2026-09-25)
- Base: production-validated main `e613356c4de12f07d1cde36043177ead162dc2dd`; CI #595 closed the previous production backend blocker and passed full production Edge smoke.
- Trusted custom package fingerprints are frozen alongside server-owned package data; a client fingerprint is equality evidence only and cannot replace package validation.
- The default production resolver returns detached copies from a closed server catalog. Unknown custom IDs resolve to null and fail admission.
- WU6 browser acceptance uses distinct client IDs from WU5 smoke so production reconnect-session residue cannot alias the next test.
- Combat acceptance verifies both custom character IDs and server materialized HP, rejects forged damage/cooldown, synchronizes position, respects server cooldowns between attacks, and requires `result_reason=combat` with the losing HP at zero.
- Final V2-6 progress must stay 62.5% until exact-main production acceptance passes and evidence is synchronized.


## V2-6 WU6 PR validation checkpoint (2026-09-25)
- PR #204 product head `4dd6c8dcc9cd696cfffab45532db02b7ffd8db6c` passed CI #596 (`36143393328`).
- Windows Native: PASS.
- Godot/domain/backend: PASS, including `PVP_TRUSTED_PACKAGE_CATALOG_TESTS_PASSED`.
- Web export/size: PASS.
- Chromium `smoke:all`: PASS, including WU5 reconnect/forfeit and WU6 custom-package authoritative combat acceptance.
- Hosted Microsoft Edge `smoke:all`: PASS with the same WU5 + WU6 coverage.
- PR production/deploy jobs are intentionally skipped. Final WU6 acceptance still requires the exact-main Windows Edge Production Full Smoke against GitHub Pages + Render production WSS after merge.
