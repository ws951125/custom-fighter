extends Control

const TRAINING_SCENE = preload("res://game/runtime/main.tscn")
const CREATOR_SCENE = preload("res://game/creator/creator_studio.tscn")

var app_mode := "training"

func _ready() -> void:
	app_mode = _requested_mode()
	var selected_scene: PackedScene = CREATOR_SCENE if app_mode == "creator" else TRAINING_SCENE
	var instance := selected_scene.instantiate()
	add_child(instance)
	if instance is Control:
		instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_web_state()

func _requested_mode() -> String:
	if not OS.has_feature("web"):
		return "training"
	var result = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('mode') || 'training'")
	var requested := str(result).strip_edges().to_lower()
	if requested == "creator":
		return "creator"
	return "training"

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.appMode=%s;" % JSON.stringify(app_mode) +
		"document.documentElement.dataset.appRouterReady='true';"
	)
