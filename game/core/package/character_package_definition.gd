class_name CharacterPackageDefinition
extends RefCounted

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")

const CURRENT_SCHEMA_VERSION := 1
const MAX_SKILL_DEFINITIONS := 6
const ALLOWED_TOP_LEVEL_FIELDS := [
	"schema_version", "package_id", "package_version", "character", "skills"
]
const ALLOWED_SKILL_FIELDS := [
	"schema_version", "id", "name", "type", "damage", "mp_cost", "cooldown",
	"startup", "active", "recovery", "speed", "range", "hitstun", "knockback",
	"hitbox_half_width", "hitbox_half_depth", "formation_count", "formation_spacing",
	"formation_interval", "formation_offset", "buff_duration", "move_speed_multiplier",
	"basic_attack_damage_multiplier", "trap_duration", "aura_duration", "visual", "impact_visual"
]

var schema_version := CURRENT_SCHEMA_VERSION
var package_id := ""
var package_version := 1
var character_data: Dictionary = {}
var skill_data_by_id: Dictionary = {}
var loaded := false

func reset() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	package_id = ""
	package_version = 1
	character_data.clear()
	skill_data_by_id.clear()
	loaded = false

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	reset()
	var errors := PackedStringArray()
	_validate_allowed_fields(data, ALLOWED_TOP_LEVEL_FIELDS, "package", errors)

	for field in ALLOWED_TOP_LEVEL_FIELDS:
		if not data.has(field):
			errors.append("missing required package field: %s" % field)

	if not errors.is_empty():
		return errors

	schema_version = int(data.get("schema_version", 0))
	package_id = str(data.get("package_id", "")).strip_edges().to_lower()
	package_version = int(data.get("package_version", 0))

	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported package schema_version: %d" % schema_version)
	if not _is_safe_token(package_id):
		errors.append("package_id must be a safe lowercase reference token")
	if package_version < 1:
		errors.append("package_version must be at least 1")

	var character_value: Variant = data.get("character")
	if not character_value is Dictionary:
		errors.append("character must be an object")

	var skills_value: Variant = data.get("skills")
	if not skills_value is Array:
		errors.append("skills must be an array")

	if not errors.is_empty():
		return errors

	var character_input: Dictionary = character_value
	var character := CharacterDefinition.new()
	var character_errors: PackedStringArray = character.load_from_dictionary(character_input)
	for character_error in character_errors:
		errors.append("character: %s" % character_error)

	if not character_errors.is_empty():
		return errors

	if package_id != character.character_id:
		errors.append("package_id must match character id")

	character_data = _character_to_dictionary(character)

	var skill_entries: Array = skills_value
	if skill_entries.is_empty():
		errors.append("skills must contain at least one skill definition")
	if skill_entries.size() > MAX_SKILL_DEFINITIONS:
		errors.append("skills must contain at most %d skill definitions" % MAX_SKILL_DEFINITIONS)

	for index in range(skill_entries.size()):
		var skill_value: Variant = skill_entries[index]
		if not skill_value is Dictionary:
			errors.append("skills[%d] must be an object" % index)
			continue

		var skill_input: Dictionary = skill_value
		_validate_allowed_fields(skill_input, ALLOWED_SKILL_FIELDS, "skills[%d]" % index, errors)

		var skill := SkillDefinition.new()
		var skill_errors: PackedStringArray = skill.load_from_dictionary(skill_input)
		for skill_error in skill_errors:
			errors.append("skills[%d]: %s" % [index, skill_error])
		if not skill_errors.is_empty():
			continue

		if not _is_safe_token(skill.skill_id):
			errors.append("skills[%d]: id must be a safe lowercase reference token" % index)
			continue
		if not _is_safe_token(skill.visual):
			errors.append("skills[%d]: visual must be a safe lowercase reference token" % index)
			continue
		if not _is_safe_token(skill.impact_visual):
			errors.append("skills[%d]: impact_visual must be a safe lowercase reference token" % index)
			continue
		if skill_data_by_id.has(skill.skill_id):
			errors.append("duplicate skill id: %s" % skill.skill_id)
			continue

		skill_data_by_id[skill.skill_id] = _skill_to_dictionary(skill)

	if not errors.is_empty():
		return errors

	var referenced_skill_ids: Dictionary = {}
	for slot in CharacterDefinition.REQUIRED_SKILL_SLOTS:
		var referenced_skill_id: String = character.skill_id_for_slot(slot)
		referenced_skill_ids[referenced_skill_id] = true
		if not skill_data_by_id.has(referenced_skill_id):
			errors.append("%s references missing package skill: %s" % [slot, referenced_skill_id])

	for skill_id_value in skill_data_by_id.keys():
		var skill_id: String = str(skill_id_value)
		if not referenced_skill_ids.has(skill_id):
			errors.append("unreferenced package skill definition: %s" % skill_id)

	loaded = errors.is_empty()
	return errors

