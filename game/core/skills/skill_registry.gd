class_name SkillRegistry
extends RefCounted

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")

const CURRENT_SCHEMA_VERSION := 1
const DEFAULT_REGISTRY_PATH := "res://content/skills/registry.json"
const SKILL_ROOT := "res://content/skills/"
const ALLOWED_TOP_LEVEL_FIELDS := ["schema_version", "skills"]
const ALLOWED_ENTRY_FIELDS := ["file", "type"]

var schema_version := CURRENT_SCHEMA_VERSION
var entries: Dictionary = {}
var loaded := false

func load_default() -> PackedStringArray:
	return load_from_file(DEFAULT_REGISTRY_PATH)

func load_from_file(path: String) -> PackedStringArray:
	loaded = false
	entries.clear()
	var errors := PackedStringArray()
	if path != DEFAULT_REGISTRY_PATH:
		errors.append("skill registry path must use the approved default path")
		return errors

	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		errors.append("skill registry file is empty or missing: %s" % path)
		return errors

	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("skill registry file must contain one JSON object: %s" % path)
		return errors
	return load_from_dictionary(parsed)

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	loaded = false
	entries.clear()
	var errors := PackedStringArray()
	_validate_allowed_fields(data, ALLOWED_TOP_LEVEL_FIELDS, "registry", errors)

	if not data.has("schema_version"):
		errors.append("missing required registry field: schema_version")
	if not data.has("skills"):
		errors.append("missing required registry field: skills")
	if not errors.is_empty():
		return errors

	if typeof(data.get("skills")) != TYPE_DICTIONARY:
		errors.append("skills must be an object")
		return errors

	schema_version = int(data.get("schema_version", 0))
	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported skill registry schema_version: %d" % schema_version)

	var skills: Dictionary = data.get("skills", {})
	for raw_id in skills.keys():
		var skill_id := str(raw_id).strip_edges()
		if not _is_safe_token(skill_id):
			errors.append("skill registry id must be a safe lowercase token: %s" % skill_id)
			continue

		var raw_entry = skills.get(raw_id)
		if typeof(raw_entry) != TYPE_DICTIONARY:
			errors.append("skill registry entry must be an object: %s" % skill_id)
			continue
		var entry: Dictionary = raw_entry
		_validate_allowed_fields(entry, ALLOWED_ENTRY_FIELDS, "skill registry entry %s" % skill_id, errors)
		if not entry.has("file"):
			errors.append("skill registry entry missing file: %s" % skill_id)
		if not entry.has("type"):
			errors.append("skill registry entry missing type: %s" % skill_id)
		if not entry.has("file") or not entry.has("type"):
			continue

		var file_name := str(entry.get("file", "")).strip_edges()
		var skill_type := str(entry.get("type", "")).strip_edges().to_lower()
		if not _is_safe_skill_file(file_name):
			errors.append("skill registry file must be a safe .sample.json filename: %s" % skill_id)
		if not SkillDefinition.SUPPORTED_TYPES.has(skill_type):
			errors.append("skill registry type is unsupported for %s: %s" % [skill_id, skill_type])
		if _is_safe_skill_file(file_name) and SkillDefinition.SUPPORTED_TYPES.has(skill_type):
			entries[skill_id] = {
				"file": file_name,
				"type": skill_type
			}

	loaded = errors.is_empty()
	if not loaded:
		entries.clear()
	return errors

func load_skill(skill_id: String, expected_type: String, target_skill) -> PackedStringArray:
	var errors := PackedStringArray()
	var normalized_id := skill_id.strip_edges()
	var normalized_type := expected_type.strip_edges().to_lower()

	if not loaded:
		errors.append("skill registry is not loaded")
		return errors
	if not _is_safe_token(normalized_id):
		errors.append("skill id must be a safe lowercase token")
		return errors
	if not SkillDefinition.SUPPORTED_TYPES.has(normalized_type):
		errors.append("expected skill type is unsupported: %s" % normalized_type)
		return errors
	if not entries.has(normalized_id):
		errors.append("unknown skill id: %s" % normalized_id)
		return errors

	var entry: Dictionary = entries[normalized_id]
	var registered_type := str(entry.get("type", ""))
	if registered_type != normalized_type:
		errors.append(
			"skill type mismatch for %s: expected %s but registry declares %s" % [
				normalized_id,
				normalized_type,
				registered_type
			]
		)
		return errors

	if target_skill == null or not target_skill.has_method("load_from_file"):
		errors.append("target skill definition is invalid")
		return errors

	var file_path := source_path_for_id(normalized_id)
	var load_errors: PackedStringArray = target_skill.load_from_file(file_path)
	for load_error in load_errors:
		errors.append(str(load_error))
	if not errors.is_empty():
		return errors

	if target_skill.skill_id != normalized_id:
		errors.append(
			"skill id mismatch for registry entry %s: file contains %s" % [
				normalized_id,
				target_skill.skill_id
			]
		)
	if target_skill.skill_type != normalized_type:
		errors.append(
			"skill type mismatch for %s: expected %s but file contains %s" % [
				normalized_id,
				normalized_type,
				target_skill.skill_type
			]
		)
	if not errors.is_empty():
		target_skill.loaded = false
	return errors

func source_path_for_id(skill_id: String) -> String:
	if not loaded or not entries.has(skill_id):
		return ""
	var entry: Dictionary = entries[skill_id]
	return SKILL_ROOT + str(entry.get("file", ""))

func registered_type_for_id(skill_id: String) -> String:
	if not loaded or not entries.has(skill_id):
		return ""
	var entry: Dictionary = entries[skill_id]
	return str(entry.get("type", ""))

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

func _is_safe_skill_file(value: String) -> bool:
	if value.is_empty() or value.contains("/") or value.contains("\\") or value.contains(".."):
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*\\.sample\\.json$")
	return regex.search(value) != null
