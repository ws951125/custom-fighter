extends SceneTree

const CharacterRegistry = preload("res://game/core/character/character_registry.gd")
const CharacterDefinition = preload("res://game/core/character/character_definition.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := CharacterRegistry.new()
	var registry_errors := registry.load_default()
	_check(registry_errors.is_empty(), "official character registry validates: %s" % " | ".join(registry_errors))
	_check(registry.loaded, "character registry marks loaded")
	_check(registry.default_character_id == "ember_vanguard_001", "default character id loads")
	_check(registry.source_path_for_id("ember_vanguard_001") == "res://content/characters/ember_vanguard.sample.json", "default character source stays in approved root")
	_check(registry.source_path_for_id("storm_duelist_001") == "res://content/characters/storm_duelist.sample.json", "second character source stays in approved root")

	var ember := CharacterDefinition.new()
	var ember_errors := registry.load_character("ember_vanguard_001", ember)
	_check(ember_errors.is_empty() and ember.loaded, "default character resolves through registry")
	_check(ember.character_id == "ember_vanguard_001", "default registry file id matches")

	var storm := CharacterDefinition.new()
	var storm_errors := registry.load_character("storm_duelist_001", storm)
	_check(storm_errors.is_empty() and storm.loaded, "second reference character resolves through registry")
	_check(storm.character_id == "storm_duelist_001", "second character id loads")
	_check(storm.character_name == "Storm Duelist" and storm.archetype == "agile", "second character identity loads")
	_check(storm.max_hp == 90 and storm.max_mp == 120, "second character resources differ from default")
	_check(is_equal_approx(storm.move_speed, 405.0) and is_equal_approx(storm.depth_speed, 0.78), "second character movement tuning loads")
	_check(storm.visual_profile == "storm_violet", "second character visual profile loads")
	_check(storm.skill_id_for_slot("skill_1") == "training_bolt_001", "second character alternate projectile loadout loads")

	var unsafe := CharacterDefinition.new()
	var unsafe_errors := registry.load_character("../evil.gd", unsafe)
	_check(_contains_error(unsafe_errors, "character id must be a safe lowercase token"), "unsafe runtime character id rejected")

	var unknown := CharacterDefinition.new()
	var unknown_errors := registry.load_character("missing_character_001", unknown)
	_check(_contains_error(unknown_errors, "unknown character id: missing_character_001"), "unknown runtime character id rejected")

	var wrong_path_registry := CharacterRegistry.new()
	var wrong_path_errors := wrong_path_registry.load_from_file("res://content/characters/other.json")
	_check(_contains_error(wrong_path_errors, "character registry path must use the approved default path"), "non-approved registry path rejected")

	var arbitrary_file_data := _valid_registry_dictionary()
	arbitrary_file_data["characters"]["ember_vanguard_001"]["file"] = "../evil.gd"
	var arbitrary_file_registry := CharacterRegistry.new()
	var arbitrary_file_errors := arbitrary_file_registry.load_from_dictionary(arbitrary_file_data)
	_check(_contains_error(arbitrary_file_errors, "character registry file must be a safe .sample.json filename: ember_vanguard_001"), "arbitrary character file path rejected")

	var executable_data := _valid_registry_dictionary()
	executable_data["characters"]["ember_vanguard_001"]["script"] = "res://evil.gd"
	var executable_registry := CharacterRegistry.new()
	var executable_errors := executable_registry.load_from_dictionary(executable_data)
	_check(_contains_error(executable_errors, "unsupported character registry entry ember_vanguard_001 field: script"), "executable-style registry field rejected")

	var missing_default_data := _valid_registry_dictionary()
	missing_default_data["default_character"] = "missing_character_001"
	var missing_default_registry := CharacterRegistry.new()
	var missing_default_errors := missing_default_registry.load_from_dictionary(missing_default_data)
	_check(_contains_error(missing_default_errors, "default_character is not registered: missing_character_001"), "unregistered default character rejected")

	var mismatch_data := {
		"schema_version": 1,
		"default_character": "storm_duelist_001",
		"characters": {
			"storm_duelist_001": {"file": "ember_vanguard.sample.json"}
		}
	}
	var mismatch_registry := CharacterRegistry.new()
	var mismatch_registry_errors := mismatch_registry.load_from_dictionary(mismatch_data)
	_check(mismatch_registry_errors.is_empty() and mismatch_registry.loaded, "safe mismatch fixture registry parses")
	var mismatch_character := CharacterDefinition.new()
	var mismatch_errors := mismatch_registry.load_character("storm_duelist_001", mismatch_character)
	_check(_contains_error(mismatch_errors, "character id mismatch for registry entry storm_duelist_001: file contains ember_vanguard_001"), "registry/file character id mismatch rejected")
	_check(not mismatch_character.loaded, "mismatched character is not accepted as loaded")

	if failures == 0:
		print("CHARACTER_REGISTRY_TESTS_PASSED")
		quit(0)
		return
	printerr("CHARACTER_REGISTRY_TEST_FAILURES=%d" % failures)
	quit(1)

func _valid_registry_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"default_character": "ember_vanguard_001",
		"characters": {
			"ember_vanguard_001": {"file": "ember_vanguard.sample.json"},
			"storm_duelist_001": {"file": "storm_duelist.sample.json"}
		}
	}

func _contains_error(errors: PackedStringArray, expected: String) -> bool:
	for error in errors:
		if error == expected:
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
