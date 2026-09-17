class_name TrapAttackState
extends RefCounted

const CombatBox = preload("res://game/core/combat/combat_box.gd")

var active := false
var center := Vector2.ZERO
var half_extents := Vector2.ZERO
var remaining := 0.0
var triggered := false
var expired := false

func place(initial_center: Vector2, half_width: float, half_depth: float, duration_seconds: float) -> bool:
	if half_width <= 0.0 or half_depth <= 0.0 or duration_seconds <= 0.0:
		return false
	center = initial_center
	half_extents = Vector2(half_width, half_depth)
	remaining = duration_seconds
	triggered = false
	expired = false
	active = true
	return true

func tick(delta: float) -> void:
	if not active:
		return
	remaining = maxf(0.0, remaining - maxf(0.0, delta))
	if remaining <= 0.0:
		active = false
		expired = true

func hitbox() -> CombatBox:
	return CombatBox.new(center, half_extents)

func can_trigger() -> bool:
	return active and not triggered

func trigger() -> bool:
	if not can_trigger():
		return false
	triggered = true
	active = false
	remaining = 0.0
	return true

func deactivate() -> void:
	active = false
	remaining = 0.0
