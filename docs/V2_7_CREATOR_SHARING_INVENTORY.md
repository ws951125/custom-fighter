# V2-7 Creator Sharing Ecosystem — Inventory and Architecture Freeze

Date: 2026-09-26  
Base main: `6d06639b9c1ceea859dcf1c58a35cd7dbb9d93cb`

## Purpose

Freeze the existing package/sharing boundary and the minimum safe sequence for V2-7 before product implementation. V2 remains **75% (6/8 phases complete)** until the full V2-7 acceptance criterion passes.

V2-7 acceptance remains:

> One user can publish a safe character package and another user can discover, download, validate, import and play it without exchanging files manually.

## Current package capability

### Runtime/package formats

- `CharacterPackageDefinition` is the legacy/core package contract:
  - schema version **1**;
  - required `package_id`, `package_version`, character and skills;
  - `package_id` must match character ID;
  - strict top-level and skill allow-lists;
  - safe lowercase reference tokens;
  - referenced skills must resolve exactly;
  - no arbitrary executable content.
- `SelfContainedCharacterPackageDefinition` is the current Creator transport contract:
  - current schema version **2**;
  - legacy schema-v1 import compatibility;
  - optional validated `animation_map`, Animation PNG, `audio_bindings`, WAV and VFX PNG;
  - malformed/oversized/unknown/mismatched assets fail closed;
  - embedded asset bytes are decoded and validated before becoming runtime state.
- Creator package JSON is bounded by `MAX_PACKAGE_JSON_BYTES = 16 MiB`.
- `package_version` already exists and must be at least 1, but Creator export currently emits version **1** and there is no update/revision workflow.

### Current Creator UX

`game/creator/package_creator_studio.gd` provides:

- **Export Package** — validates Creator state, serializes the package and downloads `<package_id>.custom-fighter.json`;
- **Import Package** — opens a Web JSON file picker, enforces the package size boundary, validates the package, checks Creator compatibility, restores drafts and refreshes Creator state;
- Web bridge functions for export/import and package-file errors.

`package_vfx_creator_studio.gd` extends this flow to self-contained schema v2 with optional animation/audio/VFX assets.

The current flow is therefore **manual file exchange only**.

## Existing trust boundaries that V2-7 must preserve

1. Player-created content stays declarative. Publishing/downloading must never introduce GDScript, executables, native libraries, shell/Python code or arbitrary script execution.
2. A downloaded package is never trusted merely because the catalog returned it. The full package must pass the existing package validator again before import/apply.
3. Catalog metadata is display/search data only. It must never override character/skill/runtime fields inside the validated package.
4. Browser-supplied identifiers, fingerprints, author IDs or compatibility claims are not authority.
5. PvP trust remains a separate boundary. Publishing a Gallery package must **not** automatically make it a server-trusted competitive package. Competitive admission continues through the V2-6 server authority/fingerprint/ruleset/power-budget path.
6. Package payloads remain lazy-loaded/on-demand so user content is not bundled into the core GitHub Pages PCK.

## Current backend/infrastructure inventory

The Render backend currently exposes:

- `GET /healthz`;
- `POST /v1/vfx/generate`;
- `WS /v1/pvp/ws`.

There is currently:

- no sharing/catalog HTTP API;
- no publish endpoint;
- no browse/search endpoint;
- no package download endpoint;
- no persistent catalog/object storage adapter;
- no publisher-auth/identity adapter;
- no Supabase or other storage integration in this repository.

The existing backend body reader is capped at **8 MiB**, which is lower than the Creator package ceiling. A future sharing upload route must use its own bounded **16 MiB** body policy without widening unrelated VFX routes.

## Missing sharing metadata

The current package carries runtime identity/version data but not Gallery metadata. V2-7 needs a separate server-derived publication manifest rather than adding untrusted Gallery fields into the runtime package.

Frozen manifest-v1 public fields:

- `manifest_schema_version` — 1;
- `publication_id` — server-owned stable publication identity;
- `package_id`;
- `package_version`;
- `package_schema_version`;
- `revision` — server-assigned immutable revision number;
- `content_sha256` — server-derived digest of the stored package payload/canonical publication bytes;
- `byte_size` — server-derived;
- `title` — plain text, 1–80 chars;
- `description` — plain text, max 500 chars;
- `tags` — max 8 lowercase safe tokens, each max 24 chars;
- `publisher_id` — opaque server-owned public publisher identifier;
- `created_at` / `updated_at` — server-owned timestamps.

Rules:

- no HTML/Markdown execution;
- no arbitrary URLs in manifest v1;
- title/description/tags never participate in runtime authority;
- search indexes only bounded manifest metadata;
- `content_sha256`, byte size, schema/version and timestamps are derived/validated server-side, never trusted from request JSON.

## Frozen revision/update semantics

- `publication_id` is stable for one publisher + package identity.
- Every accepted content change creates an immutable server-assigned `revision = previous + 1`.
- `package_version` may stay the same only when the uploaded content digest is identical; same package version with a different digest is rejected.
- `package_version` must never decrease for an existing publication.
- Re-uploading the exact same digest is idempotent and must not create duplicate revisions.
- Download URLs/API responses identify an exact revision; Gallery "latest" resolves to the latest accepted revision.
- Old revisions remain addressable for deterministic compatibility/rollback testing unless a later moderation/deletion policy explicitly marks them unavailable.

