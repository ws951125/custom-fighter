extends SceneTree

const GameModeDefinition = preload("res://game/core/mode/game_mode_definition.gd")
const GameModeRegistry = preload("res://game/core/mode/game_mode_registry.gd")
const CompetitiveRulesetDefinition = preload("res://game/core/mode/competitive_ruleset_definition.gd")
const CompetitiveRulesetRegistry = preload("res://game/core/mode/competitive_ruleset_registry.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_builtin_registries()
	_test_game_mode_contract()
	_test_game_mode_fail_closed()
	_test_ruleset_contract()
	_test_ruleset_fail_closed()
	_test_version_and_unknown_registry_fail_closed()
	_test_deterministic_round_trip()
	if failures == 0:
		print("GAME_MODE_RULESET_TESTS_PASSED")
		quit(0)
		return
	printerr("GAME_MODE_RULESET_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_builtin_registries() -> void:
	var mode_ids: PackedStringArray = GameModeRegistry.mode_ids()
	_check(
		mode_ids == PackedStringArray(["competitive_hosted", "competitive_local", "sandbox", "single_player"]),
		"game mode registry ordering is deterministic"
	)
	_check(GameModeRegistry.DEFAULT_MODE_ID == "sandbox", "sandbox remains non-competitive default")

	var ruleset_ids: PackedStringArray = CompetitiveRulesetRegistry.ruleset_ids()
	_check(
		ruleset_ids == PackedStringArray(["competitive_standard", "sandbox_default", "single_player_default"]),
		"ruleset registry ordering is deterministic"
	)

	var sandbox := GameModeDefinition.new()
	var sandbox_errors: PackedStringArray = GameModeRegistry.load_mode("sandbox", sandbox)
	_check(sandbox_errors.is_empty() and sandbox.loaded, "sandbox mode loads")
	_check(sandbox.mode_family == "sandbox", "sandbox family is explicit")
	_check(sandbox.authority_policy == "local_authoritative", "sandbox remains locally authoritative")
	_check(sandbox.power_budget_id == "sandbox_safe_limits", "sandbox uses safe schema envelope rather than competitive budget")

	var single_player := GameModeDefinition.new()
	var single_player_errors: PackedStringArray = GameModeRegistry.load_mode("single_player", single_player)
	_check(single_player_errors.is_empty() and single_player.loaded, "single-player mode loads")
	_check(single_player.ruleset_id == "single_player_default", "single-player owns explicit ruleset identity")

	var competitive_local := GameModeDefinition.new()
	var competitive_local_errors: PackedStringArray = GameModeRegistry.load_mode("competitive_local", competitive_local)
	_check(competitive_local_errors.is_empty() and competitive_local.loaded, "local competitive mode loads")
	_check(competitive_local.mode_family == "competitive", "competitive mode family is explicit")
	_check(competitive_local.ruleset_id == "competitive_standard", "competitive mode uses allow-listed ruleset")
	_check(competitive_local.power_budget_id == "competitive_standard_v1", "competitive mode uses competitive power budget")
	_check(competitive_local.authority_policy == "local_authoritative", "local competitive simulation remains authority-owned")

	var competitive_hosted := GameModeDefinition.new()
	var competitive_hosted_errors: PackedStringArray = GameModeRegistry.load_mode("competitive_hosted", competitive_hosted)
	_check(competitive_hosted_errors.is_empty() and competitive_hosted.loaded, "hosted competitive contract loads")
	_check(competitive_hosted.authority_policy == "host_authoritative", "hosted competitive contract never declares client authority")

	var competitive_ruleset := CompetitiveRulesetDefinition.new()
	var ruleset_errors: PackedStringArray = CompetitiveRulesetRegistry.load_ruleset(
		"competitive_standard",
		1,
		competitive_ruleset
	)
	_check(ruleset_errors.is_empty() and competitive_ruleset.loaded, "competitive standard ruleset loads")
	_check(competitive_ruleset.power_budget_id == competitive_local.power_budget_id, "mode and referenced ruleset power budget agree")
	_check(competitive_ruleset.determinism_policy_id == "deterministic_v1", "competitive ruleset requires deterministic policy")

func _test_game_mode_contract() -> void:
	var mode := GameModeDefinition.new()
	var raw: Dictionary = _valid_mode_dictionary()
	var errors: PackedStringArray = mode.load_from_dictionary(raw)
	_check(errors.is_empty() and mode.loaded, "valid game mode contract loads")
	_check(mode.to_dictionary() == raw, "game mode contract round-trips canonical data")

func _test_game_mode_fail_closed() -> void:
	var with_script: Dictionary = _valid_mode_dictionary()
	with_script["script"] = "res://unsafe.gd"
	var scripted := GameModeDefinition.new()
	var script_errors: PackedStringArray = scripted.load_from_dictionary(with_script)
	_check(_contains_fragment(script_errors, "unknown game mode field: script"), "game mode script field fails closed")
	_check(not scripted.loaded, "unknown executable-style field cannot partially load game mode")

	var unsafe_ruleset: Dictionary = _valid_mode_dictionary()
	unsafe_ruleset["ruleset_id"] = "https://evil.invalid/rules"
	var unsafe_ruleset_mode := GameModeDefinition.new()
	var unsafe_ruleset_errors: PackedStringArray = unsafe_ruleset_mode.load_from_dictionary(unsafe_ruleset)
	_check(_contains_fragment(unsafe_ruleset_errors, "unsupported game mode ruleset_id"), "unknown/external ruleset id fails closed")

	var mismatched_budget: Dictionary = _valid_mode_dictionary()
	mismatched_budget["power_budget_id"] = "sandbox_safe_limits"
	var mismatched_budget_mode := GameModeDefinition.new()
	var mismatched_budget_errors: PackedStringArray = mismatched_budget_mode.load_from_dictionary(mismatched_budget)
	_check(_contains_fragment(mismatched_budget_errors, "competitive mode must use"), "competitive mode cannot downgrade to sandbox budget")

	var hosted_sandbox: Dictionary = _valid_mode_dictionary()
	hosted_sandbox["id"] = "sandbox_test"
	hosted_sandbox["display_name"] = "Sandbox Test"
	hosted_sandbox["mode_family"] = "sandbox"
	hosted_sandbox["ruleset_id"] = "sandbox_default"
	hosted_sandbox["power_budget_id"] = "sandbox_safe_limits"
	hosted_sandbox["authority_policy"] = "host_authoritative"
	var hosted_sandbox_mode := GameModeDefinition.new()
	var hosted_sandbox_errors: PackedStringArray = hosted_sandbox_mode.load_from_dictionary(hosted_sandbox)
	_check(_contains_fragment(hosted_sandbox_errors, "sandbox mode must remain local_authoritative"), "sandbox cannot silently switch authority policy")

	var non_boolean: Dictionary = _valid_mode_dictionary()
	non_boolean["allows_custom_content"] = "true"
	var non_boolean_mode := GameModeDefinition.new()
	var non_boolean_errors: PackedStringArray = non_boolean_mode.load_from_dictionary(non_boolean)
	_check(_contains_fragment(non_boolean_errors, "allows_custom_content must be boolean"), "custom-content policy requires real boolean")

func _test_ruleset_contract() -> void:
	var ruleset := CompetitiveRulesetDefinition.new()
	var raw: Dictionary = _valid_ruleset_dictionary()
	var errors: PackedStringArray = ruleset.load_from_dictionary(raw)
	_check(errors.is_empty() and ruleset.loaded, "valid competitive ruleset loads")
	_check(ruleset.to_dictionary() == raw, "competitive ruleset round-trips canonical data")

func _test_ruleset_fail_closed() -> void:
	var with_callback: Dictionary = _valid_ruleset_dictionary()
	with_callback["callback"] = "bypass_budget"
	var callback_ruleset := CompetitiveRulesetDefinition.new()
	var callback_errors: PackedStringArray = callback_ruleset.load_from_dictionary(with_callback)
	_check(_contains_fragment(callback_errors, "unknown competitive ruleset field: callback"), "ruleset callback field fails closed")

	var unknown_budget: Dictionary = _valid_ruleset_dictionary()
	unknown_budget["power_budget_id"] = "unlimited_damage"
	var budget_ruleset := CompetitiveRulesetDefinition.new()
	var budget_errors: PackedStringArray = budget_ruleset.load_from_dictionary(unknown_budget)
	_check(_contains_fragment(budget_errors, "unsupported power_budget_id"), "unknown power budget fails closed")

	var unknown_character_policy: Dictionary = _valid_ruleset_dictionary()
	unknown_character_policy["character_constraints_id"] = "../unsafe"
	var character_ruleset := CompetitiveRulesetDefinition.new()
	var character_errors: PackedStringArray = character_ruleset.load_from_dictionary(unknown_character_policy)
	_check(_contains_fragment(character_errors, "unsupported character_constraints_id"), "unknown character constraints fail closed")

	var unknown_determinism: Dictionary = _valid_ruleset_dictionary()
	unknown_determinism["determinism_policy_id"] = "randomized_v1"
	var determinism_ruleset := CompetitiveRulesetDefinition.new()
	var determinism_errors: PackedStringArray = determinism_ruleset.load_from_dictionary(unknown_determinism)
	_check(_contains_fragment(determinism_errors, "unsupported determinism_policy_id"), "non-deterministic policy fails closed")

func _test_version_and_unknown_registry_fail_closed() -> void:
	var unknown_mode := GameModeDefinition.new()
	var unknown_mode_errors: PackedStringArray = GameModeRegistry.load_mode("competitive_unlimited", unknown_mode)
	_check(_contains_fragment(unknown_mode_errors, "unknown game mode id"), "unknown game mode fails closed")
	_check(not unknown_mode.loaded, "unknown game mode target remains unloaded")

	var wrong_version := CompetitiveRulesetDefinition.new()
	var wrong_version_errors: PackedStringArray = CompetitiveRulesetRegistry.load_ruleset(
		"competitive_standard",
		2,
		wrong_version
	)
	_check(_contains_fragment(wrong_version_errors, "unsupported competitive ruleset version"), "unsupported ruleset version fails closed")
	_check(not wrong_version.loaded, "unsupported ruleset version target remains unloaded")

	var unknown_ruleset := CompetitiveRulesetDefinition.new()
	var unknown_ruleset_errors: PackedStringArray = CompetitiveRulesetRegistry.load_ruleset(
		"https://evil.invalid/rules",
		1,
		unknown_ruleset
	)
	_check(_contains_fragment(unknown_ruleset_errors, "unknown competitive ruleset id"), "unknown/external ruleset registry id fails closed")
	_check(not unknown_ruleset.loaded, "unknown ruleset target remains unloaded")

func _test_deterministic_round_trip() -> void:
	var first_mode := GameModeDefinition.new()
	var second_mode := GameModeDefinition.new()
	var first_errors: PackedStringArray = GameModeRegistry.load_mode("competitive_local", first_mode)
	var second_errors: PackedStringArray = GameModeRegistry.load_mode("competitive_local", second_mode)
	_check(first_errors.is_empty() and second_errors.is_empty(), "repeated competitive mode loads succeed")
	_check(first_mode.to_dictionary() == second_mode.to_dictionary(), "same game mode input produces deterministic canonical output")

	var first_ruleset := CompetitiveRulesetDefinition.new()
	var second_ruleset := CompetitiveRulesetDefinition.new()
	var first_ruleset_errors: PackedStringArray = CompetitiveRulesetRegistry.load_ruleset("competitive_standard", 1, first_ruleset)
	var second_ruleset_errors: PackedStringArray = CompetitiveRulesetRegistry.load_ruleset("competitive_standard", 1, second_ruleset)
	_check(first_ruleset_errors.is_empty() and second_ruleset_errors.is_empty(), "repeated ruleset loads succeed")
	_check(first_ruleset.to_dictionary() == second_ruleset.to_dictionary(), "same ruleset/version produces deterministic canonical output")

func _valid_mode_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "competitive_test",
		"display_name": "Competitive Test",
		"mode_family": "competitive",
		"ruleset_id": "competitive_standard",
		"ruleset_version": 1,
		"power_budget_id": "competitive_standard_v1",
		"authority_policy": "local_authoritative",
		"allows_custom_content": true
	}

func _valid_ruleset_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "competitive_test",
		"version": 1,
		"power_budget_id": "competitive_standard_v1",
		"character_constraints_id": "competitive_standard_v1",
		"skill_constraints_id": "competitive_standard_v1",
		"determinism_policy_id": "deterministic_v1"
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
