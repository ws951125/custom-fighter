extends SceneTree

const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var draft := SkillDraft.new()
	_check(draft.is_valid(), "starter projectile skill draft validates")
	var data := draft.to_dictionary()
	_check(str(data.get("id", "")) == "my_projectile_001", "draft serializes id")
	_check(str(data.get("name", "")) == "My Projectile", "draft serializes name")
	_check(str(data.get("type", "")) == "projectile", "draft serializes projectile type")
	_check(int(data.get("damage", 0)) == 18, "draft serializes damage")
	_check(int(data.get("mp_cost", 0)) == 25, "draft serializes MP cost")
	_check(is_equal_approx(float(data.get("speed", 0.0)), 560.0), "draft serializes projectile speed")
	_check(is_equal_approx(float(data.get("range", 0.0)), 900.0), "draft serializes projectile range")
	_check(str(data.get("visual", "")) == "prototype_fireball", "draft preserves safe starter visual")
	_check(not data.has("timeline"), "legacy Creator draft stays timeline-free until events are authored")

	var definition := SkillDefinition.new()
	var definition_errors := definition.load_from_dictionary(data)
	_check(definition_errors.is_empty() and definition.loaded, "draft feeds runtime SkillDefinition contract")
	_check(definition.skill_type == "projectile", "runtime contract sees projectile type")

	_test_timeline_round_trip(draft)
	_test_invalid_timeline_fails_closed(draft)

	draft.skill_name = ""
	_check(_contains_error(draft.validate(), "name must not be empty"), "blank skill name fails closed")

	draft.skill_name = "Nova Bolt"
	draft.speed = 0.0
	_check(_contains_error(draft.validate(), "projectile speed must be positive"), "zero projectile speed fails closed")

	draft.speed = 700.0
	draft.range = 0.0
	_check(_contains_error(draft.validate(), "projectile range must be positive"), "zero projectile range fails closed")

	draft.range = 1050.0
	draft.skill_id = "../evil.gd"
	_check(_contains_error(draft.validate(), "id must be a safe lowercase reference token"), "unsafe creator skill id is rejected")

	draft.skill_id = "nova_bolt_001"
	draft.skill_type = "melee"
	_check(_contains_error(draft.validate(), "creator projectile draft type must remain projectile"), "creator template type cannot be switched outside projectile slice")

	draft.reset()
	_check(draft.is_valid(), "reset restores valid starter projectile")
	_check(draft.skill_name == "My Projectile" and draft.damage == 18 and is_equal_approx(draft.speed, 560.0), "reset restores starter values")
	_check(not draft.has_timeline() and not draft.to_dictionary().has("timeline"), "reset clears authored timeline and restores V1-compatible output")

	if failures == 0:
		print("CREATOR_SKILL_DRAFT_TESTS_PASSED")
		quit(0)
		return
	printerr("CREATOR_SKILL_DRAFT_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_timeline_round_trip(draft: SkillDraft) -> void:
	draft.reset()
	var events: Array[Dictionary] = [
		{"id": "cast_anim", "type": "animation", "time": 0.0, "duration": 0.22, "animation": "skill_1"},
		{"id": "spawn_vfx", "type": "vfx", "time": 0.22, "duration": 0.0, "visual": "prototype_fireball"},
		{"id": "hit_window", "type": "hitbox", "time": 0.22, "duration": 0.08, "half_width": 34.0, "half_depth": 0.12, "offset_x": 14.0, "offset_depth": -0.02},
		{"id": "cast_audio", "type": "audio", "time": 0.22, "duration": 0.0, "cue": "skill_cast"}
	]
	draft.set_timeline_events(events)
	_check(draft.has_timeline(), "Creator draft reports authored timeline")
	_check(draft.is_valid(), "Creator-authored timeline validates through SkillDefinition")
	var serialized := draft.to_dictionary()
	_check(serialized.has("timeline"), "Creator draft serializes timeline only when authored")
	var timeline: Dictionary = serialized.get("timeline", {})
	_check(int(timeline.get("schema_version", 0)) == SkillDefinition.TIMELINE_SCHEMA_VERSION, "Creator draft emits supported timeline schema")
	var serialized_events: Array = timeline.get("events", [])
	_check(serialized_events.size() == 4, "Creator draft serializes all timeline events")
	_check(is_equal_approx(float(serialized_events[2].get("half_width", 0.0)), 34.0), "Creator draft serializes spatial half width")
	_check(is_equal_approx(float(serialized_events[2].get("offset_x", 0.0)), 14.0), "Creator draft serializes spatial horizontal offset")
	_check(is_equal_approx(float(serialized_events[2].get("offset_depth", 0.0)), -0.02), "Creator draft serializes spatial depth offset")

	var loaded := SkillDraft.new()
	var errors := loaded.load_from_dictionary(serialized)
	_check(errors.is_empty(), "serialized Creator timeline reloads: %s" % ", ".join(errors))
	_check(loaded.has_timeline() and loaded.timeline_events.size() == 4, "Creator timeline survives draft round-trip")
	_check(str(loaded.timeline_events[2].get("id", "")) == "hit_window", "Creator timeline preserves deterministic event order")
	_check(is_equal_approx(float(loaded.timeline_events[2].get("half_width", 0.0)), 34.0), "Creator timeline preserves spatial dimensions")
	_check(is_equal_approx(float(loaded.timeline_events[2].get("offset_depth", 0.0)), -0.02), "Creator timeline preserves spatial offsets")

	# Ensure the draft owns a deep copy rather than sharing caller-owned dictionaries.
	events[0]["id"] = "mutated_outside"
	events[2]["offset_x"] = 999.0
	_check(str(loaded.timeline_events[0].get("id", "")) == "cast_anim", "Creator timeline round-trip is isolated from caller mutation")
	_check(is_equal_approx(float(loaded.timeline_events[2].get("offset_x", 0.0)), 14.0), "Creator spatial timeline deep copy is isolated from caller mutation")

func _test_invalid_timeline_fails_closed(draft: SkillDraft) -> void:
	draft.reset()
	draft.set_timeline_events([
		{"id": "late", "type": "vfx", "time": 0.5, "duration": 0.0},
		{"id": "early", "type": "audio", "time": 0.2, "duration": 0.0}
	])
	_check(_contains_error(draft.validate(), "timeline events must be ordered by non-decreasing time"), "Creator draft rejects unsorted timeline")
	draft.set_timeline_events([
		{"id": "unsafe", "type": "script", "time": 0.0, "duration": 0.0}
	])
	_check(_contains_error(draft.validate(), "unsupported timeline event type: script"), "Creator draft rejects arbitrary executable event types")
	draft.set_timeline_events([
		{"id": "bad_spatial", "type": "hitbox", "time": 0.0, "duration": 0.1, "half_width": -1.0, "half_depth": 0.08}
	])
	_check(_contains_error_fragment(draft.validate(), "half_width must be > 0"), "Creator draft rejects invalid spatial hitbox dimensions")

func _contains_error(errors: PackedStringArray, expected: String) -> bool:
	for error in errors:
		if error == expected:
			return true
	return false

func _contains_error_fragment(errors: PackedStringArray, expected: String) -> bool:
	for error in errors:
		if str(error).contains(expected):
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
