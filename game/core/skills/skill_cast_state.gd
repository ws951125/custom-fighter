class_name SkillCastState
extends RefCounted

const SkillDefinitionScript = preload("res://game/core/skills/skill_definition.gd")
const SkillTimelineRuntime = preload("res://game/core/skills/skill_timeline_runtime.gd")

enum Phase {
	READY,
	STARTUP,
	ACTIVE,
	RECOVERY,
}

var definition: SkillDefinitionScript
var phase: Phase = Phase.READY
var phase_remaining := 0.0
var cooldown_remaining := 0.0
var activation_pending := false
var timeline_runtime := SkillTimelineRuntime.new()

func configure(skill: SkillDefinitionScript) -> void:
	definition = skill
	phase = Phase.READY
	phase_remaining = 0.0
	cooldown_remaining = 0.0
	activation_pending = false
	timeline_runtime.configure(skill)

func tick(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	cooldown_remaining = maxf(0.0, cooldown_remaining - safe_delta)
	timeline_runtime.tick(safe_delta)
	if phase == Phase.READY or definition == null:
		return

	var remaining := safe_delta
	var guard := 0
	while phase != Phase.READY and guard < 8:
		guard += 1
		if phase_remaining > remaining:
			phase_remaining -= remaining
			return

		remaining = maxf(0.0, remaining - phase_remaining)
		_advance_phase()
		if remaining <= 0.0 and phase_remaining > 0.0:
			return

func can_cast(current_mp: int) -> bool:
	return (
		definition != null
		and definition.loaded
		and phase == Phase.READY
		and not timeline_runtime.is_running()
		and cooldown_remaining <= 0.0
		and current_mp >= definition.mp_cost
	)

func start_cast(current_mp: int) -> bool:
	if not can_cast(current_mp):
		return false

	cooldown_remaining = maxf(cooldown_remaining, definition.cooldown)
	phase = Phase.STARTUP
	phase_remaining = definition.startup
	activation_pending = false
	timeline_runtime.start()
	_skip_zero_length_phases()
	return true

func consume_activation() -> bool:
	if not activation_pending:
		return false
	activation_pending = false
	return true

func consume_timeline_transitions() -> Array[Dictionary]:
	return timeline_runtime.consume_transitions()

func timeline_is_running() -> bool:
	return timeline_runtime.is_running()

func timeline_elapsed_seconds() -> float:
	return timeline_runtime.elapsed_seconds()

func timeline_event_is_active(event_id: String) -> bool:
	return timeline_runtime.is_event_active(event_id)

func active_timeline_events(event_type: String = "") -> Array[Dictionary]:
	return timeline_runtime.active_events(event_type)

func is_casting() -> bool:
	return phase != Phase.READY or timeline_runtime.is_running()

func phase_name() -> String:
	match phase:
		Phase.STARTUP:
			return "STARTUP"
		Phase.ACTIVE:
			return "ACTIVE"
		Phase.RECOVERY:
			return "RECOVERY"
		_:
			return "READY"

func cooldown_ratio() -> float:
	if definition == null or definition.cooldown <= 0.0:
		return 0.0
	return clampf(cooldown_remaining / definition.cooldown, 0.0, 1.0)

func _advance_phase() -> void:
	match phase:
		Phase.STARTUP:
			phase = Phase.ACTIVE
			phase_remaining = definition.active
			activation_pending = true
		Phase.ACTIVE:
			phase = Phase.RECOVERY
			phase_remaining = definition.recovery
		Phase.RECOVERY:
			phase = Phase.READY
			phase_remaining = 0.0
		_:
			phase = Phase.READY
			phase_remaining = 0.0
	_skip_zero_length_phases()

func _skip_zero_length_phases() -> void:
	var guard := 0
	while phase != Phase.READY and phase_remaining <= 0.0 and guard < 8:
		guard += 1
		match phase:
			Phase.STARTUP:
				phase = Phase.ACTIVE
				phase_remaining = definition.active
				activation_pending = true
			Phase.ACTIVE:
				phase = Phase.RECOVERY
				phase_remaining = definition.recovery
			Phase.RECOVERY:
				phase = Phase.READY
				phase_remaining = 0.0
