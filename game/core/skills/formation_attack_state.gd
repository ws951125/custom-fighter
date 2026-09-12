class_name FormationAttackState
extends RefCounted

const CombatBox = preload("res://game/core/combat/combat_box.gd")

var active := false
var origin := Vector2.ZERO
var facing := 1.0
var half_extents := Vector2.ZERO
var formation_count := 0
var spacing := 0.0
var interval := 0.0
var offset := 0.0
var active_seconds := 0.0
var elapsed := 0.0
var centers: Array = []
var emitted := PackedByteArray()
var hit_consumed := PackedByteArray()
var pending_strikes := PackedInt32Array()

func start(
	initial_origin: Vector2,
	initial_facing: float,
	count: int,
	cell_spacing: float,
	strike_interval: float,
	forward_offset: float,
	half_width: float,
	half_depth: float,
	duration: float
) -> bool:
	if count <= 0 or cell_spacing <= 0.0 or strike_interval <= 0.0:
		return false
	if forward_offset < 0.0 or half_width <= 0.0 or half_depth <= 0.0 or duration <= 0.0:
		return false
	if duration + 0.0001 < float(count - 1) * strike_interval:
		return false

	origin = initial_origin
	facing = 1.0 if initial_facing >= 0.0 else -1.0
	half_extents = Vector2(half_width, half_depth)
	formation_count = count
	spacing = cell_spacing
	interval = strike_interval
	offset = forward_offset
	active_seconds = duration
	elapsed = 0.0
	centers.clear()
	emitted.resize(count)
	hit_consumed.resize(count)
	pending_strikes = PackedInt32Array()
	for index in range(count):
		emitted[index] = 0
		hit_consumed[index] = 0
		centers.append(Vector2(
			origin.x + facing * (offset + float(index) * spacing),
			origin.y
		))
	active = true
	return true

func tick(delta: float) -> void:
	if not active:
		return
	elapsed = minf(active_seconds, elapsed + maxf(0.0, delta))
	for index in range(formation_count):
		if emitted[index] == 0 and elapsed + 0.0001 >= strike_time(index):
			emitted[index] = 1
			pending_strikes.append(index)
	if elapsed >= active_seconds:
		active = false

func consume_due_strikes() -> PackedInt32Array:
	var result := pending_strikes
	pending_strikes = PackedInt32Array()
	return result

func strike_time(index: int) -> float:
	if index < 0 or index >= formation_count:
		return -1.0
	return float(index) * interval

func center_for(index: int) -> Vector2:
	if index < 0 or index >= centers.size():
		return Vector2.ZERO
	return centers[index]

func strike_hitbox(index: int) -> CombatBox:
	return CombatBox.new(center_for(index), half_extents)

func has_struck(index: int) -> bool:
	return index >= 0 and index < emitted.size() and emitted[index] != 0

func can_hit(index: int) -> bool:
	return has_struck(index) and hit_consumed[index] == 0

func consume_hit(index: int) -> bool:
	if not can_hit(index):
		return false
	hit_consumed[index] = 1
	return true

func emitted_count() -> int:
	var total := 0
	for value in emitted:
		if value != 0:
			total += 1
	return total

func deactivate() -> void:
	active = false
	pending_strikes = PackedInt32Array()
