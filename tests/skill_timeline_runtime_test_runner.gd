extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillTimelineRuntime = preload("res://game/core/skills/skill_timeline_runtime.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_deterministic_runtime_transitions()
	_test_cast_state_waits_for_longer_timeline()
	_test_legacy_cast_without_timeline()
	if failures == 0:
		print("SKILL_TIMELINE_RUNTIME_TESTS_PASSED")
		quit(0)
		return
	printerr("SKILL_TIMELINE_RUNTIME_TEST_FAILURES=%d" % failures)
	quit(1)

func _base_skill() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "runtime_timeline_test",
		"name": "Runtime Timeline Test",
		"type": "projectile",
		"damage": 18,
		"mp_cost": 20,
		"cooldown": 0.0,
		"startup": 0.1,
		"active": 0.1,
		"recovery": 0.1,
		"speed": 500.0,
		"range": 800.0,
		"hitbox_half_width": 24.0,
		"hitbox_half_depth": 0.08,
		"visual": "projectile",
		"impact_visual": "impact"
	}

func _load_skill(data: Dictionary) -> SkillDefinition:
	var skill := SkillDefinition.new()
	var errors: PackedStringArray = skill.load_from_dictionary(data)
	_check(errors.is_empty(), "runtime timeline fixture loads: %s" % " | ".join(errors))
	return skill

func _test_deterministic_runtime_transitions() -> void:
	var data := _base_skill()
	data["timeline"] = {
		"schema_version": 1,
		"events": [
			{"id": "anim", "type": "animation", "time": 0.0, "duration": 0.2, "animation": "skill_1"},
			{"id": "flash", "type": "vfx", "time": 0.1, "duration": 0.0, "visual": "projectile"},
			{"id": "hit", "type": "hitbox", "time": 0.15, "duration": 0.1, "half_width": 32.0, "half_depth": 0.1},
			{"id": "hurt", "type": "hurtbox", "time": 0.25, "duration": 0.05, "half_width": 20.0, "half_depth": 0.08},
			{"id": "sound", "type": "audio", "time": 0.3, "duration": 0.0, "cue": "skill_cast"}
		]
	}
	var skill := _load_skill(data)
	var runtime := SkillTimelineRuntime.new()
	runtime.configure(skill)
	_check(runtime.start(), "timeline runtime starts for a validated authored timeline")
	_check(runtime.is_running(), "timeline remains running while future boundaries exist")
	_check(runtime.is_event_active("anim"), "duration event is active immediately at time zero")

	var transitions := runtime.consume_transitions()
	_check(transitions.size() == 1, "time-zero event emits exactly one start transition")
	_check(_transition_key(transitions, 0) == "start:anim", "time-zero animation transition is deterministic")
	_check(runtime.consume_transitions().is_empty(), "timeline transitions are consumed exactly once")

	runtime.tick(-1.0)
	_check(is_equal_approx(runtime.elapsed_seconds(), 0.0), "negative delta cannot rewind or advance timeline")

	runtime.tick(0.1)
	transitions = runtime.consume_transitions()
	_check(transitions.size() == 1 and _transition_key(transitions, 0) == "start:flash", "zero-duration VFX emits at its authored time")
	_check(not runtime.is_event_active("flash"), "zero-duration event is not retained as an active window")

	runtime.tick(0.1)
	transitions = runtime.consume_transitions()
	_check(transitions.size() == 2, "one tick can cross multiple authored boundaries")
	_check(_transition_key(transitions, 0) == "start:hit", "large tick preserves earlier hitbox start ordering")
	_check(_transition_key(transitions, 1) == "end:anim", "large tick preserves later animation end ordering")
	_check(runtime.is_event_active("hit") and not runtime.is_event_active("anim"), "active duration windows track start/end state")

	runtime.tick(0.05)
	transitions = runtime.consume_transitions()
	_check(transitions.size() == 2, "same-time end/start boundaries are both emitted")
	_check(_transition_key(transitions, 0) == "end:hit", "same-time duration end is emitted before a new start")
	_check(_transition_key(transitions, 1) == "start:hurt", "same-time new duration event starts after prior end")
	_check(runtime.is_event_active("hurt") and not runtime.is_event_active("hit"), "same-time active windows switch deterministically")

	runtime.tick(0.05)
	transitions = runtime.consume_transitions()
	_check(transitions.size() == 2, "final same-time boundaries are both emitted")
	_check(_transition_key(transitions, 0) == "end:hurt", "final duration end precedes one-shot event at same time")
	_check(_transition_key(transitions, 1) == "start:sound", "audio one-shot follows the same-time duration end")
	_check(not runtime.is_running(), "runtime stops after the final authored boundary")
	_check(runtime.active_events().is_empty(), "no duration event remains active after completion")

func _test_cast_state_waits_for_longer_timeline() -> void:
	var data := _base_skill()
	data["timeline"] = {
		"schema_version": 1,
		"events": [
			{"id": "late_audio", "type": "audio", "time": 0.5, "duration": 0.0, "cue": "skill_cast"}
		]
	}
	var skill := _load_skill(data)
	var cast := SkillCastState.new()
	cast.configure(skill)
	_check(cast.can_cast(100), "timeline skill can cast before execution starts")
	_check(cast.start_cast(100), "timeline skill cast starts")
	_check(cast.timeline_is_running(), "cast starts timeline runtime")

	cast.tick(0.31)
	_check(cast.phase_name() == "READY", "legacy startup/active/recovery phases may finish before authored timeline")
	_check(cast.is_casting(), "cast remains busy while authored timeline still has future events")
	_check(not cast.can_cast(100), "skill cannot recast while authored timeline is still running")

	cast.tick(0.19)
	var transitions := cast.consume_timeline_transitions()
	_check(transitions.size() == 1 and _transition_key(transitions, 0) == "start:late_audio", "late authored event fires after legacy phases complete")
	_check(not cast.timeline_is_running(), "timeline runtime stops after late one-shot event")
	_check(not cast.is_casting(), "cast releases only after both phase state and timeline complete")
	_check(cast.can_cast(100), "skill can recast after complete authored execution")

func _test_legacy_cast_without_timeline() -> void:
	var skill := _load_skill(_base_skill())
	var cast := SkillCastState.new()
	cast.configure(skill)
	_check(cast.start_cast(100), "legacy skill without timeline still starts")
	_check(not cast.timeline_is_running(), "legacy skill does not create a runtime timeline")
	cast.tick(0.31)
	_check(not cast.is_casting(), "legacy skill retains original phase completion behavior")
	_check(cast.consume_timeline_transitions().is_empty(), "legacy skill emits no timeline transitions")

func _transition_key(transitions: Array[Dictionary], index: int) -> String:
	if index < 0 or index >= transitions.size():
		return ""
	var transition: Dictionary = transitions[index]
	var raw_event: Variant = transition.get("event", {})
	var event: Dictionary = raw_event if raw_event is Dictionary else {}
	return "%s:%s" % [str(transition.get("phase", "")), str(event.get("id", ""))]

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)
