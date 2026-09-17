extends SceneTree

const CharacterPackageDefinition = preload("res://game/core/package/character_package_definition.gd")

func _init() -> void:
	var failures := PackedStringArray()
	_test_valid_round_trip(failures)
	_test_trap_duration_round_trip_shape(failures)
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
