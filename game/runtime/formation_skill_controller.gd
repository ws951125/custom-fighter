extends Control

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const FormationAttackState = preload("res://game/core/skills/formation_attack_state.gd")

const FORMATION_SKILL_PATH := "res://content/skills/blade_rain.sample.json"
const IMPACT_SECONDS := 0.30

var host
var skill := SkillDefinition.new()
var cast_state := SkillCastState.new()
var formation_state := FormationAttackState.new()
var skill_latched := false
var last_hit := false
var hit_count := 0
var last_strike_index := -1
var last_strike_x := 0.0
var cast_origin := Vector2.ZERO
var cast_facing := 1.0
var impact_timers := PackedFloat32Array()
var web_sync_accumulator := 0.0
var status_label: Label

func _ready() -> void:
	host = get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_input()
	_load_skill()
	status_label = Label.new()
	status_label.position = Vector2(50.0, 370.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("d8e7ff"))
	add_child(status_label)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	cast_state.tick(delta)
	if cast_state.consume_activation():
		_start_formation()

	formation_state.tick(delta)
	for strike_index in formation_state.consume_due_strikes():
		_trigger_strike(strike_index)

	for index in range(impact_timers.size()):
		impact_timers[index] = maxf(0.0, impact_timers[index] - delta)

	_handle_input()

	var skill_name := skill.skill_name if skill.loaded else "Skill unavailable"
	status_label.text = "[P] %s    Phase: %s    Cooldown: %.2fs    Strikes: %d/%d" % [
		skill_name,
		cast_state.phase_name(),
		cast_state.cooldown_remaining,
		formation_state.emitted_count(),
		skill.formation_count
	]

	web_sync_accumulator += delta
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("skill_4")
	if pressed and not skill_latched and _can_start_cast():
		_try_cast()
	skill_latched = pressed

func _can_start_cast() -> bool:
	if not skill.loaded or host == null:
		return false
	if not cast_state.can_cast(host.player_state.mp):
		return false
	if host.player_guarding or host.movement_state.jumping or host.movement_state.is_dashing():
		return false
	if host.attack_chain_state.is_attacking():
		return false
	if host.fireball_cast_state.is_casting() or host.dash_slash_cast_state.is_casting() or host.dash_slash_state.active:
		return false
	var area_controller = get_node_or_null("../AreaSkillController")
	if area_controller != null and (area_controller.cast_state.is_casting() or area_controller.area_state.active):
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
	last_strike_index = -1
	last_strike_x = cast_origin.x
	_set_web_state()

func _start_formation() -> void:
	if not skill.loaded or skill.skill_type != "formation":
		return
	formation_state.start(
		cast_origin,
		cast_facing,
		skill.formation_count,
		skill.formation_spacing,
		skill.formation_interval,
		skill.formation_offset,
		skill.hitbox_half_width,
		skill.hitbox_half_depth,
		skill.active
	)
	impact_timers.resize(skill.formation_count)
	for index in range(impact_timers.size()):
		impact_timers[index] = 0.0
	_set_web_state()

func _trigger_strike(strike_index: int) -> void:
	if strike_index < 0 or strike_index >= impact_timers.size():
		return
	impact_timers[strike_index] = IMPACT_SECONDS
	last_strike_index = strike_index
	last_strike_x = formation_state.center_for(strike_index).x
	_resolve_collision(strike_index)
	_set_web_state()

func _resolve_collision(strike_index: int) -> void:
	if host.dummy_state.is_defeated() or not host.dummy_recovery_state.can_be_hit():
		return
	if not formation_state.strike_hitbox(strike_index).overlaps(host._dummy_hurtbox()):
		return
	if not formation_state.consume_hit(strike_index):
		return

	host.dummy_state.apply_damage(skill.damage)
	host.dummy_state.apply_hitstun(skill.hitstun)
	host.dummy_knockback_state.apply_impulse(formation_state.facing * skill.knockback)
	host.dummy_hit_timer = skill.hitstun
	last_hit = true
	hit_count += 1

