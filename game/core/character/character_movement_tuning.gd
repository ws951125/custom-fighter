class_name CharacterMovementTuning
extends RefCounted

# M1's original balanced values are retained only as the normalization baseline.
# Final runtime displacement is scaled to CharacterDefinition values, then optional
# runtime effects (for example Battle Focus) are composed on top.
const BASE_MOVE_SPEED := 360.0
const BASE_DEPTH_SPEED := 0.72
const BASE_RUN_MULTIPLIER := 1.60
const BASE_GUARD_MOVE_MULTIPLIER := 0.35

static func horizontal_ratio(character, running: bool, guarding: bool) -> float:
	if character == null or not character.loaded:
		return 1.0
	var ratio := float(character.move_speed) / BASE_MOVE_SPEED
	return ratio * _state_ratio(character, running, guarding)

static func depth_ratio(character, running: bool, guarding: bool) -> float:
	if character == null or not character.loaded:
		return 1.0
	var ratio := float(character.depth_speed) / BASE_DEPTH_SPEED
	return ratio * _state_ratio(character, running, guarding)

static func adjust_frame_delta(
	frame_delta: Vector2,
	character,
	running: bool,
	guarding: bool,
	extra_multiplier: float = 1.0
) -> Vector2:
	var safe_extra := maxf(0.0, extra_multiplier)
	return Vector2(
		frame_delta.x * horizontal_ratio(character, running, guarding) * safe_extra,
		frame_delta.y * depth_ratio(character, running, guarding) * safe_extra
	)

static func _state_ratio(character, running: bool, guarding: bool) -> float:
	var ratio := 1.0
	if running:
		ratio *= float(character.run_multiplier) / BASE_RUN_MULTIPLIER
	if guarding:
		ratio *= float(character.guard_move_multiplier) / BASE_GUARD_MOVE_MULTIPLIER
	return ratio
