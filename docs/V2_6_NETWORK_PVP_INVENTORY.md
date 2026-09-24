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

Planned:
- validate supported built-in/custom package inputs on the server side;
- mint or resolve the authoritative competitive snapshot/fingerprint from trusted package data;
- keep gameplay values out of client authority;
- reject unknown schema/registry/type/ruleset/budget combinations.

### Work Unit 3 — authoritative input/tick/state model

Planned:
- bounded input-intent envelope;
- monotonic input sequence numbers;
- authoritative server tick;
- deterministic participant state snapshots;
- client state is presentation/prediction only, never final combat authority;
- duplicate/out-of-order input handling.

### Work Unit 4 — network transport + Web client integration

Planned:
- WebSocket or equivalent duplex transport behind the session service;
- lobby create/join/ready/start messages;
- authenticated connection-to-client binding appropriate to the current product scope;
- browser integration for two supported clients;
- transport error handling without weakening authority.

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
- Clients submit bounded action intents with monotonic sequence numbers and a small future tick window; unknown fields/actions, stale sequences, and invalid target ticks fail closed.
- Server state owns position, HP, MP, guard state, cooldowns, hit resolution, damage and match winner. Client-provided combat facts are not accepted by the input schema.
- Basic attack/cooldown/guard behavior is intentionally minimal in WU3; it establishes authority semantics before WU4 transport/Web integration and is not yet a claim of full Godot combat parity.
- Deterministic backend regression covers movement, sequence/tick rejection, forged combat fields, server cooldown, server guard mitigation and immutable snapshots.
- V2 remains 62.5% (5/8) until complete V2-6 acceptance.
