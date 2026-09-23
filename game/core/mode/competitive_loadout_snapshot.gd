class_name CompetitiveLoadoutSnapshot
extends RefCounted

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const CompetitiveRulesetDefinition = preload("res://game/core/mode/competitive_ruleset_definition.gd")
const CompetitiveRulesetRegistry = preload("res://game/core/mode/competitive_ruleset_registry.gd")
const CompetitivePowerBudgetValidator = preload("res://game/core/mode/competitive_power_budget_validator.gd")

const SNAPSHOT_VERSION := 1
const FINGERPRINT_VERSION := 1
const REQUIRED_RULESET_ID := "competitive_standard"
const REQUIRED_CHARACTER_CONSTRAINTS_ID := "competitive_standard_v1"
const REQUIRED_SKILL_CONSTRAINTS_ID := "competitive_standard_v1"
const REQUIRED_DETERMINISM_POLICY_ID := "deterministic_v1"
const FLOAT_SCALE := 1000000.0

static func build(
	ruleset_id: String,
	ruleset_version: int,
	character_id: String,
	character_registry,
	skill_registry
) -> Dictionary:
	var diagnostics := PackedStringArray()
	var normalized_ruleset_id := ruleset_id.strip_edges().to_lower()
	var normalized_character_id := character_id.strip_edges().to_lower()

	if character_registry == null or not bool(character_registry.get("loaded")):
		diagnostics.append("CHARACTER_REGISTRY_UNAVAILABLE")
		return _failure(normalized_ruleset_id, ruleset_version, normalized_character_id, diagnostics)
	if skill_registry == null or not bool(skill_registry.get("loaded")):
		diagnostics.append("SKILL_REGISTRY_UNAVAILABLE")
		return _failure(normalized_ruleset_id, ruleset_version, normalized_character_id, diagnostics)

	var ruleset := CompetitiveRulesetDefinition.new()
	var ruleset_errors: PackedStringArray = CompetitiveRulesetRegistry.load_ruleset(
		normalized_ruleset_id,
		ruleset_version,
		ruleset
	)
	if not ruleset_errors.is_empty() or not ruleset.loaded:
		diagnostics.append("RULESET_RESOLUTION_FAILED")
		return _failure(normalized_ruleset_id, ruleset_version, normalized_character_id, diagnostics)

	if (
		ruleset.ruleset_id != REQUIRED_RULESET_ID
		or ruleset.character_constraints_id != REQUIRED_CHARACTER_CONSTRAINTS_ID
		or ruleset.skill_constraints_id != REQUIRED_SKILL_CONSTRAINTS_ID
		or ruleset.determinism_policy_id != REQUIRED_DETERMINISM_POLICY_ID
		or ruleset.power_budget_id != CompetitivePowerBudgetValidator.SUPPORTED_BUDGET_ID
	):
		diagnostics.append("NONCOMPETITIVE_RULESET_POLICY")
		return _failure(normalized_ruleset_id, ruleset_version, normalized_character_id, diagnostics)

	var character := CharacterDefinition.new()
	var character_errors: PackedStringArray = character_registry.load_character(
		normalized_character_id,
		character
	)
	if not character_errors.is_empty() or not character.loaded:
		diagnostics.append("CHARACTER_RESOLUTION_FAILED:%s" % normalized_character_id)
		return _failure(normalized_ruleset_id, ruleset_version, normalized_character_id, diagnostics)

	var resolved_skill_slots: Dictionary = {}
	var resolved_skills: Array = []
	var skill_by_id: Dictionary = {}
	var slot_names := PackedStringArray()
	for raw_slot in character.skill_slots.keys():
		slot_names.append(str(raw_slot))
	slot_names.sort()

	for slot_name in slot_names:
		var skill_id := character.skill_id_for_slot(slot_name)
		resolved_skill_slots[slot_name] = skill_id
		if skill_by_id.has(skill_id):
			continue

		var expected_type := str(skill_registry.registered_type_for_id(skill_id)).strip_edges().to_lower()
		if expected_type.is_empty():
			diagnostics.append("SKILL_REGISTRY_TYPE_MISSING:%s" % skill_id)
			continue

		var skill := SkillDefinition.new()
		var skill_errors: PackedStringArray = skill_registry.load_skill(skill_id, expected_type, skill)
		if not skill_errors.is_empty() or not skill.loaded:
			diagnostics.append("SKILL_RESOLUTION_FAILED:%s" % skill_id)
			continue
		skill_by_id[skill_id] = skill
		resolved_skills.append(skill)

	if not diagnostics.is_empty():
		return _failure(normalized_ruleset_id, ruleset_version, normalized_character_id, diagnostics)

	var budget_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		ruleset.power_budget_id,
		character,
		resolved_skills
	)
	if not bool(budget_result.get("eligible", false)):
		diagnostics.append("POWER_BUDGET_REJECTED")
		var budget_codes: PackedStringArray = budget_result.get("diagnostic_codes", PackedStringArray())
		for code in budget_codes:
			diagnostics.append("BUDGET:%s" % str(code))
		return _failure(
			normalized_ruleset_id,
			ruleset_version,
			normalized_character_id,
			diagnostics,
			budget_result
		)

	var normalized_skill_values: Dictionary = {}
	var skill_ids := PackedStringArray()
	for raw_skill_id in skill_by_id.keys():
		skill_ids.append(str(raw_skill_id))
	skill_ids.sort()
	for skill_id in skill_ids:
		normalized_skill_values[skill_id] = _authoritative_skill_values(skill_by_id[skill_id])

	var snapshot := {
		"valid": true,
		"snapshot_version": SNAPSHOT_VERSION,
		"fingerprint_version": FINGERPRINT_VERSION,
		"ruleset_id": ruleset.ruleset_id,
		"ruleset_version": ruleset.version,
		"character_id": character.character_id,
		"character_schema_version": character.schema_version,
		"normalized_character_stats": _authoritative_character_stats(character),
		"resolved_skill_slots": resolved_skill_slots.duplicate(true),
		"normalized_skill_values": normalized_skill_values.duplicate(true),
		"power_budget_result": budget_result.duplicate(true),
		"content_fingerprint": "",
		"diagnostic_codes": PackedStringArray()
	}
	var canonical := _canonical_fingerprint_input(snapshot)
	snapshot["content_fingerprint"] = canonical.sha256_text()
	return snapshot

