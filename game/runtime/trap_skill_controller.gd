extends Control

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const TrapAttackState = preload("res://game/core/skills/trap_attack_state.gd")

var host
var skill := SkillDefinition.new()
var cast_state := SkillCastState.new()
var trap_state := TrapAttackState.new()
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
	status_label.position = Vector2(50.0, 480.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("ffc86b"))
	status_label.visible = skill.loaded
	add_child(status_label)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	if host == null:
		return

	cast_state.tick(delta)
	if cast_state.consume_activation():
		_place_trap()

	trap_state.tick(delta)
	if trap_state.can_trigger():
		_resolve_collision()

	impact_timer = maxf(0.0, impact_timer - maxf(0.0, delta))
	_handle_input()

	if status_label != null:
		status_label.visible = skill.loaded
		if skill.loaded:
			status_label.text = "[T] %s    Phase: %s    Trap: %s    Cooldown: %.2fs" % [
				skill.skill_name,
				cast_state.phase_name(),
				("ARMED %.1fs" % trap_state.remaining) if trap_state.active else "READY",
				cast_state.cooldown_remaining
			]

	web_sync_accumulator += maxf(0.0, delta)
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("skill_8")
	if pressed and not skill_latched and _can_start_cast():
		_try_cast()
	skill_latched = pressed

func _can_start_cast() -> bool:
	if not skill.loaded or host == null or cast_state.is_casting() or trap_state.active:
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
	cast_origin = Vector2(host.player_x, host.player_depth)
	cast_facing = host.player_facing
	last_hit = false
	_set_web_state()

func _place_trap() -> void:
	if not skill.loaded or skill.skill_type != "trap":
		return
	var canvas_width := maxf(size.x, 1280.0)
	var trap_x := clampf(cast_origin.x + cast_facing * skill.range, 90.0, canvas_width - 90.0)
	trap_state.place(
		Vector2(trap_x, clampf(cast_origin.y, 0.0, 1.0)),
		skill.hitbox_half_width,
		skill.hitbox_half_depth,
		skill.trap_duration
	)
	_set_web_state()

func _resolve_collision() -> void:
	if host.dummy_state.is_defeated() or not host.dummy_recovery_state.can_be_hit():
		return
	if not trap_state.hitbox().overlaps(host._dummy_hurtbox()):
		return
	if not trap_state.trigger():
		return

	host.dummy_state.apply_damage(skill.damage)
	host.dummy_state.apply_hitstun(skill.hitstun)
	var direction := signf(host.dummy_x - trap_state.center.x)
	if is_zero_approx(direction):
		direction = cast_facing
	host.dummy_knockback_state.apply_impulse(direction * skill.knockback)
	host.dummy_hit_timer = skill.hitstun
	impact_timer = 0.36
	impact_x = host.dummy_x
	last_hit = true
	hit_count += 1
	_set_web_state()

func _draw() -> void:
	if host == null or not skill.loaded:
		return
	var canvas_height := maxf(size.y, 720.0)
	var canvas_width := maxf(size.x, 1280.0)
	var arena_top := canvas_height * 0.50
	var arena_bottom := canvas_height * 0.86
	var depth_radius := maxf(16.0, (arena_bottom - arena_top) * skill.hitbox_half_depth)

	if cast_state.phase_name() == "STARTUP":
		var preview_x := clampf(cast_origin.x + cast_facing * skill.range, 90.0, canvas_width - 90.0)
		var preview_center := Vector2(preview_x, lerpf(arena_top, arena_bottom, cast_origin.y))
		_draw_ellipse(preview_center, Vector2(skill.hitbox_half_width, depth_radius), Color(1.0, 0.65, 0.22, 0.08), Color(1.0, 0.78, 0.40, 0.72), 3.0)
		draw_circle(preview_center, 8.0, Color("ffe3a3"))

	if trap_state.active:
		var trap_center := Vector2(trap_state.center.x, lerpf(arena_top, arena_bottom, trap_state.center.y))
		_draw_ellipse(trap_center, Vector2(skill.hitbox_half_width, depth_radius), Color(1.0, 0.48, 0.08, 0.12), Color(1.0, 0.72, 0.26, 0.95), 4.0)
		draw_circle(trap_center, 12.0, Color("ffcf70"))
		draw_arc(trap_center, 22.0, 0.0, TAU, 20, Color("fff1bd"), 3.0)

	if impact_timer > 0.0:
		var impact_center := Vector2(impact_x, lerpf(arena_top, arena_bottom, host.dummy_depth) - 62.0)
		var progress := clampf(impact_timer / 0.36, 0.0, 1.0)
		var radius := 30.0 + (1.0 - progress) * 58.0
		draw_circle(impact_center, radius * 0.42, Color(1.0, 0.45, 0.08, 0.16 * progress))
		draw_arc(impact_center, radius, 0.0, TAU, 28, Color(1.0, 0.80, 0.32, progress), 5.0)

func _draw_ellipse(center: Vector2, radii: Vector2, fill: Color, outline: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(41):
		var angle := TAU * float(index) / 40.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, fill)
	for index in range(points.size() - 1):
		draw_line(points[index], points[index + 1], outline, width)

func _load_skill() -> void:
	# The coordinated runtime resolves Trap from the validated character/preview slot.
	# This base implementation intentionally has no hidden sample-path fallback.
	pass

func _register_input() -> void:
	var action_name := StringName("skill_8")
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_T
	InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var can_cast := _can_start_cast() if host != null else false
	JavaScriptBridge.eval(
		"document.documentElement.dataset.trapSkillLoaded='%s';" % _bool_text(skill.loaded) +
		"document.documentElement.dataset.trapSkillId=%s;" % JSON.stringify(skill.skill_id) +
		"document.documentElement.dataset.trapSkillPhase=%s;" % JSON.stringify(cast_state.phase_name()) +
		"document.documentElement.dataset.trapSkillCooldown='%.3f';" % cast_state.cooldown_remaining +
		"document.documentElement.dataset.trapSkillCanCast='%s';" % _bool_text(can_cast) +
		"document.documentElement.dataset.trapSkillActive='%s';" % _bool_text(trap_state.active) +
		"document.documentElement.dataset.trapSkillTriggered='%s';" % _bool_text(trap_state.triggered) +
		"document.documentElement.dataset.trapSkillExpired='%s';" % _bool_text(trap_state.expired) +
		"document.documentElement.dataset.trapSkillRemaining='%.3f';" % trap_state.remaining +
		"document.documentElement.dataset.trapSkillHitCount='%d';" % hit_count +
		"document.documentElement.dataset.lastTrapSkillHit='%s';" % _bool_text(last_hit) +
		"document.documentElement.dataset.trapSkillCenterX='%.2f';" % trap_state.center.x
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
