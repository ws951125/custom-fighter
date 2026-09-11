class_name DashAttackState
extends RefCounted

const CombatBox = preload("res://game/core/combat/combat_box.gd")

var active := false
var x := 0.0
var previous_x := 0.0
var depth := 0.0
var direction := 1.0
var speed := 0.0
var remaining_range := 0.0
var travelled := 0.0

func start(
	start_x: float,
	start_depth: float,
	facing: float,
	travel_speed: float,
	travel_range: float
) -> bool:
	if active or travel_speed <= 0.0 or travel_range <= 0.0:
		return false

	x = start_x
	previous_x = start_x
	depth = start_depth
	direction = 1.0 if facing >= 0.0 else -1.0
	speed = travel_speed
	remaining_range = travel_range
	travelled = 0.0
	active = true
	return true

func tick(delta: float) -> float:
	if not active:
		return 0.0

	var safe_delta := maxf(0.0, delta)
	previous_x = x
	var step_distance := minf(speed * safe_delta, remaining_range)
	var displacement := direction * step_distance
	x += displacement
	travelled += step_distance
	remaining_range = maxf(0.0, remaining_range - step_distance)
	if remaining_range <= 0.0:
		active = false
	return displacement

func stop() -> void:
	active = false
	remaining_range = 0.0

func swept_hitbox(half_width: float, half_depth: float) -> CombatBox:
	var left_x := minf(previous_x, x)
	var right_x := maxf(previous_x, x)
	var center_x := (left_x + right_x) * 0.5
	var sweep_half_width := ((right_x - left_x) * 0.5) + maxf(0.0, half_width)
	return CombatBox.new(
		Vector2(center_x, depth),
		Vector2(sweep_half_width, maxf(0.0, half_depth))
	)
