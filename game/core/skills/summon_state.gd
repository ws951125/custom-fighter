class_name SummonState
extends RefCounted

const CombatBox = preload("res://game/core/combat/combat_box.gd")

var active := false
var remaining := 0.0
var hit_consumed := false
var activation_count := 0
var hit_count := 0
var spawn_position := Vector2.ZERO
var position := Vector2.ZERO
var last_target_position := Vector2.ZERO
var last_move_direction := 0.0

func start(
	owner_position: Vector2,
	facing: float,
	spawn_offset: float,
	lifetime: float,
	min_x: float,
	max_x: float
) -> bool:
	if active:
		return false
	if (
		spawn_offset <= 0.0
		or lifetime <= 0.0
		or min_x >= max_x
		or owner_position.x < min_x
		or owner_position.x > max_x
		or owner_position.y < 0.0
		or owner_position.y > 1.0
	):
		return false
	var direction := 1.0 if facing >= 0.0 else -1.0
	var candidate := Vector2(owner_position.x + direction * spawn_offset, owner_position.y)
	if candidate.x < min_x or candidate.x > max_x:
		return false
	active = true
	remaining = lifetime
	hit_consumed = false
	activation_count += 1
	spawn_position = candidate
	position = candidate
	last_target_position = Vector2.ZERO
	last_move_direction = direction
	return true

func tick(
	delta: float,
	target_position: Vector2,
	target_half_extents: Vector2,
	target_eligible: bool,
	speed: float,
	actor_half_width: float,
	actor_half_depth: float,
	min_x: float,
	max_x: float
) -> bool:
	if not active:
		return false
	if (
		speed <= 0.0
		or actor_half_width <= 0.0
		or actor_half_depth <= 0.0
		or target_half_extents.x <= 0.0
		or target_half_extents.y <= 0.0
		or min_x >= max_x
		or target_position.x < min_x
		or target_position.x > max_x
		or target_position.y < 0.0
		or target_position.y > 1.0
	):
		cancel()
		return false

	var safe_delta := maxf(0.0, delta)
	remaining = maxf(0.0, remaining - safe_delta)
	if remaining <= 0.0:
		active = false
		return false

	last_target_position = target_position
	var delta_x := target_position.x - position.x
	if absf(delta_x) > 0.001:
		last_move_direction = 1.0 if delta_x > 0.0 else -1.0
	position.x = move_toward(position.x, target_position.x, speed * safe_delta)
	position.x = clampf(position.x, min_x, max_x)

	if hit_consumed or not target_eligible:
		return false
	var actor_box := CombatBox.new(position, Vector2(actor_half_width, actor_half_depth))
	var target_box := CombatBox.new(target_position, target_half_extents)
	if not actor_box.overlaps(target_box):
		return false
	hit_consumed = true
	hit_count += 1
	return true

func cancel() -> void:
	active = false
	remaining = 0.0