## Frozen service boundaries

### Client / Creator

Creator is responsible for:

- building the existing self-contained package;
- sending bounded publication metadata plus the package payload;
- browsing/searching manifest data;
- downloading an exact revision;
- re-running the existing package validator before applying downloaded content;
- showing validation/import failure without mutating the current valid draft.

Creator is **not** responsible for assigning publication IDs, revisions, digests, publisher identity or trust.

### Sharing backend

The Render sharing API will be responsible for:

- authenticating/resolving a publisher through an adapter boundary;
- validating publication metadata;
- validating the full self-contained package before persistence;
- deriving digest/byte size/schema/version/package identity;
- applying immutable revision rules;
- persisting package bytes and manifest atomically through a repository/storage adapter;
- serving bounded browse/search metadata;
- serving exact package revisions.

Until a production publisher-identity adapter is configured, publish must fail closed; public read-only browsing can remain independently available.

### Persistence

V2-7 must use a provider-neutral repository/storage interface:

- metadata/catalog store;
- package-object store;
- publisher identity adapter.

Production persistence must be durable and **no-cost/free-tier** under the project cost policy. No provider is silently selected in this inventory work unit. Provider credentials remain server-side and never enter Git or browser storage.

## Work-unit sequence

### Work Unit 1 — inventory + architecture freeze

Status: **complete; merged by PR #206 and exact-main validated by CI #603**.

- inventory existing package/Creator/backend boundaries;
- freeze manifest v1;
- freeze revision/update semantics;
- freeze client/server/trust boundaries;
- freeze the implementation sequence below.

Acceptance: repository docs describe an implementation-ready sharing contract without weakening existing package/PvP security.

### Work Unit 2 — publication manifest + sharing domain service

Status: **complete and merged by PR #207 to main `5ff4dfcd5b8ff4e330a7873ad36852f7f085554f`; latest PR CI #605 succeeded. Exact-main push-run evidence is not currently observable through the available connector and remains residual evidence risk.**

Implemented provider-neutral backend domain logic for:

- metadata validation;
- full package validation adapter;
- server-derived SHA-256 / byte size;
- immutable revision/idempotency rules;
- repository interface;
- deterministic unit tests with an in-memory test repository only.

Current WU2 implementation:
- `backend/sharing/publication_service.mjs`: manifest-v1 metadata validation, canonical package bytes, SHA-256/byte size derivation, stable publication identity, immutable revisions, optimistic revision expectations and fail-closed validator/repository boundaries.
- `backend/sharing/in_memory_publication_repository.mjs`: deterministic in-memory repository used only for regression tests.
- `tests/sharing_publication_service_test.mjs`: revision/idempotency/security/adapter regression coverage wired into `test:backend`.
- PR #207 CI #604 (`36221329852`) passed the sharing backend regression plus Windows Native, Godot/domain, Web export/size budget, Chromium and hosted Microsoft Edge gates on implementation head `6e44a3e0ff4a3e74b163768038e8d17bb225195a`.

No public production persistence claim in WU2. No HTTP route or Creator Gallery UI is introduced in this work unit.

### Work Unit 3 — HTTP catalog contract

Status: **implementation complete and PR-validated on head `90ab7ea354fb2ce488f7320414ab8ac82c689d90`; PR #208 CI #607 (`36225607371`) passed all required PR gates; awaiting latest-head docs-sync validation and explicit merge approval**.

Implemented bounded Render API routes:

- `POST /v1/sharing/publications` — publish;
- `GET /v1/sharing/publications` — bounded browse/search;
- publication latest detail + revision inventory;
- exact revision manifest;
- exact immutable package download.

Contract details:

- existing Origin allow-list remains authoritative;
- publication request body has an independent 16 MiB cap; VFX remains independently capped at 8 MiB;
- browser payloads cannot provide publisher identity; identity comes only from an injected server-side adapter;
- Publish requires an explicit durable-repository configuration flag and fails closed when durable persistence, publisher authentication or package validation is unavailable;
- browse/search indexes manifest metadata only, never package runtime content;
- exact revision download returns the immutable canonical package bytes stored for that revision;
- read/write failures have stable 400/401/404/405/409/413/503 error-code contracts;
- `tests/sharing_http_api_test.mjs` is wired into the existing backend CI gate.
- PR #208 implementation head `90ab7ea354fb2ce488f7320414ab8ac82c689d90` passed CI #607 (`36225607371`), latest docs-sync head `668d13ad7b04ff2678c4bc7484c8f99a3a8ab5f6` passed CI #609 (`36226449934`), and PR #208 was squash-merged as `27874d5a830a2a529bd03fe710875e75095882c0`.
- Render deploy `dep-darnbru7bikc739g9ie0` reached `live` on that exact merge SHA. Main-push GitHub Actions evidence remains unobservable through the current connector.

