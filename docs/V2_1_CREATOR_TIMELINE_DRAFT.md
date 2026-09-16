# V2-1 Creator Timeline Draft Contract

This checkpoint connects the V2-1 timeline domain schema to Creator skill drafts without changing the existing runtime cast path.

## Compatibility

- A new/reset `SkillDraft` contains no authored timeline events.
- `to_dictionary()` omits `timeline` when no events exist, preserving the existing V1-compatible projectile payload.
- When events exist, `SkillDraft` serializes the same `timeline.schema_version` and ordered event list accepted by `SkillDefinition`.
- Loading a timeline-bearing skill deep-copies its events into the draft.
- Reset and clear remove timeline authoring state.

## Validation boundary

`SkillDefinition` remains the authoritative timeline validator. Creator drafts therefore inherit the same supported event types, event-count/duration limits, duplicate-ID rules, deterministic ordering and rejection of arbitrary event types.

## Next UI slice

The next work unit exposes this draft state through safe Creator Skill Editor controls for event type, time, duration, add/remove and deterministic ordering. Spatial hitbox/hurtbox editing and runtime event execution remain later V2-1 work units.
