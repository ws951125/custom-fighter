class_name CompetitiveRuntimeAuthority
extends RefCounted

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterRegistry = preload("res://game/core/character/character_registry.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const GameModeDefinition = preload("res://game/core/mode/game_mode_definition.gd")
const GameModeRegistry = preload("res://game/core/mode/game_mode_registry.gd")
const CompetitiveLoadoutSnapshotBuilder = preload("res://game/core/mode/competitive_loadout_snapshot_builder.gd")

const LOCAL_MODE_ID := "competitive_local"
const AUTHORITY_POLICY := "local_authoritative"
const MODE_FAMILY := "competitive"
const AUTHORITATIVE_SKILL_FIELDS := [
	"damage",
	"mp_cost",
	"cooldown",
	"startup",
	"active",
	"recovery",
	"speed",
	"range",
	"hitstun",
	"knockback",
	"hitbox_half_width",
	"hitbox_half_depth",
	"formation_count",
	"formation_spacing",
	"formation_interval",
	"formation_offset",
	"buff_duration",
	"move_speed_multiplier",
	"basic_attack_damage_multiplier",
	"trap_duration",
	"aura_duration"
]

var admitted := false
var diagnostic_codes := PackedStringArray()
var snapshot: Dictionary = {}
var mode_definition := GameModeDefinition.new()
var character_registry := CharacterRegistry.new()
var skill_registry := SkillRegistry.new()

func clear() -> void:
	admitted = false
	diagnostic_codes.clear()
	snapshot.clear()
	mode_definition.clear()
	character_registry = CharacterRegistry.new()
	skill_registry = SkillRegistry.new()

func admit_registry_loadout(character_id: String, mode_id: String = LOCAL_MODE_ID) -> PackedStringArray:
	clear()

	var mode_errors: PackedStringArray = GameModeRegistry.load_mode(mode_id, mode_definition)
	if not mode_errors.is_empty() or not mode_definition.loaded:
		diagnostic_codes.append("MODE_RESOLUTION_FAILED")
		return diagnostic_codes.duplicate()
	if (
		mode_definition.mode_family != MODE_FAMILY
		or mode_definition.authority_policy != AUTHORITY_POLICY
		or mode_definition.mode_id != LOCAL_MODE_ID
	):
		diagnostic_codes.append("UNSUPPORTED_LOCAL_COMPETITIVE_MODE")
		return diagnostic_codes.duplicate()

	var result: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry(
		character_id,
		mode_definition.ruleset_id,
		mode_definition.ruleset_version
	)
	if not bool(result.get("accepted", false)):
		diagnostic_codes.append("SNAPSHOT_ADMISSION_FAILED")
		var snapshot_codes: PackedStringArray = result.get("diagnostic_codes", PackedStringArray())
		for code in snapshot_codes:
			diagnostic_codes.append("SNAPSHOT:%s" % str(code))
		return diagnostic_codes.duplicate()

	var candidate: Dictionary = result.get("snapshot", {})
	if candidate.is_empty():
		diagnostic_codes.append("SNAPSHOT_MISSING")
		return diagnostic_codes.duplicate()
	snapshot = candidate.duplicate(true)

	if not _snapshot_integrity_valid():
		diagnostic_codes.append("SNAPSHOT_INTEGRITY_FAILED")
		snapshot.clear()
		return diagnostic_codes.duplicate()
	if (
		str(snapshot.get("ruleset_id", "")) != mode_definition.ruleset_id
		or int(snapshot.get("ruleset_version", 0)) != mode_definition.ruleset_version
		or str(snapshot.get("power_budget_id", "")) != mode_definition.power_budget_id
	):
		diagnostic_codes.append("MODE_SNAPSHOT_POLICY_MISMATCH")
		snapshot.clear()
		return diagnostic_codes.duplicate()

	var character_registry_errors: PackedStringArray = character_registry.load_default()
	if not character_registry_errors.is_empty() or not character_registry.loaded:
		diagnostic_codes.append("CHARACTER_REGISTRY_LOAD_FAILED")
		snapshot.clear()
		return diagnostic_codes.duplicate()

	var skill_registry_errors: PackedStringArray = skill_registry.load_default()
	if not skill_registry_errors.is_empty() or not skill_registry.loaded:
		diagnostic_codes.append("SKILL_REGISTRY_LOAD_FAILED")
		snapshot.clear()
		return diagnostic_codes.duplicate()

	admitted = true
	return diagnostic_codes.duplicate()

func content_fingerprint() -> String:
	if not admitted or not _snapshot_integrity_valid():
		return ""
	return str(snapshot.get("content_fingerprint", ""))

func character_id() -> String:
	if not admitted or not _snapshot_integrity_valid():
		return ""
	return str(snapshot.get("character_id", ""))

func apply_character_to(target) -> PackedStringArray:
	var errors := _runtime_guard_errors()
	if target == null:
		errors.append("COMPETITIVE_CHARACTER_TARGET_MISSING")
		return errors
	if not errors.is_empty():
		return errors

	var authority_character_id := character_id()
	var registry_errors: PackedStringArray = character_registry.load_character(authority_character_id, target)
	if not registry_errors.is_empty() or not bool(target.get("loaded")):
		errors.append("COMPETITIVE_CHARACTER_RESOLUTION_FAILED")
		return errors

	var authority_slots: Dictionary = snapshot.get("resolved_skill_slots", {})
	for raw_slot in authority_slots.keys():
		var slot := str(raw_slot)
		if str(target.call("skill_id_for_slot", slot)) != str(authority_slots.get(slot, "")):
			errors.append("COMPETITIVE_CHARACTER_SLOT_MISMATCH:%s" % slot)
	if not errors.is_empty():
		target.set("loaded", false)
		return errors

	var stats: Dictionary = snapshot.get("normalized_character_stats", {})
	target.set("max_hp", int(stats.get("max_hp", 0)))
	target.set("max_mp", int(stats.get("max_mp", 0)))
	target.set("move_speed", float(stats.get("move_speed", 0.0)))
	target.set("depth_speed", float(stats.get("depth_speed", 0.0)))
	target.set("run_multiplier", float(stats.get("run_multiplier", 0.0)))
	target.set("guard_move_multiplier", float(stats.get("guard_move_multiplier", 0.0)))

	if CompetitiveLoadoutSnapshotBuilder._normalized_character_stats(target) != stats:
		target.set("loaded", false)
		errors.append("COMPETITIVE_CHARACTER_SNAPSHOT_APPLY_FAILED")
	return errors

func load_skill_for_slot(slot_name: String, expected_type: String, target) -> PackedStringArray:
	var errors := _runtime_guard_errors()
	if target == null:
		errors.append("COMPETITIVE_SKILL_TARGET_MISSING:%s" % slot_name)
		return errors
	if not errors.is_empty():
		return errors

	var slots: Dictionary = snapshot.get("resolved_skill_slots", {})
	if not slots.has(slot_name):
		errors.append("COMPETITIVE_SKILL_SLOT_NOT_ADMITTED:%s" % slot_name)
		return errors
	var skill_id := str(slots.get(slot_name, ""))
	var values_by_id: Dictionary = snapshot.get("normalized_skill_values", {})
	if not values_by_id.has(skill_id):
		errors.append("COMPETITIVE_SKILL_SNAPSHOT_MISSING:%s" % skill_id)
		return errors
	var values: Dictionary = values_by_id.get(skill_id, {})
	if str(values.get("type", "")) != expected_type:
		errors.append("COMPETITIVE_SKILL_TYPE_MISMATCH:%s" % slot_name)
		return errors

	var registered_type := skill_registry.registered_type_for_id(skill_id)
	if registered_type != expected_type:
		errors.append("COMPETITIVE_SKILL_REGISTRY_TYPE_MISMATCH:%s" % slot_name)
		return errors

	var registry_errors: PackedStringArray = skill_registry.load_skill(skill_id, expected_type, target)
	if not registry_errors.is_empty() or not bool(target.get("loaded")):
		errors.append("COMPETITIVE_SKILL_RESOLUTION_FAILED:%s" % slot_name)
		return errors

	for field in AUTHORITATIVE_SKILL_FIELDS:
		target.set(field, values.get(field, target.get(field)))
	target.set("timeline_schema_version", int(values.get("timeline_schema_version", target.get("timeline_schema_version"))))
	_apply_authoritative_gameplay_timeline(target, values.get("timeline_gameplay_events", []))

	if CompetitiveLoadoutSnapshotBuilder._normalized_skill(target) != values:
		target.set("loaded", false)
		errors.append("COMPETITIVE_SKILL_SNAPSHOT_APPLY_FAILED:%s" % slot_name)
	return errors

func _apply_authoritative_gameplay_timeline(target, raw_authority_events: Variant) -> void:
	if typeof(raw_authority_events) != TYPE_ARRAY:
		return
	var authority_by_key: Dictionary = {}
	for raw_event in raw_authority_events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = raw_event
		var key := _timeline_event_key(event)
		authority_by_key[key] = event.duplicate(true)

	var merged: Array[Dictionary] = []
	var existing_events: Array = target.get("timeline_events")
	for raw_event in existing_events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = raw_event
		var event_type := str(event.get("type", ""))
		if event_type == "hitbox" or event_type == "hurtbox":
			var key := _timeline_event_key(event)
			if authority_by_key.has(key):
				merged.append(authority_by_key.get(key).duplicate(true))
				authority_by_key.erase(key)
			continue
		merged.append(event.duplicate(true))

	var remaining_keys := PackedStringArray()
	for raw_key in authority_by_key.keys():
		remaining_keys.append(str(raw_key))
	remaining_keys.sort()
	for key in remaining_keys:
		merged.append(authority_by_key.get(key).duplicate(true))
	target.set("timeline_events", merged)

func _timeline_event_key(event: Dictionary) -> String:
	return "%s|%s" % [str(event.get("id", "")), str(event.get("type", ""))]

func _runtime_guard_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not admitted:
		errors.append("COMPETITIVE_AUTHORITY_NOT_ADMITTED")
	elif not _snapshot_integrity_valid():
		errors.append("COMPETITIVE_SNAPSHOT_INTEGRITY_FAILED")
	return errors

func _snapshot_integrity_valid() -> bool:
	if snapshot.is_empty():
		return false
	var payload: Dictionary = snapshot.duplicate(true)
	var expected := str(payload.get("content_fingerprint", ""))
	payload.erase("content_fingerprint")
	if expected.length() != 64:
		return false
	return CompetitiveLoadoutSnapshotBuilder._sha256_canonical(payload) == expected
