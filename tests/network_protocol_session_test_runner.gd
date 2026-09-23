extends SceneTree

const NetworkProtocolDefinition = preload("res://game/core/network/network_protocol_definition.gd")
const NetworkSessionState = preload("res://game/core/network/network_session_state.gd")

const EMBER_FINGERPRINT := "56451d3bdf1c7bf74852a3620894667730ddb088f350eb598badfa74c6d3c28e"
const STORM_FINGERPRINT := "5822c6cfb4737c29007f2450a598c501b79c17d8ed9a432e4327976cc6a7026e"

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_client_protocol_is_intent_only()
	_test_protocol_version_and_identifiers_fail_closed()
	_test_authority_owned_session_flow()
	_test_session_ruleset_and_capacity_fail_closed()
	if failures == 0:
		print("NETWORK_PROTOCOL_SESSION_TESTS_PASSED")
		quit(0)
		return
	printerr("NETWORK_PROTOCOL_SESSION_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_client_protocol_is_intent_only() -> void:
	var join_message := _join_message("client_a", "ember_vanguard_001")
	var join_errors: PackedStringArray = NetworkProtocolDefinition.validate_client_message(join_message)
	_check(join_errors.is_empty(), "valid join intent passes protocol validation")

	var forged_fingerprint: Dictionary = join_message.duplicate(true)
	forged_fingerprint["content_fingerprint"] = "0".repeat(64)
	var fingerprint_errors: PackedStringArray = NetworkProtocolDefinition.validate_client_message(forged_fingerprint)
	_check(
		_contains(fingerprint_errors, "CLIENT_AUTHORITY_FIELD_FORBIDDEN:content_fingerprint"),
		"client cannot submit an authority fingerprint"
	)

	var forged_damage := _input_message("client_a", 1, ["basic_attack"])
	forged_damage["damage"] = 999999
	forged_damage["cooldown"] = 0.0
	forged_damage["position_x"] = 9999.0
	var forged_errors: PackedStringArray = NetworkProtocolDefinition.validate_client_message(forged_damage)
	_check(_contains(forged_errors, "CLIENT_AUTHORITY_FIELD_FORBIDDEN:damage"), "client damage field fails closed")
	_check(_contains(forged_errors, "CLIENT_AUTHORITY_FIELD_FORBIDDEN:cooldown"), "client cooldown field fails closed")
	_check(_contains(forged_errors, "CLIENT_AUTHORITY_FIELD_FORBIDDEN:position_x"), "client position field fails closed")

	var valid_input := _input_message("client_a", 2, ["move_left", "guard", "skill_13"])
	var valid_input_errors: PackedStringArray = NetworkProtocolDefinition.validate_client_message(valid_input)
	_check(valid_input_errors.is_empty(), "current movement/guard/skill input actions are valid intents")

	var duplicate_action := _input_message("client_a", 3, ["guard", "guard"])
	var duplicate_errors: PackedStringArray = NetworkProtocolDefinition.validate_client_message(duplicate_action)
	_check(_contains(duplicate_errors, "DUPLICATE_INPUT_ACTION:guard"), "duplicate input action fails closed")

	var arbitrary_action := _input_message("client_a", 4, ["execute_script"])
	var arbitrary_errors: PackedStringArray = NetworkProtocolDefinition.validate_client_message(arbitrary_action)
	_check(_contains_fragment(arbitrary_errors, "INVALID_INPUT_ACTION"), "unknown executable-style input action fails closed")

func _test_protocol_version_and_identifiers_fail_closed() -> void:
	var wrong_protocol := _join_message("client_a", "ember_vanguard_001")
	wrong_protocol["protocol_version"] = 2
	var version_errors: PackedStringArray = NetworkProtocolDefinition.validate_client_message(wrong_protocol)
	_check(_contains(version_errors, "UNSUPPORTED_NETWORK_PROTOCOL_VERSION"), "protocol version mismatch fails closed")

	var unsafe_client := _join_message("../client.gd", "ember_vanguard_001")
	var client_errors: PackedStringArray = NetworkProtocolDefinition.validate_client_message(unsafe_client)
	_check(_contains(client_errors, "INVALID_CLIENT_ID"), "unsafe client id fails closed")

	var unknown_message := _join_message("client_a", "ember_vanguard_001")
	unknown_message["type"] = "set_damage"
	var unknown_errors: PackedStringArray = NetworkProtocolDefinition.validate_client_message(unknown_message)
	_check(_contains(unknown_errors, "UNSUPPORTED_CLIENT_MESSAGE_TYPE"), "unknown client message type fails closed")

	var fractional_sequence := _input_message("client_a", 1, ["jump"])
	fractional_sequence["sequence"] = 1.5
	var fractional_errors: PackedStringArray = NetworkProtocolDefinition.validate_client_message(fractional_sequence)
	_check(_contains(fractional_errors, "INVALID_INPUT_SEQUENCE"), "fractional input sequence fails closed")

func _test_authority_owned_session_flow() -> void:
	var session := NetworkSessionState.new()
	var create_errors: PackedStringArray = session.create("room_alpha")
	_check(create_errors.is_empty() and session.loaded, "network authority session creates")

	var join_a_errors: PackedStringArray = session.admit_client_message(
		_join_message("client_a", "ember_vanguard_001")
	)
	var join_b_errors: PackedStringArray = session.admit_client_message(
		_join_message("client_b", "storm_duelist_001")
	)
	_check(join_a_errors.is_empty() and join_b_errors.is_empty(), "two registry-backed clients join through authority")
	_check(
		str(session.authority_snapshot_for("client_a").get("content_fingerprint", "")) == EMBER_FINGERPRINT,
		"server derives frozen Ember authority fingerprint"
	)
	_check(
		str(session.authority_snapshot_for("client_b").get("content_fingerprint", "")) == STORM_FINGERPRINT,
		"server derives frozen Storm authority fingerprint"
	)

	var prestart_input_errors: PackedStringArray = session.admit_client_message(
		_input_message("client_a", 0, ["move_right"])
	)
	_check(_contains(prestart_input_errors, "SESSION_NOT_IN_MATCH"), "combat input is rejected before authoritative match start")

	_check(session.admit_client_message(_ready_message("client_a", true)).is_empty(), "client A ready intent accepted")
	_check(not session.ready_to_start(), "one ready client does not start match")
	_check(session.admit_client_message(_ready_message("client_b", true)).is_empty(), "client B ready intent accepted")
	_check(session.ready_to_start(), "two admitted ready clients make session startable")
	_check(session.start_match().is_empty(), "authority starts match only after both clients are ready")

	var first_input_errors: PackedStringArray = session.admit_client_message(
		_input_message("client_a", 0, ["move_right", "basic_attack"])
	)
	_check(first_input_errors.is_empty(), "first monotonic input intent is admitted")
	var first_latest: Dictionary = session.latest_input_for("client_a")
	_check(int(first_latest.get("sequence", -1)) == 0, "authority stores admitted input sequence")
	_check(
		first_latest.get("actions", PackedStringArray()) == PackedStringArray(["move_right", "basic_attack"]),
		"authority stores only normalized intent actions"
	)

	var forged_input := _input_message("client_a", 1, ["skill_1"])
	forged_input["damage"] = 999999
	var forged_errors: PackedStringArray = session.admit_client_message(forged_input)
	_check(_contains(forged_errors, "CLIENT_AUTHORITY_FIELD_FORBIDDEN:damage"), "forged combat state is rejected at session admission")
	_check(
		int(session.latest_input_for("client_a").get("sequence", -1)) == 0,
		"rejected forged message cannot advance authoritative input sequence"
	)

	var second_input_errors: PackedStringArray = session.admit_client_message(
		_input_message("client_a", 1, ["skill_1"])
	)
	_check(second_input_errors.is_empty(), "next monotonic input intent is admitted")
	var stale_errors: PackedStringArray = session.admit_client_message(
		_input_message("client_a", 1, ["guard"])
	)
	_check(_contains(stale_errors, "INPUT_SEQUENCE_NOT_MONOTONIC"), "duplicate/stale input sequence fails closed")

	var public_state: Dictionary = session.state_snapshot()
	var player_summaries: Array = public_state.get("players", [])
	_check(player_summaries.size() == 2, "public session state exposes two deterministic player summaries")
	for raw_summary in player_summaries:
		var summary: Dictionary = raw_summary
		_check(not summary.has("authority_snapshot"), "public session state does not echo authority snapshot payload")
		_check(not summary.has("damage"), "public session state does not expose client-authorable damage")

func _test_session_ruleset_and_capacity_fail_closed() -> void:
	var wrong_version := NetworkSessionState.new()
	var wrong_version_errors: PackedStringArray = wrong_version.create(
		"room_wrong",
		"competitive_standard",
		2
	)
	_check(_contains(wrong_version_errors, "UNSUPPORTED_SESSION_RULESET_VERSION"), "session ruleset version mismatch fails closed")
	_check(not wrong_version.loaded, "unsupported session ruleset does not partially load")

	var session := NetworkSessionState.new()
	_check(session.create("room_capacity").is_empty(), "capacity session creates")
	_check(session.admit_client_message(_join_message("client_a", "ember_vanguard_001")).is_empty(), "capacity client A joins")
	_check(session.admit_client_message(_join_message("client_b", "storm_duelist_001")).is_empty(), "capacity client B joins")
	var third_errors: PackedStringArray = session.admit_client_message(_join_message("client_c", "ember_vanguard_001"))
	_check(_contains(third_errors, "SESSION_FULL"), "third client is rejected by two-player session capacity")

	var duplicate_errors: PackedStringArray = session.join_registry_character("client_a", "ember_vanguard_001")
	_check(_contains(duplicate_errors, "CLIENT_ALREADY_JOINED"), "duplicate client id fails closed")

func _base_message(client_id: String, message_type: String) -> Dictionary:
	return {
		"schema_version": 1,
		"protocol_id": "network_pvp_v1",
		"protocol_version": 1,
		"type": message_type,
		"session_id": "room_alpha",
		"client_id": client_id
	}

func _join_message(client_id: String, character_id: String) -> Dictionary:
	var message := _base_message(client_id, "join_session")
	message["character_id"] = character_id
	return message

func _ready_message(client_id: String, ready: bool) -> Dictionary:
	var message := _base_message(client_id, "set_ready")
	message["ready"] = ready
	return message

func _input_message(client_id: String, sequence: int, actions: Array) -> Dictionary:
	var message := _base_message(client_id, "input_intent")
	message["sequence"] = sequence
	message["client_tick"] = sequence
	message["actions"] = actions
	return message

func _contains(errors: PackedStringArray, code: String) -> bool:
	return errors.has(code)

func _contains_fragment(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if str(error).contains(fragment):
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
