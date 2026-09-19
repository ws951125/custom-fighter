extends SceneTree

const CharacterPackageDefinition = preload("res://game/core/package/character_package_definition.gd")

func _init() -> void:
	var failures := PackedStringArray()
	_test_valid_round_trip(failures)
	_test_trap_duration_round_trip_shape(failures)
	_test_aura_duration_round_trip_shape(failures)
	_test_grab_common_field_round_trip_shape(failures)
	_test_summon_common_field_round_trip_shape(failures)
	_test_timeline_round_trip_shape(failures)
	_test_rejects_unsafe_timeline_event(failures)
	_test_rejects_schema_mismatch(failures)
	_test_rejects_package_character_id_mismatch(failures)
	_test_rejects_duplicate_skill_ids(failures)
	_test_rejects_unresolved_skill_slot(failures)
	_test_rejects_unsafe_package_id(failures)
	_test_rejects_unsafe_skill_reference(failures)
	_test_rejects_unknown_nested_field(failures)
	_test_rejects_tampered_nested_skill(failures)
	if failures.is_empty():
		print("CHARACTER_PACKAGE_TESTS_PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_valid_round_trip(failures: PackedStringArray) -> void:
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(_valid_package())
	_expect(errors.is_empty(), "valid package should load without errors", failures)
	_expect(package.is_valid(), "valid package should report loaded state", failures)

	var serialized: Dictionary = package.to_dictionary()
	_expect(str(serialized.get("package_id", "")) == "package_hero", "serialized package should retain package id", failures)
	var serialized_skills: Array = serialized.get("skills", [])
	_expect(serialized_skills.size() == 6, "serialized package should contain six referenced skill definitions", failures)
	if serialized_skills.size() == 6:
		_expect(str(serialized_skills[0].get("id", "")) == "pkg_area", "serialized skills should use deterministic id ordering", failures)

	var reloaded := CharacterPackageDefinition.new()
	var reload_errors: PackedStringArray = reloaded.load_from_dictionary(serialized)
	_expect(reload_errors.is_empty(), "serialized package should load again", failures)
	_expect(JSON.stringify(serialized) == JSON.stringify(reloaded.to_dictionary()), "package round trip should be deterministic", failures)

func _test_trap_duration_round_trip_shape(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	var skills: Array = data.get("skills", [])
	var trap_input: Dictionary = skills[0]
	trap_input["type"] = "trap"
	trap_input["speed"] = 0.0
	trap_input["range"] = 180.0
	trap_input["active"] = 0.12
	trap_input["hitbox_half_width"] = 62.0
	trap_input["hitbox_half_depth"] = 0.14
	trap_input["trap_duration"] = 6.5

	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(errors.is_empty(), "trap package should load with trap_duration", failures)

	var serialized: Dictionary = package.to_dictionary()
	var serialized_skills: Array = serialized.get("skills", [])
	var serialized_trap: Dictionary = {}
	for skill_value in serialized_skills:
		if skill_value is Dictionary:
			var skill_data: Dictionary = skill_value
			if str(skill_data.get("id", "")) == "pkg_projectile":
				serialized_trap = skill_data
			if str(skill_data.get("type", "")) != "trap":
				_expect(not skill_data.has("trap_duration"), "non-trap package skills should not serialize trap_duration", failures)

	_expect(not serialized_trap.is_empty(), "serialized package should retain the authored trap skill", failures)
	_expect(abs(float(serialized_trap.get("trap_duration", 0.0)) - 6.5) < 0.001, "serialized trap should retain trap_duration", failures)

	var reloaded := CharacterPackageDefinition.new()
	var reload_errors: PackedStringArray = reloaded.load_from_dictionary(serialized)
	_expect(reload_errors.is_empty(), "serialized trap package should load again", failures)
	_expect(JSON.stringify(serialized) == JSON.stringify(reloaded.to_dictionary()), "trap package round trip should be deterministic", failures)

func _test_aura_duration_round_trip_shape(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	var skills: Array = data.get("skills", [])
	var aura_input: Dictionary = skills[0]
	aura_input["type"] = "aura"
	aura_input["speed"] = 0.0
	aura_input["range"] = 0.0
	aura_input["active"] = 0.12
	aura_input["hitbox_half_width"] = 120.0
	aura_input["hitbox_half_depth"] = 0.18
	aura_input["aura_duration"] = 4.5

	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(errors.is_empty(), "aura package should load with aura_duration", failures)

	var serialized: Dictionary = package.to_dictionary()
	var serialized_skills: Array = serialized.get("skills", [])
	var serialized_aura: Dictionary = {}
	for skill_value in serialized_skills:
		if skill_value is Dictionary:
			var skill_data: Dictionary = skill_value
			if str(skill_data.get("id", "")) == "pkg_projectile":
				serialized_aura = skill_data
			if str(skill_data.get("type", "")) != "aura":
				_expect(not skill_data.has("aura_duration"), "non-aura package skills should not serialize aura_duration", failures)

	_expect(not serialized_aura.is_empty(), "serialized package should retain the authored aura skill", failures)
	_expect(abs(float(serialized_aura.get("aura_duration", 0.0)) - 4.5) < 0.001, "serialized aura should retain aura_duration", failures)

	var reloaded := CharacterPackageDefinition.new()
	var reload_errors: PackedStringArray = reloaded.load_from_dictionary(serialized)
	_expect(reload_errors.is_empty(), "serialized aura package should load again", failures)
	_expect(JSON.stringify(serialized) == JSON.stringify(reloaded.to_dictionary()), "aura package round trip should be deterministic", failures)

func _test_grab_common_field_round_trip_shape(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	var skills: Array = data.get("skills", [])
	var grab_input: Dictionary = skills[0]
	grab_input["type"] = "grab"
	grab_input["speed"] = 0.0
	grab_input["range"] = 120.0
	grab_input["active"] = 0.65
	grab_input["knockback"] = 56.0
	grab_input["hitbox_half_width"] = 54.0
	grab_input["hitbox_half_depth"] = 0.14
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(errors.is_empty(), "grab package should load using common bounded fields", failures)
	var serialized: Dictionary = package.to_dictionary()
	var serialized_grab: Dictionary = {}
	for skill_value in serialized.get("skills", []):
		if skill_value is Dictionary:
			var skill_data: Dictionary = skill_value
			if str(skill_data.get("type", "")) == "grab":
				serialized_grab = skill_data
	_expect(not serialized_grab.is_empty(), "serialized package should retain authored grab skill", failures)
	_expect(abs(float(serialized_grab.get("range", 0.0)) - 120.0) < 0.001, "serialized grab should retain bounded source range", failures)
	_expect(abs(float(serialized_grab.get("active", 0.0)) - 0.65) < 0.001, "serialized grab should retain finite hold window", failures)
	_expect(abs(float(serialized_grab.get("knockback", 0.0)) - 56.0) < 0.001, "serialized grab should retain bounded target offset", failures)
	var reloaded := CharacterPackageDefinition.new()
	var reload_errors: PackedStringArray = reloaded.load_from_dictionary(serialized)
	_expect(reload_errors.is_empty(), "serialized grab package should load again", failures)
	_expect(JSON.stringify(serialized) == JSON.stringify(reloaded.to_dictionary()), "grab package round trip should be deterministic", failures)


func _test_summon_common_field_round_trip_shape(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	var skills: Array = data.get("skills", [])
	var summon_input: Dictionary = skills[0]
	summon_input["type"] = "summon"
	summon_input["speed"] = 320.0
	summon_input["range"] = 150.0
	summon_input["active"] = 3.0
	summon_input["knockback"] = 0.0
	summon_input["hitbox_half_width"] = 38.0
	summon_input["hitbox_half_depth"] = 0.14
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(errors.is_empty(), "summon package should load using common bounded fields", failures)
	var serialized: Dictionary = package.to_dictionary()
	var serialized_summon: Dictionary = {}
	for skill_value in serialized.get("skills", []):
		if skill_value is Dictionary:
			var skill_data: Dictionary = skill_value
			if str(skill_data.get("type", "")) == "summon":
				serialized_summon = skill_data
	_expect(not serialized_summon.is_empty(), "serialized package should retain authored summon skill", failures)
	_expect(abs(float(serialized_summon.get("range", 0.0)) - 150.0) < 0.001, "serialized summon should retain bounded spawn range", failures)
	_expect(abs(float(serialized_summon.get("speed", 0.0)) - 320.0) < 0.001, "serialized summon should retain bounded actor speed", failures)
	_expect(abs(float(serialized_summon.get("active", 0.0)) - 3.0) < 0.001, "serialized summon should retain finite actor lifetime", failures)
	_expect(not serialized_summon.has("script") and not serialized_summon.has("scene") and not serialized_summon.has("path"), "summon package contains no executable actor metadata", failures)
	var reloaded := CharacterPackageDefinition.new()
	var reload_errors: PackedStringArray = reloaded.load_from_dictionary(serialized)
	_expect(reload_errors.is_empty(), "serialized summon package should load again", failures)
	_expect(JSON.stringify(serialized) == JSON.stringify(reloaded.to_dictionary()), "summon package round trip should be deterministic", failures)


func _test_timeline_round_trip_shape(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	var skills: Array = data.get("skills", [])
	var authored_skill: Dictionary = skills[0]
	authored_skill["timeline"] = {
		"schema_version": 1,
		"events": [
			{"id": "comp_anim", "type": "animation", "time": 0.0, "duration": 1.2, "animation": "skill_3"},
			{"id": "comp_vfx", "type": "vfx", "time": 0.1, "duration": 1.0, "visual": "package_impact"},
			{"id": "comp_hitbox", "type": "hitbox", "time": 0.2, "duration": 0.9, "half_width": 40.0, "half_depth": 0.12, "offset_x": 24.0, "offset_depth": -0.02},
			{"id": "comp_audio", "type": "audio", "time": 0.3, "duration": 0.0, "cue": "skill_cast"},
			{"id": "comp_hurtbox", "type": "hurtbox", "time": 0.4, "duration": 0.7, "half_width": 22.0, "half_depth": 0.09, "offset_x": -6.0, "offset_depth": 0.03}
		]
	}

	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(errors.is_empty(), "package should accept validated optional timeline", failures)

	var serialized: Dictionary = package.to_dictionary()
	var serialized_skills: Array = serialized.get("skills", [])
	var timeline_skill: Dictionary = {}
	var non_timeline_count := 0
	for skill_value in serialized_skills:
		if skill_value is Dictionary:
			var skill_data: Dictionary = skill_value
			if str(skill_data.get("id", "")) == "pkg_projectile":
				timeline_skill = skill_data
			elif not skill_data.has("timeline"):
				non_timeline_count += 1

	_expect(not timeline_skill.is_empty(), "serialized package should retain timeline skill", failures)
	_expect(timeline_skill.has("timeline"), "authored timeline should serialize conditionally", failures)
	var timeline: Dictionary = timeline_skill.get("timeline", {})
	var events: Array = timeline.get("events", [])
	_expect(events.size() == 5, "serialized timeline should retain all composed events", failures)
	if events.size() == 5:
		_expect(str(events[0].get("type", "")) == "animation", "timeline event order should survive package serialization", failures)
		_expect(str(events[4].get("type", "")) == "hurtbox", "timeline tail should survive package serialization", failures)
	_expect(non_timeline_count == 5, "legacy package skills without timeline should keep historical shape", failures)

	var reloaded := CharacterPackageDefinition.new()
	var reload_errors: PackedStringArray = reloaded.load_from_dictionary(serialized)
	_expect(reload_errors.is_empty(), "serialized timeline package should load again", failures)
	_expect(JSON.stringify(serialized) == JSON.stringify(reloaded.to_dictionary()), "timeline package round trip should be deterministic", failures)

func _test_rejects_unsafe_timeline_event(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	var skills: Array = data.get("skills", [])
	var authored_skill: Dictionary = skills[0]
	authored_skill["timeline"] = {
		"schema_version": 1,
		"events": [
			{"id": "unsafe_script", "type": "script", "time": 0.0, "duration": 0.0}
		]
	}
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "unsupported timeline event type: script"), "package timeline must reject executable event types", failures)

func _test_rejects_schema_mismatch(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	data["schema_version"] = 99
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "unsupported package schema_version"), "unsupported package schema must fail closed", failures)

func _test_rejects_package_character_id_mismatch(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	data["package_id"] = "different_package"
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "package_id must match character id"), "package id must match embedded character id", failures)

func _test_rejects_duplicate_skill_ids(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	var skills: Array = data.get("skills", [])
	skills.append(skills[0].duplicate(true))
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "duplicate skill id"), "duplicate package skill ids must be rejected", failures)

func _test_rejects_unresolved_skill_slot(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	var character: Dictionary = data.get("character", {})
	var slots: Dictionary = character.get("skill_slots", {})
	slots["skill_1"] = "missing_skill"
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "skill_1 references missing package skill"), "every character skill slot must resolve inside the package", failures)

func _test_rejects_unsafe_package_id(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	data["package_id"] = "../package_hero"
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "package_id must be a safe lowercase reference token"), "unsafe package id must be rejected", failures)

