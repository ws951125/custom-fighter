extends Control

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const BuffState = preload("res://game/core/skills/buff_state.gd")

const BUFF_SKILL_PATH := "res://content/skills/battle_focus.sample.json"

var host
var skill := SkillDefinition.new()
var cast_state := SkillCastState.new()
var buff_state := BuffState.new()
var skill_latched := false
var previous_player_x := 0.0
var previous_player_depth := 0.0
var web_sync_accumulator := 0.0
var status_label: Label

func _ready() -> void:
	host = get_parent()
	process_priority = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_input()
	_load_skill()
	previous_player_x = host.player_x if host != null else 0.0
	previous_player_depth = host.player_depth if host != null else 0.0
	status_label = Label.new()
	status_label.position = Vector2(50.0, 400.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("ffe7a6"))
	add_child(status_label)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	if host == null:
		return

	cast_state.tick(delta)
	if cast_state.consume_activation():
		_activate_buff()

	buff_state.tick(delta)
	host.attack_chain_state.set_damage_multiplier(buff_state.attack_multiplier())
	_apply_movement_boost()
	_handle_input()

	var skill_name := skill.skill_name if skill.loaded else "Skill unavailable"
	var active_text := "ACTIVE %.2fs" % buff_state.remaining if buff_state.active else "INACTIVE"
	status_label.text = "[B] %s    %s    Move x%.2f    Attack x%.2f    Cooldown: %.2fs" % [
		skill_name,
		active_text,
		buff_state.movement_multiplier(),
		buff_state.attack_multiplier(),
		cast_state.cooldown_remaining
	]

	web_sync_accumulator += delta
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("skill_5")
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
	var formation_controller = get_node_or_null("../FormationSkillController")
	if formation_controller != null and (formation_controller.cast_state.is_casting() or formation_controller.formation_state.active):
		return false
	return true

func _try_cast() -> void:
	if not cast_state.start_cast(host.player_state.mp):
		return
	if not host.player_state.spend_mp(skill.mp_cost):
		return
	_set_web_state()

func _activate_buff() -> void:
	if not skill.loaded or skill.skill_type != "buff":
		return
	if not buff_state.start(
		skill.buff_duration,
		skill.move_speed_multiplier,
		skill.basic_attack_damage_multiplier
	):
		return
	previous_player_x = host.player_x
	previous_player_depth = host.player_depth
	host.attack_chain_state.set_damage_multiplier(buff_state.attack_multiplier())
	_set_web_state()

func _apply_movement_boost() -> void:
	if not buff_state.active:
		previous_player_x = host.player_x
		previous_player_depth = host.player_depth
		return

	if host.movement_state.is_dashing() or host.dash_slash_state.active:
		previous_player_x = host.player_x
		previous_player_depth = host.player_depth
		return

	var move_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if move_vector.length_squared() <= 0.001:
		previous_player_x = host.player_x
		previous_player_depth = host.player_depth
		return

	var multiplier_extra := buff_state.movement_multiplier() - 1.0
	var frame_delta_x := host.player_x - previous_player_x
	var frame_delta_depth := host.player_depth - previous_player_depth
	host.player_x += frame_delta_x * multiplier_extra
	host.player_depth += frame_delta_depth * multiplier_extra
	host.player_x = clampf(host.player_x, 90.0, maxf(host.size.x, 1280.0) - 90.0)
	host.player_depth = clampf(host.player_depth, 0.0, 1.0)
	previous_player_x = host.player_x
	previous_player_depth = host.player_depth

func _draw() -> void:
	if host == null or not skill.loaded:
		return
	if not buff_state.active and cast_state.phase_name() != "STARTUP":
		return

	var canvas_height := maxf(size.y, 720.0)
	var arena_top := canvas_height * 0.50
	var arena_bottom := canvas_height * 0.86
	var ground := Vector2(host.player_x, lerpf(arena_top, arena_bottom, host.player_depth))
	var jump_offset := host.movement_state.jump_offset()
	var center := ground + Vector2(0.0, -72.0 - jump_offset)
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.012)
	var outer_radius := 52.0 + pulse * 9.0
	var alpha := 0.35 if buff_state.active else 0.18
	draw_circle(center, 34.0, Color(1.0, 0.78, 0.24, 0.10 + alpha * 0.12))
	draw_arc(center, outer_radius, 0.0, TAU, 32, Color(1.0, 0.82, 0.34, 0.55 + alpha), 5.0)
	draw_arc(center, outer_radius - 13.0, -1.2, 1.2, 20, Color(1.0, 0.95, 0.68, 0.72), 3.0)
	for index in range(4):
		var angle := float(index) * PI * 0.5 + float(Time.get_ticks_msec()) * 0.002
		var start := center + Vector2(cos(angle), sin(angle)) * 30.0
		var finish := center + Vector2(cos(angle), sin(angle)) * (outer_radius + 10.0)
		draw_line(start, finish, Color(1.0, 0.72, 0.20, 0.62), 3.0)

func _load_skill() -> void:
	var errors := skill.load_from_file(BUFF_SKILL_PATH)
	if not errors.is_empty():
		push_error("Failed to load buff skill: %s" % " | ".join(errors))
		return
	cast_state.configure(skill)

func _register_input() -> void:
	var action_name := StringName("skill_5")
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_B
	InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var can_cast := _can_start_cast() if host != null else false
	JavaScriptBridge.eval(
		"document.documentElement.dataset.buffSkillLoaded='%s';" % _bool_text(skill.loaded) +
		"document.documentElement.dataset.buffSkillId='%s';" % skill.skill_id +
		"document.documentElement.dataset.buffSkillPhase='%s';" % cast_state.phase_name() +
		"document.documentElement.dataset.buffSkillCooldown='%.3f';" % cast_state.cooldown_remaining +
		"document.documentElement.dataset.buffSkillCanCast='%s';" % _bool_text(can_cast) +
		"document.documentElement.dataset.buffActive='%s';" % _bool_text(buff_state.active) +
		"document.documentElement.dataset.buffRemaining='%.3f';" % buff_state.remaining +
		"document.documentElement.dataset.buffMoveMultiplier='%.3f';" % buff_state.movement_multiplier() +
		"document.documentElement.dataset.buffAttackMultiplier='%.3f';" % buff_state.attack_multiplier() +
		"document.documentElement.dataset.buffActivationCount='%d';" % buff_state.activation_count
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