func _draw() -> void:
	if host == null or not skill.loaded:
		return
	var canvas_height := maxf(size.y, 720.0)
	var arena_top := canvas_height * 0.50
	var arena_bottom := canvas_height * 0.86

	if cast_state.phase_name() == "STARTUP":
		for index in range(skill.formation_count):
			var preview_center := _projected_center(index)
			_draw_cell_telegraph(preview_center, arena_top, arena_bottom, index, 0.48)

	if formation_state.active or formation_state.emitted_count() > 0:
		for index in range(skill.formation_count):
			var center := formation_state.center_for(index)
			if center == Vector2.ZERO:
				continue
			if not formation_state.has_struck(index):
				_draw_cell_telegraph(center, arena_top, arena_bottom, index, 0.62)
			if index < impact_timers.size() and impact_timers[index] > 0.0:
				_draw_blade_impact(center, arena_top, arena_bottom, impact_timers[index] / IMPACT_SECONDS)

func _projected_center(index: int) -> Vector2:
	return Vector2(
		cast_origin.x + cast_facing * (skill.formation_offset + float(index) * skill.formation_spacing),
		cast_origin.y
	)

func _draw_cell_telegraph(center: Vector2, arena_top: float, arena_bottom: float, index: int, alpha: float) -> void:
	var ground := Vector2(center.x, lerpf(arena_top, arena_bottom, center.y))
	var depth_radius := maxf(12.0, (arena_bottom - arena_top) * skill.hitbox_half_depth)
	var pulse := 0.78 + 0.22 * sin(float(Time.get_ticks_msec()) * 0.012 + float(index) * 0.8)
	draw_arc(ground, skill.hitbox_half_width * pulse, 0.0, TAU, 24, Color(0.42, 0.72, 1.0, alpha), 3.0)
	draw_line(ground + Vector2(0.0, -155.0), ground + Vector2(0.0, -38.0), Color(0.68, 0.86, 1.0, alpha * 0.55), 3.0)
	draw_arc(ground, depth_radius, 0.0, TAU, 18, Color(0.62, 0.80, 1.0, alpha * 0.45), 2.0)

func _draw_blade_impact(center: Vector2, arena_top: float, arena_bottom: float, progress: float) -> void:
	var ground := Vector2(center.x, lerpf(arena_top, arena_bottom, center.y))
	var clamped := clampf(progress, 0.0, 1.0)
	var blade_top := ground + Vector2(0.0, -185.0 + (1.0 - clamped) * 32.0)
	var blade_bottom := ground + Vector2(0.0, -22.0)
	draw_line(blade_top, blade_bottom, Color(0.86, 0.94, 1.0, clamped), 8.0)
	draw_line(blade_top + Vector2(-10.0, 28.0), blade_top + Vector2(10.0, 28.0), Color(0.66, 0.84, 1.0, clamped), 5.0)
	var radius := skill.hitbox_half_width * (1.0 + (1.0 - clamped) * 0.45)
	draw_circle(ground, radius * 0.42, Color(0.30, 0.62, 1.0, 0.12 * clamped))
	draw_arc(ground, radius, 0.0, TAU, 26, Color(0.62, 0.84, 1.0, clamped), 5.0)

func _load_skill() -> void:
	var errors := skill.load_from_file(FORMATION_SKILL_PATH)
	if not errors.is_empty():
		push_error("Failed to load formation skill: %s" % " | ".join(errors))
		return
	cast_state.configure(skill)
	impact_timers.resize(skill.formation_count)

func _register_input() -> void:
	var action_name := StringName("skill_4")
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_P
	InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var can_cast := _can_start_cast() if host != null else false
	JavaScriptBridge.eval(
		"document.documentElement.dataset.formationSkillLoaded='%s';" % _bool_text(skill.loaded) +
		"document.documentElement.dataset.formationSkillId='%s';" % skill.skill_id +
		"document.documentElement.dataset.formationSkillPhase='%s';" % cast_state.phase_name() +
		"document.documentElement.dataset.formationSkillCooldown='%.3f';" % cast_state.cooldown_remaining +
		"document.documentElement.dataset.formationSkillCanCast='%s';" % _bool_text(can_cast) +
		"document.documentElement.dataset.formationSkillActive='%s';" % _bool_text(formation_state.active) +
		"document.documentElement.dataset.formationStrikeCount='%d';" % skill.formation_count +
		"document.documentElement.dataset.formationStrikesEmitted='%d';" % formation_state.emitted_count() +
		"document.documentElement.dataset.lastFormationStrikeIndex='%d';" % last_strike_index +
		"document.documentElement.dataset.lastFormationStrikeX='%.2f';" % last_strike_x +
		"document.documentElement.dataset.lastFormationSkillHit='%s';" % _bool_text(last_hit) +
		"document.documentElement.dataset.formationSkillHitCount='%d';" % hit_count
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
