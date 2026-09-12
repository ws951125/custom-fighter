extends SceneTree

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterAnimationMap = preload("res://game/core/character/character_animation_map.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ember := CharacterDefinition.new()
	var ember_errors := ember.load_from_file("res://content/characters/ember_vanguard.sample.json")
	_check(ember_errors.is_empty() and ember.loaded, "Ember character validates")
	_check(ember.animation_map == "ember_vanguard", "Ember animation map reference loads from CharacterDefinition")

	var ember_map := CharacterAnimationMap.new()
	var ember_map_errors := ember_map.load_from_id(ember.animation_map)
	_check(ember_map_errors.is_empty() and ember_map.loaded, "Ember animation map validates")
	_check(ember_map.map_id == "ember_vanguard", "Ember animation map id resolves")
	_check(ember_map.animation_id_for_semantic("ready") == "ember_ready", "ready semantic resolves")
	_check(ember_map.animation_id_for_semantic("attack_3") == "ember_attack_3", "attack semantic resolves")
	_check(ember_map.animation_id_for_semantic("skill_6") == "ember_skill_6", "skill semantic resolves")
	_check(ember_map.animation_id_for_semantic("unknown_state") == "ember_ready", "unknown runtime semantic falls back to ready")

	var storm := CharacterDefinition.new()
	var storm_errors := storm.load_from_file("res://content/characters/storm_duelist.sample.json")
	_check(storm_errors.is_empty() and storm.loaded, "Storm Duelist character validates")
	_check(storm.animation_map == "storm_duelist", "Storm Duelist animation map reference loads")

	var storm_map := CharacterAnimationMap.new()
	var storm_map_errors := storm_map.load_from_id(storm.animation_map)
	_check(storm_map_errors.is_empty() and storm_map.loaded, "Storm Duelist animation map validates")
	_check(storm_map.animation_id_for_semantic("ready") == "storm_ready", "Storm ready animation resolves")
	_check(storm_map.animation_id_for_semantic("skill_1") == "storm_skill_1", "Storm skill animation resolves")
	_check(
		storm_map.animation_id_for_semantic("ready") != ember_map.animation_id_for_semantic("ready"),
		"reference characters resolve distinct animation ids"
	)

	var unsafe_character_data := _valid_character_dictionary()
	unsafe_character_data["animation_map"] = "../evil.gd"
	var unsafe_character := CharacterDefinition.new()
	var unsafe_character_errors := unsafe_character.load_from_dictionary(unsafe_character_data)
	_check(
		_contains_error(unsafe_character_errors, "animation_map must be a safe lowercase reference token"),
		"unsafe CharacterDefinition animation map reference rejected"
	)

	var unsafe_reference := CharacterAnimationMap.new()
	var unsafe_reference_errors := unsafe_reference.load_from_id("../evil")
	_check(
		_contains_error(unsafe_reference_errors, "animation map reference must be a safe lowercase token"),
		"unsafe animation map file reference rejected"
	)

	var executable_data := _valid_animation_dictionary()
	executable_data["script"] = "res://evil.gd"
	var executable_map := CharacterAnimationMap.new()
	var executable_errors := executable_map.load_from_dictionary(executable_data)
	_check(
		_contains_error(executable_errors, "unsupported animation_map field: script"),
		"executable-style animation map field rejected"
	)

	var missing_data := _valid_animation_dictionary()
	missing_data["animations"].erase("attack_3")
	var missing_map := CharacterAnimationMap.new()
	var missing_errors := missing_map.load_from_dictionary(missing_data)
	_check(
		_contains_error(missing_errors, "missing required animation semantic: attack_3"),
		"missing required animation semantic rejected"
	)

	var unsafe_animation_data := _valid_animation_dictionary()
	unsafe_animation_data["animations"]["skill_1"] = "../evil.gd"
	var unsafe_animation_map := CharacterAnimationMap.new()
	var unsafe_animation_errors := unsafe_animation_map.load_from_dictionary(unsafe_animation_data)
	_check(
		_contains_error(unsafe_animation_errors, "animation id for skill_1 must be a safe lowercase token"),
		"unsafe animation id rejected"
	)

	if failures == 0:
		print("CHARACTER_ANIMATION_TESTS_PASSED")
		quit(0)
		return
	printerr("CHARACTER_ANIMATION_TEST_FAILURES=%d" % failures)
	quit(1)

func _valid_character_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "test_fighter_001",
		"name": "Test Fighter",
		"archetype": "balanced",
		"stats": {
			"max_hp": 100,
			"max_mp": 100,
			"move_speed": 360.0,
			"depth_speed": 0.72,
			"run_multiplier": 1.6,
			"guard_move_multiplier": 0.35
		},
		"skill_slots": {
			"skill_1": "fireball_001",
			"skill_2": "dash_slash_001",
			"skill_3": "arc_burst_001",
			"skill_4": "blade_rain_001",
			"skill_5": "battle_focus_001",
			"skill_6": "heavy_strike_001"
		},
		"visual_profile": "training_blue",
		"animation_map": "ember_vanguard"
	}

func _valid_animation_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "test_animation",
		"animations": {
			"ready": "test_ready",
			"walk": "test_walk",
			"run": "test_run",
			"jump": "test_jump",
			"dash": "test_dash",
			"guard": "test_guard",
			"attack_1": "test_attack_1",
			"attack_2": "test_attack_2",
			"attack_3": "test_attack_3",
			"skill_1": "test_skill_1",
			"skill_2": "test_skill_2",
			"skill_3": "test_skill_3",
			"skill_4": "test_skill_4",
			"skill_5": "test_skill_5",
			"skill_6": "test_skill_6"
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
