extends Control

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const BeamAttackState = preload("res://game/core/skills/beam_attack_state.gd")

var host
var skill := SkillDefinition.new()
var cast_state := SkillCastState.new()
var beam_state := BeamAttackState.new()
var skill_latched := false
var last_hit := false
var hit_count := 0
var cast_origin := Vector2.ZERO
var cast_facing := 1.0
var impact_timer := 0.0
var impact_x := 0.0
var web_sync_accumulator := 0.0
var status_label: Label

func _ready() -> void:
	host = get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_input()
	_load_skill()
	status_label = Label.new()
	status_label.position = Vector2(50.0, 452.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("8de9ff"))
	status_label.visible = skill.loaded
	add_child(status_label)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	if host == null:
		return

	cast_state.tick(delta)
	if cast_state.consume_activation():
		_start_beam()

	beam_state.tick(delta)
	if beam_state.can_hit():
		_resolve_collision()

	impact_timer = maxf(0.0, impact_timer - maxf(0.0, delta))
	_handle_input()

	if status_label != null:
		status_label.visible = skill.loaded
		if skill.loaded:
			status_label.text = "[Y] %s    Phase: %s    Cooldown: %.2fs" % [
				skill.skill_name,
				cast_state.phase_name(),
				cast_state.cooldown_remaining
			]

	web_sync_accumulator += maxf(0.0, delta)
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("skill_7")
	if pressed and not skill_latched and _can_start_cast():
		_try_cast()
	skill_latched = pressed

func _can_start_cast() -> bool:
	if not skill.loaded or host == null or cast_state.is_casting():
		return false
	if not cast_state.can_cast(host.player_state.mp):
		return false
	if host.player_guarding or host.movement_state.jumping or host.movement_state.is_dashing():
		return false
	if host.attack_chain_state.is_attacking():
		return false
	if host.fireball_cast_state.is_casting() or host.dash_slash_cast_state.is_casting() or host.dash_slash_state.active:
		return false
	for node_name in ["AreaSkillController", "FormationSkillController", "BuffSkillController", "MeleeSkillController"]:
		var controller: Variant = get_node_or_null("../%s" % node_name)
		if controller == null:
			continue
		var other_cast: Variant = controller.get("cast_state")
		if other_cast != null and other_cast.has_method("is_casting") and bool(other_cast.call("is_casting")):
			return false
		for state_name in ["area_state", "formation_state", "melee_state"]:
			var other_state: Variant = controller.get(state_name)
			if other_state != null and bool(other_state.get("active")):
				return false
	return true

func _try_cast() -> void:
	if not cast_state.start_cast(host.player_state.mp):
		return
	if not host.player_state.spend_mp(skill.mp_cost):
		return
	cast_origin = Vector2(host.player_x, host.player_depth)
	cast_facing = host.player_facing
	last_hit = false
	_set_web_state()

func _start_beam() -> void:
	if not skill.loaded or skill.skill_type != "beam":
		return
	beam_state.start(
		cast_origin,
		cast_facing,
		skill.range,
		skill.hitbox_half_width,
		skill.hitbox_half_depth,
		skill.active
	)
	_set_web_state()

func _resolve_collision() -> void:
	if host.dummy_state.is_defeated() or not host.dummy_recovery_state.can_be_hit():
		return
	if not beam_state.hitbox().overlaps(host._dummy_hurtbox()):
		return
	if not beam_state.consume_hit():
		return

	host.dummy_state.apply_damage(skill.damage)
	host.dummy_state.apply_hitstun(skill.hitstun)
	host.dummy_knockback_state.apply_impulse(cast_facing * skill.knockback)
	host.dummy_hit_timer = skill.hitstun
	impact_timer = 0.32
	impact_x = host.dummy_x
	last_hit = true
	hit_count += 1
	_set_web_state()

func _draw() -> void:
	if host == null or not skill.loaded:
		return
	var canvas_height := maxf(size.y, 720.0)
	var arena_top := canvas_height * 0.50
	var arena_bottom := canvas_height * 0.86
	var beam_y := lerpf(arena_top, arena_bottom, cast_origin.y) - 72.0
	var start := Vector2(cast_origin.x, beam_y)
	var end := start + Vector2(cast_facing * skill.range, 0.0)

	if cast_state.phase_name() == "STARTUP":
		draw_line(start, end, Color(0.45, 0.90, 1.0, 0.30), maxf(2.0, skill.hitbox_half_width * 0.25))
		draw_circle(end, maxf(8.0, skill.hitbox_half_width * 0.45), Color(0.55, 0.93, 1.0, 0.38))

	if beam_state.active:
		var active_start := Vector2(beam_state.origin.x, lerpf(arena_top, arena_bottom, beam_state.origin.y) - 72.0)
		var active_end := Vector2(beam_state.endpoint.x, lerpf(arena_top, arena_bottom, beam_state.endpoint.y) - 72.0)
		draw_line(active_start, active_end, Color(0.42, 0.90, 1.0, 0.96), maxf(6.0, skill.hitbox_half_width * 0.75))
		draw_line(active_start, active_end, Color(0.86, 0.98, 1.0, 0.96), maxf(2.0, skill.hitbox_half_width * 0.26))

	if impact_timer > 0.0:
		var impact_center := Vector2(impact_x, lerpf(arena_top, arena_bottom, host.dummy_depth) - 66.0)
		var progress := clampf(impact_timer / 0.32, 0.0, 1.0)
		var radius := 20.0 + (1.0 - progress) * 42.0
		draw_circle(impact_center, radius * 0.32, Color(0.45, 0.90, 1.0, 0.22 * progress))
		draw_arc(impact_center, radius, 0.0, TAU, 24, Color(0.68, 0.96, 1.0, progress), 4.0)

func _load_skill() -> void:
	# The coordinated runtime resolves Beam from the validated character/preview slot.
	# This base implementation intentionally has no hidden sample-path fallback.
	pass

func _register_input() -> void:
	var action_name := StringName("skill_7")
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Y
	InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var can_cast := _can_start_cast() if host != null else false
	JavaScriptBridge.eval(
		"document.documentElement.dataset.beamSkillLoaded='%s';" % _bool_text(skill.loaded) +
		"document.documentElement.dataset.beamSkillId=%s;" % JSON.stringify(skill.skill_id) +
		"document.documentElement.dataset.beamSkillPhase=%s;" % JSON.stringify(cast_state.phase_name()) +
		"document.documentElement.dataset.beamSkillCooldown='%.3f';" % cast_state.cooldown_remaining +
		"document.documentElement.dataset.beamSkillCanCast='%s';" % _bool_text(can_cast) +
		"document.documentElement.dataset.beamSkillActive='%s';" % _bool_text(beam_state.active) +
		"document.documentElement.dataset.beamSkillHitCount='%d';" % hit_count +
		"document.documentElement.dataset.lastBeamSkillHit='%s';" % _bool_text(last_hit) +
		"document.documentElement.dataset.beamSkillEndpointX='%.2f';" % beam_state.endpoint.x
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