func _test_rejects_unsafe_skill_reference(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	var skills: Array = data.get("skills", [])
	var skill: Dictionary = skills[0]
	skill["visual"] = "../../payload.tres"
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "visual must be a safe lowercase reference token"), "skill visual references must not accept arbitrary paths", failures)

func _test_rejects_unknown_nested_field(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	var skills: Array = data.get("skills", [])
	var skill: Dictionary = skills[0]
	skill["script_path"] = "res://unsafe.gd"
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "unsupported skills[0] field: script_path"), "unknown nested fields must fail closed", failures)

func _test_rejects_tampered_nested_skill(failures: PackedStringArray) -> void:
	var data: Dictionary = _valid_package()
	var skills: Array = data.get("skills", [])
	var skill: Dictionary = skills[0]
	skill["damage"] = -500
	var package := CharacterPackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "damage must be non-negative"), "nested skill data must be revalidated through SkillDefinition", failures)

func _valid_package() -> Dictionary:
	return {
		"schema_version": 1,
		"package_id": "package_hero",
		"package_version": 1,
		"character": {
			"schema_version": 1,
			"id": "package_hero",
			"name": "Package Hero",
			"archetype": "balanced",
			"stats": {
				"max_hp": 140,
				"max_mp": 120,
				"move_speed": 380.0,
				"depth_speed": 0.72,
				"run_multiplier": 1.6,
				"guard_move_multiplier": 0.35
			},
			"skill_slots": {
				"skill_1": "pkg_projectile",
				"skill_2": "pkg_dash",
				"skill_3": "pkg_area",
				"skill_4": "pkg_formation",
				"skill_5": "pkg_buff",
				"skill_6": "pkg_melee"
			},
			"visual_profile": "training_blue",
			"animation_map": "ember_vanguard"
		},
		"skills": [
			_skill("pkg_projectile", "projectile"),
			_skill("pkg_melee", "melee"),
			_skill("pkg_buff", "buff"),
			_skill("pkg_dash", "dash"),
			_skill("pkg_formation", "formation"),
			_skill("pkg_area", "area")
		]
	}

func _skill(skill_id: String, skill_type: String) -> Dictionary:
	return {
		"schema_version": 1,
		"id": skill_id,
		"name": skill_id,
		"type": skill_type,
		"damage": 12,
		"mp_cost": 8,
		"cooldown": 0.8,
		"startup": 0.1,
		"active": 0.5,
		"recovery": 0.15,
		"speed": 500.0,
		"range": 360.0,
		"hitstun": 0.15,
		"knockback": 120.0,
		"hitbox_half_width": 24.0,
		"hitbox_half_depth": 0.08,
		"formation_count": 3,
		"formation_spacing": 48.0,
		"formation_interval": 0.1,
		"formation_offset": 24.0,
		"buff_duration": 2.0,
		"move_speed_multiplier": 1.1,
		"basic_attack_damage_multiplier": 1.1,
		"visual": "package_visual",
		"impact_visual": "package_impact"
	}

func _contains(errors: PackedStringArray, text: String) -> bool:
	for error in errors:
		if str(error).contains(text):
			return true
	return false

func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
