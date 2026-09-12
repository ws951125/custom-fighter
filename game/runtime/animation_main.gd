extends "res://game/runtime/preview_selectable_main.gd"

const CharacterAnimationMap = preload("res://game/core/character/character_animation_map.gd")

var player_animation_map := CharacterAnimationMap.new()
var player_animation_load_error := ""
var preview_return_button: Button
var _web_preview_return_callback

func _enter_tree() -> void:
	super()
	if not player_character.loaded:
		return

	var animation_errors := player_animation_map.load_from_id(player_character.animation_map)
	if not animation_errors.is_empty():
		player_animation_load_error = " | ".join(animation_errors)
		push_error("Failed to load player animation map: %s" % player_animation_load_error)

func _ready() -> void:
	super()
	_install_preview_return_path()
	_set_web_state()

func _install_preview_return_path() -> void:
	var session = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_active_preview():
		return
	preview_return_button = Button.new()
	preview_return_button.text = "Return to Creator"
	preview_return_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	preview_return_button.offset_left = -220.0
	preview_return_button.offset_top = 28.0
	preview_return_button.offset_right = -42.0
	preview_return_button.offset_bottom = 70.0
	preview_return_button.pressed.connect(_return_to_creator)
	add_child(preview_return_button)

	if OS.has_feature("web"):
		_web_preview_return_callback = JavaScriptBridge.create_callback(_web_return_to_creator)
		var window = JavaScriptBridge.get_interface("window")
		window.customFighterPreviewReturnToCreator = _web_preview_return_callback

func _return_to_creator() -> void:
	var session = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_stored_drafts():
		return
	session.deactivate_preview()
	var router = get_parent()
	if router != null and router.has_method("switch_mode"):
		router.call_deferred("switch_mode", "creator")

func _web_return_to_creator(_args: Array) -> void:
	_return_to_creator()

func _animation_semantic_name() -> String:
	if skill_coordinator.is_busy():
		var owner := skill_coordinator.owner_name()
		if CharacterAnimationMap.REQUIRED_SEMANTICS.has(owner):
			return owner
	if player_guarding:
		return "guard"
	if movement_state.is_dashing():
		return "dash"
	if movement_state.jumping:
		return "jump"
	if attack_chain_state.is_attacking():
		var attack_semantic := "attack_%d" % attack_chain_state.combo_step
		if CharacterAnimationMap.REQUIRED_SEMANTICS.has(attack_semantic):
			return attack_semantic
	if player_running:
		return "run"

	var move_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if move_vector.length_squared() > 0.01:
		return "walk"
	return "ready"

func _current_animation_id() -> String:
	return player_animation_map.animation_id_for_semantic(_animation_semantic_name())

func _set_web_state() -> void:
	super()
	if not OS.has_feature("web"):
		return
	var session = get_node_or_null("/root/CreatorPreviewSession")
	var preview_active := session != null and session.has_active_preview()
	JavaScriptBridge.eval(
		"document.documentElement.dataset.playerCharacterAnimationMap=%s;" % JSON.stringify(player_character.animation_map) +
		"document.documentElement.dataset.playerAnimationMapLoaded='%s';" % _bool_text(player_animation_map.loaded) +
		"document.documentElement.dataset.playerAnimationMapId=%s;" % JSON.stringify(player_animation_map.map_id) +
		"document.documentElement.dataset.playerAnimationSemantic=%s;" % JSON.stringify(_animation_semantic_name()) +
		"document.documentElement.dataset.playerAnimationId=%s;" % JSON.stringify(_current_animation_id()) +
		"document.documentElement.dataset.playerAnimationLoadError=%s;" % JSON.stringify(player_animation_load_error) +
		"document.documentElement.dataset.creatorPreviewReturnReady='%s';" % ("true" if preview_active else "false")
	)
