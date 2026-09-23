class_name NetworkSessionState
extends RefCounted

const NetworkProtocolDefinition = preload("res://game/core/network/network_protocol_definition.gd")
const CompetitiveLoadoutSnapshotBuilder = preload("res://game/core/mode/competitive_loadout_snapshot_builder.gd")

const MAX_PLAYERS := 2
const STATE_LOBBY := "lobby"
const STATE_IN_MATCH := "in_match"
const SUPPORTED_RULESET_ID := "competitive_standard"
const SUPPORTED_RULESET_VERSION := 1

var loaded := false
var session_id := ""
var ruleset_id := ""
var ruleset_version := 0
var state := ""
var players: Dictionary = {}
var latest_inputs: Dictionary = {}

func clear() -> void:
	loaded = false
	session_id = ""
	ruleset_id = ""
	ruleset_version = 0
	state = ""
	players.clear()
	latest_inputs.clear()

func create(
	requested_session_id: String,
	requested_ruleset_id: String = SUPPORTED_RULESET_ID,
	requested_ruleset_version: int = SUPPORTED_RULESET_VERSION
) -> PackedStringArray:
	clear()
	var errors := PackedStringArray()
	var normalized_session_id := requested_session_id.strip_edges().to_lower()
	var normalized_ruleset_id := requested_ruleset_id.strip_edges().to_lower()

	if not NetworkProtocolDefinition.is_safe_token(normalized_session_id, 64):
		errors.append("INVALID_SESSION_ID")
	if normalized_ruleset_id != SUPPORTED_RULESET_ID:
		errors.append("UNSUPPORTED_SESSION_RULESET")
	if requested_ruleset_version != SUPPORTED_RULESET_VERSION:
		errors.append("UNSUPPORTED_SESSION_RULESET_VERSION")
	if not errors.is_empty():
		return errors

	session_id = normalized_session_id
	ruleset_id = normalized_ruleset_id
	ruleset_version = requested_ruleset_version
	state = STATE_LOBBY
	loaded = true
	return errors

