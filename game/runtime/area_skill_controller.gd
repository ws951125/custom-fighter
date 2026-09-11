extends Control

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const AreaAttackState = preload("res://game/core/skills/area_attack_state.gd")

const AREA_SKILL_PATH := "res://content/skills/arc_burst.sample.json"

var host
var skill := SkillDefinition.new()
var cast_state := SkillCastState.new()
var area_state := AreaAttackState.new()
var skill_latched := false
var last_hit := false
var hit_count := 0
var impact_timer := 0.0
var impact_x := 0.0
var cast_origin := Vector2.ZERO
var web_sync_accumulator := 0.0
var status_label: Label

func _ready() -> void:
	host = get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_input()
	_load_skill()
	status_label = Label.new()
	status_label.position = Vector2(50.0, 340.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("e9d7ff"))
	add_child(status_label)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	cast_state.tick(delta)
	if cast_state.consume_activation():
		_start_area()

	area_state.tick(delta)
	if area_state.can_hit():
		_resolve_collision()

	impact_timer = maxf(0.0, impact_timer - delta)
	_handle_input()

	var skill_name := skill.skill_name if skill.loaded else "Skill unavailable"
	status_label.text = "[O] %s    Phase: %s    Cooldown: %.2fs" % [
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
	var pressed := Input.is_action_pressed("skill_3")
	if pressed and not skill_latched and _can_start_cast():
		_try_cast()
	skill_latched = pressed

func _can_start_cast() -> bool:
	if not skill.loaded or cast_state.is_casting():
		return false
	if host == null:
		return false
	return (
		not host.player_guarding
		and not host.movement_state.jumping
		and not host.movement_state.is_dashing()
		and not host.attack_chain_state.is_attacking()
		and not host.fireball_cast_state.is_casting()
		and not host.dash_slash_cast_state.is_casting()
		and not host.dash_slash_state.active
	)

func _try_cast() -> void:
	if not cast_state.start_cast(host.player_state.mp):
		return
	if not host.player_state.spend_mp(skill.mp_cost):
		return
	cast_origin = Vector2(host.player_x, host.player_depth)
	last_hit = false
	_set_web_state()

func _start_area() -> void:
	if not skill.loaded or skill.skill_type != "area":
		return
	area_state.start(
		cast_origin,
		skill.hitbox_half_width,
		skill.hitbox_half_depth,
		skill.active
	)
	_set_web_state()

func _resolve_collision() -> void:
	if host.dummy_state.is_defeated() or not host.dummy_recovery_state.can_be_hit():
		return
	if not area_state.hitbox().overlaps(host._dummy_hurtbox()):
		return
	if not area_state.consume_hit():
		return

	host.dummy_state.apply_damage(skill.damage)
	host.dummy_state.apply_hitstun(skill.hitstun)
	var direction := signf(host.dummy_x - area_state.center.x)
	if is_zero_approx(direction):
		direction = host.player_facing
	host.dummy_knockback_state.apply_impulse(direction * skill.knockback)
	host.dummy_hit_timer = skill.hitstun
	impact_timer = 0.38
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
	var depth_radius := maxf(18.0, (arena_bottom - arena_top) * skill.hitbox_half_depth)

	if cast_state.phase_name() == "STARTUP":
		var telegraph_center := Vector2(cast_origin.x, lerpf(arena_top, arena_bottom, cast_origin.y))
		_draw_ellipse(telegraph_center, Vector2(skill.hitbox_half_width, depth_radius), Color(0.72, 0.48, 1.0, 0.10), Color(0.82, 0.66, 1.0, 0.72), 3.0)
		draw_circle(telegraph_center, 10.0, Color("e9d7ff"))

	if area_state.active:
		var active_center := Vector2(area_state.center.x, lerpf(arena_top, arena_bottom, area_state.center.y))
		_draw_ellipse(active_center, Vector2(skill.hitbox_half_width, depth_radius), Color(0.62, 0.28, 1.0, 0.16), Color(0.87, 0.66, 1.0, 0.95), 6.0)
		for index in range(4):
			var ray_angle := float(index) * PI * 0.5 + 0.35
			var ray := Vector2(cos(ray_angle) * skill.hitbox_half_width * 0.82, sin(ray_angle) * depth_radius * 0.82)
			draw_line(active_center - ray * 0.30, active_center + ray, Color(0.82, 0.60, 1.0, 0.70), 4.0)

	if impact_timer > 0.0:
		var impact_center := Vector2(impact_x, lerpf(arena_top, arena_bottom, host.dummy_depth) - 68.0)
		var progress := clampf(impact_timer / 0.38, 0.0, 1.0)
		var radius := 34.0 + (1.0 - progress) * 52.0
		draw_circle(impact_center, radius * 0.45, Color(0.70, 0.40, 1.0, 0.14 * progress))
		draw_arc(impact_center, radius, 0.0, TAU, 30, Color(0.88, 0.70, 1.0, progress), 5.0)

func _draw_ellipse(center: Vector2, radii: Vector2, fill: Color, outline: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(41):
		var angle := TAU * float(index) / 40.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, fill)
	for index in range(points.size() - 1):
		draw_line(points[index], points[index + 1], outline, width)

func _load_skill() -> void:
	var errors := skill.load_from_file(AREA_SKILL_PATH)
	if not errors.is_empty():
		push_error("Failed to load area skill: %s" % " | ".join(errors))
		return
	cast_state.configure(skill)

func _register_input() -> void:
	var action_name := StringName("skill_3")
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_O
	InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.areaSkillLoaded='%s';" % _bool_text(skill.loaded) +
		"document.documentElement.dataset.areaSkillId='%s';" % skill.skill_id +
		"document.documentElement.dataset.areaSkillPhase='%s';" % cast_state.phase_name() +
		"document.documentElement.dataset.areaSkillCooldown='%.3f';" % cast_state.cooldown_remaining +
		"document.documentElement.dataset.areaSkillCanCast='%s';" % _bool_text(skill.loaded and cast_state.can_cast(host.player_state.mp if host != null else 0)) +
		"document.documentElement.dataset.areaSkillActive='%s';" % _bool_text(area_state.active) +
		"document.documentElement.dataset.lastAreaSkillHit='%s';" % _bool_text(last_hit) +
		"document.documentElement.dataset.areaSkillHitCount='%d';" % hit_count
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
