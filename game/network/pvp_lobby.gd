extends Control

const PROTOCOL_VERSION := 1
const DEFAULT_WS_URL := "wss://custom-fighter-ai-vfx.onrender.com/v1/pvp/ws"
const EMBER_ID := "ember_vanguard_001"
const EMBER_FINGERPRINT := "56451d3bdf1c7bf74852a3620894667730ddb088f350eb598badfa74c6d3c28e"
const STORM_ID := "storm_duelist_001"
const STORM_FINGERPRINT := "5822c6cfb4737c29007f2450a598c501b79c17d8ed9a432e4327976cc6a7026e"
const HEARTBEAT_INTERVAL_MS := 2000
const RECONNECT_RETRY_MS := 500

var _socket: WebSocketPeer = WebSocketPeer.new()
var _connect_started := false
var _hello_sent := false
var _connection_state := "DISCONNECTED"
var _connection_token := ""
var _reconnect_token := ""
var _reconnect_window_ms := 10000
var _reconnect_deadline_local_ms := 0
var _next_reconnect_attempt_ms := 0
var _reconnect_count := 0
var _last_ping_ms := 0
var _latency_ms := -1
var _peer_status := ""
var _manual_close := false
var _client_id := ""
var _lobby_id := ""
var _local_ready := false
var _match_id := ""
var _match_status := ""
var _winner_client_id := ""
var _result_reason := ""
var _server_tick := 0
var _input_sequence := 0
var _last_error := ""
var _last_message := ""
var _participants: Array = []
var _players: Array = []

var _client_edit: LineEdit
var _lobby_edit: LineEdit
var _character_option: OptionButton
var _connection_label: Label
var _lobby_label: Label
var _match_label: Label
var _error_label: Label
var _ready_button: Button
var _web_command_callback

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_install_web_bridge()
	_set_web_state()

