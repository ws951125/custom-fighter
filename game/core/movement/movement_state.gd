class_name MovementState
extends RefCounted

var jump_duration := 0.52
var jump_height := 115.0
var jump_elapsed := 0.0
var jumping := false

var dash_duration := 0.18
var dash_distance := 190.0
var dash_remaining := 0.0
var dash_cooldown := 0.45
var dash_cooldown_remaining := 0.0
var dash_direction := 1.0

func start_jump() -> bool:
	if jumping:
		return false
	jumping = true
	jump_elapsed = 0.0
	return true

func start_dash(direction: float) -> bool:
	if dash_remaining > 0.0 or dash_cooldown_remaining > 0.0:
		return false
	dash_direction = 1.0 if direction >= 0.0 else -1.0
	dash_remaining = dash_duration
	dash_cooldown_remaining = dash_cooldown
	return true

func tick(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)

	if jumping:
		jump_elapsed += safe_delta
		if jump_elapsed >= jump_duration:
			jump_elapsed = jump_duration
			jumping = false

	dash_remaining = maxf(0.0, dash_remaining - safe_delta)
	dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - safe_delta)

func jump_offset() -> float:
	if not jumping or jump_duration <= 0.0:
		return 0.0
	var progress := clampf(jump_elapsed / jump_duration, 0.0, 1.0)
	return sin(progress * PI) * jump_height

func dash_velocity() -> float:
	if dash_remaining <= 0.0 or dash_duration <= 0.0:
		return 0.0
	return dash_direction * (dash_distance / dash_duration)

func is_dashing() -> bool:
	return dash_remaining > 0.0

func can_dash() -> bool:
	return dash_remaining <= 0.0 and dash_cooldown_remaining <= 0.0
