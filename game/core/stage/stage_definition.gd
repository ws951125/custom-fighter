class_name StageDefinition
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const ALLOWED_FIELDS := [
	"schema_version",
	"id",
	"display_name",
	"arena_margin_x",
	"player_spawn_x_ratio",
	"player_spawn_depth",
	"opponent_spawn_x_ratio",
	"opponent_spawn_depth",
	"background_token",
	"floor_token"
]
const BACKGROUND_TOKENS := ["training_blue", "sunset_court"]
const FLOOR_TOKENS := ["training_grid", "stone_ring"]

var loaded := false
var stage_id := ""
var display_name := ""
var arena_margin_x := 90.0
var player_spawn_x_ratio := 0.22
var player_spawn_depth := 0.58
var opponent_spawn_x_ratio := 0.67
var opponent_spawn_depth := 0.58
var background_token := ""
var floor_token := ""

func clear() -> void:
	loaded = false
	stage_id = ""
	display_name = ""
	arena_margin_x = 90.0
	player_spawn_x_ratio = 0.22
	player_spawn_depth = 0.58
	opponent_spawn_x_ratio = 0.67
	opponent_spawn_depth = 0.58
	background_token = ""
	floor_token = ""

func load_from_dictionary(raw: Dictionary) -> PackedStringArray:
	clear()
	var errors := PackedStringArray()

	for key in raw.keys():
		if not ALLOWED_FIELDS.has(str(key)):
			errors.append("unknown stage field: %s" % str(key))

	if int(raw.get("schema_version", -1)) != SUPPORTED_SCHEMA_VERSION:
		errors.append("unsupported stage schema_version")

	var candidate_id := str(raw.get("id", "")).strip_edges().to_lower()
	if not _is_safe_token(candidate_id, 48):
		errors.append("invalid stage id")

	var candidate_name := str(raw.get("display_name", "")).strip_edges()
	if candidate_name.is_empty() or candidate_name.length() > 48:
		errors.append("invalid stage display_name")

	var candidate_margin := float(raw.get("arena_margin_x", -1.0))
	if candidate_margin < 60.0 or candidate_margin > 240.0:
		errors.append("arena_margin_x must be between 60 and 240")

	var player_x := float(raw.get("player_spawn_x_ratio", -1.0))
	var opponent_x := float(raw.get("opponent_spawn_x_ratio", -1.0))
	if player_x < 0.08 or player_x > 0.92:
		errors.append("player_spawn_x_ratio out of range")
	if opponent_x < 0.08 or opponent_x > 0.92:
		errors.append("opponent_spawn_x_ratio out of range")
	if player_x >= opponent_x - 0.15:
		errors.append("stage spawns must preserve at least 0.15 horizontal separation")

	var player_depth_value := float(raw.get("player_spawn_depth", -1.0))
	var opponent_depth_value := float(raw.get("opponent_spawn_depth", -1.0))
	if player_depth_value < 0.0 or player_depth_value > 1.0:
		errors.append("player_spawn_depth out of range")
	if opponent_depth_value < 0.0 or opponent_depth_value > 1.0:
		errors.append("opponent_spawn_depth out of range")

	var candidate_background := str(raw.get("background_token", "")).strip_edges().to_lower()
	if not BACKGROUND_TOKENS.has(candidate_background):
		errors.append("unsupported background_token")

	var candidate_floor := str(raw.get("floor_token", "")).strip_edges().to_lower()
	if not FLOOR_TOKENS.has(candidate_floor):
		errors.append("unsupported floor_token")

	if not errors.is_empty():
		return errors

	stage_id = candidate_id
	display_name = candidate_name
	arena_margin_x = candidate_margin
	player_spawn_x_ratio = player_x
	player_spawn_depth = player_depth_value
	opponent_spawn_x_ratio = opponent_x
	opponent_spawn_depth = opponent_depth_value
	background_token = candidate_background
	floor_token = candidate_floor
	loaded = true
	return errors

func to_dictionary() -> Dictionary:
	if not loaded:
		return {}
	return {
		"schema_version": SUPPORTED_SCHEMA_VERSION,
		"id": stage_id,
		"display_name": display_name,
		"arena_margin_x": arena_margin_x,
		"player_spawn_x_ratio": player_spawn_x_ratio,
		"player_spawn_depth": player_spawn_depth,
		"opponent_spawn_x_ratio": opponent_spawn_x_ratio,
		"opponent_spawn_depth": opponent_spawn_depth,
		"background_token": background_token,
		"floor_token": floor_token
	}

static func _is_safe_token(value: String, max_length: int) -> bool:
	if value.is_empty() or value.length() > max_length:
		return false
	for character in value:
		var code := character.unicode_at(0)
		var safe_alpha := code >= 97 and code <= 122
		var safe_digit := code >= 48 and code <= 57
		if not safe_alpha and not safe_digit and character != "_" and character != "-":
			return false
	return true