func _process(_delta: float) -> void:
	if not _connect_started:
		return
	_socket.poll()
	var ready_state := _socket.get_ready_state()
	var now_ms := Time.get_ticks_msec()
	if ready_state == WebSocketPeer.STATE_OPEN:
		if _connection_state == "CONNECTING" or _connection_state == "RECONNECTING":
			_connection_state = "SOCKET_OPEN"
			_refresh_ui()
		if not _hello_sent:
			_hello_sent = true
			_client_id = _client_edit.text.strip_edges()
			var hello := {
				"type": "hello",
				"protocol_version": PROTOCOL_VERSION,
				"client_id": _client_id
			}
			if not _reconnect_token.is_empty():
				hello["reconnect_token"] = _reconnect_token
			_send_raw(hello)
		while _socket.get_available_packet_count() > 0:
			var packet: PackedByteArray = _socket.get_packet()
			_handle_packet(packet.get_string_from_utf8())
		if _connection_state == "BOUND" and now_ms - _last_ping_ms >= HEARTBEAT_INTERVAL_MS:
			_last_ping_ms = now_ms
			_send_command({"type": "ping", "client_time_ms": now_ms})
	elif ready_state == WebSocketPeer.STATE_CLOSED and _connection_state not in ["CLOSED", "RECONNECTING"]:
		if not _manual_close and not _reconnect_token.is_empty():
			_reconnect_deadline_local_ms = now_ms + _reconnect_window_ms
			_connection_state = "RECONNECTING"
			_next_reconnect_attempt_ms = now_ms + RECONNECT_RETRY_MS
			_last_error = "RECONNECTING"
		else:
			_connection_state = "CLOSED"
			if _last_error.is_empty():
				_last_error = "CONNECTION_CLOSED"
		_refresh_ui()
		_set_web_state()
	elif _connection_state == "RECONNECTING" and now_ms >= _next_reconnect_attempt_ms:
		_begin_connection(true)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.09, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var panel := VBoxContainer.new()
	panel.position = Vector2(24, 20)
	panel.size = Vector2(760, 680)
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)

	var title := Label.new()
	title.text = "Competitive Hosted — Network PvP"
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)

	var note := Label.new()
	note.text = "WU5 Network PvP: reconnect + heartbeat/RTT + leave/forfeit + authoritative terminal result"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(note)

	var identity_row := HBoxContainer.new()
	panel.add_child(identity_row)
	var identity_label := Label.new()
	identity_label.text = "Client ID"
	identity_row.add_child(identity_label)
	_client_edit = LineEdit.new()
	_client_edit.text = _requested_client_id()
	_client_edit.custom_minimum_size = Vector2(260, 42)
	identity_row.add_child(_client_edit)
	_add_button(identity_row, "Connect", _connect_socket)
	_add_button(identity_row, "Reconnect", _reconnect_socket)

	var lobby_row := HBoxContainer.new()
	panel.add_child(lobby_row)
	var lobby_text := Label.new()
	lobby_text.text = "Lobby"
	lobby_row.add_child(lobby_text)
	_lobby_edit = LineEdit.new()
	_lobby_edit.placeholder_text = "lobby_000001"
	_lobby_edit.custom_minimum_size = Vector2(260, 42)
	lobby_row.add_child(_lobby_edit)
	_add_button(lobby_row, "Create Lobby", _create_lobby)
	_add_button(lobby_row, "Join Lobby", _join_lobby)
	_add_button(lobby_row, "Leave Lobby", _leave_lobby)

	var loadout_row := HBoxContainer.new()
	panel.add_child(loadout_row)
	var loadout_text := Label.new()
	loadout_text.text = "Competitive loadout"
	loadout_row.add_child(loadout_text)
	_character_option = OptionButton.new()
	_character_option.add_item("Ember Vanguard")
	_character_option.set_item_metadata(0, EMBER_ID)
	_character_option.add_item("Storm Duelist")
	_character_option.set_item_metadata(1, STORM_ID)
	_character_option.custom_minimum_size = Vector2(220, 42)
	loadout_row.add_child(_character_option)
	_add_button(loadout_row, "Admit Loadout", _admit_selected)
	_ready_button = _add_button(loadout_row, "Ready", _toggle_ready)
	_add_button(loadout_row, "Start Match", _start_match)

	var action_row := HBoxContainer.new()
	panel.add_child(action_row)
	var action_text := Label.new()
	action_text.text = "Authoritative input"
	action_row.add_child(action_text)
	_add_button(action_row, "Move Left", _send_move_left)
	_add_button(action_row, "Move Right", _send_move_right)
	_add_button(action_row, "Guard", _send_guard)
	_add_button(action_row, "Neutral", _send_neutral)
	_add_button(action_row, "Attack", _send_attack)
	_add_button(action_row, "Forfeit", _forfeit_match)

	_connection_label = Label.new()
	panel.add_child(_connection_label)
	_lobby_label = Label.new()
	_lobby_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_lobby_label)
	_match_label = Label.new()
	_match_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_match_label)
	_error_label = Label.new()
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_error_label)
	_refresh_ui()

