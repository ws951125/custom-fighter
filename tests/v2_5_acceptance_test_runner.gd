extends SceneTree

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const GameModeDefinition = preload("res://game/core/mode/game_mode_definition.gd")
const GameModeRegistry = preload("res://game/core/mode/game_mode_registry.gd")
const CompetitivePowerBudgetValidator = preload("res://game/core/mode/competitive_power_budget_validator.gd")
const CompetitiveLoadoutSnapshotBuilder = preload("res://game/core/mode/competitive_loadout_snapshot_builder.gd")
const CompetitiveRuntimeAuthority = preload("res://game/core/mode/competitive_runtime_authority.gd")

const EMBER_FINGERPRINT := "56451d3bdf1c7bf74852a3620894667730ddb088f350eb598badfa74c6d3c28e"
const STORM_FINGERPRINT := "5822c6cfb4737c29007f2450a598c501b79c17d8ed9a432e4327976cc6a7026e"

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_schema_safe_content_remains_sandbox_compatible()
	_test_competitive_budget_rejects_schema_safe_overbudget_content()
	_test_overbudget_raw_values_cannot_control_admitted_runtime()
	_test_ruleset_version_mismatch_fails_closed()
	_test_reference_fingerprints_are_frozen()
	if failures == 0:
		print("V2_5_ACCEPTANCE_TESTS_PASSED")
		quit(0)
		return
	printerr("V2_5_ACCEPTANCE_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_schema_safe_content_remains_sandbox_compatible() -> void:
	var sandbox := GameModeDefinition.new()
	var mode_errors: PackedStringArray = GameModeRegistry.load_mode("sandbox", sandbox)
	_check(mode_errors.is_empty() and sandbox.loaded, "sandbox mode contract loads")
	_check(sandbox.mode_family == "sandbox", "sandbox mode remains separate from competitive")
	_check(sandbox.power_budget_id == "sandbox_safe_limits", "sandbox keeps safe-limit budget identity")
	_check(sandbox.allows_custom_content, "sandbox continues allowing declarative custom content")

	var fixture := _schema_safe_overbudget_fixture()
	var character = fixture.get("character")
	var skills: Array = fixture.get("skills", [])
	_check(character != null and bool(character.get("loaded")), "schema-safe custom character remains loadable")
	_check(skills.size() == 6, "schema-safe custom loadout contains all required skills")
	for skill in skills:
		_check(bool(skill.get("loaded")), "schema-safe custom skill remains loadable: %s" % str(skill.get("skill_id")))

	var over_skill = skills[0]
	_check(int(character.get("max_hp")) == 180, "sandbox-compatible character may exceed competitive HP cap")
	_check(int(over_skill.get("damage")) == 41, "sandbox-compatible skill may exceed competitive damage cap")
	_check(int(over_skill.get("mp_cost")) == 4, "sandbox-compatible skill may be cheaper than competitive MP floor")
	_check(absf(float(over_skill.get("cooldown")) - 0.49) < 0.001, "sandbox-compatible skill may be faster than competitive cooldown floor")

func _test_competitive_budget_rejects_schema_safe_overbudget_content() -> void:
	var fixture := _schema_safe_overbudget_fixture()
	var result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"competitive_standard_v1",
		fixture.get("character"),
		fixture.get("skills", [])
	)
	_check(not bool(result.get("eligible")), "schema-safe overbudget loadout is rejected by competitive budget")
	_check(_contains_code(result, "CHARACTER_MAX_HP_CAP"), "competitive rejects sandbox-safe HP above cap")
	_check(_contains_code(result, "SKILL_DAMAGE_CAP:overbudget_melee_001"), "competitive rejects sandbox-safe damage above cap")
	_check(_contains_code(result, "SKILL_MP_COST_FLOOR:overbudget_melee_001"), "competitive rejects sandbox-safe MP cost below floor")
	_check(_contains_code(result, "SKILL_COOLDOWN_FLOOR:overbudget_melee_001"), "competitive rejects sandbox-safe cooldown below floor")

	var authority := CompetitiveRuntimeAuthority.new()
	var admission_errors: PackedStringArray = authority.admit_registry_loadout("sandbox_overbudget_fighter")
	_check(not authority.admitted, "unregistered custom package cannot mint local competitive authority")
	_check(admission_errors.has("SNAPSHOT_ADMISSION_FAILED"), "custom package rejection is attributed to snapshot admission")
	_check(admission_errors.has("SNAPSHOT:CHARACTER_RESOLUTION_FAILED"), "custom package cannot bypass authority registry resolution")

