extends Control

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const CounterState = preload("res://game/core/skills/counter_state.gd")
const CombatBox = preload("res://game/core/combat/combat_box.gd")

var host
var skill := SkillDefinition.new()
var cast_state := SkillCastState.new()
var counter_state := CounterState.new()
var skill_latched := false
var last_counter_success := false
var last_retaliation_hit := false
var retaliation_hit_count := 0
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
	status_label.position = Vector2(50.0, 552.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("ffb5e8"))
	status_label.visible = skill.loaded
	add_child(status_label)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	if host == null:
		return

	cast_state.tick(delta)
	if cast_state.consume_activation():
		_open_counter_window()
	counter_state.tick(delta)

	impact_timer = maxf(0.0, impact_timer - maxf(0.0, delta))
	_handle_input()

	if status_label != null:
		status_label.visible = skill.loaded
		if skill.loaded:
			status_label.text = "[F] %s    Phase: %s    Window: %.2fs    Cooldown: %.2fs" % [
				skill.skill_name,
				cast_state.phase_name(),
				counter_state.remaining,
				cast_state.cooldown_remaining
			]

	web_sync_accumulator += maxf(0.0, delta)
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_input() -> void:
	var pressed := Input.is_action_pressed("skill_11")
	if pressed and not skill_latched and _can_start_cast():
		_try_cast()
	skill_latched = pressed

func _can_start_cast() -> bool:
	if not skill.loaded or host == null or cast_state.is_casting() or counter_state.active:
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
	last_counter_success = false
	last_retaliation_hit = false
	_set_web_state()

func _open_counter_window() -> void:
	if not skill.loaded or skill.skill_type != "counter":
		return
	counter_state.start(skill.active)
	_set_web_state()

func try_counter_incoming_hit(source_x: float, source_depth: float) -> bool:
	if host == null or not skill.loaded or skill.skill_type != "counter":
		return false
	var source := Vector2(source_x, source_depth)
	var player_position := Vector2(host.player_x, host.player_depth)
	if not counter_state.intercept(player_position, source, skill.range, skill.hitbox_half_depth):
		return false

	last_counter_success = true
	last_retaliation_hit = false
	_resolve_training_retaliation(source)
	_set_web_state()
	queue_redraw()
	return true

func _resolve_training_retaliation(source: Vector2) -> void:
	if host.dummy_state.is_defeated() or not host.dummy_recovery_state.can_be_hit():
		return
	var source_probe := CombatBox.new(source, Vector2(1.0, 0.005))
	if not source_probe.overlaps(host._dummy_hurtbox()):
		return

	host.dummy_state.apply_damage(skill.damage)
	host.dummy_state.apply_hitstun(skill.hitstun)
	var direction := signf(host.dummy_x - host.player_x)
	if is_zero_approx(direction):
		direction = host.player_facing
	host.dummy_knockback_state.apply_impulse(direction * skill.knockback)
	host.dummy_hit_timer = skill.hitstun
	impact_timer = 0.34
	impact_x = host.dummy_x
	last_retaliation_hit = true
	retaliation_hit_count += 1

func _draw() -> void:
	if host == null or not skill.loaded:
		return
	var canvas_height := maxf(size.y, 720.0)
	var arena_top := canvas_height * 0.50
	var arena_bottom := canvas_height * 0.86
	var player_center := Vector2(host.player_x, lerpf(arena_top, arena_bottom, host.player_depth) - 70.0)

	if cast_state.phase_name() == "STARTUP":
		draw_arc(player_center, 46.0, 0.0, TAU, 28, Color(1.0, 0.55, 0.86, 0.42), 4.0)

	if counter_state.active:
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.020)
		var radius := 48.0 + pulse * 8.0
		draw_circle(player_center, radius * 0.76, Color(1.0, 0.35, 0.75, 0.08))
		draw_arc(player_center, radius, 0.0, TAU, 30, Color(1.0, 0.62, 0.88, 0.92), 6.0)

	if impact_timer > 0.0:
		var impact_center := Vector2(impact_x, lerpf(arena_top, arena_bottom, host.dummy_depth) - 66.0)
		var progress := clampf(impact_timer / 0.34, 0.0, 1.0)
		var radius := 26.0 + (1.0 - progress) * 48.0
		draw_circle(impact_center, radius * 0.32, Color(1.0, 0.40, 0.78, 0.16 * progress))
		draw_arc(impact_center, radius, 0.0, TAU, 24, Color(1.0, 0.72, 0.92, progress), 5.0)

func _load_skill() -> void:
	# The coordinated runtime resolves Counter from the validated character/preview slot.
	pass

func _register_input() -> void:
	var action_name := StringName("skill_11")
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var can_cast := _can_start_cast() if host != null else false
	JavaScriptBridge.eval(
		"document.documentElement.dataset.counterSkillLoaded='%s';" % _bool_text(skill.loaded) +
		"document.documentElement.dataset.counterSkillId=%s;" % JSON.stringify(skill.skill_id) +
		"document.documentElement.dataset.counterSkillPhase=%s;" % JSON.stringify(cast_state.phase_name()) +
		"document.documentElement.dataset.counterSkillCooldown='%.3f';" % cast_state.cooldown_remaining +
		"document.documentElement.dataset.counterSkillCanCast='%s';" % _bool_text(can_cast) +
		"document.documentElement.dataset.counterSkillWindowActive='%s';" % _bool_text(counter_state.active) +
		"document.documentElement.dataset.counterSkillWindowRemaining='%.3f';" % counter_state.remaining +
		"document.documentElement.dataset.counterSkillTriggered='%s';" % _bool_text(counter_state.triggered) +
		"document.documentElement.dataset.counterSkillActivationCount='%d';" % counter_state.activation_count +
		"document.documentElement.dataset.counterSkillTriggerCount='%d';" % counter_state.trigger_count +
		"document.documentElement.dataset.counterSkillRetaliationHitCount='%d';" % retaliation_hit_count +
		"document.documentElement.dataset.lastCounterSkillSuccess='%s';" % _bool_text(last_counter_success) +
		"document.documentElement.dataset.lastCounterSkillHit='%s';" % _bool_text(last_retaliation_hit)
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"
