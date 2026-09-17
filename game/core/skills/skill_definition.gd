class_name SkillDefinition
extends RefCounted

const SUPPORTED_TYPES = ["melee", "projectile", "area", "dash", "formation", "buff", "beam"]
const CURRENT_SCHEMA_VERSION := 1
const TIMELINE_SCHEMA_VERSION := 1
const SUPPORTED_TIMELINE_EVENT_TYPES := ["animation", "vfx", "audio", "hitbox", "hurtbox"]
const TIMELINE_SPATIAL_EVENT_TYPES := ["hitbox", "hurtbox"]
const TIMELINE_MEDIA_EVENT_TYPES := ["animation", "vfx", "audio"]
const TIMELINE_MEDIA_FIELDS := ["animation", "visual", "cue"]
const MAX_TIMELINE_EVENTS := 64
const MAX_TIMELINE_SECONDS := 30.0
const DEFAULT_TIMELINE_ANIMATION := "skill_1"
const DEFAULT_TIMELINE_VFX := "projectile"
const DEFAULT_TIMELINE_AUDIO_CUE := "skill_cast"
const DEFAULT_TIMELINE_SPATIAL_HALF_WIDTH := 24.0
const DEFAULT_TIMELINE_SPATIAL_HALF_DEPTH := 0.08
const MAX_TIMELINE_SPATIAL_HALF_WIDTH := 4096.0
const MAX_TIMELINE_SPATIAL_HALF_DEPTH := 1.0
const MAX_TIMELINE_SPATIAL_OFFSET_X := 4096.0
const MAX_TIMELINE_SPATIAL_OFFSET_DEPTH := 1.0
const MAX_BEAM_RANGE := 4096.0

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
var timeline_schema_version := TIMELINE_SCHEMA_VERSION
var timeline_events: Array[Dictionary] = []
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
	timeline_events.clear()
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

	if skill_type == "melee":
		_validate_melee_skill(errors)
	elif skill_type == "projectile" or skill_type == "dash":
		_validate_motion_skill(errors)
	elif skill_type == "area":
		_validate_area_skill(errors)
	elif skill_type == "formation":
		_validate_formation_skill(errors)
	elif skill_type == "buff":
		_validate_buff_skill(errors)
	elif skill_type == "beam":
		_validate_beam_skill(errors)

	_load_timeline(data, errors)
	loaded = errors.is_empty()
	return errors

func has_timeline() -> bool:
	return not timeline_events.is_empty()

func total_timeline_duration() -> float:
	var total := startup + active + recovery
	for event in timeline_events:
		total = maxf(total, float(event.get("time", 0.0)) + float(event.get("duration", 0.0)))
	return total

func _load_timeline(data: Dictionary, errors: PackedStringArray) -> void:
	if not data.has("timeline"):
		return
	var raw_timeline = data.get("timeline")
	if typeof(raw_timeline) != TYPE_DICTIONARY:
		errors.append("timeline must be an object")
		return
	var timeline: Dictionary = raw_timeline
	timeline_schema_version = int(timeline.get("schema_version", 0))
	if timeline_schema_version != TIMELINE_SCHEMA_VERSION:
		errors.append("unsupported timeline schema_version: %d" % timeline_schema_version)
	var raw_events = timeline.get("events", [])
	if typeof(raw_events) != TYPE_ARRAY:
		errors.append("timeline events must be an array")
		return
	if raw_events.size() > MAX_TIMELINE_EVENTS:
		errors.append("timeline exceeds maximum event count: %d" % MAX_TIMELINE_EVENTS)
		return
	var seen_ids := {}
	var previous_time := -1.0
	for index in range(raw_events.size()):
		var raw_event = raw_events[index]
		if typeof(raw_event) != TYPE_DICTIONARY:
			errors.append("timeline event %d must be an object" % index)
			continue
		var event: Dictionary = raw_event.duplicate(true)
		var event_id := str(event.get("id", "")).strip_edges()
		var event_type := str(event.get("type", "")).strip_edges().to_lower()
		var event_time := float(event.get("time", -1.0))
		var event_duration := float(event.get("duration", 0.0))
		if event_id.is_empty():
			errors.append("timeline event %d id must not be empty" % index)
		elif seen_ids.has(event_id):
			errors.append("duplicate timeline event id: %s" % event_id)
		else:
			seen_ids[event_id] = true
		if not SUPPORTED_TIMELINE_EVENT_TYPES.has(event_type):
			errors.append("unsupported timeline event type: %s" % event_type)
		if event_time < 0.0:
			errors.append("timeline event %s time must be non-negative" % event_id)
		if event_duration < 0.0:
			errors.append("timeline event %s duration must be non-negative" % event_id)
		if event_time + event_duration > MAX_TIMELINE_SECONDS:
			errors.append("timeline event %s exceeds maximum timeline duration" % event_id)
		if event_time + 0.0001 < previous_time:
			errors.append("timeline events must be ordered by non-decreasing time")
		previous_time = maxf(previous_time, event_time)
		event["id"] = event_id
		event["type"] = event_type
		event["time"] = event_time
		event["duration"] = event_duration
		_normalize_timeline_media_payload(event, event_id, event_type, errors)
		_normalize_timeline_spatial_payload(event, event_id, event_type, errors)
		timeline_events.append(event)

