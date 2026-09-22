extends Control

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const TeleportState = preload("res://game/core/skills/teleport_state.gd")

var host
var skill := SkillDefinition.new()
var cast_state := SkillCastState.new()
var teleport_state := TeleportState.new()
var skill_latched := false
var last_teleport_success := false
var visual_timer := 0.0
var web_sync_accumulator := 0.0
var status_label: Label

func _ready() -> void:
	host = get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_input()
	_load_skill()
	status_label = Label.new()
	status_label.position = Vector2(50.0, 526.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("cbb6ff"))
	status_label.visible = skill.loaded
	add_child(status_label)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	if host == null:
		return

	cast_state.tick(delta)
	if cast_state.consume_activation():
		_perform_teleport()

	visual_timer = maxf(0.0, visual_timer - maxf(0.0, delta))
	_handle_input()

	if status_label != null:
		status_label.visible = skill.loaded
		if skill.loaded:
			status_label.text = "[R] %s    Phase: %s    Last: %.0fpx    Cooldown: %.2fs" % [
				skill.skill_name,
				cast_state.phase_name(),
				teleport_state.last_distance,
				cast_state.cooldown_remaining
			]

	web_sync_accumulator += maxf(0.0, delta)
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("skill_10")
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
	return true

func _try_cast() -> void:
	if not cast_state.start_cast(host.player_state.mp):
		return
	if not host.player_state.spend_mp(skill.mp_cost):
		return
	last_teleport_success = false
	_set_web_state()

func _perform_teleport() -> void:
	if not skill.loaded or skill.skill_type != "teleport":
		return
	var arena_left := float(host.arena_left_x()) if host.has_method("arena_left_x") else 90.0
	var arena_right := float(host.arena_right_x()) if host.has_method("arena_right_x") else maxf(host.size.x, 1280.0) - 90.0
	if not teleport_state.resolve(
		host.player_x,
		host.player_facing,
		skill.range,
		arena_left,
		arena_right
	):
		last_teleport_success = false
		_set_web_state()
		return
	host.player_x = teleport_state.last_destination_x
	last_teleport_success = true
	visual_timer = 0.28
	_set_web_state()
	queue_redraw()

func _draw() -> void:
	if host == null or not skill.loaded or visual_timer <= 0.0:
		return
	var canvas_height := maxf(size.y, 720.0)
	var arena_top := canvas_height * 0.50
	var arena_bottom := canvas_height * 0.86
	var y := lerpf(arena_top, arena_bottom, host.player_depth) - 54.0
	var pulse := clampf(visual_timer / 0.28, 0.0, 1.0)
	var start := Vector2(teleport_state.last_start_x, y)
	var destination := Vector2(teleport_state.last_destination_x, y)
	draw_arc(start, 32.0 + (1.0 - pulse) * 18.0, 0.0, TAU, 24, Color(0.58, 0.42, 1.0, 0.78 * pulse), 4.0)
	draw_arc(destination, 42.0 - (1.0 - pulse) * 10.0, 0.0, TAU, 24, Color(0.78, 0.66, 1.0, 0.95 * pulse), 5.0)
	draw_line(start, destination, Color(0.68, 0.54, 1.0, 0.32 * pulse), 3.0)

func _load_skill() -> void:
	# The coordinated runtime resolves Teleport from the validated character/preview slot.
	pass

func _register_input() -> void:
	var action_name := StringName("skill_10")
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_R
	InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var can_cast := _can_start_cast() if host != null else false
	JavaScriptBridge.eval(
		"document.documentElement.dataset.teleportSkillLoaded='%s';" % _bool_text(skill.loaded) +
		"document.documentElement.dataset.teleportSkillId=%s;" % JSON.stringify(skill.skill_id) +
		"document.documentElement.dataset.teleportSkillPhase=%s;" % JSON.stringify(cast_state.phase_name()) +
		"document.documentElement.dataset.teleportSkillCooldown='%.3f';" % cast_state.cooldown_remaining +
		"document.documentElement.dataset.teleportSkillCanCast='%s';" % _bool_text(can_cast) +
		"document.documentElement.dataset.teleportSkillLastSuccess='%s';" % _bool_text(last_teleport_success) +
		"document.documentElement.dataset.teleportSkillActivationCount='%d';" % teleport_state.activation_count +
		"document.documentElement.dataset.teleportSkillLastStartX='%.2f';" % teleport_state.last_start_x +
		"document.documentElement.dataset.teleportSkillDestinationX='%.2f';" % teleport_state.last_destination_x +
		"document.documentElement.dataset.teleportSkillLastDistance='%.2f';" % teleport_state.last_distance +
		"document.documentElement.dataset.teleportSkillLastDirection='%.0f';" % teleport_state.last_direction
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
