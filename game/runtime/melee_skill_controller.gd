extends Control

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const MeleeAttackState = preload("res://game/core/skills/melee_attack_state.gd")

const MELEE_SKILL_PATH := "res://content/skills/heavy_strike.sample.json"

var host
var skill := SkillDefinition.new()
var cast_state := SkillCastState.new()
var melee_state := MeleeAttackState.new()
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
	status_label.position = Vector2(50.0, 430.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("ffd3a8"))
	add_child(status_label)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	if host == null:
		return

	cast_state.tick(delta)
	if cast_state.consume_activation():
		_start_melee()

	melee_state.tick(delta)
	if melee_state.can_hit():
		_resolve_collision()

	impact_timer = maxf(0.0, impact_timer - delta)
	_handle_input()

	var skill_name := skill.skill_name if skill.loaded else "Skill unavailable"
	status_label.text = "[H] %s    Phase: %s    Cooldown: %.2fs" % [
		skill_name,
		cast_state.phase_name(),
		cast_state.cooldown_remaining
	]

	web_sync_accumulator += delta
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("skill_6")
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

	var area_controller = get_node_or_null("../AreaSkillController")
	if area_controller != null and (area_controller.cast_state.is_casting() or area_controller.area_state.active):
		return false
	var formation_controller = get_node_or_null("../FormationSkillController")
	if formation_controller != null and (formation_controller.cast_state.is_casting() or formation_controller.formation_state.active):
		return false
	var buff_controller = get_node_or_null("../BuffSkillController")
	if buff_controller != null and buff_controller.cast_state.is_casting():
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

func _start_melee() -> void:
	if not skill.loaded or skill.skill_type != "melee":
		return
	melee_state.start(
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
	if not melee_state.hitbox().overlaps(host._dummy_hurtbox()):
		return
	if not melee_state.consume_hit():
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
	var depth_radius := maxf(15.0, (arena_bottom - arena_top) * skill.hitbox_half_depth)
	var origin_ground := Vector2(cast_origin.x, lerpf(arena_top, arena_bottom, cast_origin.y))
	var center_x := cast_origin.x + cast_facing * skill.range
	var telegraph_center := Vector2(center_x, origin_ground.y - 56.0)

	if cast_state.phase_name() == "STARTUP":
		var rect := Rect2(
			telegraph_center - Vector2(skill.hitbox_half_width, depth_radius),
			Vector2(skill.hitbox_half_width * 2.0, depth_radius * 2.0)
		)
		draw_rect(rect, Color(1.0, 0.55, 0.18, 0.10), true)
		draw_rect(rect, Color(1.0, 0.72, 0.35, 0.82), false, 3.0)
		var sweep_end := telegraph_center + Vector2(cast_facing * skill.hitbox_half_width, -34.0)
		draw_line(origin_ground + Vector2(0.0, -64.0), sweep_end, Color(1.0, 0.88, 0.62, 0.72), 4.0)

	if melee_state.active:
		var active_center := Vector2(
			melee_state.center.x,
			lerpf(arena_top, arena_bottom, melee_state.center.y) - 56.0
		)
		var sweep_start := -1.15 if cast_facing > 0.0 else PI - 1.15
		var sweep_end_angle := 1.15 if cast_facing > 0.0 else PI + 1.15
		draw_arc(active_center, skill.hitbox_half_width, sweep_start, sweep_end_angle, 20, Color(1.0, 0.72, 0.28, 0.95), 9.0)
		draw_arc(active_center, skill.hitbox_half_width - 14.0, sweep_start, sweep_end_angle, 20, Color(1.0, 0.94, 0.72, 0.88), 4.0)

	if impact_timer > 0.0:
		var impact_center := Vector2(impact_x, lerpf(arena_top, arena_bottom, host.dummy_depth) - 66.0)
		var progress := clampf(impact_timer / 0.32, 0.0, 1.0)
		var radius := 24.0 + (1.0 - progress) * 46.0
		draw_circle(impact_center, radius * 0.34, Color(1.0, 0.54, 0.16, 0.18 * progress))
		draw_arc(impact_center, radius, 0.0, TAU, 24, Color(1.0, 0.78, 0.38, progress), 5.0)
		for index in range(4):
			var angle := float(index) * PI * 0.5 + 0.25
			var ray := Vector2(cos(angle), sin(angle)) * radius
			draw_line(impact_center + ray * 0.30, impact_center + ray, Color(1.0, 0.90, 0.66, progress), 3.0)

func _load_skill() -> void:
	var errors := skill.load_from_file(MELEE_SKILL_PATH)
	if not errors.is_empty():
		push_error("Failed to load melee skill: %s" % " | ".join(errors))
		return
	cast_state.configure(skill)

func _register_input() -> void:
	var action_name := StringName("skill_6")
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_H
	InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var can_cast := _can_start_cast() if host != null else false
	JavaScriptBridge.eval(
		"document.documentElement.dataset.meleeSkillLoaded='%s';" % _bool_text(skill.loaded) +
		"document.documentElement.dataset.meleeSkillId='%s';" % skill.skill_id +
		"document.documentElement.dataset.meleeSkillPhase='%s';" % cast_state.phase_name() +
		"document.documentElement.dataset.meleeSkillCooldown='%.3f';" % cast_state.cooldown_remaining +
		"document.documentElement.dataset.meleeSkillCanCast='%s';" % _bool_text(can_cast) +
		"document.documentElement.dataset.meleeSkillActive='%s';" % _bool_text(melee_state.active) +
		"document.documentElement.dataset.lastMeleeSkillHit='%s';" % _bool_text(last_hit) +
		"document.documentElement.dataset.meleeSkillHitCount='%d';" % hit_count +
		"document.documentElement.dataset.meleeSkillCenterX='%.2f';" % melee_state.center.x
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