No durable production repository or production publisher-identity provider is claimed in WU3; those are implemented/configured in Work Unit 4.

### Work Unit 4 — durable free-tier persistence + publisher identity

Status: **server adapters/schema/validator merged via PR #210 as main `a154e748662d66305938fb81202234a03c4ffea5`; latest-head CI #626 succeeded; exact-SHA Render deploy `dep-daroec7f3r2c73a8tgkg` is live. Production Supabase provider/schema/keys and cross-user durable acceptance remain unprovisioned, blocked pending separate user authorization; main-push GitHub Actions evidence is unobservable through the current connector.**.

Current implementation:

- `backend/sharing/supabase_publication_repository.mjs`: server-only durable repository adapter over bounded Supabase RPCs;
- `backend/sharing/supabase_publisher_resolver.mjs`: authenticated publisher identity from Supabase Auth `/auth/v1/user` only; browser metadata is not trusted;
- `backend/sharing/supabase_integration.mjs`: all-or-nothing environment configuration; incomplete configuration remains fail-closed;
- `backend/sharing/self_contained_package_validator.mjs`: independent Node validation of the current package v1/v2 safety contract before persistence;
- `backend/sharing/supabase_schema.sql`: reviewed RLS-enabled append-only publication/revision schema + atomic RPC contract, not automatically applied;
- WU4 security review hardened the new-key headers (`sb_secret_` only via `apikey`), SQL SHA-256/byte parity, 128 MiB aggregate package quota under transactional locking, literal metadata query semantics and HTTP 507 quota contract;
- `tests/supabase_sharing_adapter_test.mjs` and `tests/self_contained_package_validator_test.mjs`: deterministic backend coverage wired into `test:backend`;
- `docs/V2_7_SUPABASE_SHARING_SETUP.md`: no-cost/server-secret deployment contract.

Production activation still requires an explicitly approved dedicated no-cost Supabase project and server-side credentials. Existing unrelated projects are not reused or modified automatically. No paid service is permitted.

### Work Unit 5 — Creator Gallery UX

Status: **read-side Gallery slice implemented on PR #212 (`feat/v2-7-wu5-creator-gallery-browse`), exact previous HEAD `d560192cd59320c29b5add24db6cfaee44270750` passed CI #638 (`36234225075`) in both Chromium and hosted Edge, including all 29 smoke stages. The reconciled HEAD `6320229e25fe600458a79c524432b22b138422d0` independently passed exact-head CI #640 (`36236310673`), with all three required jobs SUCCESS and Chromium/Edge `CREATOR_GALLERY_BROWSER_SMOKE_PASSED`; PR remains unmerged. Production persistence/auth and manual UI/UX acceptance are not yet complete.**

Delivered in this slice:
- Creator Gallery overlay with metadata browse/search, cursor pagination, publication detail and immutable revision selector;
- explicit download/import confirmation; 16 MiB byte bound, manifest UTF-8 byte-size and SHA-256 parity, existing Self-contained Package validation before Creator import;
- no automatic competitive/PvP trust, no catalogue-driven draft mutation; unavailable/invalid/tampered responses fail closed;
- Publish is visibly disabled until separately authorized dedicated free provider plus trusted user sign-in;
- hosted Chromium/Edge regression covers 503 unavailable, browse/detail, exact revision and tampered download rejection;
- branch-side WU5 hardening binds revision manifest's package/publisher identity to the selected publication, and binds SHA-verified downloaded package ID/version/schema back to the immutable manifest before Creator draft mutation. Cross-package and wrong-version mock responses fail closed; implementation SHA `ca54a980f5b3a49af7904dbda95fce89dc556749` passed CI #646 (`36256148248`) on attempt 2, with Chromium/Edge `manifestEnvelopeBound=true`, `paginationBounded=true` and 29 stages. Unchanged Network PvP hosted Edge first-attempt timeout cleared on same-SHA failed-job retry.

Remaining: approved durable production provider/schema/keys, real publisher authentication and publish/update UX, separately authorized standalone no-charge preview site and manual UX acceptance, and WU6 cross-user production contract. GitHub Pages production remains on PR #211, not PR #212.

### Work Unit 6 — update/revision UX + cross-user production acceptance

Add safe update/revision handling and prove the complete production contract:

1. User A publishes a safe package.
2. User B discovers it through Gallery/search.
3. User B downloads one exact revision.
4. Client validation succeeds.
5. Creator import succeeds.
6. Training can play the imported package.
7. Tampered/incompatible packages fail closed.
8. Same-version/different-content update is rejected; valid monotonic update creates a new immutable revision.
9. Existing package/PvP regressions stay green.

V2 advances from **75% to 87.5% (7/8)** only after this full acceptance and evidence are synchronized.

## Explicit non-goals for early V2-7 work

- Do not turn Gallery publication into automatic competitive/PvP trust.
- Do not execute uploaded code.
- Do not bundle Gallery packages into the startup PCK.
- Do not choose a paid persistence/auth provider.
- Do not weaken current package size/type/schema validation.
- Do not overwrite historical package revisions in place.
