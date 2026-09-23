class_name CompetitivePowerBudgetValidator
extends RefCounted

const SUPPORTED_BUDGET_ID := "competitive_standard_v1"
const BUDGET_VERSION := 1

const CHARACTER_SCORE_LIMIT := 3200
const SKILL_SCORE_LIMIT := 4500
const LOADOUT_SCORE_LIMIT := 18000

const CHARACTER_MAX_HP := 160
const CHARACTER_MAX_MP := 180
const CHARACTER_MAX_MOVE_SPEED := 480.0
const CHARACTER_MAX_DEPTH_SPEED := 1.0
const CHARACTER_MAX_RUN_MULTIPLIER := 2.0
const CHARACTER_MAX_GUARD_MOVE_MULTIPLIER := 0.65

const SKILL_MAX_DAMAGE := 40
const SKILL_MIN_MP_COST := 5
const SKILL_MIN_COOLDOWN := 0.50
const SKILL_MIN_STARTUP := 0.02
const SKILL_MAX_ACTIVE := 6.0
const SKILL_MIN_RECOVERY := 0.05
const SKILL_MAX_SPEED := 1200.0
const SKILL_MAX_RANGE := 1200.0
const SKILL_MAX_HITSTUN := 0.80
const SKILL_MAX_KNOCKBACK := 500.0
const SKILL_MAX_HITBOX_HALF_WIDTH := 180.0
const SKILL_MAX_HITBOX_HALF_DEPTH := 0.30
const FORMATION_MAX_COUNT := 6
const FORMATION_MAX_SPACING := 180.0
const FORMATION_MIN_INTERVAL := 0.08
const FORMATION_MAX_OFFSET := 180.0
const BUFF_MAX_DURATION := 4.0
const BUFF_MAX_MOVE_SPEED_MULTIPLIER := 1.60
const BUFF_MAX_BASIC_ATTACK_DAMAGE_MULTIPLIER := 1.60
const TRAP_MAX_DURATION := 8.0
const AURA_MAX_DURATION := 6.0
const TELEPORT_MAX_RANGE := 600.0
const COUNTER_MAX_WINDOW := 1.80
const GRAB_MAX_WINDOW := 1.00
const SUMMON_MAX_LIFETIME := 5.0

static func evaluate(budget_id: String, character, skills: Array) -> Dictionary:
	var requested_budget := budget_id.strip_edges().to_lower()
	var diagnostics := PackedStringArray()
	var skill_scores: Dictionary = {}
	var character_score := 0
	var total_score := 0

	if requested_budget != SUPPORTED_BUDGET_ID:
		diagnostics.append("UNSUPPORTED_BUDGET_ID")
		return _result(false, requested_budget, character_score, skill_scores, total_score, diagnostics)

	if character == null or not bool(character.get("loaded")):
		diagnostics.append("UNLOADED_CHARACTER")
		return _result(false, requested_budget, character_score, skill_scores, total_score, diagnostics)

	character_score = score_character(character)
	_append_character_diagnostics(character, character_score, diagnostics)

	var skill_by_id: Dictionary = {}
	var provided_ids := PackedStringArray()
	for raw_skill in skills:
		if raw_skill == null or not bool(raw_skill.get("loaded")):
			diagnostics.append("UNLOADED_SKILL")
			continue
		var skill_id := str(raw_skill.get("skill_id")).strip_edges()
		if skill_id.is_empty():
			diagnostics.append("INVALID_SKILL_ID")
			continue
		if skill_by_id.has(skill_id):
			diagnostics.append("DUPLICATE_SKILL:%s" % skill_id)
			continue
		skill_by_id[skill_id] = raw_skill
		provided_ids.append(skill_id)
	provided_ids.sort()

	var referenced_ids := PackedStringArray()
	var validated_skill_ids: Dictionary = {}
	var slot_names := PackedStringArray()
	var raw_slots: Dictionary = character.get("skill_slots")
	for raw_slot in raw_slots.keys():
		slot_names.append(str(raw_slot))
	slot_names.sort()

	for slot_name in slot_names:
		var skill_id := str(raw_slots.get(slot_name, "")).strip_edges()
		if skill_id.is_empty():
			diagnostics.append("EMPTY_SKILL_SLOT:%s" % slot_name)
			continue
		if not referenced_ids.has(skill_id):
			referenced_ids.append(skill_id)
		if not skill_by_id.has(skill_id):
			diagnostics.append("MISSING_SKILL:%s" % skill_id)
			continue
		var skill = skill_by_id[skill_id]
		var one_score := score_skill(skill)
		skill_scores[skill_id] = one_score
		if not validated_skill_ids.has(skill_id):
			_append_skill_diagnostics(skill, one_score, diagnostics)
			validated_skill_ids[skill_id] = true
		total_score += one_score

	referenced_ids.sort()
	for skill_id in provided_ids:
		if not referenced_ids.has(skill_id):
			diagnostics.append("UNREFERENCED_SKILL:%s" % skill_id)

	total_score += character_score
	if total_score > LOADOUT_SCORE_LIMIT:
		diagnostics.append("LOADOUT_SCORE_CAP")

	return _result(
		diagnostics.is_empty(),
		requested_budget,
		character_score,
		skill_scores,
		total_score,
		diagnostics
	)

