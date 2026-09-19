extends "res://game/runtime/preview_selectable_main.gd"

const CharacterAnimationMap = preload("res://game/core/character/character_animation_map.gd")
const VfxDraft = preload("res://game/creator/vfx_editor/vfx_draft.gd")
const TimelineCombatBox = preload("res://game/core/combat/combat_box.gd")
const TIMELINE_INSTANT_PULSE_SECONDS := 0.18

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

var preview_timeline_transition_count := 0
var preview_timeline_last_event_id := ""
var preview_timeline_last_event_type := ""
var preview_timeline_last_phase := ""
var preview_timeline_animation_semantic := ""
var preview_timeline_animation_pulse_remaining := 0.0
var preview_timeline_last_vfx := ""
var preview_timeline_vfx_pulse_remaining := 0.0
var preview_timeline_last_audio_cue := ""
var preview_timeline_audio_event_count := 0

func _enter_tree() -> void:
	super()
	if not player_character.loaded:
		return

	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	var animation_errors := PackedStringArray()
	if (
		session != null
		and session.has_method("has_active_animation_preview")
		and bool(session.call("has_active_animation_preview"))
		and session.has_method("preview_animation_map_data")
	):
		var preview_animation_data: Dictionary = session.call("preview_animation_map_data")
		animation_errors = player_animation_map.load_from_dictionary(preview_animation_data)
	else:
		animation_errors = player_animation_map.load_from_id(player_character.animation_map)
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
	_consume_creator_preview_timeline_transitions()
	_tick_creator_preview_timeline_pulses(delta)
	_tick_creator_preview_vfx(delta)

func _consume_creator_preview_timeline_transitions() -> void:
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if not _preview_session_active(session):
		return
	var transitions: Array[Dictionary] = fireball_cast_state.consume_timeline_transitions()
	if transitions.is_empty():
		return

	for transition in transitions:
		var event_value: Variant = transition.get("event", {})
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var event_id := str(event.get("id", ""))
		var event_type := str(event.get("type", ""))
		var phase_name := str(transition.get("phase", ""))
		var duration := float(event.get("duration", 0.0))

		preview_timeline_transition_count += 1
		preview_timeline_last_event_id = event_id
		preview_timeline_last_event_type = event_type
		preview_timeline_last_phase = phase_name

		if phase_name == "start":
			match event_type:
				"animation":
					preview_timeline_animation_semantic = str(event.get("animation", "")).strip_edges().to_lower()
					preview_timeline_animation_pulse_remaining = TIMELINE_INSTANT_PULSE_SECONDS if duration <= 0.0 else 0.0
				"vfx":
					preview_timeline_last_vfx = str(event.get("visual", "")).strip_edges().to_lower()
					preview_timeline_vfx_pulse_remaining = TIMELINE_INSTANT_PULSE_SECONDS if duration <= 0.0 else 0.0
				"audio":
					preview_timeline_last_audio_cue = str(event.get("cue", "")).strip_edges().to_lower()
					preview_timeline_audio_event_count += 1
		elif phase_name == "end" and event_type == "animation":
			var ending_semantic := str(event.get("animation", "")).strip_edges().to_lower()
			if preview_timeline_animation_semantic == ending_semantic:
				preview_timeline_animation_semantic = ""
				preview_timeline_animation_pulse_remaining = 0.0

	_set_web_state()
	queue_redraw()

