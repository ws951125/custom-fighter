extends SceneTree

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterRegistry = preload("res://game/core/character/character_registry.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const CompetitivePowerBudgetValidator = preload("res://game/core/mode/competitive_power_budget_validator.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_reference_fixtures_and_determinism()
	_test_budget_and_resolution_fail_closed()
	_test_hard_caps_and_stable_diagnostics()
	_test_aggregate_budget_counts_slots()
	_test_boundary_and_monotonicity()
	if failures == 0:
		print("COMPETITIVE_POWER_BUDGET_TESTS_PASSED")
		quit(0)
		return
	printerr("COMPETITIVE_POWER_BUDGET_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_reference_fixtures_and_determinism() -> void:
	var ember: Dictionary = _reference_loadout("ember_vanguard_001")
	var ember_character = ember.get("character")
	var ember_skills: Array = ember.get("skills", [])
	var ember_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"competitive_standard_v1",
		ember_character,
		ember_skills
	)
	_check(bool(ember_result.get("eligible")), "Ember Vanguard reference loadout is competitive eligible")
	_check(int(ember_result.get("character_score", 0)) == 2683, "Ember Vanguard character score is frozen")
	_check(int(ember_result.get("total_score", 0)) == 15649, "Ember Vanguard loadout score is frozen")
	_check(
		str(ember_result.get("budget_id", "")) == "competitive_standard_v1"
		and int(ember_result.get("budget_version", 0)) == 1,
		"competitive result identifies frozen budget policy"
	)

	var reversed_skills: Array = ember_skills.duplicate()
	reversed_skills.reverse()
	var reversed_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"competitive_standard_v1",
		ember_character,
		reversed_skills
	)
	_check(reversed_result == ember_result, "input skill order does not change deterministic result")

	var ember_hp_before := int(ember_character.get("max_hp"))
	var fireball = _find_skill(ember_skills, "fireball_001")
	var fireball_damage_before := int(fireball.get("damage"))
	CompetitivePowerBudgetValidator.evaluate("competitive_standard_v1", ember_character, ember_skills)
	_check(int(ember_character.get("max_hp")) == ember_hp_before, "budget evaluation does not mutate character stats")
	_check(int(fireball.get("damage")) == fireball_damage_before, "budget evaluation does not mutate authored skill values")

	var storm: Dictionary = _reference_loadout("storm_duelist_001")
	var storm_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"competitive_standard_v1",
		storm.get("character"),
		storm.get("skills", [])
	)
	_check(bool(storm_result.get("eligible")), "Storm Duelist reference loadout is competitive eligible")
	_check(int(storm_result.get("character_score", 0)) == 2787, "Storm Duelist character score is frozen")
	_check(int(storm_result.get("total_score", 0)) == 15426, "Storm Duelist loadout score is frozen")

func _test_budget_and_resolution_fail_closed() -> void:
	var reference: Dictionary = _reference_loadout("ember_vanguard_001")
	var character = reference.get("character")
	var skills: Array = reference.get("skills", [])

	var wrong_budget: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"sandbox_safe_limits",
		character,
		skills
	)
	_check(not bool(wrong_budget.get("eligible")), "sandbox budget cannot be used as competitive budget")
	_check(_contains_code(wrong_budget, "UNSUPPORTED_BUDGET_ID"), "unknown/noncompetitive budget fails with stable code")

	var missing_skills: Array = []
	for skill in skills:
		if str(skill.get("skill_id")) != "fireball_001":
			missing_skills.append(skill)
	var missing_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"competitive_standard_v1",
		character,
		missing_skills
	)
	_check(not bool(missing_result.get("eligible")), "missing referenced skill fails closed")
	_check(_contains_code(missing_result, "MISSING_SKILL:fireball_001"), "missing skill emits stable id-specific code")

	var extra_skill = _melee_skill("unreferenced_melee_001", 1, 20, 5.0, 0.50, 0.50)
	var extra_skills: Array = skills.duplicate()
	extra_skills.append(extra_skill)
	var extra_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"competitive_standard_v1",
		character,
		extra_skills
	)
	_check(not bool(extra_result.get("eligible")), "unreferenced supplied skill fails closed")
	_check(
		_contains_code(extra_result, "UNREFERENCED_SKILL:unreferenced_melee_001"),
		"unreferenced skill emits stable id-specific code"
	)