func admit_client_message(raw: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = NetworkProtocolDefinition.validate_client_message(raw)
	if not errors.is_empty():
		return errors
	if not loaded:
		errors.append("SESSION_NOT_CREATED")
		return errors

	if str(raw.get("session_id", "")).strip_edges().to_lower() != session_id:
		errors.append("SESSION_ID_MISMATCH")
		return errors

	var client_id := str(raw.get("client_id", "")).strip_edges().to_lower()
	var message_type := str(raw.get("type", "")).strip_edges().to_lower()
	match message_type:
		"join_session":
			return join_registry_character(client_id, str(raw.get("character_id", "")))
		"set_ready":
			return set_ready(client_id, bool(raw.get("ready")))
		"input_intent":
			return _admit_input_intent(client_id, raw)
		_:
			errors.append("UNSUPPORTED_CLIENT_MESSAGE_TYPE")
			return errors

func join_registry_character(client_id: String, character_id: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if not loaded:
		errors.append("SESSION_NOT_CREATED")
		return errors
	if state != STATE_LOBBY:
		errors.append("SESSION_JOIN_CLOSED")
		return errors

	var normalized_client_id := client_id.strip_edges().to_lower()
	if not NetworkProtocolDefinition.is_safe_token(normalized_client_id, 64):
		errors.append("INVALID_CLIENT_ID")
		return errors
	if players.has(normalized_client_id):
		errors.append("CLIENT_ALREADY_JOINED")
		return errors
	if players.size() >= MAX_PLAYERS:
		errors.append("SESSION_FULL")
		return errors

	var snapshot_result: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry(
		character_id.strip_edges().to_lower(),
		ruleset_id,
		ruleset_version
	)
	if not bool(snapshot_result.get("accepted", false)):
		errors.append("AUTHORITY_SNAPSHOT_REJECTED")
		var diagnostics: PackedStringArray = snapshot_result.get("diagnostic_codes", PackedStringArray())
		for code in diagnostics:
			errors.append("SNAPSHOT:%s" % str(code))
		return errors

	var snapshot: Dictionary = snapshot_result.get("snapshot", {})
	var fingerprint := str(snapshot.get("content_fingerprint", ""))
	if fingerprint.length() != 64:
		errors.append("AUTHORITY_FINGERPRINT_INVALID")
		return errors

	players[normalized_client_id] = {
		"client_id": normalized_client_id,
		"character_id": str(snapshot.get("character_id", "")),
		"content_fingerprint": fingerprint,
		"ready": false,
		"authority_snapshot": snapshot.duplicate(true)
	}
	latest_inputs[normalized_client_id] = {
		"sequence": -1,
		"client_tick": -1,
		"actions": PackedStringArray()
	}
	return errors

func set_ready(client_id: String, ready: bool) -> PackedStringArray:
	var errors := PackedStringArray()
	if not loaded:
		errors.append("SESSION_NOT_CREATED")
		return errors
	if state != STATE_LOBBY:
		errors.append("READY_STATE_CLOSED")
		return errors

	var normalized_client_id := client_id.strip_edges().to_lower()
	if not players.has(normalized_client_id):
		errors.append("CLIENT_NOT_IN_SESSION")
		return errors

	var player: Dictionary = players.get(normalized_client_id, {})
	player["ready"] = ready
	players[normalized_client_id] = player
	return errors

func ready_to_start() -> bool:
	if not loaded or state != STATE_LOBBY or players.size() != MAX_PLAYERS:
		return false
	for raw_client_id in players.keys():
		var player: Dictionary = players.get(str(raw_client_id), {})
		if not bool(player.get("ready", false)):
			return false
	return true

func start_match() -> PackedStringArray:
	var errors := PackedStringArray()
	if not loaded:
		errors.append("SESSION_NOT_CREATED")
		return errors
	if state != STATE_LOBBY:
		errors.append("SESSION_ALREADY_STARTED")
		return errors
	if not ready_to_start():
		errors.append("SESSION_NOT_READY")
		return errors
	state = STATE_IN_MATCH
	return errors

func authority_snapshot_for(client_id: String) -> Dictionary:
	var normalized_client_id := client_id.strip_edges().to_lower()
	if not players.has(normalized_client_id):
		return {}
	var player: Dictionary = players.get(normalized_client_id, {})
	var snapshot: Dictionary = player.get("authority_snapshot", {})
	return snapshot.duplicate(true)

func latest_input_for(client_id: String) -> Dictionary:
	var normalized_client_id := client_id.strip_edges().to_lower()
	if not latest_inputs.has(normalized_client_id):
		return {}
	var latest: Dictionary = latest_inputs.get(normalized_client_id, {})
	return latest.duplicate(true)

func state_snapshot() -> Dictionary:
	if not loaded:
		return {}

	var client_ids := PackedStringArray()
	for raw_client_id in players.keys():
		client_ids.append(str(raw_client_id))
	client_ids.sort()

	var summaries: Array[Dictionary] = []
	for client_id in client_ids:
		var player: Dictionary = players.get(client_id, {})
		var latest: Dictionary = latest_inputs.get(client_id, {})
		summaries.append({
			"client_id": client_id,
			"character_id": str(player.get("character_id", "")),
			"content_fingerprint": str(player.get("content_fingerprint", "")),
			"ready": bool(player.get("ready", false)),
			"latest_input_sequence": int(latest.get("sequence", -1))
		})

	return {
		"protocol_id": NetworkProtocolDefinition.PROTOCOL_ID,
		"protocol_version": NetworkProtocolDefinition.PROTOCOL_VERSION,
		"session_id": session_id,
		"ruleset_id": ruleset_id,
		"ruleset_version": ruleset_version,
		"state": state,
		"players": summaries
	}

func _admit_input_intent(client_id: String, raw: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if state != STATE_IN_MATCH:
		errors.append("SESSION_NOT_IN_MATCH")
		return errors
	if not players.has(client_id):
		errors.append("CLIENT_NOT_IN_SESSION")
		return errors

	var sequence := int(raw.get("sequence", -1))
	var previous: Dictionary = latest_inputs.get(client_id, {})
	if sequence <= int(previous.get("sequence", -1)):
		errors.append("INPUT_SEQUENCE_NOT_MONOTONIC")
		return errors

	latest_inputs[client_id] = {
		"sequence": sequence,
		"client_tick": int(raw.get("client_tick", -1)),
		"actions": NetworkProtocolDefinition.normalized_actions(raw.get("actions", []))
	}
	return errors
