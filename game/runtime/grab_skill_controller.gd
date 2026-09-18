extends Control

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const GrabState = preload("res://game/core/skills/grab_state.gd")

const ARENA_MARGIN_X := 90.0

var host
var skill := SkillDefinition.new()
var cast_state := SkillCastState.new()
var grab_state := GrabState.new()
var skill_latched := false
var last_grab_success := false
var last_grab_hit := false
var visual_timer := 0.0
var web_sync_accumulator := 0.0
var status_label: Label

func _ready() -> void:
	host = get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_input()
	_load_skill()
	status_label = Label.new()
	status_label.position = Vector2(50.0, 578.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("ffd0a8"))
	status_label.visible = skill.loaded
	add_child(status_label)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	if host == null:
		return
	cast_state.tick(delta)
	if cast_state.consume_activation():
		_attempt_grab()
	grab_state.tick(delta)
	if grab_state.active:
		_hold_captured_target()
	visual_timer = maxf(0.0, visual_timer - maxf(0.0, delta))
	_handle_input()
	if status_label != null:
		status_label.visible = skill.loaded
		if skill.loaded:
			status_label.text = "[E] %s    Phase: %s    Hold: %.2fs    Cooldown: %.2fs" % [
				skill.skill_name,
				cast_state.phase_name(),
				grab_state.remaining,
				cast_state.cooldown_remaining
			]
	web_sync_accumulator += maxf(0.0, delta)
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("skill_12")
	if pressed and not skill_latched and _can_start_cast():
		_try_cast()
	skill_latched = pressed

func _can_start_cast() -> bool:
	if not skill.loaded or host == null or cast_state.is_casting() or grab_state.active:
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
	last_grab_success = false
	last_grab_hit = false
	_set_web_state()

func _attempt_grab() -> void:
	if not skill.loaded or skill.skill_type != "grab":
		return
	if host.dummy_state.is_defeated() or not host.dummy_recovery_state.can_be_hit():
		last_grab_success = false
		last_grab_hit = false
		_set_web_state()
		return
	var arena_right := maxf(host.size.x, 1280.0) - ARENA_MARGIN_X
	var hurtbox = host._dummy_hurtbox()
	var captured := grab_state.try_capture(
		Vector2(host.player_x, host.player_depth),
		Vector2(host.dummy_x, host.dummy_depth),
		hurtbox.half_extents,
		host.player_facing,
		skill.range,
		skill.hitbox_half_width,
		skill.hitbox_half_depth,
		skill.active,
		skill.knockback,
		ARENA_MARGIN_X,
		arena_right
	)
	if not captured:
		last_grab_success = false
		last_grab_hit = false
		_set_web_state()
		return
	host.dummy_x = grab_state.last_target_destination.x
	host.dummy_depth = grab_state.last_target_destination.y
	host.dummy_state.apply_damage(skill.damage)
	host.dummy_state.apply_hitstun(maxf(skill.hitstun, skill.active))
	host.dummy_hit_timer = maxf(skill.hitstun, skill.active)
	last_grab_success = true
	last_grab_hit = true
	visual_timer = 0.34
	_set_web_state()
	queue_redraw()

func _hold_captured_target() -> void:
	if host.dummy_state.is_defeated():
		grab_state.cancel()
		return
	var arena_right := maxf(host.size.x, 1280.0) - ARENA_MARGIN_X
	var destination := grab_state.anchored_target_position(
		Vector2(host.player_x, host.player_depth),
		host.player_facing,
		skill.knockback,
		ARENA_MARGIN_X,
		arena_right
	)
	host.dummy_x = destination.x
	host.dummy_depth = destination.y

func _draw() -> void:
	if host == null or not skill.loaded:
		return
	var canvas_height := maxf(size.y, 720.0)
	var arena_top := canvas_height * 0.50
	var arena_bottom := canvas_height * 0.86
	var player_center := Vector2(host.player_x, lerpf(arena_top, arena_bottom, host.player_depth) - 70.0)
	if cast_state.phase_name() == "STARTUP":
		var source_x: float = float(host.player_x) + float(host.player_facing) * skill.range
		draw_arc(
			Vector2(source_x, player_center.y),
			maxf(20.0, skill.hitbox_half_width * 0.55),
			0.0,
			TAU,
			24,
			Color(1.0, 0.70, 0.38, 0.72),
			4.0
		)
	if grab_state.active or visual_timer > 0.0:
		var target_center := Vector2(
			host.dummy_x,
			lerpf(arena_top, arena_bottom, host.dummy_depth) - 66.0
		)
		var pulse := 1.0 if grab_state.active else clampf(visual_timer / 0.34, 0.0, 1.0)
		draw_line(player_center, target_center, Color(1.0, 0.68, 0.34, 0.62 * pulse), 5.0)
		draw_arc(
			target_center,
			38.0 + (1.0 - pulse) * 12.0,
			0.0,
			TAU,
			26,
			Color(1.0, 0.82, 0.52, 0.94 * pulse),
			5.0
		)

func _load_skill() -> void:
	# The coordinated runtime resolves Grab from the validated character/preview slot.
	pass

func _register_input() -> void:
	var action_name := StringName("skill_12")
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var can_cast := _can_start_cast() if host != null else false
	JavaScriptBridge.eval(
		"document.documentElement.dataset.grabSkillLoaded='%s';" % _bool_text(skill.loaded) +
		"document.documentElement.dataset.grabSkillId=%s;" % JSON.stringify(skill.skill_id) +
		"document.documentElement.dataset.grabSkillPhase=%s;" % JSON.stringify(cast_state.phase_name()) +
		"document.documentElement.dataset.grabSkillCooldown='%.3f';" % cast_state.cooldown_remaining +
		"document.documentElement.dataset.grabSkillCanCast='%s';" % _bool_text(can_cast) +
		"document.documentElement.dataset.grabSkillActive='%s';" % _bool_text(grab_state.active) +
		"document.documentElement.dataset.grabSkillRemaining='%.3f';" % grab_state.remaining +
		"document.documentElement.dataset.grabSkillCaptured='%s';" % _bool_text(grab_state.captured) +
		"document.documentElement.dataset.grabSkillActivationCount='%d';" % grab_state.activation_count +
		"document.documentElement.dataset.grabSkillCaptureCount='%d';" % grab_state.capture_count +
		"document.documentElement.dataset.grabSkillSourceCenterX='%.2f';" % grab_state.last_source_center.x +
		"document.documentElement.dataset.grabSkillTargetStartX='%.2f';" % grab_state.last_target_start.x +
		"document.documentElement.dataset.grabSkillTargetDestinationX='%.2f';" % grab_state.last_target_destination.x +
		"document.documentElement.dataset.grabSkillTargetDestinationDepth='%.3f';" % grab_state.last_target_destination.y +
		"document.documentElement.dataset.lastGrabSkillSuccess='%s';" % _bool_text(last_grab_success) +
		"document.documentElement.dataset.lastGrabSkillHit='%s';" % _bool_text(last_grab_hit)
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
