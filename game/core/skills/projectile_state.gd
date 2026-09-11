class_name ProjectileState
extends RefCounted

const CombatBox = preload("res://game/core/combat/combat_box.gd")

var active := false
var x := 0.0
var previous_x := 0.0
var depth := 0.0
var direction := 1.0
var speed := 0.0
var max_range := 0.0
var distance_traveled := 0.0
var active_remaining := 0.0

func spawn(
	origin_x: float,
	origin_depth: float,
	facing: float,
	projectile_speed: float,
	projectile_range: float,
	active_seconds: float
) -> bool:
	x = origin_x
	previous_x = origin_x
	depth = origin_depth
	direction = 1.0 if facing >= 0.0 else -1.0
	speed = maxf(0.0, projectile_speed)
	max_range = maxf(0.0, projectile_range)
	distance_traveled = 0.0
	active_remaining = maxf(0.0, active_seconds)
	active = speed > 0.0 and max_range > 0.0 and active_remaining > 0.0
	return active

func tick(delta: float) -> void:
	if not active:
		return

	var safe_delta := maxf(0.0, delta)
	previous_x = x
	var displacement := direction * speed * safe_delta
	x += displacement
	distance_traveled += absf(displacement)
	active_remaining = maxf(0.0, active_remaining - safe_delta)

	if distance_traveled >= max_range or active_remaining <= 0.0:
		active = false

func swept_hitbox(half_width: float, half_depth: float) -> CombatBox:
	var center_x := (previous_x + x) * 0.5
	var swept_half_width := maxf(0.0, half_width) + absf(x - previous_x) * 0.5
	return CombatBox.new(
		Vector2(center_x, depth),
		Vector2(swept_half_width, maxf(0.0, half_depth))
	)

func deactivate() -> void:
	active = false
	active_remaining = 0.0