static func score_character(character) -> int:
	return (
		int(character.get("max_hp")) * 10
		+ int(character.get("max_mp")) * 4
		+ int(round(float(character.get("move_speed")) * 2.0))
		+ int(round(float(character.get("depth_speed")) * 400.0))
		+ int(round(float(character.get("run_multiplier")) * 150.0))
		+ int(round(float(character.get("guard_move_multiplier")) * 100.0))
	)

static func score_skill(skill) -> int:
	var cooldown := float(skill.get("cooldown"))
	var mp_cost := int(skill.get("mp_cost"))
	var startup := float(skill.get("startup"))
	var recovery := float(skill.get("recovery"))
	return (
		int(skill.get("damage")) * 60
		+ int(round(float(skill.get("range")) * 0.8))
		+ int(round(float(skill.get("hitbox_half_width")) * 5.0))
		+ int(round(float(skill.get("hitbox_half_depth")) * 1000.0))
		+ int(round(float(skill.get("hitstun")) * 800.0))
		+ int(round(float(skill.get("knockback")) * 0.5))
		+ int(round(float(skill.get("speed")) * 0.2))
		+ int(round(float(skill.get("active")) * 60.0))
		+ int(skill.get("formation_count")) * 80
		+ int(round(float(skill.get("buff_duration")) * 60.0))
		+ int(round(maxf(0.0, float(skill.get("move_speed_multiplier")) - 1.0) * 500.0))
		+ int(round(maxf(0.0, float(skill.get("basic_attack_damage_multiplier")) - 1.0) * 600.0))
		+ int(round(float(skill.get("trap_duration")) * 40.0))
		+ int(round(float(skill.get("aura_duration")) * 40.0))
		+ int(round(maxf(0.0, 3.0 - cooldown) * 150.0))
		+ int(round(maxf(0.0, 20.0 - float(mp_cost)) * 20.0))
		+ int(round(maxf(0.0, 0.25 - startup) * 800.0))
		+ int(round(maxf(0.0, 0.30 - recovery) * 600.0))
	)

static func _append_character_diagnostics(character, score: int, diagnostics: PackedStringArray) -> void:
	if int(character.get("max_hp")) > CHARACTER_MAX_HP:
		diagnostics.append("CHARACTER_MAX_HP_CAP")
	if int(character.get("max_mp")) > CHARACTER_MAX_MP:
		diagnostics.append("CHARACTER_MAX_MP_CAP")
	if float(character.get("move_speed")) > CHARACTER_MAX_MOVE_SPEED:
		diagnostics.append("CHARACTER_MOVE_SPEED_CAP")
	if float(character.get("depth_speed")) > CHARACTER_MAX_DEPTH_SPEED:
		diagnostics.append("CHARACTER_DEPTH_SPEED_CAP")
	if float(character.get("run_multiplier")) > CHARACTER_MAX_RUN_MULTIPLIER:
		diagnostics.append("CHARACTER_RUN_MULTIPLIER_CAP")
	if float(character.get("guard_move_multiplier")) > CHARACTER_MAX_GUARD_MOVE_MULTIPLIER:
		diagnostics.append("CHARACTER_GUARD_MOVE_MULTIPLIER_CAP")
	if score > CHARACTER_SCORE_LIMIT:
		diagnostics.append("CHARACTER_SCORE_CAP")

