extends Control

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const AuraAttackState = preload("res://game/core/skills/aura_attack_state.gd")

var host
var skill := SkillDefinition.new()
var cast_state := SkillCastState.new()
var aura_state := AuraAttackState.new()
var skill_latched := false
var last_hit := false
var hit_count := 0
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
	status_label.position = Vector2(50.0, 500.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("bbff9c"))
	status_label.visible = skill.loaded
	add_child(status_label)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	if host == null:
		return

	cast_state.tick(delta)
	if cast_state.consume_activation():
		_activate_aura()

	if aura_state.active:
		aura_state.follow(Vector2(host.player_x, host.player_depth))
		_resolve_collision()
	aura_state.tick(delta)

	impact_timer = maxf(0.0, impact_timer - maxf(0.0, delta))
	_handle_input()

	if status_label != null:
		status_label.visible = skill.loaded
		if skill.loaded:
			status_label.text = "[G] %s    Phase: %s    Aura: %s    Cooldown: %.2fs" % [
				skill.skill_name,
				cast_state.phase_name(),
				("ACTIVE %.1fs" % aura_state.remaining) if aura_state.active else "READY",
				cast_state.cooldown_remaining
			]

	web_sync_accumulator += maxf(0.0, delta)
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("skill_9")
	if pressed and not skill_latched and _can_start_cast():
		_try_cast()
	skill_latched = pressed

func _can_start_cast() -> bool:
	if not skill.loaded or host == null or cast_state.is_casting() or aura_state.active:
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
	last_hit = false
	_set_web_state()

func _activate_aura() -> void:
	if not skill.loaded or skill.skill_type != "aura":
		return
	aura_state.start(
		Vector2(host.player_x, host.player_depth),
		skill.hitbox_half_width,
		skill.hitbox_half_depth,
		skill.aura_duration
	)
	_set_web_state()

func _resolve_collision() -> void:
	if not aura_state.can_hit():
		return
	if host.dummy_state.is_defeated() or not host.dummy_recovery_state.can_be_hit():
		return
	if not aura_state.hitbox().overlaps(host._dummy_hurtbox()):
		return
	if not aura_state.consume_hit():
		return

	host.dummy_state.apply_damage(skill.damage)
	host.dummy_state.apply_hitstun(skill.hitstun)
	var direction := signf(host.dummy_x - host.player_x)
	if is_zero_approx(direction):
		direction = host.player_facing
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
	if not aura_state.active and cast_state.phase_name() != "STARTUP":
		return

	var canvas_height := maxf(size.y, 720.0)
	var arena_top := canvas_height * 0.50
	var arena_bottom := canvas_height * 0.86
	var depth_radius := maxf(18.0, (arena_bottom - arena_top) * skill.hitbox_half_depth)
	var center := Vector2(host.player_x, lerpf(arena_top, arena_bottom, host.player_depth))
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.010)
	var width := skill.hitbox_half_width + pulse * 7.0
	var fill_alpha := 0.12 if aura_state.active else 0.06
	_draw_ellipse(
		center,
		Vector2(width, depth_radius),
		Color(0.42, 1.0, 0.42, fill_alpha),
		Color(0.65, 1.0, 0.54, 0.82),
		4.0
	)

	if impact_timer > 0.0:
		var impact_center := Vector2(impact_x, lerpf(arena_top, arena_bottom, host.dummy_depth) - 62.0)
		var progress := clampf(impact_timer / 0.36, 0.0, 1.0)
		var radius := 28.0 + (1.0 - progress) * 50.0
		draw_circle(impact_center, radius * 0.42, Color(0.32, 1.0, 0.28, 0.15 * progress))
		draw_arc(impact_center, radius, 0.0, TAU, 28, Color(0.68, 1.0, 0.58, progress), 5.0)

func _draw_ellipse(center: Vector2, radii: Vector2, fill: Color, outline: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(41):
		var angle := TAU * float(index) / 40.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, fill)
	for index in range(points.size() - 1):
		draw_line(points[index], points[index + 1], outline, width)

func _load_skill() -> void:
	# The coordinated runtime resolves Aura from the validated character/preview slot.
	# This base implementation intentionally has no hidden sample-path fallback.
	pass

func _register_input() -> void:
	var action_name := StringName("skill_9")
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_G
	InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var can_cast := _can_start_cast() if host != null else false
	JavaScriptBridge.eval(
		"document.documentElement.dataset.auraSkillLoaded='%s';" % _bool_text(skill.loaded) +
		"document.documentElement.dataset.auraSkillId=%s;" % JSON.stringify(skill.skill_id) +
		"document.documentElement.dataset.auraSkillPhase=%s;" % JSON.stringify(cast_state.phase_name()) +
		"document.documentElement.dataset.auraSkillCooldown='%.3f';" % cast_state.cooldown_remaining +
		"document.documentElement.dataset.auraSkillCanCast='%s';" % _bool_text(can_cast) +
		"document.documentElement.dataset.auraSkillActive='%s';" % _bool_text(aura_state.active) +
		"document.documentElement.dataset.auraSkillRemaining='%.3f';" % aura_state.remaining +
		"document.documentElement.dataset.auraSkillHitConsumed='%s';" % _bool_text(aura_state.hit_consumed) +
		"document.documentElement.dataset.auraSkillHitCount='%d';" % hit_count +
		"document.documentElement.dataset.auraSkillActivationCount='%d';" % aura_state.activation_count +
		"document.documentElement.dataset.lastAuraSkillHit='%s';" % _bool_text(last_hit) +
		"document.documentElement.dataset.auraSkillCenterX='%.2f';" % aura_state.center.x
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
