extends Control

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const SummonState = preload("res://game/core/skills/summon_state.gd")

var host
var skill := SkillDefinition.new()
var cast_state := SkillCastState.new()
var summon_state := SummonState.new()
var skill_latched := false
var last_summon_success := false
var last_summon_hit := false
var impact_timer := 0.0
var web_sync_accumulator := 0.0
var status_label: Label

func _ready() -> void:
	host = get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_input()
	_load_skill()
	status_label = Label.new()
	status_label.position = Vector2(50.0, 602.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("d8c7ff"))
	status_label.visible = skill.loaded
	add_child(status_label)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	if host == null:
		return
	cast_state.tick(delta)
	if cast_state.consume_activation():
		_spawn_summon()
	if summon_state.active:
		_tick_summon(delta)
	impact_timer = maxf(0.0, impact_timer - maxf(0.0, delta))
	_handle_input()
	if status_label != null:
		status_label.visible = skill.loaded
		if skill.loaded:
			status_label.text = "[Q] %s    Phase: %s    Actor: %.2fs    Cooldown: %.2fs" % [
				skill.skill_name,
				cast_state.phase_name(),
				summon_state.remaining,
				cast_state.cooldown_remaining
			]
	web_sync_accumulator += maxf(0.0, delta)
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("skill_13")
	if pressed and not skill_latched and _can_start_cast():
		_try_cast()
	skill_latched = pressed

func _can_start_cast() -> bool:
	if not skill.loaded or host == null or cast_state.is_casting() or summon_state.active:
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
	last_summon_success = false
	last_summon_hit = false
	_set_web_state()

func _spawn_summon() -> void:
	if not skill.loaded or skill.skill_type != "summon":
		return
	var arena_left := float(host.arena_left_x()) if host.has_method("arena_left_x") else 90.0
	var arena_right := float(host.arena_right_x()) if host.has_method("arena_right_x") else maxf(host.size.x, 1280.0) - 90.0
	last_summon_success = summon_state.start(
		Vector2(host.player_x, host.player_depth),
		host.player_facing,
		skill.range,
		skill.active,
		arena_left,
		arena_right
	)
	last_summon_hit = false
	_set_web_state()
	queue_redraw()

func _tick_summon(delta: float) -> void:
	var arena_left := float(host.arena_left_x()) if host.has_method("arena_left_x") else 90.0
	var arena_right := float(host.arena_right_x()) if host.has_method("arena_right_x") else maxf(host.size.x, 1280.0) - 90.0
	var hurtbox = host._dummy_hurtbox()
	var target_eligible: bool = not host.dummy_state.is_defeated() and host.dummy_recovery_state.can_be_hit()
	var hit := summon_state.tick(
		delta,
		Vector2(host.dummy_x, host.dummy_depth),
		hurtbox.half_extents,
		target_eligible,
		skill.speed,
		skill.hitbox_half_width,
		skill.hitbox_half_depth,
		arena_left,
		arena_right
	)
	if not hit:
		return
	host.dummy_state.apply_damage(skill.damage)
	host.dummy_state.apply_hitstun(skill.hitstun)
	host.dummy_hit_timer = skill.hitstun
	last_summon_hit = true
	impact_timer = 0.30
	_set_web_state()

func _draw() -> void:
	if host == null or not skill.loaded:
		return
	var canvas_height := maxf(size.y, 720.0)
	var arena_top := canvas_height * 0.50
	var arena_bottom := canvas_height * 0.86
	if summon_state.active:
		var actor_center := Vector2(
			summon_state.position.x,
			lerpf(arena_top, arena_bottom, summon_state.position.y) - 48.0
		)
		draw_circle(actor_center, 24.0, Color(0.55, 0.40, 0.95, 0.22))
		draw_arc(actor_center, 30.0, 0.0, TAU, 24, Color(0.78, 0.68, 1.0, 0.92), 4.0)
		draw_line(actor_center, actor_center + Vector2(summon_state.last_move_direction * 26.0, 0.0), Color(0.95, 0.88, 1.0, 0.90), 4.0)
	if impact_timer > 0.0:
		var pulse := clampf(impact_timer / 0.30, 0.0, 1.0)
		var target_center := Vector2(
			host.dummy_x,
			lerpf(arena_top, arena_bottom, host.dummy_depth) - 58.0
		)
		draw_arc(target_center, 34.0 + (1.0 - pulse) * 20.0, 0.0, TAU, 24, Color(0.82, 0.68, 1.0, 0.92 * pulse), 5.0)

func _load_skill() -> void:
	pass

func _register_input() -> void:
	var action_name := StringName("skill_13")
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var can_cast := _can_start_cast() if host != null else false
	JavaScriptBridge.eval(
		"document.documentElement.dataset.summonSkillLoaded='%s';" % _bool_text(skill.loaded) +
		"document.documentElement.dataset.summonSkillId=%s;" % JSON.stringify(skill.skill_id) +
		"document.documentElement.dataset.summonSkillPhase=%s;" % JSON.stringify(cast_state.phase_name()) +
		"document.documentElement.dataset.summonSkillCooldown='%.3f';" % cast_state.cooldown_remaining +
		"document.documentElement.dataset.summonSkillCanCast='%s';" % _bool_text(can_cast) +
		"document.documentElement.dataset.summonSkillActive='%s';" % _bool_text(summon_state.active) +
		"document.documentElement.dataset.summonSkillRemaining='%.3f';" % summon_state.remaining +
		"document.documentElement.dataset.summonSkillHitConsumed='%s';" % _bool_text(summon_state.hit_consumed) +
		"document.documentElement.dataset.summonSkillActivationCount='%d';" % summon_state.activation_count +
		"document.documentElement.dataset.summonSkillHitCount='%d';" % summon_state.hit_count +
		"document.documentElement.dataset.summonSkillSpawnX='%.2f';" % summon_state.spawn_position.x +
		"document.documentElement.dataset.summonSkillSpawnDepth='%.3f';" % summon_state.spawn_position.y +
		"document.documentElement.dataset.summonSkillPositionX='%.2f';" % summon_state.position.x +
		"document.documentElement.dataset.summonSkillPositionDepth='%.3f';" % summon_state.position.y +
		"document.documentElement.dataset.summonSkillTargetX='%.2f';" % summon_state.last_target_position.x +
		"document.documentElement.dataset.summonSkillTargetDepth='%.3f';" % summon_state.last_target_position.y +
		"document.documentElement.dataset.lastSummonSkillSuccess='%s';" % _bool_text(last_summon_success) +
		"document.documentElement.dataset.lastSummonSkillHit='%s';" % _bool_text(last_summon_hit)
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