func _test_hard_caps_and_stable_diagnostics() -> void:
	var character_case: Dictionary = _reference_loadout("ember_vanguard_001")
	var capped_character = character_case.get("character")
	capped_character.set("max_hp", 161)
	var character_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"competitive_standard_v1",
		capped_character,
		character_case.get("skills", [])
	)
	_check(not bool(character_result.get("eligible")), "character over hard HP cap is rejected")
	_check(_contains_code(character_result, "CHARACTER_MAX_HP_CAP"), "character HP cap emits stable code")

	var skill_case: Dictionary = _reference_loadout("ember_vanguard_001")
	var capped_skill = _find_skill(skill_case.get("skills", []), "fireball_001")
	capped_skill.set("damage", 41)
	var skill_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"competitive_standard_v1",
		skill_case.get("character"),
		skill_case.get("skills", [])
	)
	_check(not bool(skill_result.get("eligible")), "skill over damage hard cap is rejected")
	_check(
		_contains_code(skill_result, "SKILL_DAMAGE_CAP:fireball_001"),
		"skill damage cap emits stable id-specific code"
	)
	_check(
		_count_code(skill_result, "SKILL_DAMAGE_CAP:fireball_001") == 1,
		"one over-cap skill emits one stable diagnostic"
	)

func _test_aggregate_budget_counts_slots() -> void:
	var reference: Dictionary = _reference_loadout("ember_vanguard_001")
	var character = reference.get("character")
	var skills: Array = reference.get("skills", [])
	var fireball = _find_skill(skills, "fireball_001")
	var raw_slots: Dictionary = character.get("skill_slots")
	for slot_name in raw_slots.keys():
		raw_slots[slot_name] = "fireball_001"

	var aggregate_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"competitive_standard_v1",
		character,
		[fireball]
	)
	_check(not bool(aggregate_result.get("eligible")), "repeated strong skill slots cannot bypass aggregate budget")
	_check(_contains_code(aggregate_result, "LOADOUT_SCORE_CAP"), "aggregate over-budget loadout emits stable code")
	_check(int(aggregate_result.get("total_score", 0)) == 18565, "aggregate score counts repeated skill per occupied slot")
	_check(
		not _contains_code(aggregate_result, "SKILL_SCORE_CAP:fireball_001"),
		"aggregate rejection remains distinct from per-skill rejection"
	)

func _test_boundary_and_monotonicity() -> void:
	var ids := PackedStringArray([
		"boundary_melee_001",
		"minimal_melee_002",
		"minimal_melee_003",
		"minimal_melee_004",
		"minimal_melee_005",
		"minimal_melee_006"
	])
	var character = _budget_character(ids)
	var boundary = _melee_skill("boundary_melee_001", 40, 20, 5.0, 0.50, 0.50)
	var skills: Array = [boundary]
	for index in range(2, 7):
		skills.append(_melee_skill("minimal_melee_%03d" % index, 0, 20, 5.0, 0.50, 0.50))

	var boundary_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"competitive_standard_v1",
		character,
		skills
	)
	_check(bool(boundary_result.get("eligible")), "damage exactly at hard cap remains eligible when total budget fits")
	_check(not _contains_code(boundary_result, "SKILL_DAMAGE_CAP:boundary_melee_001"), "hard cap boundary is inclusive")

	var over_boundary = _melee_skill("boundary_melee_001", 41, 20, 5.0, 0.50, 0.50)
	var over_skills: Array = [over_boundary]
	for index in range(1, skills.size()):
		over_skills.append(skills[index])
	var over_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		"competitive_standard_v1",
		character,
		over_skills
	)
	_check(not bool(over_result.get("eligible")), "damage one point above hard cap fails")
	_check(_contains_code(over_result, "SKILL_DAMAGE_CAP:boundary_melee_001"), "above-boundary damage emits hard-cap code")

	var damage_low = _melee_skill("damage_low_001", 10, 20, 5.0, 0.50, 0.50)
	var damage_high = _melee_skill("damage_high_001", 11, 20, 5.0, 0.50, 0.50)
	_check(
		CompetitivePowerBudgetValidator.score_skill(damage_high)
		> CompetitivePowerBudgetValidator.score_skill(damage_low),
		"higher damage monotonically increases score"
	)

	var cooldown_slow = _melee_skill("cooldown_slow_001", 10, 18, 2.0, 0.20, 0.25)
	var cooldown_fast = _melee_skill("cooldown_fast_001", 10, 18, 1.9, 0.20, 0.25)
	_check(
		CompetitivePowerBudgetValidator.score_skill(cooldown_fast)
		> CompetitivePowerBudgetValidator.score_skill(cooldown_slow),
		"shorter cooldown monotonically increases score"
	)

	var cost_normal = _melee_skill("cost_normal_001", 10, 18, 2.0, 0.20, 0.25)
	var cost_cheaper = _melee_skill("cost_cheaper_001", 10, 17, 2.0, 0.20, 0.25)
	_check(
		CompetitivePowerBudgetValidator.score_skill(cost_cheaper)
		> CompetitivePowerBudgetValidator.score_skill(cost_normal),
		"lower MP cost monotonically increases score"
	)

