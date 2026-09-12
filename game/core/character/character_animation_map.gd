class_name CharacterAnimationMap
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1
const ANIMATION_ROOT := "res://content/character_animations"
const REQUIRED_SEMANTICS := [
	"ready",
	"walk",
	"run",
	"jump",
	"dash",
	"guard",
	"attack_1",
	"attack_2",
	"attack_3",
	"skill_1",
	"skill_2",
	"skill_3",
	"skill_4",
	"skill_5",
	"skill_6"
]
const ALLOWED_TOP_LEVEL_FIELDS := ["schema_version", "id", "animations"]

var schema_version := CURRENT_SCHEMA_VERSION
var map_id := ""
var animations: Dictionary = {}
var loaded := false

func load_from_id(requested_id: String) -> PackedStringArray:
	loaded = false
	var safe_id := requested_id.strip_edges().to_lower()
	var errors := PackedStringArray()
	if not _is_safe_token(safe_id):
		errors.append("animation map reference must be a safe lowercase token")
		return errors

	var path := "%s/%s.animation.json" % [ANIMATION_ROOT, safe_id]
	errors = load_from_file(path)
	if errors.is_empty() and map_id != safe_id:
		errors.append("animation map id mismatch: expected %s, got %s" % [safe_id, map_id])
		loaded = false
	return errors

func load_from_file(path: String) -> PackedStringArray:
	loaded = false
	var errors := PackedStringArray()
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		errors.append("animation map file is empty or missing: %s" % path)
		return errors

	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("animation map file must contain one JSON object: %s" % path)
		return errors
	return load_from_dictionary(parsed)

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	loaded = false
	var errors := PackedStringArray()
	_validate_allowed_fields(data, ALLOWED_TOP_LEVEL_FIELDS, "animation_map", errors)

	for field in ALLOWED_TOP_LEVEL_FIELDS:
		if not data.has(field):
			errors.append("missing required animation map field: %s" % field)
	if not errors.is_empty():
		return errors

	if typeof(data.get("animations")) != TYPE_DICTIONARY:
		errors.append("animation map animations must be an object")
		return errors

	var raw_animations: Dictionary = data.get("animations", {})
	_validate_allowed_fields(raw_animations, REQUIRED_SEMANTICS, "animation_map.animations", errors)
	for semantic in REQUIRED_SEMANTICS:
		if not raw_animations.has(semantic):
			errors.append("missing required animation semantic: %s" % semantic)
	if not errors.is_empty():
		return errors

	schema_version = int(data.get("schema_version", 0))
	map_id = str(data.get("id", "")).strip_edges().to_lower()
	animations.clear()
	for semantic in REQUIRED_SEMANTICS:
		animations[semantic] = str(raw_animations.get(semantic, "")).strip_edges().to_lower()

	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported animation map schema_version: %d" % schema_version)
	if not _is_safe_token(map_id):
		errors.append("animation map id must be a safe lowercase token")
	for semantic in REQUIRED_SEMANTICS:
		var animation_id := str(animations.get(semantic, ""))
		if not _is_safe_token(animation_id):
			errors.append("animation id for %s must be a safe lowercase token" % semantic)

	loaded = errors.is_empty()
	return errors

func animation_id_for_semantic(semantic: String) -> String:
	if not loaded:
		return ""
	var normalized := semantic.strip_edges().to_lower()
	if not REQUIRED_SEMANTICS.has(normalized):
		normalized = "ready"
	return str(animations.get(normalized, animations.get("ready", "")))

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
