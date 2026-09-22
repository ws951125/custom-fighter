extends SceneTree

const StageDefinition = preload("res://game/core/stage/stage_definition.gd")
const StageRegistry = preload("res://game/core/stage/stage_registry.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_builtin_registry()
	_test_valid_stage_contract()
	_test_unknown_and_executable_fields_fail_closed()
	_test_presentation_tokens_fail_closed()
	_test_bounds_and_spawn_rules()
	if failures == 0:
		print("STAGE_DEFINITION_TESTS_PASSED")
		quit(0)
		return
	printerr("STAGE_DEFINITION_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_builtin_registry() -> void:
	var ids: PackedStringArray = StageRegistry.stage_ids()
	_check(ids == PackedStringArray(["sunset_court", "training_arena"]), "stage registry ordering is deterministic")
	_check(StageRegistry.DEFAULT_STAGE_ID == "training_arena", "training arena remains bounded default")
	_check(StageRegistry.normalize_stage_id("SUNSET_COURT") == "sunset_court", "allow-listed stage id normalizes")
	_check(StageRegistry.normalize_stage_id("missing_stage") == "training_arena", "unknown stage id falls back to bounded default")
	_check(StageRegistry.display_label("sunset_court") == "Sunset Court", "stage registry exposes stable display label")

	var training := StageDefinition.new()
	var training_errors: PackedStringArray = StageRegistry.load_stage("training_arena", training)
	_check(training_errors.is_empty() and training.loaded, "training stage loads")
	_check(is_equal_approx(training.arena_margin_x, 90.0), "training stage preserves legacy arena margin")
	_check(is_equal_approx(training.player_spawn_x_ratio, 0.22), "training player spawn is bounded normalized data")
	_check(is_equal_approx(training.opponent_spawn_x_ratio, 0.67), "training opponent spawn is bounded normalized data")
	_check(training.background_token == "training_blue", "training background uses allow-listed token")
	_check(training.floor_token == "training_grid", "training floor uses allow-listed token")

	var sunset := StageDefinition.new()
	var sunset_errors: PackedStringArray = StageRegistry.load_stage("sunset_court", sunset)
	_check(sunset_errors.is_empty() and sunset.loaded, "second built-in stage loads")
	_check(sunset.background_token == "sunset_court" and sunset.floor_token == "stone_ring", "second stage uses declarative presentation tokens")

	var unknown := StageDefinition.new()
	var unknown_errors: PackedStringArray = StageRegistry.load_stage("https://evil.invalid/stage", unknown)
	_check(_contains_fragment(unknown_errors, "unknown stage id"), "unknown/external stage id fails closed")
	_check(not unknown.loaded, "unknown registry stage never marks target loaded")

func _test_valid_stage_contract() -> void:
	var stage := StageDefinition.new()
	var raw := _valid_stage_dictionary()
	var errors: PackedStringArray = stage.load_from_dictionary(raw)
	_check(errors.is_empty() and stage.loaded, "valid stage contract loads")
	_check(stage.to_dictionary() == raw, "stage contract round-trips canonical declarative data")

func _test_unknown_and_executable_fields_fail_closed() -> void:
	var with_script := _valid_stage_dictionary()
	with_script["script"] = "res://unsafe.gd"
	var scripted := StageDefinition.new()
	var script_errors: PackedStringArray = scripted.load_from_dictionary(with_script)
	_check(_contains_fragment(script_errors, "unknown stage field: script"), "script field fails closed")
	_check(not scripted.loaded, "script field cannot partially load stage")

	var with_callback := _valid_stage_dictionary()
	with_callback["callback"] = "run_me"
	var callback_stage := StageDefinition.new()
	var callback_errors: PackedStringArray = callback_stage.load_from_dictionary(with_callback)
	_check(_contains_fragment(callback_errors, "unknown stage field: callback"), "callback field fails closed")

	var unsafe_id := _valid_stage_dictionary()
	unsafe_id["id"] = "../unsafe_stage"
	var unsafe_id_stage := StageDefinition.new()
	var unsafe_id_errors: PackedStringArray = unsafe_id_stage.load_from_dictionary(unsafe_id)
	_check(_contains_fragment(unsafe_id_errors, "invalid stage id"), "unsafe stage id fails closed")

func _test_presentation_tokens_fail_closed() -> void:
	var external_background := _valid_stage_dictionary()
	external_background["background_token"] = "https://example.com/bg.png"
	var external_stage := StageDefinition.new()
	var external_errors: PackedStringArray = external_stage.load_from_dictionary(external_background)
	_check(_contains_fragment(external_errors, "unsupported background_token"), "external background URL fails closed")

	var resource_floor := _valid_stage_dictionary()
	resource_floor["floor_token"] = "res://content/floor.png"
	var resource_stage := StageDefinition.new()
	var resource_errors: PackedStringArray = resource_stage.load_from_dictionary(resource_floor)
	_check(_contains_fragment(resource_errors, "unsupported floor_token"), "resource path floor fails closed")

func _test_bounds_and_spawn_rules() -> void:
	var low_margin := _valid_stage_dictionary()
	low_margin["arena_margin_x"] = 20.0
	var low_margin_stage := StageDefinition.new()
	var low_margin_errors: PackedStringArray = low_margin_stage.load_from_dictionary(low_margin)
	_check(_contains_fragment(low_margin_errors, "arena_margin_x"), "unsafe arena margin fails closed")

	var invalid_depth := _valid_stage_dictionary()
	invalid_depth["player_spawn_depth"] = 1.2
	var invalid_depth_stage := StageDefinition.new()
	var invalid_depth_errors: PackedStringArray = invalid_depth_stage.load_from_dictionary(invalid_depth)
	_check(_contains_fragment(invalid_depth_errors, "player_spawn_depth"), "spawn depth outside normalized range fails closed")

	var crossed_spawns := _valid_stage_dictionary()
	crossed_spawns["player_spawn_x_ratio"] = 0.60
	crossed_spawns["opponent_spawn_x_ratio"] = 0.65
	var crossed_stage := StageDefinition.new()
	var crossed_errors: PackedStringArray = crossed_stage.load_from_dictionary(crossed_spawns)
	_check(_contains_fragment(crossed_errors, "horizontal separation"), "insufficient spawn separation fails closed")

func _valid_stage_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "test_stage",
		"display_name": "Test Stage",
		"arena_margin_x": 100.0,
		"player_spawn_x_ratio": 0.24,
		"player_spawn_depth": 0.60,
		"opponent_spawn_x_ratio": 0.72,
		"opponent_spawn_depth": 0.54,
		"background_token": "training_blue",
		"floor_token": "training_grid"
	}

func _contains_fragment(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if str(error).contains(fragment):
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
