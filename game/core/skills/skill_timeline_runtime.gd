class_name SkillTimelineRuntime
extends RefCounted

const SkillDefinitionScript = preload("res://game/core/skills/skill_definition.gd")
const TIME_EPSILON := 0.0001

var definition: SkillDefinitionScript
var _boundaries: Array[Dictionary] = []
var _next_boundary_index := 0
var _pending_transitions: Array[Dictionary] = []
var _active_events: Dictionary = {}
var _elapsed := 0.0
var _running := false

func configure(skill: SkillDefinitionScript) -> void:
	definition = skill
	_boundaries.clear()
	if definition != null and definition.loaded and definition.has_timeline():
		_build_boundaries()
	_reset_execution()

func start() -> bool:
	_reset_execution()
	if definition == null or not definition.loaded or _boundaries.is_empty():
		return false
	_running = true
	_emit_due_boundaries(0.0)
	_finish_if_complete()
	return true

func tick(delta: float) -> void:
	if not _running:
		return
	_elapsed += maxf(0.0, delta)
	_emit_due_boundaries(_elapsed)
	_finish_if_complete()

func cancel() -> void:
	_reset_execution()

func is_running() -> bool:
	return _running

func elapsed_seconds() -> float:
	return _elapsed

func has_pending_transitions() -> bool:
	return not _pending_transitions.is_empty()

func consume_transitions() -> Array[Dictionary]:
	var transitions: Array[Dictionary] = []
	for transition in _pending_transitions:
		transitions.append(transition.duplicate(true))
	_pending_transitions.clear()
	return transitions

func is_event_active(event_id: String) -> bool:
	return _active_events.has(event_id)

func active_events(event_type := "") -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if definition == null:
		return events
	for source_event in definition.timeline_events:
		var event_id := str(source_event.get("id", ""))
		if not _active_events.has(event_id):
			continue
		if not event_type.is_empty() and str(source_event.get("type", "")) != event_type:
			continue
		events.append(source_event.duplicate(true))
	return events

func _build_boundaries() -> void:
	for source_index in range(definition.timeline_events.size()):
		var event: Dictionary = definition.timeline_events[source_index].duplicate(true)
		var event_time := float(event.get("time", 0.0))
		_insert_boundary(_make_boundary(event, "start", event_time, source_index))
		var duration := float(event.get("duration", 0.0))
		if duration > 0.0:
			_insert_boundary(_make_boundary(event, "end", event_time + duration, source_index))

func _make_boundary(event: Dictionary, phase_name: String, boundary_time: float, source_index: int) -> Dictionary:
	return {
		"time": boundary_time,
		"phase": phase_name,
		"phase_order": 0 if phase_name == "end" else 1,
		"source_index": source_index,
		"event": event.duplicate(true),
	}

func _insert_boundary(boundary: Dictionary) -> void:
	var insert_at := _boundaries.size()
	for index in range(_boundaries.size()):
		if _boundary_precedes(boundary, _boundaries[index]):
			insert_at = index
			break
	_boundaries.insert(insert_at, boundary)

func _boundary_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_time := float(left.get("time", 0.0))
	var right_time := float(right.get("time", 0.0))
	if left_time < right_time - TIME_EPSILON:
		return true
	if left_time > right_time + TIME_EPSILON:
		return false
	var left_phase_order := int(left.get("phase_order", 1))
	var right_phase_order := int(right.get("phase_order", 1))
	if left_phase_order != right_phase_order:
		return left_phase_order < right_phase_order
	return int(left.get("source_index", 0)) < int(right.get("source_index", 0))

func _emit_due_boundaries(target_time: float) -> void:
	while _next_boundary_index < _boundaries.size():
		var boundary: Dictionary = _boundaries[_next_boundary_index]
		if float(boundary.get("time", 0.0)) > target_time + TIME_EPSILON:
			break
		_emit_boundary(boundary)
		_next_boundary_index += 1

func _emit_boundary(boundary: Dictionary) -> void:
	var event: Dictionary = boundary.get("event", {}).duplicate(true)
	var event_id := str(event.get("id", ""))
	var phase_name := str(boundary.get("phase", ""))
	var duration := float(event.get("duration", 0.0))
	if phase_name == "start" and duration > 0.0:
		_active_events[event_id] = event.duplicate(true)
	elif phase_name == "end":
		_active_events.erase(event_id)
	_pending_transitions.append({
		"phase": phase_name,
		"time": float(boundary.get("time", 0.0)),
		"event": event,
	})

func _finish_if_complete() -> void:
	if _next_boundary_index >= _boundaries.size():
		_running = false

func _reset_execution() -> void:
	_next_boundary_index = 0
	_pending_transitions.clear()
	_active_events.clear()
	_elapsed = 0.0
	_running = false
