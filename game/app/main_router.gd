extends Control

const TRAINING_SCENE = preload("res://game/runtime/main.tscn")
const CREATOR_SCENE = preload("res://game/creator/creator_studio.tscn")
const VFX_SCENE = preload("res://game/creator/vfx_editor/vfx_studio.tscn")

var app_mode := "training"
var active_instance: Node

func _ready() -> void:
	app_mode = _requested_mode()
	_mount_mode(app_mode)

func switch_mode(requested_mode: String) -> void:
	var normalized_mode := _normalize_mode(requested_mode)
	if active_instance != null and is_instance_valid(active_instance):
		remove_child(active_instance)
		active_instance.queue_free()
	active_instance = null
	app_mode = normalized_mode
	_mount_mode(app_mode)

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

func _normalize_mode(requested_mode: String) -> String:
	var requested := requested_mode.strip_edges().to_lower()
	if requested == "creator":
		return "creator"
	if requested == "vfx":
		return "vfx"
	return "training"

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.appMode=%s;" % JSON.stringify(app_mode) +
		"document.documentElement.dataset.appRouterReady='true';"
	)
