class_name GrabState
extends RefCounted

const CombatBox = preload("res://game/core/combat/combat_box.gd")

var active := false
var remaining := 0.0
var captured := false
var activation_count := 0
var capture_count := 0
var last_direction := 1.0
var last_source_center := Vector2.ZERO
var last_target_start := Vector2.ZERO
var last_target_destination := Vector2.ZERO

func try_capture(
	player_position: Vector2,
	target_position: Vector2,
	target_half_extents: Vector2,
	facing: float,
	source_offset: float,
	source_half_width: float,
	source_half_depth: float,
	hold_seconds: float,
	target_offset: float,
	min_x: float,
	max_x: float
) -> bool:
	if active:
		return false
	captured = false
	if (
		source_offset <= 0.0
		or source_half_width <= 0.0
		or source_half_depth <= 0.0
		or hold_seconds <= 0.0
		or target_offset <= 0.0
		or target_half_extents.x <= 0.0
		or target_half_extents.y <= 0.0
		or min_x >= max_x
	):
		return false
	if player_position.x < min_x or player_position.x > max_x or player_position.y < 0.0 or player_position.y > 1.0:
		return false
	if target_position.x < min_x or target_position.x > max_x or target_position.y < 0.0 or target_position.y > 1.0:
		return false
	var direction := 1.0 if facing >= 0.0 else -1.0
	var source_center := Vector2(player_position.x + direction * source_offset, player_position.y)
	if source_center.x < min_x or source_center.x > max_x:
		return false
	var source_box := CombatBox.new(source_center, Vector2(source_half_width, source_half_depth))
	var target_box := CombatBox.new(target_position, target_half_extents)
	if not source_box.overlaps(target_box):
		return false
	active = true
	remaining = hold_seconds
	captured = true
	activation_count += 1
	capture_count += 1
	last_direction = direction
	last_source_center = source_center
	last_target_start = target_position
	last_target_destination = _bounded_anchor(player_position, direction, target_offset, min_x, max_x)
	return true

func tick(delta: float) -> void:
	if not active:
		return
	remaining = maxf(0.0, remaining - maxf(0.0, delta))
	if remaining <= 0.0:
		active = false

func anchored_target_position(
	player_position: Vector2,
	facing: float,
	target_offset: float,
	min_x: float,
	max_x: float
) -> Vector2:
	if not active or target_offset <= 0.0 or min_x >= max_x:
		return last_target_destination
	var direction := 1.0 if facing >= 0.0 else -1.0
	last_direction = direction
	last_target_destination = _bounded_anchor(player_position, direction, target_offset, min_x, max_x)
	return last_target_destination

func cancel() -> void:
	active = false
	remaining = 0.0

func _bounded_anchor(
	player_position: Vector2,
	direction: float,
	target_offset: float,
	min_x: float,
	max_x: float
) -> Vector2:
	return Vector2(
		clampf(player_position.x + direction * target_offset, min_x, max_x),
		clampf(player_position.y, 0.0, 1.0)
	)
