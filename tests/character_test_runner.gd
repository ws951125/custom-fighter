extends SceneTree

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterMovementTuning = preload("res://game/core/character/character_movement_tuning.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var character := CharacterDefinition.new()
	var errors := character.load_from_file("res://content/characters/ember_vanguard.sample.json")
	_check(errors.is_empty(), "official character validates: %s" % " | ".join(errors))
	_check(character.loaded, "valid character marks loaded")
	_check(character.character_id == "ember_vanguard_001", "character id loads")
	_check(character.character_name == "Ember Vanguard", "character name loads")
	_check(character.archetype == "balanced", "character archetype loads")
	_check(character.max_hp == 100 and character.max_mp == 100, "resources load")
	_check(is_equal_approx(character.move_speed, 360.0), "move speed loads")
	_check(is_equal_approx(character.depth_speed, 0.72), "depth speed loads")
	_check(is_equal_approx(character.run_multiplier, 1.6), "run multiplier loads")
	_check(is_equal_approx(character.guard_move_multiplier, 0.35), "guard movement multiplier loads")
	_check(character.skill_id_for_slot("skill_1") == "fireball_001", "skill slot 1 loads")
	_check(character.skill_id_for_slot("skill_6") == "heavy_strike_001", "skill slot 6 loads")
	_test_movement_tuning(character)

	var missing := CharacterDefinition.new()
	var missing_errors := missing.load_from_dictionary({"schema_version": 1})
	_check(not missing_errors.is_empty() and not missing.loaded, "missing fields rejected")

	var executable := _valid_dictionary()
	executable["script"] = "res://evil.gd"
	var executable_character := CharacterDefinition.new()
	var executable_errors := executable_character.load_from_dictionary(executable)
	_check(_contains_error(executable_errors, "unsupported character field: script"), "script field rejected")

	var unsafe_slot := _valid_dictionary()
	unsafe_slot["skill_slots"]["skill_1"] = "../evil.gd"
	var unsafe_character := CharacterDefinition.new()
	var unsafe_errors := unsafe_character.load_from_dictionary(unsafe_slot)
	_check(_contains_error(unsafe_errors, "skill_1 must contain a safe skill id token"), "unsafe skill reference rejected")

	var invalid_stats := _valid_dictionary()
	invalid_stats["stats"]["max_hp"] = 0
	invalid_stats["stats"]["move_speed"] = -10
	var stats_character := CharacterDefinition.new()
	var stats_errors := stats_character.load_from_dictionary(invalid_stats)
	_check(not stats_errors.is_empty() and not stats_character.loaded, "invalid stat ranges rejected")

	var wrong_schema := _valid_dictionary()
	wrong_schema["schema_version"] = 99
	var schema_character := CharacterDefinition.new()
	var schema_errors := schema_character.load_from_dictionary(wrong_schema)
	_check(_contains_error(schema_errors, "unsupported schema_version: 99"), "unsupported schema rejected")

	if failures == 0:
		print("CHARACTER_TESTS_PASSED")
		quit(0)
		return
	printerr("CHARACTER_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_movement_tuning(baseline_character) -> void:
	_check(
		is_equal_approx(CharacterMovementTuning.horizontal_ratio(baseline_character, false, false), 1.0),
		"balanced character preserves baseline horizontal movement"
	)
	_check(
		is_equal_approx(CharacterMovementTuning.depth_ratio(baseline_character, false, false), 1.0),
		"balanced character preserves baseline depth movement"
	)

	var baseline_delta := Vector2(36.0, 0.072)
	var baseline_adjusted := CharacterMovementTuning.adjust_frame_delta(
		baseline_delta,
		baseline_character,
		false,
		false
	)
	_check(baseline_adjusted.is_equal_approx(baseline_delta), "balanced movement delta remains unchanged")

	var tuned_data := _valid_dictionary()
	tuned_data["stats"]["move_speed"] = 270.0
	tuned_data["stats"]["depth_speed"] = 0.54
	tuned_data["stats"]["run_multiplier"] = 1.2
	tuned_data["stats"]["guard_move_multiplier"] = 0.70
	var tuned_character := CharacterDefinition.new()
	var tuned_errors := tuned_character.load_from_dictionary(tuned_data)
	_check(tuned_errors.is_empty() and tuned_character.loaded, "alternate movement tuning validates")
	_check(
		is_equal_approx(CharacterMovementTuning.horizontal_ratio(tuned_character, false, false), 0.75),
		"move_speed changes horizontal runtime ratio"
	)
	_check(
		is_equal_approx(CharacterMovementTuning.depth_ratio(tuned_character, false, false), 0.75),
		"depth_speed changes depth runtime ratio"
	)
	_check(
		is_equal_approx(CharacterMovementTuning.horizontal_ratio(tuned_character, true, false), 0.5625),
		"run_multiplier changes running runtime ratio"
	)
	_check(
		is_equal_approx(CharacterMovementTuning.horizontal_ratio(tuned_character, false, true), 1.5),
		"guard_move_multiplier changes guarded runtime ratio"
	)
	var tuned_adjusted := CharacterMovementTuning.adjust_frame_delta(
		baseline_delta,
		tuned_character,
		false,
		false
	)
	_check(
		tuned_adjusted.is_equal_approx(Vector2(27.0, 0.054)),
		"alternate CharacterDefinition changes actual movement delta"
	)
	_check(
		is_equal_approx(CharacterMovementTuning.horizontal_ratio(null, false, false), 1.0),
		"missing character uses safe movement fallback"
	)

func _valid_dictionary() -> Dictionary:
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
		"visual_profile": "training_blue"
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
