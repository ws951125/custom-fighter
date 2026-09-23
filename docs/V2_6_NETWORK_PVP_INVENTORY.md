# V2-6 Network PvP — Architecture Inventory

## Purpose

V2-6 turns the V2-5 competitive trust boundary into a two-client network match without allowing either browser/client to become combat authority.

Acceptance remains:

> Two supported clients can complete an authoritative online match using validated custom characters without either client controlling authoritative damage/cooldown state.

## Repository inventory at V2-6 start

Existing reusable foundations:
- `competitive_hosted` already declares `host_authoritative`.
- `CompetitiveLoadoutSnapshotBuilder` derives authority-owned normalized character/skill values and a deterministic SHA-256 content fingerprint.
- `CompetitivePowerBudgetValidator` enforces `competitive_standard_v1`.
- `CompetitiveRuntimeAuthority` proves a runtime can materialize combat values from an admitted authority snapshot rather than raw Creator/client values.
- `match_flow_main.gd` already owns match win/loss/restart state for local runtime.
- character package formats are declarative/validated and prohibit arbitrary executable content.
- GitHub CI already validates Godot domain logic, Web export, Chromium, Windows native and hosted Microsoft Edge.

Missing at V2-6 start:
- no lobby/session state machine;
- no network message contract;
- no network transport;
- no authoritative remote simulation service;
- no client network adapter/UI;
- no input/state synchronization;
- no reconnect/forfeit flow;
- no network custom-package negotiation;
- no two-client online regression harness.

The existing `backend/server.mjs` is an AI/VFX HTTP service and is not treated as gameplay authority.

## Trust boundary

Client may propose:
- session/client identity tokens;
- desired validated character ID/package reference;
- ready/not-ready intent;
- monotonic input intents using the existing action vocabulary.

Client must never author:
- authoritative character/loadout snapshot;
- content fingerprint;
- HP/MP;
- damage;
- cooldown;
- position;
- hit result;
- combat state;
- match result.

Authority owns:
- competitive admission and snapshot/fingerprint derivation;
- authoritative simulation tick/state;
- movement/combat resolution;
- HP/MP and cooldown mutation;
- hit confirmation;
- victory/defeat;
- reconnect/forfeit result.

Transport must remain replaceable. WU1 deliberately defines protocol/session semantics without coupling them to a deployment provider or socket implementation.

## Work Unit 1 — protocol + session authority contract

Implemented on branch `feat/v2-6-wu1-network-authority-contract`:
- `NetworkProtocolDefinition` freezes `network_pvp_v1@1`.
- client message surface is limited to `join_session`, `set_ready`, and `input_intent`.
- current gameplay actions are allow-listed as intents: movement, run/jump, basic attack, dash, guard, and Skill 1–13.
- unknown fields and authority-owned fields fail closed.
- input sequence/client tick must be bounded non-negative integers; duplicate actions and unknown actions fail closed.
- `NetworkSessionState` supports a deterministic two-player lobby and authoritative start gate.
- session admission derives each built-in character snapshot/fingerprint through `CompetitiveLoadoutSnapshotBuilder`; a client cannot supply its own fingerprint or combat snapshot.
- input intent admission is allowed only after both admitted players are ready and the authority starts the match.
- per-client input sequence must be strictly monotonic.
- public session state exposes only bounded summaries, never the internal authority snapshot.
- `tests/network_protocol_session_test_runner.gd` covers the trust boundary, exact Ember/Storm fingerprints, readiness/start gating, capacity, ruleset mismatch, forged combat fields, and stale sequence rejection.

WU1 intentionally does not open a socket or add user-facing lobby UI.

## Planned bounded sequence

### Work Unit 2 — authoritative match service core
- deterministic server tick contract;
- authority-owned match state snapshot/delta format;
- bind admitted session players to authoritative combat state;
- no transport dependency.

### Work Unit 3 — network transport adapter
- secure WebSocket-compatible transport boundary;
- session create/join/ready message routing;
- disconnect/error handling;
- no peer/client authority fallback.

### Work Unit 4 — Web client lobby + network adapter
- create/join lobby UI;
- ready/cancel-ready;
- network mode router entry;
- client sends only validated intents.

### Work Unit 5 — authoritative combat synchronization
- input sequencing/tick processing;
- server-authoritative movement/combat results;
- bounded state snapshots;
- latency-safe rendering without accepting client damage/cooldown.

### Work Unit 6 — validated custom-package negotiation
- safe package metadata/content negotiation;
- authority-side package validation and competitive budget admission;
- deterministic compatibility fingerprint agreement;
- no arbitrary executable package content.

### Work Unit 7 — reconnect / forfeit / latency handling
- bounded reconnect token/session restoration;
- disconnect grace policy;
- explicit forfeit and timeout result;
- deterministic stale/out-of-order packet rejection.

### Work Unit 8 — two-client phase acceptance
- two supported Web clients complete one authoritative online match;
- validated custom characters admitted;
- Chromium/hosted Edge regression where technically applicable;
- neither client can alter authoritative damage/cooldown/match result.

## Validation policy

All V2-6 engineering validation remains GitHub/online-only. No Remote Desktop Commander, local Godot, local browsers, or user-machine terminal is part of formal validation.

Until a deployed multiplayer service exists, transport-dependent items must remain explicitly pending rather than being simulated as production success.
