class_name CharacterDefinition
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1
const REQUIRED_SKILL_SLOTS := ["skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6"]
const OPTIONAL_SKILL_SLOTS := ["skill_7", "skill_8", "skill_9", "skill_10", "skill_11", "skill_12"]
const SUPPORTED_SKILL_SLOTS := ["skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6", "skill_7", "skill_8", "skill_9", "skill_10", "skill_11", "skill_12"]
const ALLOWED_TOP_LEVEL_FIELDS := [
	"schema_version", "id", "name", "archetype", "stats", "skill_slots", "visual_profile", "animation_map"
]
const ALLOWED_STAT_FIELDS := [
	"max_hp", "max_mp", "move_speed", "depth_speed", "run_multiplier", "guard_move_multiplier"
]

var schema_version := CURRENT_SCHEMA_VERSION
var character_id := ""
var character_name := ""
var archetype := ""
var max_hp := 100
var max_mp := 100
var move_speed := 360.0
var depth_speed := 0.72
var run_multiplier := 1.60
var guard_move_multiplier := 0.35
var visual_profile := ""
var animation_map := ""
var skill_slots: Dictionary = {}
var loaded := false

func load_from_file(path: String) -> PackedStringArray:
	loaded = false
	var errors := PackedStringArray()
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		errors.append("character file is empty or missing: %s" % path)
		return errors

	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("character file must contain one JSON object: %s" % path)
		return errors

	return load_from_dictionary(parsed)

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	loaded = false
	var errors := PackedStringArray()
	_validate_allowed_fields(data, ALLOWED_TOP_LEVEL_FIELDS, "character", errors)

	var required_fields := ["schema_version", "id", "name", "archetype", "stats", "skill_slots", "visual_profile"]
	for field in required_fields:
		if not data.has(field):
			errors.append("missing required field: %s" % field)

	if not errors.is_empty():
		return errors

	if typeof(data.get("stats")) != TYPE_DICTIONARY:
		errors.append("stats must be an object")
	if typeof(data.get("skill_slots")) != TYPE_DICTIONARY:
		errors.append("skill_slots must be an object")
	if not errors.is_empty():
		return errors

	var stats: Dictionary = data.get("stats", {})
	var slots: Dictionary = data.get("skill_slots", {})
	_validate_allowed_fields(stats, ALLOWED_STAT_FIELDS, "stats", errors)
	_validate_allowed_fields(slots, SUPPORTED_SKILL_SLOTS, "skill_slots", errors)

	for field in ALLOWED_STAT_FIELDS:
		if not stats.has(field):
			errors.append("missing required stats field: %s" % field)
	for slot in REQUIRED_SKILL_SLOTS:
		if not slots.has(slot):
			errors.append("missing required skill slot: %s" % slot)

	if not errors.is_empty():
		return errors

	schema_version = int(data.get("schema_version", 0))
	character_id = str(data.get("id", "")).strip_edges()
	character_name = str(data.get("name", "")).strip_edges()
	archetype = str(data.get("archetype", "")).strip_edges().to_lower()
	max_hp = int(stats.get("max_hp", 0))
	max_mp = int(stats.get("max_mp", 0))
	move_speed = float(stats.get("move_speed", 0.0))
	depth_speed = float(stats.get("depth_speed", 0.0))
	run_multiplier = float(stats.get("run_multiplier", 0.0))
	guard_move_multiplier = float(stats.get("guard_move_multiplier", -1.0))
	visual_profile = str(data.get("visual_profile", "")).strip_edges()
	animation_map = str(data.get("animation_map", character_id)).strip_edges()
	skill_slots.clear()
	for slot in REQUIRED_SKILL_SLOTS:
		skill_slots[slot] = str(slots.get(slot, "")).strip_edges()
	for slot in OPTIONAL_SKILL_SLOTS:
		if slots.has(slot):
			skill_slots[slot] = str(slots.get(slot, "")).strip_edges()

	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported schema_version: %d" % schema_version)
	if not _is_safe_token(character_id):
		errors.append("id must be a safe lowercase reference token")
	if character_name.is_empty():
		errors.append("name must not be empty")
	if not _is_safe_token(archetype):
		errors.append("archetype must be a safe lowercase reference token")
	if not _is_safe_token(visual_profile):
		errors.append("visual_profile must be a safe lowercase reference token")
	if not _is_safe_token(animation_map):
		errors.append("animation_map must be a safe lowercase reference token")

	if max_hp < 1 or max_hp > 10000:
		errors.append("max_hp must be between 1 and 10000")
	if max_mp < 0 or max_mp > 10000:
		errors.append("max_mp must be between 0 and 10000")
	if move_speed <= 0.0 or move_speed > 2000.0:
		errors.append("move_speed must be greater than 0 and at most 2000")
	if depth_speed <= 0.0 or depth_speed > 5.0:
		errors.append("depth_speed must be greater than 0 and at most 5")
	if run_multiplier < 1.0 or run_multiplier > 3.0:
		errors.append("run_multiplier must be between 1.0 and 3.0")
	if guard_move_multiplier < 0.0 or guard_move_multiplier > 1.0:
		errors.append("guard_move_multiplier must be between 0.0 and 1.0")

	for slot in skill_slots.keys():
		var skill_id := str(skill_slots.get(slot, ""))
		if not _is_safe_token(skill_id):
			errors.append("%s must contain a safe skill id token" % slot)

	loaded = errors.is_empty()
	return errors

func skill_id_for_slot(slot_name: String) -> String:
	return str(skill_slots.get(slot_name, ""))

func _validate_allowed_fields(data: Dictionary, allowed_fields: Array, scope: String, errors: PackedStringArray) -> void:
	for raw_key in data.keys():
		var key := str(raw_key)
		if not allowed_fields.has(key):
			errors.append("unsupported %s field: %s" % [scope, key])

func _is_safe_token(value: String) -> bool:
	if value.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null
