class_name CompetitiveLoadoutSnapshotBuilder
extends RefCounted

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterRegistry = preload("res://game/core/character/character_registry.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const CompetitiveRulesetDefinition = preload("res://game/core/mode/competitive_ruleset_definition.gd")
const CompetitiveRulesetRegistry = preload("res://game/core/mode/competitive_ruleset_registry.gd")
const CompetitivePowerBudgetValidator = preload("res://game/core/mode/competitive_power_budget_validator.gd")

const SNAPSHOT_SCHEMA_VERSION := 1
const FINGERPRINT_VERSION := 1
const FINGERPRINT_ALGORITHM := "sha256"
const SUPPORTED_RULESET_ID := "competitive_standard"
const SUPPORTED_POWER_BUDGET_ID := "competitive_standard_v1"
const SUPPORTED_DETERMINISM_POLICY_ID := "deterministic_v1"

static func build_from_registry(
	character_id: String,
	ruleset_id: String = SUPPORTED_RULESET_ID,
	ruleset_version: int = 1
) -> Dictionary:
	var diagnostics := PackedStringArray()

	var ruleset := CompetitiveRulesetDefinition.new()
	var ruleset_errors: PackedStringArray = CompetitiveRulesetRegistry.load_ruleset(
		ruleset_id,
		ruleset_version,
		ruleset
	)
	if not ruleset_errors.is_empty() or not ruleset.loaded:
		diagnostics.append("RULESET_RESOLUTION_FAILED")
		return _result(false, diagnostics, {})

	if (
		ruleset.ruleset_id != SUPPORTED_RULESET_ID
		or ruleset.power_budget_id != SUPPORTED_POWER_BUDGET_ID
		or ruleset.character_constraints_id != SUPPORTED_POWER_BUDGET_ID
		or ruleset.skill_constraints_id != SUPPORTED_POWER_BUDGET_ID
		or ruleset.determinism_policy_id != SUPPORTED_DETERMINISM_POLICY_ID
	):
		diagnostics.append("UNSUPPORTED_COMPETITIVE_RULESET")
		return _result(false, diagnostics, {})

	var character_registry := CharacterRegistry.new()
	var character_registry_errors: PackedStringArray = character_registry.load_default()
	if not character_registry_errors.is_empty() or not character_registry.loaded:
		diagnostics.append("CHARACTER_REGISTRY_LOAD_FAILED")
		return _result(false, diagnostics, {})

	var character := CharacterDefinition.new()
	var character_errors: PackedStringArray = character_registry.load_character(character_id, character)
	if not character_errors.is_empty() or not character.loaded:
		diagnostics.append("CHARACTER_RESOLUTION_FAILED")
		return _result(false, diagnostics, {})

	var skill_registry := SkillRegistry.new()
	var skill_registry_errors: PackedStringArray = skill_registry.load_default()
	if not skill_registry_errors.is_empty() or not skill_registry.loaded:
		diagnostics.append("SKILL_REGISTRY_LOAD_FAILED")
		return _result(false, diagnostics, {})

	var slot_names := PackedStringArray()
	for raw_slot in character.skill_slots.keys():
		slot_names.append(str(raw_slot))
	slot_names.sort()

	var resolved_skill_slots: Dictionary = {}
	var skill_by_id: Dictionary = {}
	var skills: Array = []
	for slot_name in slot_names:
		var skill_id := character.skill_id_for_slot(slot_name)
		resolved_skill_slots[slot_name] = skill_id
		if skill_by_id.has(skill_id):
			continue

		var expected_type := skill_registry.registered_type_for_id(skill_id)
		if expected_type.is_empty():
			diagnostics.append("SKILL_RESOLUTION_FAILED:%s:%s" % [slot_name, skill_id])
			continue

		var skill := SkillDefinition.new()
		var skill_errors: PackedStringArray = skill_registry.load_skill(skill_id, expected_type, skill)
		if not skill_errors.is_empty() or not skill.loaded:
			diagnostics.append("SKILL_RESOLUTION_FAILED:%s:%s" % [slot_name, skill_id])
			continue

		skill_by_id[skill_id] = skill
		skills.append(skill)

	if not diagnostics.is_empty():
		return _result(false, diagnostics, {})

	var budget_result: Dictionary = CompetitivePowerBudgetValidator.evaluate(
		ruleset.power_budget_id,
		character,
		skills
	)
	if not bool(budget_result.get("eligible", false)):
		diagnostics.append("POWER_BUDGET_REJECTED")
		var budget_codes: PackedStringArray = budget_result.get("diagnostic_codes", PackedStringArray())
		for code in budget_codes:
			diagnostics.append("BUDGET:%s" % code)
		return _result(false, diagnostics, {})

	var normalized_skill_values: Dictionary = {}
	var skill_ids := PackedStringArray()
	for raw_skill_id in skill_by_id.keys():
		skill_ids.append(str(raw_skill_id))
	skill_ids.sort()
	for skill_id in skill_ids:
		normalized_skill_values[skill_id] = _normalized_skill(skill_by_id[skill_id])

	var snapshot := {
		"snapshot_schema_version": SNAPSHOT_SCHEMA_VERSION,
		"fingerprint_version": FINGERPRINT_VERSION,
		"fingerprint_algorithm": FINGERPRINT_ALGORITHM,
		"ruleset_id": ruleset.ruleset_id,
		"ruleset_version": ruleset.version,
		"determinism_policy_id": ruleset.determinism_policy_id,
		"power_budget_id": ruleset.power_budget_id,
		"power_budget_version": int(budget_result.get("budget_version", 0)),
		"character_id": character.character_id,
		"normalized_character_stats": _normalized_character_stats(character),
		"resolved_skill_slots": resolved_skill_slots,
		"normalized_skill_values": normalized_skill_values,
		"power_budget_result": budget_result.duplicate(true)
	}
	snapshot["content_fingerprint"] = _sha256_canonical(snapshot)
	return _result(true, diagnostics, snapshot)

static func _normalized_character_stats(character) -> Dictionary:
	return {
		"max_hp": int(character.get("max_hp")),
		"max_mp": int(character.get("max_mp")),
		"move_speed": float(character.get("move_speed")),
		"depth_speed": float(character.get("depth_speed")),
		"run_multiplier": float(character.get("run_multiplier")),
		"guard_move_multiplier": float(character.get("guard_move_multiplier"))
	}

static func _normalized_skill(skill) -> Dictionary:
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
		"timeline_gameplay_events": _normalized_gameplay_timeline(skill)
	}