static func _authoritative_character_stats(character) -> Dictionary:
	return {
		"max_hp": int(character.get("max_hp")),
		"max_mp": int(character.get("max_mp")),
		"move_speed": float(character.get("move_speed")),
		"depth_speed": float(character.get("depth_speed")),
		"run_multiplier": float(character.get("run_multiplier")),
		"guard_move_multiplier": float(character.get("guard_move_multiplier"))
	}

static func _authoritative_skill_values(skill) -> Dictionary:
	return {
		"schema_version": int(skill.get("schema_version")),
		"id": str(skill.get("skill_id")),
		"type": str(skill.get("skill_type")),
		"damage": int(skill.get("damage")),
		"mp_cost": int(skill.get("mp_cost")),
		"cooldown": float(skill.get("cooldown")),
		"startup": float(skill.get("startup")),
		"active": float(skill.get("active")),
		"recovery": float(skill.get("recovery")),
		"speed": float(skill.get("speed")),
		"range": float(skill.get("range")),
		"hitstun": float(skill.get("hitstun")),
		"knockback": float(skill.get("knockback")),
		"hitbox_half_width": float(skill.get("hitbox_half_width")),
		"hitbox_half_depth": float(skill.get("hitbox_half_depth")),
		"formation_count": int(skill.get("formation_count")),
		"formation_spacing": float(skill.get("formation_spacing")),
		"formation_interval": float(skill.get("formation_interval")),
		"formation_offset": float(skill.get("formation_offset")),
		"buff_duration": float(skill.get("buff_duration")),
		"move_speed_multiplier": float(skill.get("move_speed_multiplier")),
		"basic_attack_damage_multiplier": float(skill.get("basic_attack_damage_multiplier")),
		"trap_duration": float(skill.get("trap_duration")),
		"aura_duration": float(skill.get("aura_duration")),
		"timeline_schema_version": int(skill.get("timeline_schema_version")),
		"spatial_timeline_events": _authoritative_spatial_timeline_events(skill)
	}

static func _authoritative_spatial_timeline_events(skill) -> Array:
	var result: Array = []
	var raw_events: Array = skill.get("timeline_events")
	for raw_event in raw_events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = raw_event
		var event_type := str(event.get("type", "")).strip_edges().to_lower()
		if event_type != "hitbox" and event_type != "hurtbox":
			continue
		result.append({
			"id": str(event.get("id", "")).strip_edges(),
			"type": event_type,
			"time": float(event.get("time", 0.0)),
			"duration": float(event.get("duration", 0.0)),
			"half_width": float(event.get("half_width", 0.0)),
			"half_depth": float(event.get("half_depth", 0.0)),
			"offset_x": float(event.get("offset_x", 0.0)),
			"offset_depth": float(event.get("offset_depth", 0.0))
		})
	return result