func to_dictionary() -> Dictionary:
	if not loaded:
		return {}

	var ordered_skills: Array = []
	var skill_ids: Array = skill_data_by_id.keys()
	skill_ids.sort()
	for skill_id_value in skill_ids:
		var skill_id: String = str(skill_id_value)
		ordered_skills.append(skill_data_by_id[skill_id].duplicate(true))

	return {
		"schema_version": schema_version,
		"package_id": package_id,
		"package_version": package_version,
		"character": character_data.duplicate(true),
		"skills": ordered_skills
	}

func is_valid() -> bool:
	return loaded

func _character_to_dictionary(character: Variant) -> Dictionary:
	var slots := {}
	for slot in CharacterDefinition.REQUIRED_SKILL_SLOTS:
		slots[slot] = character.skill_id_for_slot(slot)
	return {
		"schema_version": character.schema_version,
		"id": character.character_id,
		"name": character.character_name,
		"archetype": character.archetype,
		"stats": {
			"max_hp": character.max_hp,
			"max_mp": character.max_mp,
			"move_speed": character.move_speed,
			"depth_speed": character.depth_speed,
			"run_multiplier": character.run_multiplier,
			"guard_move_multiplier": character.guard_move_multiplier
		},
		"skill_slots": slots,
		"visual_profile": character.visual_profile,
		"animation_map": character.animation_map
	}

func _skill_to_dictionary(skill: Variant) -> Dictionary:
	var data := {
		"schema_version": skill.schema_version,
		"id": skill.skill_id,
		"name": skill.skill_name,
		"type": skill.skill_type,
		"damage": skill.damage,
		"mp_cost": skill.mp_cost,
		"cooldown": skill.cooldown,
		"startup": skill.startup,
		"active": skill.active,
		"recovery": skill.recovery,
		"speed": skill.speed,
		"range": skill.range,
		"hitstun": skill.hitstun,
		"knockback": skill.knockback,
		"hitbox_half_width": skill.hitbox_half_width,
		"hitbox_half_depth": skill.hitbox_half_depth,
		"formation_count": skill.formation_count,
		"formation_spacing": skill.formation_spacing,
		"formation_interval": skill.formation_interval,
		"formation_offset": skill.formation_offset,
		"buff_duration": skill.buff_duration,
		"move_speed_multiplier": skill.move_speed_multiplier,
		"basic_attack_damage_multiplier": skill.basic_attack_damage_multiplier,
		"visual": skill.visual,
		"impact_visual": skill.impact_visual
	}
	if skill.skill_type == "trap":
		data["trap_duration"] = skill.trap_duration
	if skill.skill_type == "aura":
		data["aura_duration"] = skill.aura_duration
	return data

func _validate_allowed_fields(data: Dictionary, allowed_fields: Array, scope: String, errors: PackedStringArray) -> void:
	for raw_key in data.keys():
		var key: String = str(raw_key)
		if not allowed_fields.has(key):
			errors.append("unsupported %s field: %s" % [scope, key])

func _is_safe_token(value: String) -> bool:
	if value.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null