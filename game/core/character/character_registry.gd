class_name CharacterRegistry
extends RefCounted

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")

const CURRENT_SCHEMA_VERSION := 1
const DEFAULT_REGISTRY_PATH := "res://content/characters/registry.json"
const CHARACTER_ROOT := "res://content/characters/"
const ALLOWED_TOP_LEVEL_FIELDS := ["schema_version", "default_character", "characters"]
const ALLOWED_ENTRY_FIELDS := ["file"]

var schema_version := CURRENT_SCHEMA_VERSION
var default_character_id := ""
var entries: Dictionary = {}
var loaded := false

func load_default() -> PackedStringArray:
	return load_from_file(DEFAULT_REGISTRY_PATH)

func load_from_file(path: String) -> PackedStringArray:
	loaded = false
	entries.clear()
	default_character_id = ""
	var errors := PackedStringArray()
	if path != DEFAULT_REGISTRY_PATH:
		errors.append("character registry path must use the approved default path")
		return errors
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		errors.append("character registry file is empty or missing: %s" % path)
		return errors
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("character registry file must contain one JSON object: %s" % path)
		return errors
	return load_from_dictionary(parsed)

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	loaded = false
	entries.clear()
	default_character_id = ""
	var errors := PackedStringArray()
	_validate_allowed_fields(data, ALLOWED_TOP_LEVEL_FIELDS, "registry", errors)
	for field in ALLOWED_TOP_LEVEL_FIELDS:
		if not data.has(field):
			errors.append("missing required character registry field: %s" % field)
	if not errors.is_empty():
		return errors
	if typeof(data.get("characters")) != TYPE_DICTIONARY:
		errors.append("characters must be an object")
		return errors

	schema_version = int(data.get("schema_version", 0))
	default_character_id = str(data.get("default_character", "")).strip_edges()
	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported character registry schema_version: %d" % schema_version)
	if not _is_safe_token(default_character_id):
		errors.append("default_character must be a safe lowercase token")

	var characters: Dictionary = data.get("characters", {})
	for raw_id in characters.keys():
		var character_id := str(raw_id).strip_edges()
		if not _is_safe_token(character_id):
			errors.append("character registry id must be a safe lowercase token: %s" % character_id)
			continue
		var raw_entry = characters.get(raw_id)
		if typeof(raw_entry) != TYPE_DICTIONARY:
			errors.append("character registry entry must be an object: %s" % character_id)
			continue
		var entry: Dictionary = raw_entry
		_validate_allowed_fields(entry, ALLOWED_ENTRY_FIELDS, "character registry entry %s" % character_id, errors)
		if not entry.has("file"):
			errors.append("character registry entry missing file: %s" % character_id)
			continue
		var file_name := str(entry.get("file", "")).strip_edges()
		if not _is_safe_character_file(file_name):
			errors.append("character registry file must be a safe .sample.json filename: %s" % character_id)
			continue
		entries[character_id] = {"file": file_name}

	if not default_character_id.is_empty() and not entries.has(default_character_id):
		errors.append("default_character is not registered: %s" % default_character_id)

	loaded = errors.is_empty()
	if not loaded:
		entries.clear()
	return errors

func load_character(character_id: String, target_character) -> PackedStringArray:
	var errors := PackedStringArray()
	var normalized_id := character_id.strip_edges()
	if not loaded:
		errors.append("character registry is not loaded")
		return errors
	if not _is_safe_token(normalized_id):
		errors.append("character id must be a safe lowercase token")
		return errors
	if not entries.has(normalized_id):
		errors.append("unknown character id: %s" % normalized_id)
		return errors
	if target_character == null or not target_character.has_method("load_from_file"):
		errors.append("target character definition is invalid")
		return errors

	var load_errors: PackedStringArray = target_character.load_from_file(source_path_for_id(normalized_id))
	for load_error in load_errors:
		errors.append(str(load_error))
	if not errors.is_empty():
		return errors
	if target_character.character_id != normalized_id:
		errors.append("character id mismatch for registry entry %s: file contains %s" % [normalized_id, target_character.character_id])
		target_character.loaded = false
	return errors

func source_path_for_id(character_id: String) -> String:
	if not loaded or not entries.has(character_id):
		return ""
	var entry: Dictionary = entries[character_id]
	return CHARACTER_ROOT + str(entry.get("file", ""))

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

func _is_safe_character_file(value: String) -> bool:
	if value.is_empty() or value.contains("/") or value.contains("\\") or value.contains(".."):
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*\\.sample\\.json$")
	return regex.search(value) != null
