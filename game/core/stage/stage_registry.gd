class_name StageRegistry
extends RefCounted

const StageDefinition = preload("res://game/core/stage/stage_definition.gd")

const DEFAULT_STAGE_ID := "training_arena"
const BUILTIN_STAGES := {
	"training_arena": {
		"schema_version": 1,
		"id": "training_arena",
		"display_name": "Training Arena",
		"arena_margin_x": 90.0,
		"player_spawn_x_ratio": 0.22,
		"player_spawn_depth": 0.58,
		"opponent_spawn_x_ratio": 0.67,
		"opponent_spawn_depth": 0.58,
		"background_token": "training_blue",
		"floor_token": "training_grid"
	},
	"sunset_court": {
		"schema_version": 1,
		"id": "sunset_court",
		"display_name": "Sunset Court",
		"arena_margin_x": 120.0,
		"player_spawn_x_ratio": 0.20,
		"player_spawn_depth": 0.62,
		"opponent_spawn_x_ratio": 0.72,
		"opponent_spawn_depth": 0.54,
		"background_token": "sunset_court",
		"floor_token": "stone_ring"
	}
}

static func stage_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for stage_id in BUILTIN_STAGES.keys():
		ids.append(str(stage_id))
	ids.sort()
	return ids

static func is_supported(stage_id: String) -> bool:
	return BUILTIN_STAGES.has(stage_id.strip_edges().to_lower())

static func normalize_stage_id(stage_id: String) -> String:
	var normalized := stage_id.strip_edges().to_lower()
	if is_supported(normalized):
		return normalized
	return DEFAULT_STAGE_ID

static func display_label(stage_id: String) -> String:
	var normalized := normalize_stage_id(stage_id)
	var raw: Dictionary = BUILTIN_STAGES.get(normalized, {})
	return str(raw.get("display_name", normalized))

static func load_stage(stage_id: String, target) -> PackedStringArray:
	var errors := PackedStringArray()
	var normalized := stage_id.strip_edges().to_lower()
	if target == null:
		errors.append("stage target must not be null")
		return errors
	if not BUILTIN_STAGES.has(normalized):
		errors.append("unknown stage id: %s" % normalized)
		return errors
	var raw: Dictionary = BUILTIN_STAGES[normalized].duplicate(true)
	return target.load_from_dictionary(raw)
