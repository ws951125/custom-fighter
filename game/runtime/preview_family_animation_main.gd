extends "res://game/runtime/animation_main.gd"

func _preview_family_cast_state() -> Variant:
	var session: Variant = _creator_preview_session()
	if not _preview_session_active(session):
		return null
	var preview_slot := _preview_skill_slot(session)
	match preview_slot:
		"skill_1":
			return fireball_cast_state
		"skill_2":
			return dash_slash_cast_state
		"skill_3":
			return _controller_cast_state("AreaSkillController")
		"skill_4":
			return _controller_cast_state("FormationSkillController")
		"skill_5":
			return _controller_cast_state("BuffSkillController")
		"skill_6":
			return _controller_cast_state("MeleeSkillController")
		"skill_7":
			return _controller_cast_state("BeamSkillController")
	return null

func _controller_cast_state(node_name: String) -> Variant:
	var controller: Variant = get_node_or_null(node_name)
	if controller == null:
		return null
	var value: Variant = controller.get("cast_state")
	return value

func _preview_family_active_events(event_type: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var cast_state: Variant = _preview_family_cast_state()
	if cast_state == null or not cast_state.has_method("active_timeline_events"):
		return events
	var value: Variant = cast_state.call("active_timeline_events", event_type)
	if typeof(value) != TYPE_ARRAY:
		return events
	for raw_event in value:
		if typeof(raw_event) == TYPE_DICTIONARY:
			var event: Dictionary = raw_event
			events.append(event)
	return events

func _preview_family_consume_transitions() -> Array[Dictionary]:
	var transitions: Array[Dictionary] = []
	var cast_state: Variant = _preview_family_cast_state()
	if cast_state == null or not cast_state.has_method("consume_timeline_transitions"):
		return transitions
	var value: Variant = cast_state.call("consume_timeline_transitions")
	if typeof(value) != TYPE_ARRAY:
		return transitions
	for raw_transition in value:
		if typeof(raw_transition) == TYPE_DICTIONARY:
			var transition: Dictionary = raw_transition
			transitions.append(transition)
	return transitions

func _preview_family_timeline_running() -> bool:
	var cast_state: Variant = _preview_family_cast_state()
	return cast_state != null and cast_state.has_method("timeline_is_running") and bool(cast_state.call("timeline_is_running"))

func _preview_family_timeline_elapsed() -> float:
	var cast_state: Variant = _preview_family_cast_state()
	if cast_state == null or not cast_state.has_method("timeline_elapsed_seconds"):
		return 0.0
	return float(cast_state.call("timeline_elapsed_seconds"))

func _consume_creator_preview_timeline_transitions() -> void:
	var session: Variant = _creator_preview_session()
	if not _preview_session_active(session):
		return
	if _preview_skill_slot(session) == "skill_1":
		super()
		return

	var transitions: Array[Dictionary] = _preview_family_consume_transitions()
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

func _draw_creator_preview_timeline_overlays(arena_top: float, arena_bottom: float) -> void:
	var session: Variant = _creator_preview_session()
	if not _preview_session_active(session):
		return
	if _preview_skill_slot(session) == "skill_1":
		super(arena_top, arena_bottom)
		return

	var hitboxes: Array[Dictionary] = _preview_family_active_events("hitbox")
	for event in hitboxes:
		_draw_combat_box(_preview_timeline_spatial_box(event), arena_top, arena_bottom, Color(0.35, 0.95, 0.55, 0.82))

	var hurtboxes: Array[Dictionary] = _preview_family_active_events("hurtbox")
	for event in hurtboxes:
		_draw_combat_box(_preview_timeline_spatial_box(event), arena_top, arena_bottom, Color(0.36, 0.72, 1.0, 0.78))

	var vfx_events: Array[Dictionary] = _preview_family_active_events("vfx")
	if not vfx_events.is_empty() or preview_timeline_vfx_pulse_remaining > 0.0:
		var center := Vector2(player_x, lerpf(arena_top, arena_bottom, player_depth) - 76.0)
		var pulse := 1.0
		if vfx_events.is_empty():
			pulse = clampf(preview_timeline_vfx_pulse_remaining / TIMELINE_INSTANT_PULSE_SECONDS, 0.0, 1.0)
		var radius := 30.0 + (1.0 - pulse) * 26.0
		draw_circle(center, radius * 0.55, Color(0.58, 0.42, 1.0, 0.14 * pulse))
		draw_arc(center, radius, 0.0, TAU, 24, Color(0.72, 0.62, 1.0, 0.90 * pulse), 4.0)

func _set_web_state() -> void:
	super()
	if not OS.has_feature("web"):
		return
	var session: Variant = _creator_preview_session()
	if not _preview_session_active(session) or _preview_skill_slot(session) == "skill_1":
		return

	var timeline_vfx_events: Array[Dictionary] = _preview_family_active_events("vfx")
	var timeline_hitboxes: Array[Dictionary] = _preview_family_active_events("hitbox")
	var timeline_hurtboxes: Array[Dictionary] = _preview_family_active_events("hurtbox")
	var timeline_vfx_active := not timeline_vfx_events.is_empty() or preview_timeline_vfx_pulse_remaining > 0.0
	var timeline_hitboxes_json := JSON.stringify(timeline_hitboxes)
	var timeline_hurtboxes_json := JSON.stringify(timeline_hurtboxes)
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorPreviewTimelineRunning='%s';" % _bool_text(_preview_family_timeline_running()) +
		"document.documentElement.dataset.creatorPreviewTimelineElapsed='%.4f';" % _preview_family_timeline_elapsed() +
		"document.documentElement.dataset.creatorPreviewTimelineVfxActive='%s';" % _bool_text(timeline_vfx_active) +
		"document.documentElement.dataset.creatorPreviewTimelineHitboxActiveCount='%d';" % timeline_hitboxes.size() +
		"document.documentElement.dataset.creatorPreviewTimelineHurtboxActiveCount='%d';" % timeline_hurtboxes.size() +
		"document.documentElement.dataset.creatorPreviewTimelineHitboxes=%s;" % JSON.stringify(timeline_hitboxes_json) +
		"document.documentElement.dataset.creatorPreviewTimelineHurtboxes=%s;" % JSON.stringify(timeline_hurtboxes_json)
	)
