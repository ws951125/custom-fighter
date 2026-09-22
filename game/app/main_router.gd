extends Control

const TRAINING_SCENE = preload("res://game/runtime/main.tscn")
const CREATOR_SCENE = preload("res://game/creator/creator_studio.tscn")
const VFX_SCENE = preload("res://game/creator/vfx_editor/vfx_studio.tscn")
const OpponentBehaviorProfiles = preload("res://game/core/ai/opponent_behavior_profiles.gd")
const StageRegistry = preload("res://game/core/stage/stage_registry.gd")

var app_mode := "training"
var opponent_profile_id := OpponentBehaviorProfiles.DEFAULT_PROFILE_ID
var stage_id := StageRegistry.DEFAULT_STAGE_ID
var active_instance: Node

func _ready() -> void:
	app_mode = _requested_mode()
	opponent_profile_id = _requested_opponent_profile()
	stage_id = _requested_stage()
	_mount_mode(app_mode)

func switch_mode(requested_mode: String) -> void:
	var normalized_mode := _normalize_mode(requested_mode)
	if active_instance != null and is_instance_valid(active_instance):
		remove_child(active_instance)
		active_instance.queue_free()
	active_instance = null
	app_mode = normalized_mode
	_mount_mode(app_mode)

func switch_opponent_profile(requested_profile: String) -> void:
	if app_mode != "single_player":
		return
	var normalized := requested_profile.strip_edges().to_lower()
	if not OpponentBehaviorProfiles.is_supported(normalized):
		return
	if normalized == opponent_profile_id:
		return
	opponent_profile_id = normalized
	switch_mode("single_player")

func switch_stage(requested_stage: String) -> void:
	if app_mode != "single_player":
		return
	var normalized := requested_stage.strip_edges().to_lower()
	if not StageRegistry.is_supported(normalized):
		return
	if normalized == stage_id:
		return
	stage_id = normalized
	switch_mode("single_player")

func _mount_mode(mode_name: String) -> void:
	var selected_scene: PackedScene = TRAINING_SCENE
	if mode_name == "creator":
		selected_scene = CREATOR_SCENE
	elif mode_name == "vfx":
		selected_scene = VFX_SCENE
	active_instance = selected_scene.instantiate()
	add_child(active_instance)
	if active_instance is Control:
		active_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_web_state()

func _requested_mode() -> String:
	if not OS.has_feature("web"):
		return "training"
	var result = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('mode') || 'training'")
	return _normalize_mode(str(result))

func _requested_opponent_profile() -> String:
	if not OS.has_feature("web"):
		return OpponentBehaviorProfiles.DEFAULT_PROFILE_ID
	var result = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('opponent_profile') || ''")
	return OpponentBehaviorProfiles.normalize_profile_id(str(result))

func _requested_stage() -> String:
	if not OS.has_feature("web"):
		return StageRegistry.DEFAULT_STAGE_ID
	var result = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('stage') || ''")
	return StageRegistry.normalize_stage_id(str(result))

func _normalize_mode(requested_mode: String) -> String:
	var requested := requested_mode.strip_edges().to_lower()
	if requested == "creator":
		return "creator"
	if requested == "vfx":
		return "vfx"
	if requested == "single_player":
		return "single_player"
	return "training"

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var active_profile := opponent_profile_id if app_mode == "single_player" else ""
	var active_stage := stage_id if app_mode == "single_player" else ""
	JavaScriptBridge.eval(
		"document.documentElement.dataset.appMode=%s;" % JSON.stringify(app_mode) +
		"document.documentElement.dataset.appOpponentProfile=%s;" % JSON.stringify(active_profile) +
		"document.documentElement.dataset.appStage=%s;" % JSON.stringify(active_stage) +
		"document.documentElement.dataset.appRouterReady='true';"
	)
