class_name CounterState
extends RefCounted

var active := false
var remaining := 0.0
var triggered := false
var activation_count := 0
var trigger_count := 0
var last_source := Vector2.ZERO

func start(window_seconds: float) -> bool:
	if window_seconds <= 0.0:
		return false
	active = true
	remaining = window_seconds
	triggered = false
	last_source = Vector2.ZERO
	activation_count += 1
	return true

func tick(delta: float) -> void:
	if not active:
		return
	remaining = maxf(0.0, remaining - maxf(0.0, delta))
	if remaining <= 0.0:
		active = false

func can_intercept(player_position: Vector2, source_position: Vector2, max_range: float, max_depth: float) -> bool:
	if not active or triggered or max_range <= 0.0 or max_depth <= 0.0:
		return false
	return (
		absf(source_position.x - player_position.x) <= max_range
		and absf(source_position.y - player_position.y) <= max_depth
	)

func intercept(player_position: Vector2, source_position: Vector2, max_range: float, max_depth: float) -> bool:
	if not can_intercept(player_position, source_position, max_range, max_depth):
		return false
	active = false
	remaining = 0.0
	triggered = true
	last_source = source_position
	trigger_count += 1
	return true

func cancel() -> void:
	active = false
	remaining = 0.0
