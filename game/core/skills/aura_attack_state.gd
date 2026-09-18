class_name AuraAttackState
extends RefCounted

const CombatBox = preload("res://game/core/combat/combat_box.gd")

var active := false
var center := Vector2.ZERO
var half_extents := Vector2.ZERO
var remaining := 0.0
var hit_consumed := false
var activation_count := 0

func start(initial_center: Vector2, half_width: float, half_depth: float, duration_seconds: float) -> bool:
	if half_width <= 0.0 or half_depth <= 0.0 or duration_seconds <= 0.0:
		return false
	center = initial_center
	half_extents = Vector2(half_width, half_depth)
	remaining = duration_seconds
	hit_consumed = false
	active = true
	activation_count += 1
	return true

func follow(next_center: Vector2) -> void:
	if active:
		center = next_center

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