func _reference_loadout(character_id: String) -> Dictionary:
	var character_registry := CharacterRegistry.new()
	var character_registry_errors: PackedStringArray = character_registry.load_default()
	_check(character_registry_errors.is_empty(), "reference character registry loads")

	var character := CharacterDefinition.new()
	var character_errors: PackedStringArray = character_registry.load_character(character_id, character)
	_check(character_errors.is_empty() and character.loaded, "reference character loads: %s" % character_id)

	var skill_registry := SkillRegistry.new()
	var skill_registry_errors: PackedStringArray = skill_registry.load_default()
	_check(skill_registry_errors.is_empty(), "reference skill registry loads")

	var skills: Array = []
	var seen: Dictionary = {}
	var slot_names := PackedStringArray()
	for raw_slot in character.skill_slots.keys():
		slot_names.append(str(raw_slot))
	slot_names.sort()
	for slot_name in slot_names:
		var skill_id := character.skill_id_for_slot(slot_name)
		if seen.has(skill_id):
			continue
		var expected_type := skill_registry.registered_type_for_id(skill_id)
		var skill := SkillDefinition.new()
		var skill_errors: PackedStringArray = skill_registry.load_skill(skill_id, expected_type, skill)
		_check(skill_errors.is_empty() and skill.loaded, "reference skill loads: %s" % skill_id)
		skills.append(skill)
		seen[skill_id] = true

	return {
		"character": character,
		"skills": skills
	}

func _budget_character(skill_ids: PackedStringArray):
	var raw := {
		"schema_version": 1,
		"id": "budget_test_fighter",
		"name": "Budget Test Fighter",
		"archetype": "balanced",
		"stats": {
			"max_hp": 100,
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
	var character := CharacterDefinition.new()
	var errors: PackedStringArray = character.load_from_dictionary(raw)
	_check(errors.is_empty() and character.loaded, "budget test character fixture loads")
	return character

func _melee_skill(
	skill_id: String,
	damage: int,
	mp_cost: int,
	cooldown: float,
	startup: float,
	recovery: float
):
	var raw := {
		"schema_version": 1,
		"id": skill_id,
		"name": skill_id,
		"type": "melee",
		"damage": damage,
		"mp_cost": mp_cost,
		"cooldown": cooldown,
		"startup": startup,
		"active": 0.10,
		"recovery": recovery,
		"speed": 0.0,
		"range": 50.0,
		"hitstun": 0.05,
		"knockback": 50.0,
		"hitbox_half_width": 20.0,
		"hitbox_half_depth": 0.05,
		"visual": "heavy_slash",
		"impact_visual": "heavy_impact"
	}
	var skill := SkillDefinition.new()
	var errors: PackedStringArray = skill.load_from_dictionary(raw)
	_check(errors.is_empty() and skill.loaded, "synthetic melee fixture loads: %s" % skill_id)
	return skill

func _find_skill(skills: Array, skill_id: String):
	for skill in skills:
		if str(skill.get("skill_id")) == skill_id:
			return skill
	_check(false, "expected skill exists: %s" % skill_id)
	return null

func _contains_code(result: Dictionary, code: String) -> bool:
	var codes: PackedStringArray = result.get("diagnostic_codes", PackedStringArray())
	return codes.has(code)

func _count_code(result: Dictionary, code: String) -> int:
	var count := 0
	var codes: PackedStringArray = result.get("diagnostic_codes", PackedStringArray())
	for candidate in codes:
		if candidate == code:
			count += 1
	return count

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
