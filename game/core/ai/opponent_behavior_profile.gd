class_name OpponentBehaviorProfile
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1
const SUPPORTED_SKILL_SLOTS := [
	"skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6",
	"skill_7", "skill_8", "skill_9", "skill_10", "skill_11", "skill_12", "skill_13"
]
const SUPPORTED_GUARD_POLICIES := ["never", "when_threatened"]
const ALLOWED_FIELDS := [
	"schema_version",
	"id",
	"reaction_interval",
	"preferred_min_distance",
	"preferred_max_distance",
	"depth_tolerance",
	"basic_attack_range",
	"guard_policy",
	"allow_basic_attack",
	"preferred_skill_slot"
]
const REQUIRED_FIELDS := ALLOWED_FIELDS

var schema_version := CURRENT_SCHEMA_VERSION
var profile_id := ""
var reaction_interval := 0.25
var preferred_min_distance := 100.0
var preferred_max_distance := 180.0
var depth_tolerance := 0.10
var basic_attack_range := 150.0
var guard_policy := "never"
var allow_basic_attack := true
var preferred_skill_slot := ""
var loaded := false

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	loaded = false
	var errors := PackedStringArray()
	_validate_allowed_fields(data, errors)
	for field in REQUIRED_FIELDS:
		if not data.has(field):
			errors.append("missing required opponent behavior field: %s" % field)
	if not errors.is_empty():
		return errors

	_validate_field_types(data, errors)
	if not errors.is_empty():
		return errors

	schema_version = int(data.get("schema_version", 0))
	profile_id = str(data.get("id", "")).strip_edges().to_lower()
	reaction_interval = float(data.get("reaction_interval", 0.0))
	preferred_min_distance = float(data.get("preferred_min_distance", 0.0))
	preferred_max_distance = float(data.get("preferred_max_distance", 0.0))
	depth_tolerance = float(data.get("depth_tolerance", 0.0))
	basic_attack_range = float(data.get("basic_attack_range", 0.0))
	guard_policy = str(data.get("guard_policy", "")).strip_edges().to_lower()
	allow_basic_attack = bool(data.get("allow_basic_attack", false))
	preferred_skill_slot = str(data.get("preferred_skill_slot", "")).strip_edges().to_lower()

	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported opponent behavior schema_version: %d" % schema_version)
	if not _is_safe_token(profile_id):
		errors.append("opponent behavior id must be a safe lowercase token")
	if reaction_interval < 0.05 or reaction_interval > 2.0:
		errors.append("reaction_interval must be between 0.05 and 2.0")
	if preferred_min_distance < 0.0 or preferred_min_distance > 1000.0:
		errors.append("preferred_min_distance must be between 0 and 1000")
	if preferred_max_distance < preferred_min_distance or preferred_max_distance > 1200.0:
		errors.append("preferred_max_distance must be >= preferred_min_distance and <= 1200")
	if depth_tolerance < 0.01 or depth_tolerance > 0.50:
		errors.append("depth_tolerance must be between 0.01 and 0.50")
	if basic_attack_range < 0.0 or basic_attack_range > 500.0:
		errors.append("basic_attack_range must be between 0 and 500")
	if not SUPPORTED_GUARD_POLICIES.has(guard_policy):
		errors.append("unsupported guard_policy: %s" % guard_policy)
	if not preferred_skill_slot.is_empty() and not SUPPORTED_SKILL_SLOTS.has(preferred_skill_slot):
		errors.append("unsupported preferred_skill_slot: %s" % preferred_skill_slot)

	loaded = errors.is_empty()
	return errors

func _validate_allowed_fields(data: Dictionary, errors: PackedStringArray) -> void:
	for raw_key in data.keys():
		var key := str(raw_key)
		if not ALLOWED_FIELDS.has(key):
			errors.append("unsupported opponent behavior field: %s" % key)

func _validate_field_types(data: Dictionary, errors: PackedStringArray) -> void:
	if typeof(data.get("schema_version")) != TYPE_INT:
		errors.append("schema_version must be an integer")
	if typeof(data.get("id")) != TYPE_STRING:
		errors.append("id must be a string")
	for field in [
		"reaction_interval",
		"preferred_min_distance",
		"preferred_max_distance",
		"depth_tolerance",
		"basic_attack_range"
	]:
		var value = data.get(field)
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			errors.append("%s must be numeric" % field)
	if typeof(data.get("guard_policy")) != TYPE_STRING:
		errors.append("guard_policy must be a string")
	if typeof(data.get("allow_basic_attack")) != TYPE_BOOL:
		errors.append("allow_basic_attack must be a boolean")
	if typeof(data.get("preferred_skill_slot")) != TYPE_STRING:
		errors.append("preferred_skill_slot must be a string")

func _is_safe_token(value: String) -> bool:
	if value.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null