static func _append_skill_diagnostics(skill, score: int, diagnostics: PackedStringArray) -> void:
	var skill_id := str(skill.get("skill_id"))
	var skill_type := str(skill.get("skill_type"))
	if int(skill.get("damage")) > SKILL_MAX_DAMAGE:
		diagnostics.append("SKILL_DAMAGE_CAP:%s" % skill_id)
	if int(skill.get("mp_cost")) < SKILL_MIN_MP_COST:
		diagnostics.append("SKILL_MP_COST_FLOOR:%s" % skill_id)
	if float(skill.get("cooldown")) < SKILL_MIN_COOLDOWN:
		diagnostics.append("SKILL_COOLDOWN_FLOOR:%s" % skill_id)
	if float(skill.get("startup")) < SKILL_MIN_STARTUP:
		diagnostics.append("SKILL_STARTUP_FLOOR:%s" % skill_id)
	if float(skill.get("active")) > SKILL_MAX_ACTIVE:
		diagnostics.append("SKILL_ACTIVE_CAP:%s" % skill_id)
	if float(skill.get("recovery")) < SKILL_MIN_RECOVERY:
		diagnostics.append("SKILL_RECOVERY_FLOOR:%s" % skill_id)
	if float(skill.get("speed")) > SKILL_MAX_SPEED:
		diagnostics.append("SKILL_SPEED_CAP:%s" % skill_id)
	if float(skill.get("range")) > SKILL_MAX_RANGE:
		diagnostics.append("SKILL_RANGE_CAP:%s" % skill_id)
	if float(skill.get("hitstun")) > SKILL_MAX_HITSTUN:
		diagnostics.append("SKILL_HITSTUN_CAP:%s" % skill_id)
	if float(skill.get("knockback")) > SKILL_MAX_KNOCKBACK:
		diagnostics.append("SKILL_KNOCKBACK_CAP:%s" % skill_id)
	if float(skill.get("hitbox_half_width")) > SKILL_MAX_HITBOX_HALF_WIDTH:
		diagnostics.append("SKILL_HITBOX_WIDTH_CAP:%s" % skill_id)
	if float(skill.get("hitbox_half_depth")) > SKILL_MAX_HITBOX_HALF_DEPTH:
		diagnostics.append("SKILL_HITBOX_DEPTH_CAP:%s" % skill_id)

	if skill_type == "formation":
		if int(skill.get("formation_count")) > FORMATION_MAX_COUNT:
			diagnostics.append("FORMATION_COUNT_CAP:%s" % skill_id)
		if float(skill.get("formation_spacing")) > FORMATION_MAX_SPACING:
			diagnostics.append("FORMATION_SPACING_CAP:%s" % skill_id)
		if float(skill.get("formation_interval")) < FORMATION_MIN_INTERVAL:
			diagnostics.append("FORMATION_INTERVAL_FLOOR:%s" % skill_id)
		if float(skill.get("formation_offset")) > FORMATION_MAX_OFFSET:
			diagnostics.append("FORMATION_OFFSET_CAP:%s" % skill_id)
	elif skill_type == "buff":
		if float(skill.get("buff_duration")) > BUFF_MAX_DURATION:
			diagnostics.append("BUFF_DURATION_CAP:%s" % skill_id)
		if float(skill.get("move_speed_multiplier")) > BUFF_MAX_MOVE_SPEED_MULTIPLIER:
			diagnostics.append("BUFF_MOVE_MULTIPLIER_CAP:%s" % skill_id)
		if float(skill.get("basic_attack_damage_multiplier")) > BUFF_MAX_BASIC_ATTACK_DAMAGE_MULTIPLIER:
			diagnostics.append("BUFF_DAMAGE_MULTIPLIER_CAP:%s" % skill_id)
	elif skill_type == "trap":
		if float(skill.get("trap_duration")) > TRAP_MAX_DURATION:
			diagnostics.append("TRAP_DURATION_CAP:%s" % skill_id)
	elif skill_type == "aura":
		if float(skill.get("aura_duration")) > AURA_MAX_DURATION:
			diagnostics.append("AURA_DURATION_CAP:%s" % skill_id)
	elif skill_type == "teleport":
		if float(skill.get("range")) > TELEPORT_MAX_RANGE:
			diagnostics.append("TELEPORT_RANGE_CAP:%s" % skill_id)
	elif skill_type == "counter":
		if float(skill.get("active")) > COUNTER_MAX_WINDOW:
			diagnostics.append("COUNTER_WINDOW_CAP:%s" % skill_id)
	elif skill_type == "grab":
		if float(skill.get("active")) > GRAB_MAX_WINDOW:
			diagnostics.append("GRAB_WINDOW_CAP:%s" % skill_id)
	elif skill_type == "summon":
		if float(skill.get("active")) > SUMMON_MAX_LIFETIME:
			diagnostics.append("SUMMON_LIFETIME_CAP:%s" % skill_id)

	if score > SKILL_SCORE_LIMIT:
		diagnostics.append("SKILL_SCORE_CAP:%s" % skill_id)

static func _result(
	eligible: bool,
	budget_id: String,
	character_score: int,
	skill_scores: Dictionary,
	total_score: int,
	diagnostics: PackedStringArray
) -> Dictionary:
	return {
		"eligible": eligible,
		"budget_id": budget_id,
		"budget_version": BUDGET_VERSION,
		"character_score": character_score,
		"skill_scores": skill_scores.duplicate(true),
		"total_score": total_score,
		"diagnostic_codes": diagnostics.duplicate()
	}