static func _normalized_gameplay_timeline(skill) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var raw_events: Array = skill.get("timeline_events")
	for raw_event in raw_events:
		var event: Dictionary = raw_event
		var event_type := str(event.get("type", ""))
		if event_type != "hitbox" and event_type != "hurtbox":
			continue
		events.append({
			"id": str(event.get("id", "")),
			"type": event_type,
			"time": float(event.get("time", 0.0)),
			"duration": float(event.get("duration", 0.0)),
			"half_width": float(event.get("half_width", 0.0)),
			"half_depth": float(event.get("half_depth", 0.0)),
			"offset_x": float(event.get("offset_x", 0.0)),
			"offset_depth": float(event.get("offset_depth", 0.0))
		})
	return events

static func _sha256_canonical(value: Variant) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(_canonical_string(value).to_utf8_buffer())
	return context.finish().hex_encode()

static func _canonical_string(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return JSON.stringify(value)
		TYPE_PACKED_STRING_ARRAY:
			var packed_values: PackedStringArray = value
			var string_items := PackedStringArray()
			for item in packed_values:
				string_items.append(_canonical_string(item))
			return "[" + ",".join(string_items) + "]"
		TYPE_ARRAY:
			var array_values: Array = value
			var array_items := PackedStringArray()
			for item in array_values:
				array_items.append(_canonical_string(item))
			return "[" + ",".join(array_items) + "]"
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			var keys := PackedStringArray()
			for raw_key in dictionary.keys():
				keys.append(str(raw_key))
			keys.sort()
			var dictionary_items := PackedStringArray()
			for key in keys:
				dictionary_items.append(JSON.stringify(key) + ":" + _canonical_string(dictionary.get(key)))
			return "{" + ",".join(dictionary_items) + "}"
		_:
			return JSON.stringify(str(value))

static func _result(accepted: bool, diagnostics: PackedStringArray, snapshot: Dictionary) -> Dictionary:
	return {
		"accepted": accepted,
		"diagnostic_codes": diagnostics.duplicate(),
		"snapshot": snapshot.duplicate(true)
	}
