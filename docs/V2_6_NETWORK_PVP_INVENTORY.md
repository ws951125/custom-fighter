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

Status: **implementation active on `feat/v2-6-wu4-websocket-web-client`; online validation pending**.

Implementation scope:
- RFC-6455 WebSocket transport at `/v1/pvp/ws` behind the existing session/authority services;
- exact-field allow-listed hello/create/join/admit/ready/start/input/state messages;
- allow-listed browser Origin plus server-issued per-connection token and socket-bound client identity; reconnect identity is deliberately deferred to WU5;
- trusted server loadout resolution for WU3 initial HP/MP using WU2-admitted/fingerprint-matched content;
- `competitive_hosted` Godot Web lobby/client UI for two supported clients;
- two-browser Chromium/hosted-Edge regression covering lobby, authority admission, ready/start, synchronized server state and bounded input;
- transport errors fail closed without creating any client-authored combat-state path.

### Work Unit 5 — reconnect / forfeit / latency handling

Planned:
- bounded reconnect window;
- reconnect token/session binding;
- explicit forfeit/leave semantics;
- disconnect timeout;
- latency/heartbeat handling;
- deterministic terminal match result.

### Work Unit 6 — full two-client online acceptance

Planned cross-browser/online proof:
- two supported clients join one lobby;
- both negotiate validated custom characters;
- both become ready and start;
- input/state synchronization completes a real authoritative match;
- reconnect/forfeit path is covered;
- attempted client-authored damage/cooldown is rejected;
- Chromium and hosted Edge online regression evidence is synchronized.

## Progress rule

V2 remains **62.5% (5/8 phases complete)** throughout partial V2-6 work. It advances to **75% (6/8)** only after the complete V2-6 acceptance criterion passes and evidence is synchronized.


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
- Required validation: backend transport regression, existing backend/domain gates, Web export/size, two-client network smoke in Chromium and hosted Edge. Production WSS remains a post-merge gate and is blocked whenever the existing Render service is unavailable.
