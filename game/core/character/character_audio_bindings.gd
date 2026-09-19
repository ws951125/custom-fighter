class_name CharacterAudioBindings
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1
const REQUIRED_BINDINGS := ["ready", "basic_attack", "hit_received", "skill_cast", "skill_impact"]
const ALLOWED_TOP_LEVEL_FIELDS := ["schema_version", "cues"]
const DEFAULT_CUES := {
	"ready": "character_ready",
	"basic_attack": "basic_attack",
	"hit_received": "character_hit",
	"skill_cast": "skill_cast",
	"skill_impact": "skill_impact"
}

var schema_version := CURRENT_SCHEMA_VERSION
var cues: Dictionary = {}
var loaded := false

func load_defaults() -> PackedStringArray:
	return load_from_dictionary(default_dictionary())

static func default_dictionary() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"cues": DEFAULT_CUES.duplicate(true)
	}

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	loaded = false
	var errors := PackedStringArray()
	_validate_allowed_fields(data, ALLOWED_TOP_LEVEL_FIELDS, "audio_bindings", errors)
	for field in ALLOWED_TOP_LEVEL_FIELDS:
		if not data.has(field):
			errors.append("missing required audio bindings field: %s" % field)
	if not errors.is_empty():
		return errors

	if typeof(data.get("cues")) != TYPE_DICTIONARY:
		errors.append("audio bindings cues must be an object")
		return errors

	var raw_cues: Dictionary = data.get("cues", {})
	_validate_allowed_fields(raw_cues, REQUIRED_BINDINGS, "audio_bindings.cues", errors)
	for binding in REQUIRED_BINDINGS:
		if not raw_cues.has(binding):
			errors.append("missing required audio binding: %s" % binding)
	if not errors.is_empty():
		return errors

	schema_version = int(data.get("schema_version", 0))
	cues.clear()
	for binding in REQUIRED_BINDINGS:
		cues[binding] = str(raw_cues.get(binding, "")).strip_edges().to_lower()

	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported audio bindings schema_version: %d" % schema_version)
	for binding in REQUIRED_BINDINGS:
		var cue := str(cues.get(binding, ""))
		if not _is_safe_token(cue):
			errors.append("audio cue for %s must be a safe lowercase token" % binding)

	loaded = errors.is_empty()
	return errors

func cue_for_binding(binding: String) -> String:
	if not loaded:
		return ""
	var normalized := binding.strip_edges().to_lower()
	if not REQUIRED_BINDINGS.has(normalized):
		return ""
	return str(cues.get(normalized, ""))

func to_dictionary() -> Dictionary:
	if not loaded:
		return {}
	var canonical: Dictionary = {}
	for binding in REQUIRED_BINDINGS:
		canonical[binding] = str(cues.get(binding, ""))
	return {
		"schema_version": schema_version,
		"cues": canonical
	}

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
