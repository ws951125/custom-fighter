extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_legacy_skill_has_no_timeline()
	_test_valid_timeline()
	_test_spatial_defaults_remain_backwards_compatible()
	_test_invalid_timeline()
	_test_invalid_spatial_payloads()
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
			{"id": "hit_window", "type": "hitbox", "time": 0.2, "duration": 0.3, "half_width": 32.0, "half_depth": 0.12, "offset_x": 16.0, "offset_depth": -0.02},
			{"id": "cast_audio", "type": "audio", "time": 0.2, "duration": 0.0, "cue": "skill_cast"},
			{"id": "recovery_hurtbox", "type": "hurtbox", "time": 0.5, "duration": 0.2, "half_width": 18.0, "half_depth": 0.08, "offset_x": -4.0, "offset_depth": 0.03}
		]
	}
	var skill := SkillDefinition.new()
	var errors := skill.load_from_dictionary(data)
	_check(errors.is_empty(), "valid timeline loads: %s" % ", ".join(errors))
	_check(skill.loaded and skill.has_timeline(), "timeline marks skill loaded and timeline-present")
	_check(skill.timeline_events.size() == 5, "timeline preserves all events")
	_check(skill.timeline_events[2]["id"] == "hit_window", "timeline preserves deterministic event order")
	_check(is_equal_approx(float(skill.timeline_events[2].get("half_width", 0.0)), 32.0), "hitbox half width is preserved")
	_check(is_equal_approx(float(skill.timeline_events[2].get("offset_x", 0.0)), 16.0), "hitbox horizontal offset is preserved")
	_check(is_equal_approx(float(skill.timeline_events[4].get("offset_depth", 0.0)), 0.03), "hurtbox depth offset is preserved")
	_check(is_equal_approx(skill.total_timeline_duration(), 0.7), "timeline duration includes latest event end")

func _test_spatial_defaults_remain_backwards_compatible() -> void:
	var data := _base_skill()
	data["timeline"] = {
		"schema_version": 1,
		"events": [
			{"id": "legacy_hit", "type": "hitbox", "time": 0.2, "duration": 0.1},
			{"id": "legacy_hurt", "type": "hurtbox", "time": 0.4, "duration": 0.1, "half_width": 20.0, "half_depth": 0.1}
		]
	}
	var skill := SkillDefinition.new()
	var errors := skill.load_from_dictionary(data)
	_check(errors.is_empty() and skill.loaded, "pre-spatial V2 timeline events remain valid")
	var hitbox: Dictionary = skill.timeline_events[0]
	_check(is_equal_approx(float(hitbox.get("half_width", 0.0)), SkillDefinition.DEFAULT_TIMELINE_SPATIAL_HALF_WIDTH), "missing half width receives safe default")
	_check(is_equal_approx(float(hitbox.get("half_depth", 0.0)), SkillDefinition.DEFAULT_TIMELINE_SPATIAL_HALF_DEPTH), "missing half depth receives safe default")
	_check(is_equal_approx(float(hitbox.get("offset_x", 999.0)), 0.0) and is_equal_approx(float(hitbox.get("offset_depth", 999.0)), 0.0), "missing spatial offsets default to zero")

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

func _test_invalid_spatial_payloads() -> void:
	var bad_width := _base_skill()
	bad_width["timeline"] = {"schema_version": 1, "events": [{"id": "bad_width", "type": "hitbox", "time": 0.0, "half_width": 0.0}]}
	var width_skill := SkillDefinition.new()
	var width_errors := width_skill.load_from_dictionary(bad_width)
	_check(_contains_error(width_errors, "half_width must be > 0"), "zero spatial half width fails closed")
	_check(not width_skill.loaded, "invalid spatial width prevents loading")

	var bad_depth := _base_skill()
	bad_depth["timeline"] = {"schema_version": 1, "events": [{"id": "bad_depth", "type": "hurtbox", "time": 0.0, "half_depth": 2.0}]}
	var depth_skill := SkillDefinition.new()
	var depth_errors := depth_skill.load_from_dictionary(bad_depth)
	_check(_contains_error(depth_errors, "half_depth must be > 0"), "oversized spatial half depth fails closed")

	var bad_offset := _base_skill()
	bad_offset["timeline"] = {"schema_version": 1, "events": [{"id": "bad_offset", "type": "hitbox", "time": 0.0, "offset_x": 5000.0, "offset_depth": -1.5}]}
	var offset_skill := SkillDefinition.new()
	var offset_errors := offset_skill.load_from_dictionary(bad_offset)
	_check(_contains_error(offset_errors, "offset_x exceeds safe spatial limit"), "oversized horizontal offset fails closed")
	_check(_contains_error(offset_errors, "offset_depth exceeds safe spatial limit"), "oversized depth offset fails closed")

func _contains_error(errors: PackedStringArray, expected_fragment: String) -> bool:
	for error in errors:
		if str(error).contains(expected_fragment):
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)
