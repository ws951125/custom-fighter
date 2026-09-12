class_name SkillDefinition
extends RefCounted

const SUPPORTED_TYPES = ["melee", "projectile", "area", "dash", "formation", "buff"]
const CURRENT_SCHEMA_VERSION := 1

var schema_version := CURRENT_SCHEMA_VERSION
var skill_id := ""
var skill_name := ""
var skill_type := ""
var damage := 0
var mp_cost := 0
var cooldown := 0.0
var startup := 0.0
var active := 0.0
var recovery := 0.0
var speed := 0.0
var range := 0.0
var hitstun := 0.0
var knockback := 0.0
var hitbox_half_width := 24.0
var hitbox_half_depth := 0.08
var formation_count := 0
var formation_spacing := 0.0
var formation_interval := 0.0
var formation_offset := 0.0
var buff_duration := 0.0
var move_speed_multiplier := 1.0
var basic_attack_damage_multiplier := 1.0
var visual := ""
var impact_visual := ""
var loaded := false

func load_from_file(path: String) -> PackedStringArray:
	loaded = false
	var errors := PackedStringArray()
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		errors.append("skill file is empty or missing: %s" % path)
		return errors

	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("skill file must contain one JSON object: %s" % path)
		return errors

	return load_from_dictionary(parsed)

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	loaded = false
	var errors := PackedStringArray()
	var required_fields := [
		"schema_version", "id", "name", "type", "damage", "mp_cost", "cooldown",
		"startup", "active", "recovery", "visual", "impact_visual"
	]
	for field in required_fields:
		if not data.has(field):
			errors.append("missing required field: %s" % field)

	if not errors.is_empty():
		return errors

	schema_version = int(data.get("schema_version", 0))
	skill_id = str(data.get("id", "")).strip_edges()
	skill_name = str(data.get("name", "")).strip_edges()
	skill_type = str(data.get("type", "")).strip_edges().to_lower()
	damage = int(data.get("damage", 0))
	mp_cost = int(data.get("mp_cost", 0))
	cooldown = float(data.get("cooldown", 0.0))
	startup = float(data.get("startup", 0.0))
	active = float(data.get("active", 0.0))
	recovery = float(data.get("recovery", 0.0))
	speed = float(data.get("speed", 0.0))
	range = float(data.get("range", 0.0))
	hitstun = float(data.get("hitstun", 0.0))
	knockback = float(data.get("knockback", 0.0))
	hitbox_half_width = float(data.get("hitbox_half_width", 24.0))
	hitbox_half_depth = float(data.get("hitbox_half_depth", 0.08))
	formation_count = int(data.get("formation_count", 0))
	formation_spacing = float(data.get("formation_spacing", 0.0))
	formation_interval = float(data.get("formation_interval", 0.0))
	formation_offset = float(data.get("formation_offset", 0.0))
	buff_duration = float(data.get("buff_duration", 0.0))
	move_speed_multiplier = float(data.get("move_speed_multiplier", 1.0))
	basic_attack_damage_multiplier = float(data.get("basic_attack_damage_multiplier", 1.0))
	visual = str(data.get("visual", "")).strip_edges()
	impact_visual = str(data.get("impact_visual", "")).strip_edges()

	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported schema_version: %d" % schema_version)
	if skill_id.is_empty():
		errors.append("id must not be empty")
	if skill_name.is_empty():
		errors.append("name must not be empty")
	if not SUPPORTED_TYPES.has(skill_type):
		errors.append("unsupported skill type: %s" % skill_type)
	if damage < 0:
		errors.append("damage must be non-negative")
	if mp_cost < 0:
		errors.append("mp_cost must be non-negative")
	if cooldown < 0.0:
		errors.append("cooldown must be non-negative")
	if startup < 0.0 or active < 0.0 or recovery < 0.0:
		errors.append("startup/active/recovery must be non-negative")
	if hitstun < 0.0 or knockback < 0.0:
		errors.append("hitstun/knockback must be non-negative")
	if visual.is_empty() or impact_visual.is_empty():
		errors.append("visual and impact_visual must not be empty")

	if skill_type == "projectile" or skill_type == "dash":
		_validate_motion_skill(errors)
	elif skill_type == "area":
		_validate_area_skill(errors)
	elif skill_type == "formation":
		_validate_formation_skill(errors)
	elif skill_type == "buff":
		_validate_buff_skill(errors)

	loaded = errors.is_empty()
	return errors

func _validate_motion_skill(errors: PackedStringArray) -> void:
	if speed <= 0.0:
		errors.append("%s speed must be positive" % skill_type)
	if range <= 0.0:
		errors.append("%s range must be positive" % skill_type)
	if active <= 0.0:
		errors.append("%s active duration must be positive" % skill_type)
	if hitbox_half_width <= 0.0 or hitbox_half_depth <= 0.0:
		errors.append("%s hitbox dimensions must be positive" % skill_type)

func _validate_area_skill(errors: PackedStringArray) -> void:
	if active <= 0.0:
		errors.append("area active duration must be positive")
	if hitbox_half_width <= 0.0 or hitbox_half_depth <= 0.0:
		errors.append("area hitbox dimensions must be positive")

func _validate_formation_skill(errors: PackedStringArray) -> void:
	if active <= 0.0:
		errors.append("formation active duration must be positive")
	if hitbox_half_width <= 0.0 or hitbox_half_depth <= 0.0:
		errors.append("formation hitbox dimensions must be positive")
	if formation_count <= 0:
		errors.append("formation_count must be positive")
	if formation_spacing <= 0.0:
		errors.append("formation_spacing must be positive")
	if formation_interval <= 0.0:
		errors.append("formation_interval must be positive")
	if formation_offset < 0.0:
		errors.append("formation_offset must be non-negative")
	if formation_count > 0 and formation_interval > 0.0:
		var final_strike_time := float(formation_count - 1) * formation_interval
		if active + 0.0001 < final_strike_time:
			errors.append("formation active duration must include the final strike")

func _validate_buff_skill(errors: PackedStringArray) -> void:
	if buff_duration <= 0.0:
		errors.append("buff_duration must be positive")
	if move_speed_multiplier < 1.0:
		errors.append("move_speed_multiplier must be at least 1.0")
	if basic_attack_damage_multiplier < 1.0:
		errors.append("basic_attack_damage_multiplier must be at least 1.0")
