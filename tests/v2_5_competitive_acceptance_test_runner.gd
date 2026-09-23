extends SceneTree

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const GameModeDefinition = preload("res://game/core/mode/game_mode_definition.gd")
const GameModeRegistry = preload("res://game/core/mode/game_mode_registry.gd")
const CompetitiveRulesetDefinition = preload("res://game/core/mode/competitive_ruleset_definition.gd")
const CompetitiveRulesetRegistry = preload("res://game/core/mode/competitive_ruleset_registry.gd")
const CompetitivePowerBudgetValidator = preload("res://game/core/mode/competitive_power_budget_validator.gd")
const CompetitiveLoadoutSnapshotBuilder = preload("res://game/core/mode/competitive_loadout_snapshot_builder.gd")
const CompetitiveRuntimeAuthority = preload("res://game/core/mode/competitive_runtime_authority.gd")

const EMBER_FINGERPRINT := "56451d3bdf1c7bf74852a3620894667730ddb088f350eb598badfa74c6d3c28e"
const STORM_FINGERPRINT := "5822c6cfb4737c29007f2450a598c501b79c17d8ed9a432e4327976cc6a7026e"

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_sandbox_safe_overspec_and_competitive_rejection()
	_test_ruleset_version_mismatch_fails_closed()
	_test_reference_authority_fingerprints_are_frozen()
	_test_runtime_materializes_only_frozen_authority_values()
	if failures == 0:
		print("V2_5_COMPETITIVE_ACCEPTANCE_TESTS_PASSED")
		quit(0)
		return
	printerr("V2_5_COMPETITIVE_ACCEPTANCE_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_sandbox_safe_overspec_and_competitive_rejection() -> void:
	var sandbox := GameModeDefinition.new()
	var sandbox_errors: PackedStringArray = GameModeRegistry.load_mode("sandbox", sandbox)
	_check(sandbox_errors.is_empty() and sandbox.loaded, "sandbox mode resolves")
	_check(sandbox.mode_family == "sandbox", "sandbox mode keeps sandbox family")
	_check(sandbox.power_budget_id == "sandbox_safe_limits", "sandbox mode uses safe-schema budget")
	_check(sandbox.allows_custom_content, "sandbox mode allows validated custom content")

	var competitive := GameModeDefinition.new()
	var competitive_errors: PackedStringArray = GameModeRegistry.load_mode("competitive_local", competitive)
	_check(competitive_errors.is_empty() and competitive.loaded, "competitive local mode resolves")
	_check(competitive.mode_family == "competitive", "competitive local keeps competitive family")
	_check(competitive.ruleset_id == "competitive_standard", "competitive local freezes standard ruleset")
	_check(competitive.ruleset_version == 1, "competitive local freezes ruleset version 1")
	_check(competitive.power_budget_id == "competitive_standard_v1", "competitive local freezes v1 power budget")

	var character := CharacterDefinition.new()
	var character_errors: PackedStringArray = character.load_from_dictionary(_overspec_character_data())
	_check(character_errors.is_empty() and character.loaded, "schema-safe overspec character is valid sandbox content")
	_check(character.max_hp == 222, "sandbox-safe overspec character preserves authored HP")

	var skill := SkillDefinition.new()
	var skill_errors: PackedStringArray = skill.load_from_dictionary(_overspec_skill_data())
	_check(skill_errors.is_empty() and skill.loaded, "schema-safe overspec skill is valid sandbox content")
	_check(skill.damage == 41, "sandbox-safe overspec skill preserves authored damage")
	_check(skill.mp_cost == 4, "sandbox-safe overspec skill preserves authored MP cost")
	_check(absf(skill.cooldown - 0.25) < 0.001, "sandbox-safe overspec skill preserves authored cooldown")

	var budget: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		competitive.power_budget_id,
		character,
		[skill]
	)
	var codes: PackedStringArray = budget.get("diagnostic_codes", PackedStringArray())
	_check(not bool(budget.get("eligible", true)), "same schema-safe content is rejected by competitive budget")
	_check(codes.has("CHARACTER_MAX_HP_CAP"), "competitive rejects overspec HP by frozen rule")
	_check(codes.has("SKILL_DAMAGE_CAP:overspec_projectile_001"), "competitive rejects overspec damage by frozen rule")
	_check(codes.has("SKILL_MP_COST_FLOOR:overspec_projectile_001"), "competitive rejects under-floor MP cost by frozen rule")
	_check(codes.has("SKILL_COOLDOWN_FLOOR:overspec_projectile_001"), "competitive rejects under-floor cooldown by frozen rule")