static func _canonical_fingerprint_input(snapshot: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("snapshot_version=%d" % int(snapshot.get("snapshot_version", 0)))
	lines.append("fingerprint_version=%d" % int(snapshot.get("fingerprint_version", 0)))
	lines.append("ruleset_id=%s" % str(snapshot.get("ruleset_id", "")))
	lines.append("ruleset_version=%d" % int(snapshot.get("ruleset_version", 0)))
	lines.append("character_id=%s" % str(snapshot.get("character_id", "")))
	lines.append("character_schema_version=%d" % int(snapshot.get("character_schema_version", 0)))

	var character_stats: Dictionary = snapshot.get("normalized_character_stats", {})
	lines.append("character.max_hp=%d" % int(character_stats.get("max_hp", 0)))
	lines.append("character.max_mp=%d" % int(character_stats.get("max_mp", 0)))
	lines.append("character.move_speed=%d" % _scaled(character_stats.get("move_speed", 0.0)))
	lines.append("character.depth_speed=%d" % _scaled(character_stats.get("depth_speed", 0.0)))
	lines.append("character.run_multiplier=%d" % _scaled(character_stats.get("run_multiplier", 0.0)))
	lines.append("character.guard_move_multiplier=%d" % _scaled(character_stats.get("guard_move_multiplier", 0.0)))

	var resolved_slots: Dictionary = snapshot.get("resolved_skill_slots", {})
	var slot_names := PackedStringArray()
	for raw_slot in resolved_slots.keys():
		slot_names.append(str(raw_slot))
	slot_names.sort()
	for slot_name in slot_names:
		lines.append("slot.%s=%s" % [slot_name, str(resolved_slots.get(slot_name, ""))])

	var skills: Dictionary = snapshot.get("normalized_skill_values", {})
	var skill_ids := PackedStringArray()
	for raw_skill_id in skills.keys():
		skill_ids.append(str(raw_skill_id))
	skill_ids.sort()
	for skill_id in skill_ids:
		var values: Dictionary = skills.get(skill_id, {})
		_append_skill_fingerprint_lines(lines, skill_id, values)

	var budget: Dictionary = snapshot.get("power_budget_result", {})
	lines.append("budget.id=%s" % str(budget.get("budget_id", "")))
	lines.append("budget.version=%d" % int(budget.get("budget_version", 0)))
	lines.append("budget.character_score=%d" % int(budget.get("character_score", 0)))
	lines.append("budget.total_score=%d" % int(budget.get("total_score", 0)))
	var skill_scores: Dictionary = budget.get("skill_scores", {})
	var scored_ids := PackedStringArray()
	for raw_skill_id in skill_scores.keys():
		scored_ids.append(str(raw_skill_id))
	scored_ids.sort()
	for skill_id in scored_ids:
		lines.append("budget.skill.%s=%d" % [skill_id, int(skill_scores.get(skill_id, 0))])

	return "\n".join(lines)

static func _append_skill_fingerprint_lines(
	lines: PackedStringArray,
	skill_id: String,
	values: Dictionary
) -> void:
	lines.append("skill.%s.schema_version=%d" % [skill_id, int(values.get("schema_version", 0))])
	lines.append("skill.%s.id=%s" % [skill_id, str(values.get("id", ""))])
	lines.append("skill.%s.type=%s" % [skill_id, str(values.get("type", ""))])
	lines.append("skill.%s.damage=%d" % [skill_id, int(values.get("damage", 0))])
	lines.append("skill.%s.mp_cost=%d" % [skill_id, int(values.get("mp_cost", 0))])
	for field in [
		"cooldown",
		"startup",
		"active",
		"recovery",
		"speed",
		"range",
		"hitstun",
		"knockback",
		"hitbox_half_width",
		"hitbox_half_depth",
		"formation_spacing",
		"formation_interval",
		"formation_offset",
		"buff_duration",
		"move_speed_multiplier",
		"basic_attack_damage_multiplier",
		"trap_duration",
		"aura_duration"
	]:
		lines.append(
			"skill.%s.%s=%d" % [skill_id, field, _scaled(values.get(field, 0.0))]
		)
	lines.append("skill.%s.formation_count=%d" % [skill_id, int(values.get("formation_count", 0))])
	lines.append(
		"skill.%s.timeline_schema_version=%d"
		% [skill_id, int(values.get("timeline_schema_version", 0))]
	)

	var spatial_events: Array = values.get("spatial_timeline_events", [])
	lines.append("skill.%s.spatial_event_count=%d" % [skill_id, spatial_events.size()])
	for index in range(spatial_events.size()):
		var event: Dictionary = spatial_events[index]
		var prefix := "skill.%s.spatial.%d" % [skill_id, index]
		lines.append("%s.id=%s" % [prefix, str(event.get("id", ""))])
		lines.append("%s.type=%s" % [prefix, str(event.get("type", ""))])
		for field in ["time", "duration", "half_width", "half_depth", "offset_x", "offset_depth"]:
			lines.append("%s.%s=%d" % [prefix, field, _scaled(event.get(field, 0.0))])

static func _scaled(value) -> int:
	return int(round(float(value) * FLOAT_SCALE))

static func _failure(
	ruleset_id: String,
	ruleset_version: int,
	character_id: String,
	diagnostics: PackedStringArray,
	budget_result: Dictionary = {}
) -> Dictionary:
	return {
		"valid": false,
		"snapshot_version": SNAPSHOT_VERSION,
		"fingerprint_version": FINGERPRINT_VERSION,
		"ruleset_id": ruleset_id,
		"ruleset_version": ruleset_version,
		"character_id": character_id,
		"character_schema_version": 0,
		"normalized_character_stats": {},
		"resolved_skill_slots": {},
		"normalized_skill_values": {},
		"power_budget_result": budget_result.duplicate(true),
		"content_fingerprint": "",
		"diagnostic_codes": diagnostics.duplicate()
	}
