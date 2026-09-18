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

	_test_supported_family_round_trips()
	_test_timeline_round_trip(draft)
	_test_invalid_timeline_fails_closed(draft)

	draft.reset()
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
	draft.skill_type = "arbitrary_code"
	_check(_contains_error(draft.validate(), "unsupported skill type: arbitrary_code"), "unsupported Creator family fails closed through SkillDefinition")

	draft.reset()
	var previous_type := draft.skill_type
	_check(not draft.set_skill_type("../summon.gd"), "family selector rejects unsafe/unsupported type")
	_check(draft.skill_type == previous_type, "rejected family selector does not mutate the draft")

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

func _test_supported_family_round_trips() -> void:
	for family in SkillDefinition.SUPPORTED_TYPES:
		var draft := SkillDraft.new()
		_check(draft.set_skill_type(family), "Creator accepts supported family %s" % family)
		_check(draft.skill_type == family, "Creator stores selected family %s" % family)
		var errors := draft.validate()
		_check(errors.is_empty(), "safe defaults validate for family %s: %s" % [family, " | ".join(errors)])
		var serialized := draft.to_dictionary()
		_check(str(serialized.get("type", "")) == family, "Creator serializes selected family %s" % family)
		var runtime_definition := SkillDefinition.new()
		var runtime_errors := runtime_definition.load_from_dictionary(serialized)
		_check(runtime_errors.is_empty() and runtime_definition.loaded, "runtime accepts Creator family %s: %s" % [family, " | ".join(runtime_errors)])
		_check(runtime_definition.skill_type == family, "runtime preserves Creator family %s" % family)
		var reloaded := SkillDraft.new()
		var reload_errors := reloaded.load_from_dictionary(serialized)
		_check(reload_errors.is_empty(), "Creator reloads family %s: %s" % [family, " | ".join(reload_errors)])
		_check(reloaded.skill_type == family and reloaded.is_valid(), "Creator family %s survives round-trip" % family)

	var formation := SkillDraft.new()
	formation.set_skill_type("formation")
	_check(formation.formation_count == 4, "formation defaults include safe strike count")
	_check(is_equal_approx(formation.formation_spacing, 80.0), "formation defaults include safe spacing")
	_check(is_equal_approx(formation.formation_interval, 0.15), "formation defaults include safe interval")
	formation.formation_count = 0
	_check(_contains_error(formation.validate(), "formation_count must be positive"), "invalid formation family parameter fails closed")

	var buff := SkillDraft.new()
	buff.set_skill_type("buff")
	_check(is_equal_approx(buff.buff_duration, 5.0), "buff defaults include safe duration")
	_check(buff.move_speed_multiplier >= 1.0 and buff.basic_attack_damage_multiplier >= 1.0, "buff defaults include safe multipliers")
	buff.buff_duration = 0.0
	_check(_contains_error(buff.validate(), "buff_duration must be positive"), "invalid buff family parameter fails closed")

	var aura := SkillDraft.new()
	aura.set_skill_type("aura")
	_check(is_equal_approx(aura.aura_duration, 4.0), "aura defaults include safe duration")
	_check(is_equal_approx(aura.hitbox_half_width, 120.0) and is_equal_approx(aura.hitbox_half_depth, 0.18), "aura defaults include safe volume")
	aura.aura_duration = 0.0
	_check(_contains_error_fragment(aura.validate(), "aura_duration must be"), "invalid aura duration fails closed")

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
	_check(str(serialized_events[0].get("animation", "")) == "skill_1", "Creator draft serializes animation payload")
	_check(str(serialized_events[1].get("visual", "")) == "prototype_fireball", "Creator draft serializes VFX payload")
	_check(str(serialized_events[3].get("cue", "")) == "skill_cast", "Creator draft serializes audio cue payload")
	_check(is_equal_approx(float(serialized_events[2].get("half_width", 0.0)), 34.0), "Creator draft serializes spatial half width")
	_check(is_equal_approx(float(serialized_events[2].get("offset_x", 0.0)), 14.0), "Creator draft serializes spatial horizontal offset")
	_check(is_equal_approx(float(serialized_events[2].get("offset_depth", 0.0)), -0.02), "Creator draft serializes spatial depth offset")

	var loaded := SkillDraft.new()
	var errors := loaded.load_from_dictionary(serialized)
	_check(errors.is_empty(), "serialized Creator timeline reloads: %s" % ", ".join(errors))
	_check(loaded.has_timeline() and loaded.timeline_events.size() == 4, "Creator timeline survives draft round-trip")
	_check(str(loaded.timeline_events[0].get("id", "")) == "cast_anim", "Creator timeline preserves deterministic event order")
	_check(str(loaded.timeline_events[0].get("animation", "")) == "skill_1", "Creator timeline preserves animation payload")
	_check(str(loaded.timeline_events[1].get("visual", "")) == "prototype_fireball", "Creator timeline preserves VFX payload")
	_check(str(loaded.timeline_events[3].get("cue", "")) == "skill_cast", "Creator timeline preserves audio cue payload")
	_check(is_equal_approx(float(loaded.timeline_events[2].get("half_width", 0.0)), 34.0), "Creator timeline preserves spatial dimensions")
	_check(is_equal_approx(float(loaded.timeline_events[2].get("offset_depth", 0.0)), -0.02), "Creator timeline preserves spatial offsets")

	events[0]["id"] = "mutated_outside"
	events[0]["animation"] = "attack_1"
	events[1]["visual"] = "mutated_visual"
	events[2]["offset_x"] = 999.0
	_check(str(loaded.timeline_events[0].get("id", "")) == "cast_anim", "Creator timeline round-trip is isolated from caller mutation")
	_check(str(loaded.timeline_events[0].get("animation", "")) == "skill_1", "Creator animation payload deep copy is isolated from caller mutation")
	_check(str(loaded.timeline_events[1].get("visual", "")) == "prototype_fireball", "Creator VFX payload deep copy is isolated from caller mutation")
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
		{"id": "bad_animation", "type": "animation", "time": 0.0, "duration": 0.1, "animation": "../evil.gd"}
	])
	_check(_contains_error_fragment(draft.validate(), "animation must be a safe lowercase token"), "Creator draft rejects unsafe animation payload")
	draft.set_timeline_events([
		{"id": "bad_vfx", "type": "vfx", "time": 0.0, "duration": 0.1, "visual": "https://example.com/vfx"}
	])
	_check(_contains_error_fragment(draft.validate(), "visual must be a safe lowercase token"), "Creator draft rejects unsafe VFX payload")
	draft.set_timeline_events([
		{"id": "bad_audio", "type": "audio", "time": 0.0, "duration": 0.1, "cue": "../../sound.wav"}
	])
	_check(_contains_error_fragment(draft.validate(), "cue must be a safe lowercase token"), "Creator draft rejects unsafe audio cue payload")
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