func _tick_creator_preview_timeline_pulses(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	if preview_timeline_animation_pulse_remaining > 0.0:
		preview_timeline_animation_pulse_remaining = maxf(0.0, preview_timeline_animation_pulse_remaining - safe_delta)
		if preview_timeline_animation_pulse_remaining <= 0.0:
			preview_timeline_animation_semantic = ""
	if preview_timeline_vfx_pulse_remaining > 0.0:
		preview_timeline_vfx_pulse_remaining = maxf(0.0, preview_timeline_vfx_pulse_remaining - safe_delta)

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
	elif fireball_projectile.active:
		var frame_width := preview_vfx_draft.frame_width()
		var frame_height := preview_vfx_draft.frame_height()
		if frame_width < 1 or frame_height < 1:
			super(arena_top, arena_bottom)
		else:
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
	_draw_creator_preview_timeline_overlays(arena_top, arena_bottom)

func _draw_creator_preview_timeline_overlays(arena_top: float, arena_bottom: float) -> void:
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if not _preview_session_active(session):
		return

	var hitboxes: Array[Dictionary] = fireball_cast_state.active_timeline_events("hitbox")
	for event in hitboxes:
		_draw_combat_box(_preview_timeline_spatial_box(event), arena_top, arena_bottom, Color(0.35, 0.95, 0.55, 0.82))

	var hurtboxes: Array[Dictionary] = fireball_cast_state.active_timeline_events("hurtbox")
	for event in hurtboxes:
		_draw_combat_box(_preview_timeline_spatial_box(event), arena_top, arena_bottom, Color(0.36, 0.72, 1.0, 0.78))

	var vfx_events: Array[Dictionary] = fireball_cast_state.active_timeline_events("vfx")
	if not vfx_events.is_empty() or preview_timeline_vfx_pulse_remaining > 0.0:
		var center := Vector2(player_x, lerpf(arena_top, arena_bottom, player_depth) - 76.0)
		var pulse := 1.0
		if vfx_events.is_empty():
			pulse = clampf(preview_timeline_vfx_pulse_remaining / TIMELINE_INSTANT_PULSE_SECONDS, 0.0, 1.0)
		var radius := 30.0 + (1.0 - pulse) * 26.0
		draw_circle(center, radius * 0.55, Color(0.58, 0.42, 1.0, 0.14 * pulse))
		draw_arc(center, radius, 0.0, TAU, 24, Color(0.72, 0.62, 1.0, 0.90 * pulse), 4.0)

func _preview_timeline_spatial_box(event: Dictionary) -> TimelineCombatBox:
	var direction := 1.0 if player_facing >= 0.0 else -1.0
	var center := Vector2(
		player_x + direction * float(event.get("offset_x", 0.0)),
		clampf(player_depth + float(event.get("offset_depth", 0.0)), 0.0, 1.0)
	)
	var half_extents := Vector2(
		float(event.get("half_width", 1.0)),
		float(event.get("half_depth", 0.01))
	)
	return TimelineCombatBox.new(center, half_extents)

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
	if (
		not preview_timeline_animation_semantic.is_empty()
		and CharacterAnimationMap.REQUIRED_SEMANTICS.has(preview_timeline_animation_semantic)
	):
		return preview_timeline_animation_semantic
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
	var timeline_vfx_events: Array[Dictionary] = []
	var timeline_hitboxes: Array[Dictionary] = []
	var timeline_hurtboxes: Array[Dictionary] = []
	if preview_active:
		timeline_vfx_events = fireball_cast_state.active_timeline_events("vfx")
		timeline_hitboxes = fireball_cast_state.active_timeline_events("hitbox")
		timeline_hurtboxes = fireball_cast_state.active_timeline_events("hurtbox")
	var timeline_vfx_active := not timeline_vfx_events.is_empty() or preview_timeline_vfx_pulse_remaining > 0.0
	var timeline_hitboxes_json := JSON.stringify(timeline_hitboxes)
	var timeline_hurtboxes_json := JSON.stringify(timeline_hurtboxes)
	JavaScriptBridge.eval(
		"document.documentElement.dataset.playerCharacterAnimationMap=%s;" % JSON.stringify(player_character.animation_map) +
		"document.documentElement.dataset.playerAnimationMapLoaded='%s';" % _bool_text(player_animation_map.loaded) +
		"document.documentElement.dataset.playerAnimationMapId=%s;" % JSON.stringify(player_animation_map.map_id) +
		"document.documentElement.dataset.playerAnimationSemantic=%s;" % JSON.stringify(_animation_semantic_name()) +
		"document.documentElement.dataset.playerAnimationId=%s;" % JSON.stringify(_current_animation_id()) +
		"document.documentElement.dataset.playerAnimationLoadError=%s;" % JSON.stringify(player_animation_load_error) +
		"document.documentElement.dataset.creatorPreviewAnimationOverrideActive='%s';" % ("true" if preview_active and session != null and session.has_method("has_active_animation_preview") and bool(session.call("has_active_animation_preview")) else "false") +
		"document.documentElement.dataset.creatorPreviewReturnReady='%s';" % ("true" if preview_active else "false") +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeLoaded='%s';" % _bool_text(preview_vfx_loaded) +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeFrameCount='%d';" % (preview_vfx_draft.frame_count if preview_vfx_loaded else 0) +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeCurrentFrame='%d';" % preview_vfx_frame_index +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeMaxFrameSeen='%d';" % preview_vfx_max_frame_seen +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeScale='%.3f';" % (preview_vfx_draft.scale if preview_vfx_loaded else 1.0) +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeOffsetX='%.3f';" % (preview_vfx_draft.offset_x if preview_vfx_loaded else 0.0) +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeOffsetY='%.3f';" % (preview_vfx_draft.offset_y if preview_vfx_loaded else 0.0) +
		"document.documentElement.dataset.creatorPreviewVfxProjectileVisible='%s';" % _bool_text(runtime_vfx_active) +
		"document.documentElement.dataset.creatorPreviewVfxRuntimeLoadError=%s;" % JSON.stringify(preview_vfx_load_error) +
		"document.documentElement.dataset.creatorPreviewTimelineRunning='%s';" % _bool_text(preview_active and fireball_cast_state.timeline_is_running()) +
		"document.documentElement.dataset.creatorPreviewTimelineElapsed='%.4f';" % (fireball_cast_state.timeline_elapsed_seconds() if preview_active else 0.0) +
		"document.documentElement.dataset.creatorPreviewTimelineTransitionCount='%d';" % preview_timeline_transition_count +
		"document.documentElement.dataset.creatorPreviewTimelineLastEventId=%s;" % JSON.stringify(preview_timeline_last_event_id) +
		"document.documentElement.dataset.creatorPreviewTimelineLastEventType=%s;" % JSON.stringify(preview_timeline_last_event_type) +
		"document.documentElement.dataset.creatorPreviewTimelineLastPhase=%s;" % JSON.stringify(preview_timeline_last_phase) +
		"document.documentElement.dataset.creatorPreviewTimelineAnimationSemantic=%s;" % JSON.stringify(preview_timeline_animation_semantic) +
		"document.documentElement.dataset.creatorPreviewTimelineLastVfx=%s;" % JSON.stringify(preview_timeline_last_vfx) +
		"document.documentElement.dataset.creatorPreviewTimelineVfxActive='%s';" % _bool_text(preview_active and timeline_vfx_active) +
		"document.documentElement.dataset.creatorPreviewTimelineLastAudioCue=%s;" % JSON.stringify(preview_timeline_last_audio_cue) +
		"document.documentElement.dataset.creatorPreviewTimelineAudioEventCount='%d';" % preview_timeline_audio_event_count +
		"document.documentElement.dataset.creatorPreviewTimelineHitboxActiveCount='%d';" % timeline_hitboxes.size() +
		"document.documentElement.dataset.creatorPreviewTimelineHurtboxActiveCount='%d';" % timeline_hurtboxes.size() +
		"document.documentElement.dataset.creatorPreviewTimelineHitboxes=%s;" % JSON.stringify(timeline_hitboxes_json) +
		"document.documentElement.dataset.creatorPreviewTimelineHurtboxes=%s;" % JSON.stringify(timeline_hurtboxes_json)
	)