func _normalize_timeline_media_payload(event: Dictionary, event_id: String, event_type: String, errors: PackedStringArray) -> void:
	var active_field := ""
	var fallback := ""
	if event_type == "animation":
		active_field = "animation"
		fallback = DEFAULT_TIMELINE_ANIMATION
	elif event_type == "vfx":
		active_field = "visual"
		fallback = visual if not visual.is_empty() else DEFAULT_TIMELINE_VFX
	elif event_type == "audio":
		active_field = "cue"
		fallback = DEFAULT_TIMELINE_AUDIO_CUE
	else:
		for key in TIMELINE_MEDIA_FIELDS:
			event.erase(key)
		return

	for key in TIMELINE_MEDIA_FIELDS:
		if key != active_field:
			event.erase(key)
	var token := str(event.get(active_field, fallback)).strip_edges().to_lower()
	if not _is_safe_timeline_token(token):
		errors.append("timeline event %s %s must be a safe lowercase token" % [event_id, active_field])
	event[active_field] = token

func _normalize_timeline_spatial_payload(event: Dictionary, event_id: String, event_type: String, errors: PackedStringArray) -> void:
	if not TIMELINE_SPATIAL_EVENT_TYPES.has(event_type):
		for key in ["half_width", "half_depth", "offset_x", "offset_depth"]:
			event.erase(key)
		return
	var half_width := float(event.get("half_width", DEFAULT_TIMELINE_SPATIAL_HALF_WIDTH))
	var half_depth := float(event.get("half_depth", DEFAULT_TIMELINE_SPATIAL_HALF_DEPTH))
	var offset_x := float(event.get("offset_x", 0.0))
	var offset_depth := float(event.get("offset_depth", 0.0))
	if half_width <= 0.0 or half_width > MAX_TIMELINE_SPATIAL_HALF_WIDTH:
		errors.append("timeline event %s half_width must be > 0 and <= %.0f" % [event_id, MAX_TIMELINE_SPATIAL_HALF_WIDTH])
	if half_depth <= 0.0 or half_depth > MAX_TIMELINE_SPATIAL_HALF_DEPTH:
		errors.append("timeline event %s half_depth must be > 0 and <= %.2f" % [event_id, MAX_TIMELINE_SPATIAL_HALF_DEPTH])
	if absf(offset_x) > MAX_TIMELINE_SPATIAL_OFFSET_X:
		errors.append("timeline event %s offset_x exceeds safe spatial limit" % event_id)
	if absf(offset_depth) > MAX_TIMELINE_SPATIAL_OFFSET_DEPTH:
		errors.append("timeline event %s offset_depth exceeds safe spatial limit" % event_id)
	event["half_width"] = half_width
	event["half_depth"] = half_depth
	event["offset_x"] = offset_x
	event["offset_depth"] = offset_depth

func _is_safe_timeline_token(value: String) -> bool:
	if value.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null

func _validate_melee_skill(errors: PackedStringArray) -> void:
	if range <= 0.0:
		errors.append("melee range must be positive")
	if active <= 0.0:
		errors.append("melee active duration must be positive")
	if hitbox_half_width <= 0.0 or hitbox_half_depth <= 0.0:
		errors.append("melee hitbox dimensions must be positive")

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

func _validate_beam_skill(errors: PackedStringArray) -> void:
	if range <= 0.0 or range > MAX_BEAM_RANGE:
		errors.append("beam range must be > 0 and <= %.0f" % MAX_BEAM_RANGE)
	if active <= 0.0:
		errors.append("beam active duration must be positive")
	if hitbox_half_depth <= 0.0 or hitbox_half_depth > MAX_TIMELINE_SPATIAL_HALF_DEPTH:
		errors.append("beam hitbox_half_depth must be > 0 and <= %.2f" % MAX_TIMELINE_SPATIAL_HALF_DEPTH)
