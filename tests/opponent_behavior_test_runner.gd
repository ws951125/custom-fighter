extends SceneTree

const OpponentBehaviorProfile = preload("res://game/core/ai/opponent_behavior_profile.gd")
const OpponentBehaviorProfiles = preload("res://game/core/ai/opponent_behavior_profiles.gd")
const OpponentDecisionState = preload("res://game/core/ai/opponent_decision_state.gd")
const CombatantState = preload("res://game/core/combat/combatant_state.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_builtin_profiles()
	_test_profile_fail_closed()
	_test_distance_and_depth_decisions()
	_test_guard_attack_and_skill_eligibility()
	_test_disabled_and_invalid_snapshots()
	_test_determinism_and_no_combat_mutation()
	if failures == 0:
		print("OPPONENT_BEHAVIOR_TESTS_PASSED")
		quit(0)
		return
	printerr("OPPONENT_BEHAVIOR_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_builtin_profiles() -> void:
	var ids: PackedStringArray = OpponentBehaviorProfiles.profile_ids()
	_check(ids == PackedStringArray(["training_balanced", "training_pressure"]), "built-in profile allow-list is deterministic")

	var balanced := OpponentBehaviorProfile.new()
	var balanced_errors: PackedStringArray = OpponentBehaviorProfiles.load_profile("training_balanced", balanced)
	_check(balanced_errors.is_empty() and balanced.loaded, "balanced profile loads: %s" % " | ".join(balanced_errors))
	_check(balanced.guard_policy == "when_threatened", "balanced profile guard policy loads")
	_check(balanced.preferred_skill_slot.is_empty(), "balanced profile does not invent a skill preference")

	var pressure := OpponentBehaviorProfile.new()
	var pressure_errors: PackedStringArray = OpponentBehaviorProfiles.load_profile("training_pressure", pressure)
	_check(pressure_errors.is_empty() and pressure.loaded, "pressure profile loads: %s" % " | ".join(pressure_errors))
	_check(pressure.preferred_skill_slot == "skill_1", "pressure profile uses allow-listed skill slot")

func _test_profile_fail_closed() -> void:
	var unknown := OpponentBehaviorProfile.new()
	var unknown_errors: PackedStringArray = OpponentBehaviorProfiles.load_profile("missing_profile", unknown)
	_check(_contains_fragment(unknown_errors, "unknown opponent behavior profile"), "unknown profile fails closed")
	_check(not unknown.loaded, "unknown profile never marks loaded")

	var executable := _valid_profile_dictionary()
	executable["script"] = "res://evil.gd"
	var executable_profile := OpponentBehaviorProfile.new()
	var executable_errors: PackedStringArray = executable_profile.load_from_dictionary(executable)
	_check(_contains_fragment(executable_errors, "unsupported opponent behavior field: script"), "executable-style field fails closed")

	var invalid_range := _valid_profile_dictionary()
	invalid_range["preferred_min_distance"] = 300.0
	invalid_range["preferred_max_distance"] = 200.0
	var invalid_profile := OpponentBehaviorProfile.new()
	var invalid_errors: PackedStringArray = invalid_profile.load_from_dictionary(invalid_range)
	_check(_contains_fragment(invalid_errors, "preferred_max_distance must be"), "invalid distance band fails closed")

	var invalid_slot := _valid_profile_dictionary()
	invalid_slot["preferred_skill_slot"] = "skill_99"
	var invalid_slot_profile := OpponentBehaviorProfile.new()
	var invalid_slot_errors: PackedStringArray = invalid_slot_profile.load_from_dictionary(invalid_slot)
	_check(_contains_fragment(invalid_slot_errors, "unsupported preferred_skill_slot"), "unsupported preferred skill slot fails closed")

func _test_distance_and_depth_decisions() -> void:
	var profile: OpponentBehaviorProfile = _load_balanced()
	var state := OpponentDecisionState.new()

	var approach: Dictionary = state.decide(profile, _snapshot(100.0, 0.50, 400.0, 0.50))
	_check(is_equal_approx(float(approach["move_x"]), 1.0) and not bool(approach["idle"]), "opponent approaches beyond preferred band")

	var retreat: Dictionary = state.decide(profile, _snapshot(350.0, 0.50, 400.0, 0.50))
	_check(is_equal_approx(float(retreat["move_x"]), -1.0) and not bool(retreat["idle"]), "opponent retreats inside minimum distance")

	var align_depth: Dictionary = state.decide(profile, _snapshot(250.0, 0.15, 390.0, 0.50))
	_check(is_equal_approx(float(align_depth["move_depth"]), 1.0) and is_equal_approx(float(align_depth["move_x"]), 0.0), "opponent aligns depth before horizontal action")

	var hold: Dictionary = state.decide(profile, _snapshot(250.0, 0.50, 390.0, 0.50, false, false, false))
	_check(bool(hold["idle"]), "opponent holds preferred band when no action is ready")

func _test_guard_attack_and_skill_eligibility() -> void:
	var balanced: OpponentBehaviorProfile = _load_balanced()
	var state := OpponentDecisionState.new()

	var guard_snapshot := _snapshot(250.0, 0.50, 390.0, 0.50, true, true, true)
	var guard: Dictionary = state.decide(balanced, guard_snapshot)
	_check(bool(guard["guard"]) and not bool(guard["basic_attack"]), "threatened guard has priority over attack")

	var close_to_attack_snapshot := _snapshot(100.0, 0.50, 270.0, 0.50, true, false, false)
	var close_to_attack: Dictionary = state.decide(balanced, close_to_attack_snapshot)
	_check(
		is_equal_approx(float(close_to_attack["move_x"]), 1.0) and not bool(close_to_attack["basic_attack"]),
		"attack-ready opponent closes from preferred band to basic-attack range"
	)

	var attack_snapshot := _snapshot(250.0, 0.50, 390.0, 0.50, true, false, false)
	var attack: Dictionary = state.decide(balanced, attack_snapshot)
	_check(bool(attack["basic_attack"]) and not bool(attack["guard"]), "basic attack requires readiness and in-range state")

	var close_attack_snapshot := _snapshot(350.0, 0.50, 400.0, 0.50, true, false, false)
	var close_attack: Dictionary = state.decide(balanced, close_attack_snapshot)
	_check(
		bool(close_attack["basic_attack"]) and is_equal_approx(float(close_attack["move_x"]), 0.0),
		"ready attack inside range takes precedence over too-close spacing retreat"
	)

	var pressure := OpponentBehaviorProfile.new()
	var pressure_errors: PackedStringArray = OpponentBehaviorProfiles.load_profile("training_pressure", pressure)
	_check(pressure_errors.is_empty(), "pressure profile available for skill decision")
	var skill_snapshot := _snapshot(250.0, 0.50, 360.0, 0.50, true, false, false, ["skill_1"])
	var skill: Dictionary = state.decide(pressure, skill_snapshot)
	_check(str(skill["skill_slot"]) == "skill_1" and not bool(skill["basic_attack"]), "preferred validated skill slot is deterministic")

func _test_disabled_and_invalid_snapshots() -> void:
	var profile := _load_balanced()
	var state := OpponentDecisionState.new()

	var disabled_snapshot := _snapshot(100.0, 0.50, 400.0, 0.50)
	disabled_snapshot["opponent_actionable"] = false
	var disabled: Dictionary = state.decide(profile, disabled_snapshot)
	_check(bool(disabled["idle"]), "disabled opponent fails closed to idle")

	var invalid_snapshot := _snapshot(100.0, 0.50, 400.0, 0.50)
	invalid_snapshot["script"] = "res://evil.gd"
	var invalid_errors: PackedStringArray = state.decision_errors(profile, invalid_snapshot)
	_check(_contains_fragment(invalid_errors, "unsupported opponent decision snapshot field: script"), "snapshot rejects executable-style field")
	var invalid: Dictionary = state.decide(profile, invalid_snapshot)
	_check(bool(invalid["idle"]) and is_equal_approx(float(invalid["move_x"]), 0.0), "invalid snapshot returns inert intent")

	var bad_slot_snapshot := _snapshot(250.0, 0.50, 360.0, 0.50, true, false, false, ["skill_99"])
	var bad_slot_errors: PackedStringArray = state.decision_errors(profile, bad_slot_snapshot)
	_check(_contains_fragment(bad_slot_errors, "unsupported ready skill slot"), "runtime readiness rejects unknown skill slots")

func _test_determinism_and_no_combat_mutation() -> void:
	var profile := _load_balanced()
	var state := OpponentDecisionState.new()
	var player := CombatantState.new(100, 75)
	var opponent := CombatantState.new(120, 60)
	var snapshot := _snapshot(250.0, 0.50, 390.0, 0.50, true, false, false)

	var first: Dictionary = state.decide(profile, snapshot)
	var second: Dictionary = state.decide(profile, snapshot)
	_check(first == second, "same explicit inputs return the same decision")
	_check(player.hp == 100 and player.mp == 75, "decision layer does not mutate player combat state")
	_check(opponent.hp == 120 and opponent.mp == 60, "decision layer does not mutate opponent combat state")

func _load_balanced() -> OpponentBehaviorProfile:
	var profile := OpponentBehaviorProfile.new()
	var errors: PackedStringArray = OpponentBehaviorProfiles.load_profile("training_balanced", profile)
	_check(errors.is_empty() and profile.loaded, "balanced fixture loads for decision tests")
	return profile

func _snapshot(
	opponent_x: float,
	opponent_depth: float,
	player_x: float,
	player_depth: float,
	basic_attack_ready: bool = false,
	guard_ready: bool = false,
	threatened: bool = false,
	ready_skill_slots: Array = []
) -> Dictionary:
	return {
		"decision_tick": 10,
		"opponent_x": opponent_x,
		"opponent_depth": opponent_depth,
		"player_x": player_x,
		"player_depth": player_depth,
		"opponent_actionable": true,
		"guard_ready": guard_ready,
		"threatened": threatened,
		"basic_attack_ready": basic_attack_ready,
		"ready_skill_slots": ready_skill_slots.duplicate()
	}

func _valid_profile_dictionary() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "test_behavior",
		"reaction_interval": 0.2,
		"preferred_min_distance": 100.0,
		"preferred_max_distance": 180.0,
		"depth_tolerance": 0.1,
		"basic_attack_range": 150.0,
		"guard_policy": "when_threatened",
		"allow_basic_attack": true,
		"preferred_skill_slot": ""
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