func _add_button(parent: Container, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(110, 42)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _requested_client_id() -> String:
	var requested := _query_value("client").strip_edges()
	if not requested.is_empty():
		return requested
	return "web_client_%d" % Time.get_ticks_msec()

func _query_value(name: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var result = JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get(%s) || ''" % JSON.stringify(name)
	)
	return str(result)

func _resolved_ws_url() -> String:
	var requested := _query_value("pvp_ws").strip_edges()
	if requested.is_empty() or requested == DEFAULT_WS_URL:
		return DEFAULT_WS_URL
	if requested.ends_with("/v1/pvp/ws"):
		if requested.begins_with("ws://127.0.0.1:") or requested.begins_with("ws://localhost:"):
			return requested
	_last_error = "PVP_WS_URL_REJECTED"
	return DEFAULT_WS_URL

func _connect_socket() -> void:
	_reconnect_token = ""
	_reconnect_count = 0
	_begin_connection(false)

func _reconnect_socket() -> void:
	if _reconnect_token.is_empty():
		_last_error = "RECONNECT_TOKEN_UNAVAILABLE"
		_refresh_ui()
		_set_web_state()
		return
	_begin_connection(true)

func _begin_connection(preserve_session: bool) -> void:
	if _connect_started and _socket.get_ready_state() in [WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN]:
		return
	_last_error = ""
	_last_message = ""
	_connection_token = ""
	_manual_close = false
	if not preserve_session:
		_lobby_id = ""
		_match_id = ""
		_match_status = ""
		_winner_client_id = ""
		_result_reason = ""
		_server_tick = 0
		_input_sequence = 0
		_participants.clear()
		_players.clear()
		_local_ready = false
		_latency_ms = -1
		_peer_status = ""
	_hello_sent = false
	_socket = WebSocketPeer.new()
	var endpoint := _resolved_ws_url()
	var result := _socket.connect_to_url(endpoint)
	if result != OK:
		_connection_state = "RECONNECTING" if preserve_session else "CLOSED"
		_last_error = "CONNECT_FAILED_%d" % result
		if preserve_session:
			_next_reconnect_attempt_ms = Time.get_ticks_msec() + RECONNECT_RETRY_MS
		_refresh_ui()
		_set_web_state()
		return
	_connect_started = true
	_connection_state = "RECONNECTING" if preserve_session else "CONNECTING"
	_refresh_ui()
	_set_web_state()

func _create_lobby() -> void:
	_send_command({"type": "create_lobby"})

func _join_lobby() -> void:
	var requested := _lobby_edit.text.strip_edges()
	if requested.is_empty():
		_last_error = "LOBBY_ID_REQUIRED"
		_refresh_ui()
		_set_web_state()
		return
	_send_command({"type": "join_lobby", "lobby_id": requested})

func _leave_lobby() -> void:
	if _lobby_id.is_empty():
		_last_error = "LOBBY_ID_REQUIRED"
		_refresh_ui()
		_set_web_state()
		return
	_send_command({"type": "leave_lobby", "lobby_id": _lobby_id})

func _forfeit_match() -> void:
	if _match_id.is_empty() or _match_status != "active":
		_last_error = "MATCH_NOT_ACTIVE"
		_refresh_ui()
		_set_web_state()
		return
	_send_command({"type": "forfeit", "match_id": _match_id})

func _disconnect_for_reconnect() -> void:
	_manual_close = false
	if _socket.get_ready_state() in [WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING]:
		_socket.close(3001, "client reconnect test")

func _admit_selected() -> void:
	var character_id := str(_character_option.get_item_metadata(_character_option.selected))
	_admit_character(character_id)

func _admit_character(character_id: String) -> void:
	var fingerprint := ""
	if character_id == EMBER_ID:
		fingerprint = EMBER_FINGERPRINT
	elif character_id == STORM_ID:
		fingerprint = STORM_FINGERPRINT
	else:
		_last_error = "CHARACTER_NOT_SUPPORTED"
		_refresh_ui()
		_set_web_state()
		return
	_send_command({
		"type": "negotiate_loadout",
		"lobby_id": _lobby_id,
		"claim": {
			"character_id": character_id,
			"content_fingerprint": fingerprint,
			"package_schema_version": 1
		}
	})

func _toggle_ready() -> void:
	_send_command({
		"type": "set_ready",
		"lobby_id": _lobby_id,
		"ready": not _local_ready
	})

func _start_match() -> void:
	_send_command({"type": "start_match", "lobby_id": _lobby_id})

func _send_move_left() -> void:
	_send_action(["move_left"])

func _send_move_right() -> void:
	_send_action(["move_right"])

func _send_guard() -> void:
	_send_action(["guard"])

func _send_neutral() -> void:
	_send_action([])

func _send_attack() -> void:
	_send_action(["basic_attack"])

func _send_action(actions: Array) -> void:
	if _match_id.is_empty() or _match_status != "active":
		_last_error = "MATCH_NOT_ACTIVE"
		_refresh_ui()
		_set_web_state()
		return
	_input_sequence += 1
	_send_command({
		"type": "input",
		"match_id": _match_id,
		"input": {
			"sequence": _input_sequence,
			"actions": actions
		}
	})

func _send_command(payload: Dictionary) -> void:
	if _connection_state != "BOUND" or _connection_token.is_empty():
		_last_error = "CONNECTION_NOT_BOUND"
		_refresh_ui()
		_set_web_state()
		return
	var message := payload.duplicate(true)
	message["connection_token"] = _connection_token
	_send_raw(message)

func _send_raw(payload: Dictionary) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_last_error = "SOCKET_NOT_OPEN"
		_refresh_ui()
		_set_web_state()
		return
	var result := _socket.send_text(JSON.stringify(payload))
	if result != OK:
		_last_error = "SOCKET_SEND_FAILED_%d" % result
		_refresh_ui()
		_set_web_state()

func _handle_packet(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_last_error = "SERVER_MESSAGE_INVALID"
		_refresh_ui()
		_set_web_state()
		return
	var message: Dictionary = parsed
	var message_type := str(message.get("type", ""))
	_last_message = message_type
	if message_type == "hello_ok":
		_connection_token = str(message.get("connection_token", ""))
		_reconnect_token = str(message.get("reconnect_token", _reconnect_token))
		_reconnect_window_ms = int(message.get("reconnect_window_ms", _reconnect_window_ms))
		_reconnect_deadline_local_ms = Time.get_ticks_msec() + _reconnect_window_ms
		_client_id = str(message.get("client_id", _client_id))
		if bool(message.get("reconnected", false)):
			_reconnect_count += 1
		_connection_state = "BOUND"
		_last_error = ""
		_last_ping_ms = 0
	elif message_type == "lobby_state":
		_apply_lobby(message.get("lobby", {}))
	elif message_type == "authority_admitted":
		_last_error = ""
	elif message_type == "match_started":
		var match_data: Dictionary = message.get("match", {})
		_match_id = str(match_data.get("match_id", ""))
		_match_status = str(match_data.get("status", "active"))
	elif message_type == "match_state":
		_apply_match_state(message.get("state", {}))
	elif message_type == "input_ack":
		_last_error = ""
	elif message_type == "pong":
		var client_time_ms := int(message.get("client_time_ms", Time.get_ticks_msec()))
		_latency_ms = maxi(0, Time.get_ticks_msec() - client_time_ms)
	elif message_type == "peer_status":
		_peer_status = "%s:%s" % [str(message.get("client_id", "")), str(message.get("status", ""))]
	elif message_type == "lobby_left":
		_lobby_id = ""
		_participants.clear()
		_local_ready = false
	elif message_type == "match_finished":
		_apply_match_state(message.get("state", {}))
	elif message_type == "forfeit_ack":
		_last_error = ""
	elif message_type == "error":
		_last_error = str(message.get("code", "UNKNOWN_TRANSPORT_ERROR"))
	_refresh_ui()
	_set_web_state()

func _apply_lobby(value) -> void:
	if not (value is Dictionary):
		_last_error = "LOBBY_STATE_INVALID"
		return
	var lobby: Dictionary = value
	_lobby_id = str(lobby.get("lobby_id", ""))
	if _lobby_edit != null:
		_lobby_edit.text = _lobby_id
	_participants = Array(lobby.get("participants", [])).duplicate(true)
	_local_ready = false
	for participant_value in _participants:
		if participant_value is Dictionary:
			var participant: Dictionary = participant_value
			if str(participant.get("client_id", "")) == _client_id:
				_local_ready = bool(participant.get("ready", false))
				break

func _apply_match_state(value) -> void:
	if not (value is Dictionary):
		_last_error = "MATCH_STATE_INVALID"
		return
	var state: Dictionary = value
	_match_id = str(state.get("match_id", _match_id))
	_match_status = str(state.get("status", ""))
	_winner_client_id = str(state.get("winner_client_id", ""))
	_result_reason = str(state.get("result_reason", ""))
	_server_tick = int(state.get("tick", 0))
	_players = Array(state.get("players", [])).duplicate(true)

func _refresh_ui() -> void:
	if _connection_label == null:
		return
	_connection_label.text = "Connection: %s · client=%s · RTT=%sms · reconnects=%d · peer=%s" % [_connection_state, _client_id, str(_latency_ms), _reconnect_count, _peer_status]
	_lobby_label.text = "Lobby: %s · participants=%s" % [_lobby_id, JSON.stringify(_participants)]
	_match_label.text = "Match: %s · status=%s · tick=%d · winner=%s · reason=%s · players=%s" % [
		_match_id,
		_match_status,
		_server_tick,
		_winner_client_id,
		_result_reason,
		JSON.stringify(_players)
	]
	_error_label.text = "Last transport error: %s" % (_last_error if not _last_error.is_empty() else "none")
	if _ready_button != null:
		_ready_button.text = "Unready" if _local_ready else "Ready"

func _install_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_command_callback = JavaScriptBridge.create_callback(_web_command)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterNetworkPvpCommand = _web_command_callback

func _web_command(args: Array) -> void:
	if args.is_empty():
		return
	var command := str(args[0]).strip_edges().to_lower()
	if command == "connect":
		_connect_socket()
	elif command == "reconnect":
		_reconnect_socket()
	elif command == "disconnect":
		_disconnect_for_reconnect()
	elif command == "create_lobby":
		_create_lobby()
	elif command == "join_lobby":
		if args.size() > 1:
			_lobby_edit.text = str(args[1])
		_join_lobby()
	elif command == "leave_lobby":
		_leave_lobby()
	elif command == "admit_ember":
		_admit_character(EMBER_ID)
	elif command == "admit_storm":
		_admit_character(STORM_ID)
	elif command == "ready":
		_toggle_ready()
	elif command == "start":
		_start_match()
	elif command == "move_left":
		_send_move_left()
	elif command == "move_right":
		_send_move_right()
	elif command == "guard":
		_send_guard()
	elif command == "neutral":
		_send_neutral()
	elif command == "attack":
		_send_attack()
	elif command == "forfeit":
		_forfeit_match()
	elif command == "request_state":
		_send_command({"type": "request_state", "match_id": _match_id})

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var participants_json := JSON.stringify(_participants)
	var players_json := JSON.stringify(_players)
	JavaScriptBridge.eval(
		"document.documentElement.dataset.networkPvpReady='true';" +
		"document.documentElement.dataset.networkPvpConnection=%s;" % JSON.stringify(_connection_state) +
		"document.documentElement.dataset.networkPvpClientId=%s;" % JSON.stringify(_client_id) +
		"document.documentElement.dataset.networkPvpLobbyId=%s;" % JSON.stringify(_lobby_id) +
		"document.documentElement.dataset.networkPvpParticipants=%s;" % JSON.stringify(participants_json) +
		"document.documentElement.dataset.networkPvpReadyState='%s';" % ("true" if _local_ready else "false") +
		"document.documentElement.dataset.networkPvpMatchId=%s;" % JSON.stringify(_match_id) +
		"document.documentElement.dataset.networkPvpMatchStatus=%s;" % JSON.stringify(_match_status) +
		"document.documentElement.dataset.networkPvpTick='%d';" % _server_tick +
		"document.documentElement.dataset.networkPvpLatencyMs='%d';" % _latency_ms +
		"document.documentElement.dataset.networkPvpReconnectCount='%d';" % _reconnect_count +
		"document.documentElement.dataset.networkPvpPeerStatus=%s;" % JSON.stringify(_peer_status) +
		"document.documentElement.dataset.networkPvpWinner=%s;" % JSON.stringify(_winner_client_id) +
		"document.documentElement.dataset.networkPvpResultReason=%s;" % JSON.stringify(_result_reason) +
		"document.documentElement.dataset.networkPvpPlayers=%s;" % JSON.stringify(players_json) +
		"document.documentElement.dataset.networkPvpLastMessage=%s;" % JSON.stringify(_last_message) +
		"document.documentElement.dataset.networkPvpLastError=%s;" % JSON.stringify(_last_error)
	)
