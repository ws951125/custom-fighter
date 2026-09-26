# V2-7 WU4 Supabase sharing setup

This document describes the server-only configuration contract for Creator Sharing durable persistence and publisher identity.

## Cost and provisioning boundary

- Use a dedicated Supabase project on a no-cost/free-tier plan only.
- Do not reuse another project's database without explicit approval.
- Do not upgrade a plan or enable paid add-ons for this feature.
- Provisioning a new external project, changing an existing project, or supplying secrets requires explicit user authorization.

## Database contract

The reviewed reference schema is:

`backend/sharing/supabase_schema.sql`

It defines:

- one stable publication row per publisher/package identity;
- immutable revision rows containing the canonical manifest and package JSON;
- optimistic latest-revision checks;
- monotonic package-version protection at the database boundary;
- bounded catalog search and pagination RPCs;
- RLS on both tables;
- no table access for `anon` or `authenticated`;
- RPC execution granted only to `service_role`.

The SQL file is not applied automatically by GitHub or Render.

## Render server environment

All three values are required together:

- `CUSTOM_FIGHTER_SHARING_SUPABASE_URL`
- `CUSTOM_FIGHTER_SHARING_SUPABASE_SECRET_KEY`
- `CUSTOM_FIGHTER_SHARING_SUPABASE_PUBLISHABLE_KEY`

If none are present, Sharing persistence/auth stays disabled. If only part of the set is present, the integration also stays disabled.

The secret key is server-only. It must never be committed to Git or exposed to the browser.

## Publisher identity

The browser sends its Supabase Auth access token as the normal `Authorization: Bearer ...` request header.

The backend does not trust token payload text or browser-supplied publisher fields. It asks Supabase Auth `/auth/v1/user` to validate the bearer token and derives the publisher identity exclusively from the returned authenticated user UUID.

Anonymous users are not accepted as publishers. User-editable `user_metadata` is never used for authorization or publisher identity.

## Package validation

Durable persistence is not sufficient by itself. Before any publication write, the backend runs:

`backend/sharing/self_contained_package_validator.mjs`

This independently checks the current Self-contained Package v1/v2 safety contract, including strict fields, character/skill references, bounded timeline data, Animation PNG, WAV audio and VFX PNG payloads.

Gallery publication still does not grant competitive/PvP trust.

## Fail-closed behavior

Publish remains unavailable when any required boundary is missing:

- durable repository;
- publisher authentication;
- full-package validator.

Read routes also fail closed when the repository is unavailable.
