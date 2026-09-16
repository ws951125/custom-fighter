extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_legacy_skill_has_no_timeline()
	_test_valid_timeline()
	_test_invalid_timeline()
	if failures == 0:
		print("SKILL_TIMELINE_TESTS_PASSED")
		quit(0)
		return
	printerr("SKILL_TIMELINE_TEST_FAILURES=%d" % failures)
	quit(1)

func _base_skill() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "timeline_test",
		"name": "Timeline Test",
		"type": "projectile",
		"damage": 18,
		"mp_cost": 20,
		"cooldown": 1.0,
		"startup": 0.2,
		"active": 0.3,
		"recovery": 0.2,
		"speed": 500.0,
		"range": 800.0,
		"hitbox_half_width": 24.0,
		"hitbox_half_depth": 0.08,
		"visual": "projectile",
		"impact_visual": "impact"
	}

func _test_legacy_skill_has_no_timeline() -> void:
	var skill := SkillDefinition.new()
	var errors := skill.load_from_dictionary(_base_skill())
	_check(errors.is_empty(), "legacy V1 skill remains valid")
	_check(skill.loaded, "legacy V1 skill loads")
	_check(not skill.has_timeline(), "legacy V1 skill does not require timeline")
	_check(is_equal_approx(skill.total_timeline_duration(), 0.7), "legacy timing remains startup + active + recovery")

func _test_valid_timeline() -> void:
	var data := _base_skill()
	data["timeline"] = {
		"schema_version": 1,
		"events": [
			{"id": "anim_cast", "type": "animation", "time": 0.0, "duration": 0.2, "animation": "skill_1"},
			{"id": "vfx_spawn", "type": "vfx", "time": 0.2, "duration": 0.0, "visual": "projectile"},
			{"id": "hit_window", "type": "hitbox", "time": 0.2, "duration": 0.3, "half_width": 24.0, "half_depth": 0.08},
			{"id": "cast_audio", "type": "audio", "time": 0.2, "duration": 0.0, "cue": "skill_cast"},
			{"id": "recovery_hurtbox", "type": "hurtbox", "time": 0.5, "duration": 0.2, "half_width": 18.0, "half_depth": 0.08}
		]
	}
	var skill := SkillDefinition.new()
	var errors := skill.load_from_dictionary(data)
	_check(errors.is_empty(), "valid timeline loads: %s" % ", ".join(errors))
	_check(skill.loaded and skill.has_timeline(), "timeline marks skill loaded and timeline-present")
	_check(skill.timeline_events.size() == 5, "timeline preserves all events")
	_check(skill.timeline_events[2]["id"] == "hit_window", "timeline preserves deterministic event order")
	_check(is_equal_approx(skill.total_timeline_duration(), 0.7), "timeline duration includes latest event end")

func _test_invalid_timeline() -> void:
	var duplicate := _base_skill()
	duplicate["timeline"] = {
		"schema_version": 1,
		"events": [
			{"id": "same", "type": "vfx", "time": 0.2},
			{"id": "same", "type": "audio", "time": 0.3}
		]
	}
	var duplicate_skill := SkillDefinition.new()
	var duplicate_errors := duplicate_skill.load_from_dictionary(duplicate)
	_check(not duplicate_errors.is_empty() and not duplicate_skill.loaded, "duplicate event ids are rejected")

	var unordered := _base_skill()
	unordered["timeline"] = {
		"schema_version": 1,
		"events": [
			{"id": "late", "type": "vfx", "time": 0.5},
			{"id": "early", "type": "vfx", "time": 0.1}
		]
	}
	var unordered_skill := SkillDefinition.new()
	var unordered_errors := unordered_skill.load_from_dictionary(unordered)
	_check(not unordered_errors.is_empty() and not unordered_skill.loaded, "out-of-order events are rejected")

	var unsupported := _base_skill()
	unsupported["timeline"] = {"schema_version": 1, "events": [{"id": "script", "type": "arbitrary_code", "time": 0.0}]}
	var unsupported_skill := SkillDefinition.new()
	var unsupported_errors := unsupported_skill.load_from_dictionary(unsupported)
	_check(not unsupported_errors.is_empty() and not unsupported_skill.loaded, "arbitrary event types are rejected")

	var bad_version := _base_skill()
	bad_version["timeline"] = {"schema_version": 99, "events": []}
	var bad_version_skill := SkillDefinition.new()
	var bad_version_errors := bad_version_skill.load_from_dictionary(bad_version)
	_check(not bad_version_errors.is_empty() and not bad_version_skill.loaded, "unsupported timeline schema version is rejected")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)
