# Project Status

## Current phase

**Post-MVP P3/P4 integration is substantially implemented; production real-provider acceptance remains blocked on server-side provider credentials.**

Whole-project completion is still counted only by fully completed roadmap phases: **84.6% (11/13 phases)**.

Roadmap:
- M0–M8 MVP: 9/9 complete.
- P1 Safe real-provider boundary: complete.
- P2 Async remote AI transport: complete.
- P3 Production AI provider/backend integration: in progress; implementation is largely complete, but real-provider production E2E is not accepted yet.
- P4 Image → skill proposal → Creator → Training production flow: in progress; reference-image contracts, review/confirm flow, Creator→Training preview and browser E2E are implemented, but real-provider production acceptance remains.

## Completed milestones

### M0–M8 MVP — 100%
Foundation, combat prototype, data-driven skill/character systems, Creator Studio, VFX Creator, provider-neutral AI-assisted VFX boundary, versioned character packages, Web release and Windows release flow are complete.

### P1 — Safe real-provider boundary — 100%
Validated provider configuration, HTTPS-only remote endpoint, embedded credential rejection, provider-neutral adapter boundary and deterministic mock fallback are complete.

### P2 — Async remote AI transport — 100%
Async Godot HTTP transport, strict JSON/PNG decoding, request/result matching, VFX draft revalidation and fail-closed malformed-output handling are complete.

## P3 — Production provider/backend integration — in progress

Implemented:
- trusted Node backend for AI VFX generation,
- OpenAI image provider adapter kept server-side,
- provider secret excluded from browser/Git,
- Render-compatible health/readiness endpoint,
- Creator remote-provider selection,
- async production request path,
- strict backend and Godot response validation,
- reference-image path using the image-edit provider boundary,
- production request payload compatibility fixes,
- online backend/contract/browser regression coverage.

Remaining acceptance blocker:
- production backend readiness must report the real provider configured,
- execute and accept a real provider request through the deployed trusted backend,
- verify returned generated asset through the existing fail-closed Creator boundary.

Do not mark P3 complete until the real-provider production E2E succeeds.

## P4 — Image → skill → Creator → Training E2E — in progress

Implemented:
- validated `AiSkillProposal` model,
- AI proposal cannot apply itself; explicit user confirmation is required,
- Creator proposal Review / Confirm & Apply / Discard UI,
- Confirm & Preview flow into Training,
- backend VFX response bundles a validated skill proposal,
- Godot remote codec validates proposal/request identity,
- Creator preview session carries pending proposal safely,
- reference PNG validation and trusted-backend transport,
- reference-image browser E2E with fake trusted backend,
- Creator → Training preview of accepted proposal,
- Training match result flow with Victory/Defeat and Restart,
- Restart remounts a fresh Training instance to reset HP, MP, positions, cooldowns, projectiles, buffs/controllers, hit counters and combat state,
- Chromium and Microsoft Edge regression coverage through GitHub Actions.

Remaining:
- real production reference-image/provider generation acceptance,
- confirm the real generated VFX + skill proposal in Creator,
- enter Training and cast that real generated skill end-to-end,
- final P4 production acceptance and documentation.

## Validation policy

Validation is now **online-only**.

Required path:
1. GitHub Actions logic/domain tests,
2. Godot headless import/boot,
3. backend and AI contract tests,
4. Web export and size budget,
5. Chromium smoke/E2E,
6. Windows native cross-export,
7. Microsoft Edge smoke/E2E on GitHub-hosted Windows,
8. public deployment checks when intentionally publishing.

Do not use Remote Desktop Commander or the user's local machine for this repository unless the user explicitly reverses this policy.

The latest Training match-result/restart batch passed GitHub Actions Run #189 across all three required jobs before merge.

## Development cadence

When adjacent roadmap work is clear and does not require new user input, continue through multiple coherent slices in one batch: implement → open/update PR → observe online CI to terminal state → fix failures → merge → continue to the next unblocked adjacent slice. Do not stop after every small sub-step.

## Production links

Training: `https://ws951125.github.io/custom-fighter/`

Creator Studio: `https://ws951125.github.io/custom-fighter/?mode=creator`

VFX Creator: `https://ws951125.github.io/custom-fighter/?mode=vfx`

These links represent the intentionally deployed public build. Source changes merged after the last deployment are not assumed live until a deployment is explicitly verified.

## Remaining roadmap

Whole-project roadmap remains:
- finish P3 real-provider production acceptance,
- finish P4 real image → generated VFX + proposal → Creator confirmation → Training cast production acceptance.

Until those phases are fully accepted, whole-project progress remains **84.6% (11/13)** under the phase-completion accounting rule.
