class_name NetworkProtocolDefinition
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const PROTOCOL_ID := "network_pvp_v1"
const PROTOCOL_VERSION := 1
const MAX_SEQUENCE := 2147483647
const MAX_ACTIONS_PER_INTENT := 16

const CLIENT_MESSAGE_TYPES := [
	"join_session",
	"set_ready",
	"input_intent"
]

const COMMON_FIELDS := [
	"schema_version",
	"protocol_id",
	"protocol_version",
	"type",
	"session_id",
	"client_id"
]

const MESSAGE_FIELDS := {
	"join_session": ["character_id"],
	"set_ready": ["ready"],
	"input_intent": ["sequence", "client_tick", "actions"]
}

const AUTHORITY_OWNED_FIELDS := [
	"authority_snapshot",
	"content_fingerprint",
	"damage",
	"hp",
	"mp",
	"cooldown",
	"position",
	"position_x",
	"position_depth",
	"hit_result",
	"match_result",
	"combat_state",
	"state_snapshot"
]

const INPUT_ACTIONS := [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"run",
	"jump",
	"basic_attack",
	"dash",
	"guard",
	"skill_1",
	"skill_2",
	"skill_3",
	"skill_4",
	"skill_5",
	"skill_6",
	"skill_7",
	"skill_8",
	"skill_9",
	"skill_10",
	"skill_11",
	"skill_12",
	"skill_13"
]

static func validate_client_message(raw: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var message_type := str(raw.get("type", "")).strip_edges().to_lower()
	if not CLIENT_MESSAGE_TYPES.has(message_type):
		errors.append("UNSUPPORTED_CLIENT_MESSAGE_TYPE")
		return errors

	var allowed_fields: Array = COMMON_FIELDS.duplicate()
	var specific_fields: Array = MESSAGE_FIELDS.get(message_type, [])
	allowed_fields.append_array(specific_fields)

	for raw_key in raw.keys():
		var field := str(raw_key)
		if AUTHORITY_OWNED_FIELDS.has(field):
			errors.append("CLIENT_AUTHORITY_FIELD_FORBIDDEN:%s" % field)
		elif not allowed_fields.has(field):
			errors.append("UNKNOWN_CLIENT_MESSAGE_FIELD:%s" % field)

	for field in allowed_fields:
		if not raw.has(field):
			errors.append("MISSING_CLIENT_MESSAGE_FIELD:%s" % field)

	if int(raw.get("schema_version", -1)) != SUPPORTED_SCHEMA_VERSION:
		errors.append("UNSUPPORTED_NETWORK_SCHEMA_VERSION")
	if str(raw.get("protocol_id", "")).strip_edges().to_lower() != PROTOCOL_ID:
		errors.append("UNSUPPORTED_NETWORK_PROTOCOL_ID")
	if int(raw.get("protocol_version", -1)) != PROTOCOL_VERSION:
		errors.append("UNSUPPORTED_NETWORK_PROTOCOL_VERSION")

	var session_id := str(raw.get("session_id", "")).strip_edges().to_lower()
	if not is_safe_token(session_id, 64):
		errors.append("INVALID_SESSION_ID")
	var client_id := str(raw.get("client_id", "")).strip_edges().to_lower()
	if not is_safe_token(client_id, 64):
		errors.append("INVALID_CLIENT_ID")

	match message_type:
		"join_session":
			var character_id := str(raw.get("character_id", "")).strip_edges().to_lower()
			if not is_safe_token(character_id, 64):
				errors.append("INVALID_CHARACTER_ID")
		"set_ready":
			if typeof(raw.get("ready")) != TYPE_BOOL:
				errors.append("READY_MUST_BE_BOOLEAN")
		"input_intent":
			_validate_input_intent(raw, errors)

	return errors

static func normalized_actions(raw: Variant) -> PackedStringArray:
	var normalized := PackedStringArray()
	if typeof(raw) != TYPE_ARRAY:
		return normalized
	for raw_action in raw:
		if typeof(raw_action) != TYPE_STRING:
			continue
		normalized.append(str(raw_action).strip_edges().to_lower())
	return normalized

static func is_safe_token(value: String, max_length: int) -> bool:
	if value.is_empty() or value.length() > max_length:
		return false
	for character in value:
		var code := character.unicode_at(0)
		var safe_alpha := code >= 97 and code <= 122
		var safe_digit := code >= 48 and code <= 57
		if not safe_alpha and not safe_digit and character != "_" and character != "-":
			return false
	return true

static func _validate_input_intent(raw: Dictionary, errors: PackedStringArray) -> void:
	if not _is_nonnegative_integer(raw.get("sequence")):
		errors.append("INVALID_INPUT_SEQUENCE")
	if not _is_nonnegative_integer(raw.get("client_tick")):
		errors.append("INVALID_CLIENT_TICK")

	var raw_actions: Variant = raw.get("actions")
	if typeof(raw_actions) != TYPE_ARRAY:
		errors.append("INPUT_ACTIONS_MUST_BE_ARRAY")
		return

	var actions: Array = raw_actions
	if actions.size() > MAX_ACTIONS_PER_INTENT:
		errors.append("TOO_MANY_INPUT_ACTIONS")

	var seen := {}
	for raw_action in actions:
		if typeof(raw_action) != TYPE_STRING:
			errors.append("INVALID_INPUT_ACTION")
			continue
		var action_text := str(raw_action)
		var action := action_text.strip_edges().to_lower()
		if action_text != action or not INPUT_ACTIONS.has(action):
			errors.append("INVALID_INPUT_ACTION:%s" % action)
			continue
		if seen.has(action):
			errors.append("DUPLICATE_INPUT_ACTION:%s" % action)
			continue
		seen[action] = true

static func _is_nonnegative_integer(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var numeric := float(value)
	if numeric < 0.0 or numeric > float(MAX_SEQUENCE):
		return false
	return absf(numeric - floor(numeric)) <= 0.000001
