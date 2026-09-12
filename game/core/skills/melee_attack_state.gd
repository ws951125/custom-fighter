class_name MeleeAttackState
extends RefCounted

const CombatBox = preload("res://game/core/combat/combat_box.gd")

var active := false
var center := Vector2.ZERO
var half_extents := Vector2.ZERO
var remaining := 0.0
var hit_consumed := false
var facing := 1.0
var activation_count := 0

func start(
	origin: Vector2,
	facing_direction: float,
	forward_offset: float,
	half_width: float,
	half_depth: float,
	active_seconds: float
) -> bool:
	if forward_offset <= 0.0 or half_width <= 0.0 or half_depth <= 0.0 or active_seconds <= 0.0:
		return false
	facing = signf(facing_direction)
	if is_zero_approx(facing):
		facing = 1.0
	center = origin + Vector2(facing * forward_offset, 0.0)
	half_extents = Vector2(half_width, half_depth)
	remaining = active_seconds
	hit_consumed = false
	active = true
	activation_count += 1
	return true

func tick(delta: float) -> void:
	if not active:
		return
	remaining = maxf(0.0, remaining - maxf(0.0, delta))
	if remaining <= 0.0:
		active = false

func hitbox() -> CombatBox:
	return CombatBox.new(center, half_extents)

func can_hit() -> bool:
	return active and not hit_consumed

func consume_hit() -> bool:
	if not can_hit():
		return false
	hit_consumed = true
	return true

func deactivate() -> void:
	active = false
	remaining = 0.0