func _test_ruleset_version_mismatch_fails_closed() -> void:
	var ruleset := CompetitiveRulesetDefinition.new()
	var ruleset_errors: PackedStringArray = CompetitiveRulesetRegistry.load_ruleset(
		"competitive_standard",
		2,
		ruleset
	)
	_check(not ruleset_errors.is_empty(), "unsupported competitive ruleset version is rejected")
	_check(not ruleset.loaded, "unsupported ruleset version leaves target unloaded")

	var snapshot_result: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry(
		"ember_vanguard_001",
		"competitive_standard",
		2
	)
	var codes: PackedStringArray = snapshot_result.get("diagnostic_codes", PackedStringArray())
	_check(not bool(snapshot_result.get("accepted", true)), "ruleset version mismatch cannot mint authority snapshot")
	_check(codes.has("RULESET_RESOLUTION_FAILED"), "ruleset version mismatch emits stable fail-closed diagnostic")
	_check(snapshot_result.get("snapshot", {}).is_empty(), "ruleset mismatch emits no authority snapshot")

func _test_reference_authority_fingerprints_are_frozen() -> void:
	var ember: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry("ember_vanguard_001")
	var storm: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry("storm_duelist_001")
	_check(bool(ember.get("accepted", false)), "Ember authority snapshot accepted")
	_check(bool(storm.get("accepted", false)), "Storm authority snapshot accepted")
	_check(
		str(ember.get("snapshot", {}).get("content_fingerprint", "")) == EMBER_FINGERPRINT,
		"Ember authority fingerprint matches frozen cross-browser fixture"
	)
	_check(
		str(storm.get("snapshot", {}).get("content_fingerprint", "")) == STORM_FINGERPRINT,
		"Storm authority fingerprint matches frozen cross-browser fixture"
	)
	_check(EMBER_FINGERPRINT != STORM_FINGERPRINT, "distinct accepted content keeps distinct authority fingerprint")

func _test_runtime_materializes_only_frozen_authority_values() -> void:
	var authority := CompetitiveRuntimeAuthority.new()
	var admission_errors: PackedStringArray = authority.admit_registry_loadout("ember_vanguard_001")
	_check(admission_errors.is_empty() and authority.admitted, "Ember enters competitive runtime authority")
	_check(authority.content_fingerprint() == EMBER_FINGERPRINT, "runtime authority keeps frozen Ember fingerprint")

	var character := CharacterDefinition.new()
	character.loaded = true
	character.character_id = "forged_client_character"
	character.max_hp = 222
	character.max_mp = 999
	var character_errors: PackedStringArray = authority.apply_character_to(character)
	_check(character_errors.is_empty() and character.loaded, "authority replaces forged runtime character values")
	_check(character.character_id == "ember_vanguard_001", "runtime authority owns character identity")
	_check(character.max_hp == 100, "competitive authority normalizes HP to admitted value")
	_check(character.max_mp == 100, "competitive authority normalizes MP to admitted value")

	var skill := SkillDefinition.new()
	skill.loaded = true
	skill.skill_id = "overspec_projectile_001"
	skill.skill_type = "projectile"
	skill.damage = 41
	skill.mp_cost = 4
	skill.cooldown = 0.25
	var skill_errors: PackedStringArray = authority.load_skill_for_slot("skill_1", "projectile", skill)
	_check(skill_errors.is_empty() and skill.loaded, "authority replaces forged runtime skill values")
	_check(skill.skill_id == "fireball_001", "competitive authority owns admitted Skill 1 identity")
	_check(skill.damage == 18, "competitive authority damage is admitted registry value")
	_check(skill.mp_cost == 25, "competitive authority MP cost is admitted registry value")
	_check(absf(skill.cooldown - 1.8) < 0.001, "competitive authority cooldown is admitted registry value")

func _overspec_character_data() -> Dictionary:
	var slots := {}
	for index in range(1, 7):
		slots["skill_%d" % index] = "overspec_projectile_001"
	return {
		"schema_version": 1,
		"id": "sandbox_overspec_001",
		"name": "Sandbox Overspec",
		"archetype": "balanced",
		"stats": {
			"max_hp": 222,
			"max_mp": 100,
			"move_speed": 360.0,
			"depth_speed": 0.72,
			"run_multiplier": 1.6,
			"guard_move_multiplier": 0.35
		},
		"skill_slots": slots,
		"visual_profile": "training_blue",
		"animation_map": "ember_vanguard"
	}

func _overspec_skill_data() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "overspec_projectile_001",
		"name": "Sandbox Overspec Projectile",
		"type": "projectile",
		"damage": 41,
		"mp_cost": 4,
		"cooldown": 0.25,
		"startup": 0.22,
		"active": 0.08,
		"recovery": 0.3,
		"speed": 560.0,
		"range": 900.0,
		"hitstun": 0.22,
		"knockback": 260.0,
		"hitbox_half_width": 28.0,
		"hitbox_half_depth": 0.08,
		"visual": "prototype_fireball",
		"impact_visual": "prototype_impact"
	}

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
