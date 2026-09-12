class_name CharacterVisualProfile
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1
const PROFILE_ROOT := "res://content/character_profiles"
const ALLOWED_TOP_LEVEL_FIELDS := ["schema_version", "id", "palette", "body"]
const ALLOWED_PALETTE_FIELDS := ["body", "accent", "weapon", "guard"]
const ALLOWED_BODY_FIELDS := [
	"body_height",
	"head_radius",
	"torso_width",
	"torso_height",
	"arm_reach",
	"arm_width",
	"leg_length",
	"leg_spread",
	"leg_width",
	"shadow_half_width",
	"shadow_half_height",
	"weapon_length",
	"weapon_width"
]

var schema_version := CURRENT_SCHEMA_VERSION
var profile_id := ""
var body_color_hex := "#62d8ff"
var accent_color_hex := "#b8f3ff"
var weapon_color_hex := "#e9edf7"
var guard_color_hex := "#9cf5d4"
var body_height := 118.0
var head_radius := 22.0
var torso_width := 36.0
var torso_height := 70.0
var arm_reach := 48.0
var arm_width := 9.0
var leg_length := 30.0
var leg_spread := 20.0
var leg_width := 10.0
var shadow_half_width := 34.0
var shadow_half_height := 10.0
var weapon_length := 49.0
var weapon_width := 5.0
var loaded := false

func load_from_id(requested_id: String) -> PackedStringArray:
	loaded = false
	var safe_id := requested_id.strip_edges().to_lower()
	var errors := PackedStringArray()
	if not _is_safe_token(safe_id):
		errors.append("visual profile reference must be a safe lowercase token")
		return errors

	var path := "%s/%s.profile.json" % [PROFILE_ROOT, safe_id]
	errors = load_from_file(path)
	if errors.is_empty() and profile_id != safe_id:
		errors.append("visual profile id mismatch: expected %s, got %s" % [safe_id, profile_id])
		loaded = false
	return errors

func load_from_file(path: String) -> PackedStringArray:
	loaded = false
	var errors := PackedStringArray()
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		errors.append("visual profile file is empty or missing: %s" % path)
		return errors

	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("visual profile file must contain one JSON object: %s" % path)
		return errors
	return load_from_dictionary(parsed)

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	loaded = false
	var errors := PackedStringArray()
	_validate_allowed_fields(data, ALLOWED_TOP_LEVEL_FIELDS, "visual_profile", errors)

	for field in ALLOWED_TOP_LEVEL_FIELDS:
		if not data.has(field):
			errors.append("missing required visual profile field: %s" % field)
	if not errors.is_empty():
		return errors

	if typeof(data.get("palette")) != TYPE_DICTIONARY:
		errors.append("visual profile palette must be an object")
	if typeof(data.get("body")) != TYPE_DICTIONARY:
		errors.append("visual profile body must be an object")
	if not errors.is_empty():
		return errors

	var palette: Dictionary = data.get("palette", {})
	var body: Dictionary = data.get("body", {})
	_validate_allowed_fields(palette, ALLOWED_PALETTE_FIELDS, "visual_profile.palette", errors)
	_validate_allowed_fields(body, ALLOWED_BODY_FIELDS, "visual_profile.body", errors)
	for field in ALLOWED_PALETTE_FIELDS:
		if not palette.has(field):
			errors.append("missing required visual profile palette field: %s" % field)
	for field in ALLOWED_BODY_FIELDS:
		if not body.has(field):
			errors.append("missing required visual profile body field: %s" % field)
	if not errors.is_empty():
		return errors

	schema_version = int(data.get("schema_version", 0))
	profile_id = str(data.get("id", "")).strip_edges().to_lower()
	body_color_hex = str(palette.get("body", "")).strip_edges().to_lower()
	accent_color_hex = str(palette.get("accent", "")).strip_edges().to_lower()
	weapon_color_hex = str(palette.get("weapon", "")).strip_edges().to_lower()
	guard_color_hex = str(palette.get("guard", "")).strip_edges().to_lower()
	body_height = float(body.get("body_height", 0.0))
	head_radius = float(body.get("head_radius", 0.0))
	torso_width = float(body.get("torso_width", 0.0))
	torso_height = float(body.get("torso_height", 0.0))
	arm_reach = float(body.get("arm_reach", 0.0))
	arm_width = float(body.get("arm_width", 0.0))
	leg_length = float(body.get("leg_length", 0.0))
	leg_spread = float(body.get("leg_spread", 0.0))
	leg_width = float(body.get("leg_width", 0.0))
	shadow_half_width = float(body.get("shadow_half_width", 0.0))
	shadow_half_height = float(body.get("shadow_half_height", 0.0))
	weapon_length = float(body.get("weapon_length", 0.0))
	weapon_width = float(body.get("weapon_width", 0.0))

	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported visual profile schema_version: %d" % schema_version)
	if not _is_safe_token(profile_id):
		errors.append("visual profile id must be a safe lowercase token")

	_validate_color(body_color_hex, "palette.body", errors)
	_validate_color(accent_color_hex, "palette.accent", errors)
	_validate_color(weapon_color_hex, "palette.weapon", errors)
	_validate_color(guard_color_hex, "palette.guard", errors)

	_validate_range(body_height, 60.0, 220.0, "body_height", errors)
	_validate_range(head_radius, 8.0, 64.0, "head_radius", errors)
	_validate_range(torso_width, 16.0, 100.0, "torso_width", errors)
	_validate_range(torso_height, 30.0, 140.0, "torso_height", errors)
	_validate_range(arm_reach, 20.0, 120.0, "arm_reach", errors)
	_validate_range(arm_width, 2.0, 24.0, "arm_width", errors)
	_validate_range(leg_length, 12.0, 90.0, "leg_length", errors)
	_validate_range(leg_spread, 8.0, 70.0, "leg_spread", errors)
	_validate_range(leg_width, 2.0, 24.0, "leg_width", errors)
	_validate_range(shadow_half_width, 10.0, 100.0, "shadow_half_width", errors)
	_validate_range(shadow_half_height, 3.0, 35.0, "shadow_half_height", errors)
	_validate_range(weapon_length, 0.0, 160.0, "weapon_length", errors)
	_validate_range(weapon_width, 1.0, 18.0, "weapon_width", errors)

	loaded = errors.is_empty()
	return errors

func body_color() -> Color:
	return Color(body_color_hex)

func accent_color() -> Color:
	return Color(accent_color_hex)

func weapon_color() -> Color:
	return Color(weapon_color_hex)

func guard_color() -> Color:
	return Color(guard_color_hex)

func _validate_allowed_fields(data: Dictionary, allowed_fields: Array, scope: String, errors: PackedStringArray) -> void:
	for raw_key in data.keys():
		var key := str(raw_key)
		if not allowed_fields.has(key):
			errors.append("unsupported %s field: %s" % [scope, key])

func _validate_color(value: String, label: String, errors: PackedStringArray) -> void:
	var regex := RegEx.new()
	regex.compile("^#[0-9a-f]{6}([0-9a-f]{2})?$")
	if regex.search(value) == null:
		errors.append("visual profile %s must be #rrggbb or #rrggbbaa" % label)

func _validate_range(value: float, minimum: float, maximum: float, label: String, errors: PackedStringArray) -> void:
	if value < minimum or value > maximum:
		errors.append("visual profile %s must be between %.2f and %.2f" % [label, minimum, maximum])

func _is_safe_token(value: String) -> bool:
	if value.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null
