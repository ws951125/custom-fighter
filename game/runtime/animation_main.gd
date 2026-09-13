extends "res://game/runtime/preview_selectable_main.gd"

const CharacterAnimationMap = preload("res://game/core/character/character_animation_map.gd")
const VfxDraft = preload("res://game/creator/vfx_editor/vfx_draft.gd")

var player_animation_map := CharacterAnimationMap.new()
var player_animation_load_error := ""
var preview_return_button: Button
var _web_preview_return_callback

var preview_vfx_draft := VfxDraft.new()
var preview_vfx_texture: ImageTexture
var preview_vfx_loaded := false
var preview_vfx_load_error := ""
var preview_vfx_frame_index := 0
var preview_vfx_max_frame_seen := 0
var preview_vfx_elapsed := 0.0
var preview_vfx_projectile_was_active := false

func _enter_tree() -> void:
	super()
	if not player_character.loaded:
		return

	var animation_errors: PackedStringArray = player_animation_map.load_from_id(player_character.animation_map)
	if not animation_errors.is_empty():
		player_animation_load_error = " | ".join(animation_errors)
		push_error("Failed to load player animation map: %s" % player_animation_load_error)

func _ready() -> void:
	super()
	_load_creator_preview_vfx()
	_install_preview_return_path()
	_set_web_state()

func _process(delta: float) -> void:
	super(delta)
	_tick_creator_preview_vfx(delta)

func _load_creator_preview_vfx() -> void:
	preview_vfx_loaded = false
	preview_vfx_texture = null
	preview_vfx_load_error = ""
	preview_vfx_frame_index = 0
	preview_vfx_max_frame_seen = 0
	preview_vfx_elapsed = 0.0
	preview_vfx_projectile_was_active = false

	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_method("has_active_vfx_preview") or not bool(session.call("has_active_vfx_preview")):
		return
	if not session.has_method("preview_vfx_data") or not session.has_method("preview_vfx_png_bytes"):
		preview_vfx_load_error = "Creator preview VFX session accessors are unavailable"
		return

	var vfx_data: Dictionary = session.call("preview_vfx_data")
	var png_bytes: PackedByteArray = session.call("preview_vfx_png_bytes")
	var draft_errors: PackedStringArray = preview_vfx_draft.load_from_dictionary(vfx_data)
	if not draft_errors.is_empty():
		preview_vfx_load_error = " | ".join(draft_errors)
		return
	if png_bytes.is_empty() or png_bytes.size() > 5 * 1024 * 1024:
		preview_vfx_load_error = "Creator preview VFX PNG bytes violate the in-memory size boundary"
		return

	var image := Image.new()
	var decode_error: Error = image.load_png_from_buffer(png_bytes)
	if decode_error != OK:
		preview_vfx_load_error = "Creator preview VFX PNG failed runtime decode"
		return
	if image.get_width() != preview_vfx_draft.image_width or image.get_height() != preview_vfx_draft.image_height:
		preview_vfx_load_error = "Creator preview VFX decoded dimensions do not match metadata"
		return
	preview_vfx_texture = ImageTexture.create_from_image(image)
	preview_vfx_loaded = preview_vfx_texture != null
	if not preview_vfx_loaded:
		preview_vfx_load_error = "Creator preview VFX texture creation failed"

func _tick_creator_preview_vfx(delta: float) -> void:
	if not preview_vfx_loaded:
		return
	var projectile_active := fireball_projectile.active
	if projectile_active and not preview_vfx_projectile_was_active:
		preview_vfx_frame_index = 0
		preview_vfx_max_frame_seen = 0
		preview_vfx_elapsed = 0.0
	elif projectile_active and preview_vfx_draft.frame_count > 1:
		var seconds_per_frame := 1.0 / preview_vfx_draft.fps
		preview_vfx_elapsed += maxf(0.0, delta)
		while preview_vfx_elapsed >= seconds_per_frame:
			preview_vfx_elapsed -= seconds_per_frame
			preview_vfx_frame_index = (preview_vfx_frame_index + 1) % preview_vfx_draft.frame_count
			preview_vfx_max_frame_seen = maxi(preview_vfx_max_frame_seen, preview_vfx_frame_index)
	elif not projectile_active:
		preview_vfx_frame_index = 0
		preview_vfx_elapsed = 0.0
	preview_vfx_projectile_was_active = projectile_active

func _draw_fireball(arena_top: float, arena_bottom: float) -> void:
	if not preview_vfx_loaded or preview_vfx_texture == null:
		super(arena_top, arena_bottom)
		return
	if not fireball_projectile.active:
		return
	var frame_width := preview_vfx_draft.frame_width()
	var frame_height := preview_vfx_draft.frame_height()
	if frame_width < 1 or frame_height < 1:
		super(arena_top, arena_bottom)
		return
	var center := Vector2(
		fireball_projectile.x,
		lerpf(arena_top, arena_bottom, fireball_projectile.depth) - 76.0
	) + Vector2(preview_vfx_draft.offset_x, preview_vfx_draft.offset_y)
	var source_region := Rect2(
		preview_vfx_draft.crop_x + preview_vfx_frame_index * frame_width,
		preview_vfx_draft.crop_y,
		frame_width,
		frame_height
	)
	var draw_size := Vector2(frame_width, frame_height) * preview_vfx_draft.scale
	var destination := Rect2(center - draw_size * 0.5, draw_size)
	draw_texture_rect_region(preview_vfx_texture, destination, source_region)

func _install_preview_return_path() -> void:
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if not _preview_session_active(session):
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
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_method("has_stored_drafts") or not bool(session.call("has_stored_drafts")):
		return
	if session.has_method("deactivate_preview"):
		session.call("deactivate_preview")
	var router: Variant = get_parent()
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
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	var preview_active: bool = _preview_session_active(session)
	var runtime_vfx_active := preview_vfx_loaded and fireball_projectile.active
	JavaScriptBridge.eval(
		"document.documentElement.dataset.playerCharacterAnimationMap=%s;" % JSON.stringify(player_character.animation_map) +
		"document.documentElement.dataset.playerAnimationMapLoaded='%s';" % _bool_text(player_animation_map.loaded) +
		"document.documentElement.dataset.playerAnimationMapId=%s;" % JSON.stringify(player_animation_map.map_id) +
		"document.documentElement.dataset.playerAnimationSemantic=%s;" % JSON.stringify(_animation_semantic_name()) +
		"document.documentElement.dataset.playerAnimationId=%s;" % JSON.stringify(_current_animation_id()) +
		"document.documentElement.dataset.playerAnimationLoadError=%s;" % JSON.stringify(player_animation_load_error) +
		"document.documentElement.dataset.creatorPreviewReturnReady='%s';" % ("true" if preview_active else "false") +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeLoaded='%s';" % ("true" if preview_vfx_loaded else "false") +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeFrameCount='%d';" % (preview_vfx_draft.frame_count if preview_vfx_loaded else 0) +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeCurrentFrame='%d';" % preview_vfx_frame_index +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeMaxFrameSeen='%d';" % preview_vfx_max_frame_seen +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeScale='%.3f';" % (preview_vfx_draft.scale if preview_vfx_loaded else 1.0) +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeOffsetX='%.3f';" % (preview_vfx_draft.offset_x if preview_vfx_loaded else 0.0) +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeOffsetY='%.3f';" % (preview_vfx_draft.offset_y if preview_vfx_loaded else 0.0) +
		"document.documentElement.dataset.creatorPreviewVfxProjectileVisible='%s';" % ("true" if runtime_vfx_active else "false") +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeLoadError=%s;" % JSON.stringify(preview_vfx_load_error)
	)