func _test_overbudget_raw_values_cannot_control_admitted_runtime() -> void:
	var authority := CompetitiveRuntimeAuthority.new()
	var admission_errors: PackedStringArray = authority.admit_registry_loadout("ember_vanguard_001")
	_check(admission_errors.is_empty() and authority.admitted, "reference authority loadout admits")

	var forged_character := CharacterDefinition.new()
	var forged_character_errors: PackedStringArray = forged_character.load_from_dictionary(
		_character_raw("forged_client_fighter", 180)
	)
	_check(forged_character_errors.is_empty() and forged_character.loaded, "forged schema-safe character target loads")
	var apply_errors: PackedStringArray = authority.apply_character_to(forged_character)
	_check(apply_errors.is_empty() and forged_character.loaded, "authority replaces forged character target")
	_check(forged_character.character_id == "ember_vanguard_001", "authority owns runtime character identity")
	_check(forged_character.max_hp == 100, "overbudget raw HP cannot control admitted runtime")

	var forged_skill := SkillDefinition.new()
	var forged_skill_errors: PackedStringArray = forged_skill.load_from_dictionary(
		_melee_raw("forged_client_skill", 41, 4, 0.49)
	)
	_check(forged_skill_errors.is_empty() and forged_skill.loaded, "forged schema-safe skill target loads")
	var skill_errors: PackedStringArray = authority.load_skill_for_slot("skill_1", "projectile", forged_skill)
	_check(skill_errors.is_empty() and forged_skill.loaded, "authority replaces forged skill target")
	_check(forged_skill.skill_id == "fireball_001", "authority owns runtime skill identity")
	_check(forged_skill.damage == 18, "overbudget raw damage cannot control admitted runtime")
	_check(forged_skill.mp_cost == 25, "underpriced raw MP cost cannot control admitted runtime")
	_check(absf(forged_skill.cooldown - 1.8) < 0.001, "underpriced raw cooldown cannot control admitted runtime")

func _test_ruleset_version_mismatch_fails_closed() -> void:
	var result: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry(
		"ember_vanguard_001",
		"competitive_standard",
		2
	)
	_check(not bool(result.get("accepted")), "unsupported competitive ruleset version is rejected")
	_check(_contains_code(result, "RULESET_RESOLUTION_FAILED"), "ruleset version mismatch emits stable fail-closed code")
	_check(result.get("snapshot", {}).is_empty(), "ruleset version mismatch emits no authority snapshot")

func _test_reference_fingerprints_are_frozen() -> void:
	var ember: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry("ember_vanguard_001")
	var storm: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry("storm_duelist_001")
	_check(bool(ember.get("accepted")), "Ember reference loadout remains admitted")
	_check(bool(storm.get("accepted")), "Storm reference loadout remains admitted")
	_check(
		str(ember.get("snapshot", {}).get("content_fingerprint", "")) == EMBER_FINGERPRINT,
		"Ember authority fingerprint is frozen"
	)
	_check(
		str(storm.get("snapshot", {}).get("content_fingerprint", "")) == STORM_FINGERPRINT,
		"Storm authority fingerprint is frozen"
	)

func _schema_safe_overbudget_fixture() -> Dictionary:
	var ids := PackedStringArray([
		"overbudget_melee_001",
		"safe_melee_002",
		"safe_melee_003",
		"safe_melee_004",
		"safe_melee_005",
		"safe_melee_006"
	])
	var character := CharacterDefinition.new()
	var character_errors: PackedStringArray = character.load_from_dictionary(
		_character_raw("sandbox_overbudget_fighter", 180, ids)
	)
	_check(character_errors.is_empty() and character.loaded, "overbudget fixture character loads through schema validation")

	var skills: Array = []
	for index in range(ids.size()):
		var skill := SkillDefinition.new()
		var raw: Dictionary
		if index == 0:
			raw = _melee_raw(ids[index], 41, 4, 0.49)
		else:
			raw = _melee_raw(ids[index], 10, 20, 2.0)
		var skill_errors: PackedStringArray = skill.load_from_dictionary(raw)
		_check(skill_errors.is_empty() and skill.loaded, "overbudget fixture skill loads: %s" % ids[index])
		skills.append(skill)
	return {"character": character, "skills": skills}

func _character_raw(
	character_id: String,
	max_hp: int,
	skill_ids: PackedStringArray = PackedStringArray([
		"overbudget_melee_001",
		"safe_melee_002",
		"safe_melee_003",
		"safe_melee_004",
		"safe_melee_005",
		"safe_melee_006"
	])
) -> Dictionary:
	return {
		"schema_version": 1,
		"id": character_id,
		"name": character_id,
		"archetype": "balanced",
		"stats": {
			"max_hp": max_hp,
			"max_mp": 100,
			"move_speed": 360.0,
			"depth_speed": 0.72,
			"run_multiplier": 1.60,
			"guard_move_multiplier": 0.35
		},
		"skill_slots": {
			"skill_1": skill_ids[0],
			"skill_2": skill_ids[1],
			"skill_3": skill_ids[2],
			"skill_4": skill_ids[3],
			"skill_5": skill_ids[4],
			"skill_6": skill_ids[5]
		},
		"visual_profile": "training_blue"
	}

func _melee_raw(skill_id: String, damage: int, mp_cost: int, cooldown: float) -> Dictionary:
	return {
		"schema_version": 1,
		"id": skill_id,
		"name": skill_id,
		"type": "melee",
		"damage": damage,
		"mp_cost": mp_cost,
		"cooldown": cooldown,
		"startup": 0.20,
		"active": 0.10,
		"recovery": 0.25,
		"speed": 0.0,
		"range": 50.0,
		"hitstun": 0.05,
		"knockback": 50.0,
		"hitbox_half_width": 20.0,
		"hitbox_half_depth": 0.05,
		"visual": "heavy_slash",
		"impact_visual": "heavy_impact"
	}

func _contains_code(result: Dictionary, code: String) -> bool:
	var codes: PackedStringArray = result.get("diagnostic_codes", PackedStringArray())
	return codes.has(code)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
