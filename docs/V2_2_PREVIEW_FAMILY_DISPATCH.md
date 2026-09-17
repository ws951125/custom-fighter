# V2-2 Work Unit 2 — Creator Preview Family Dispatch

Date: 2026-09-17
Branch: `feat/v2-2-preview-family-dispatch`

## Goal

Remove the remaining projectile-only Creator Preview routing boundary for the six already-supported V1 families without creating an alternate combat engine.

## Implementation

- `CreatorPreviewSession` validates the authored skill through `SkillDefinition`, maps the validated family to its existing runtime slot, and rewrites only that slot in the temporary preview character.
- `preview_selectable_main.gd` injects the authored skill only when the runtime requests that mapped slot and still requires an exact expected-type match.
- `preview_family_animation_main.gd` adapts V2 timeline reads/transition consumption to the selected family's existing `SkillCastState`.
- `match_flow_main.gd` includes that adapter in the normal runtime inheritance chain; without an active Creator preview it is a no-op and ordinary Training keeps its existing controllers.
- Projectile-only imported VFX remains bound only for projectile preview. Non-projectile preview leaves stored VFX intact but does not activate it.

## Validation contract

`creator_preview_session_test_runner.gd` covers all six family-to-slot mappings, slot isolation, stored-draft isolation, VFX family isolation and unsupported-family fail-closed behavior.

`creator_preview_family_web_smoke.mjs` runs all six families in the real exported Web Creator/Training flow. For each family it authors the family, MP/cooldown values and one safe declarative audio timeline event, launches Preview, verifies runtime slot/type/source, casts using the mapped key, verifies authored MP consumption and timeline execution, then returns to Creator and verifies round-trip preservation.

The new browser smoke is part of `npm run smoke:all`, so both Chromium and GitHub-hosted Microsoft Edge execute it in normal CI. Formal acceptance still requires latest-head PR CI and post-merge main production gates to pass.
