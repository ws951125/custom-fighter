extends Control

const CombatantState = preload("res://game/core/combat/combatant_state.gd")
const MovementState = preload("res://game/core/movement/movement_state.gd")
const CombatBox = preload("res://game/core/combat/combat_box.gd")
const AttackChainState = preload("res://game/core/combat/attack_chain_state.gd")
const KnockbackState = preload("res://game/core/combat/knockback_state.gd")

const MOVE_SPEED := 360.0
const DEPTH_SPEED := 0.72
const RUN_MULTIPLIER := 1.60
const GUARD_MOVE_MULTIPLIER := 0.35
const DUMMY_HURTBOX_HALF_WIDTH := 30.0
const DUMMY_HURTBOX_HALF_DEPTH := 0.11

var player_x := 280.0
var player_depth := 0.58
var player_facing := 1.0
var dummy_x := 860.0
var dummy_depth := 0.58

var attack_visual_timer := 0.0
var attack_latched := false
var jump_latched := false
var dash_latched := false
var player_guarding := false
var player_running := false
var dummy_hit_timer := 0.0
var web_sync_accumulator := 0.0
var last_attack_step := 0
var last_attack_hit := false

var dummy_state := CombatantState.new(100, 0)
var movement_state := MovementState.new()
var attack_chain_state := AttackChainState.new()
var dummy_knockback_state := KnockbackState.new()
var status_label: Label

func _ready() -> void:
	_ensure_input_actions()
	_create_label("CUSTOM FIGHTER", Vector2(48, 28), 34)
	_create_label("Milestone 1 · Combo / Hitbox / Knockback", Vector2(50, 72), 20)
	_create_label("Move: WASD / Arrows   Run: Shift   Jump: Space   Attack: J   Dash: K   Guard: L", Vector2(50, 108), 16)
	_create_label("Training goal: approach the dummy and press J three times for the full combo", Vector2(50, 138), 15)
	status_label = _create_label("", Vector2(50, 174), 17)

	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	_handle_action_edges()
	movement_state.tick(delta)
	attack_chain_state.tick(delta)

	dummy_x += dummy_knockback_state.tick(delta)
	dummy_x = clampf(dummy_x, 90.0, maxf(size.x, 1280.0) - 90.0)

	var move_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if move_vector.length_squared() > 1.0:
		move_vector = move_vector.normalized()

	player_guarding = Input.is_action_pressed("guard") and not movement_state.is_dashing()
	player_running = (
		Input.is_action_pressed("run")
		and move_vector.length_squared() > 0.01
		and not player_guarding
		and not movement_state.is_dashing()
		and not attack_chain_state.is_attacking()
	)

	if movement_state.is_dashing():
		player_x += movement_state.dash_velocity() * delta
	else:
		var speed_multiplier := RUN_MULTIPLIER if player_running else 1.0
		if player_guarding:
			speed_multiplier *= GUARD_MOVE_MULTIPLIER
		if attack_chain_state.is_attacking():
			speed_multiplier *= 0.30
		player_x += move_vector.x * MOVE_SPEED * speed_multiplier * delta
		player_depth += move_vector.y * DEPTH_SPEED * speed_multiplier * delta

	player_x = clampf(player_x, 90.0, maxf(size.x, 1280.0) - 90.0)
	player_depth = clampf(player_depth, 0.0, 1.0)
	if absf(move_vector.x) > 0.01 and not movement_state.is_dashing():
		player_facing = signf(move_vector.x)

	var attacking := Input.is_action_pressed("attack")
	if attacking and not attack_latched and not player_guarding and not movement_state.is_dashing():
		_begin_attack()
	attack_latched = attacking

	attack_visual_timer = maxf(0.0, attack_visual_timer - delta)
	dummy_hit_timer = maxf(0.0, dummy_hit_timer - delta)
	dummy_state.tick(delta)

	status_label.text = "Dummy HP: %d / %d    Distance: %d    Combo: %d    State: %s" % [
		dummy_state.hp,
		dummy_state.max_hp,
		roundi(absf(dummy_x - player_x)),
		attack_chain_state.combo_step,
		_player_state_name()
	]

	web_sync_accumulator += delta
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_action_edges() -> void:
	var jump_pressed := Input.is_action_pressed("jump")
	if jump_pressed and not jump_latched:
		movement_state.start_jump()
		_set_web_state()
	jump_latched = jump_pressed

	var dash_pressed := Input.is_action_pressed("dash")
	if (
		dash_pressed
		and not dash_latched
		and not Input.is_action_pressed("guard")
		and not movement_state.jumping
		and not attack_chain_state.is_attacking()
	):
		movement_state.start_dash(player_facing)
		_set_web_state()
	dash_latched = dash_pressed

func _begin_attack() -> void:
	var step := attack_chain_state.try_start_attack()
	if step == 0:
		return

	last_attack_step = step
	last_attack_hit = false
	attack_visual_timer = attack_chain_state.visual_duration_for_step(step)

	var hitbox := _attack_hitbox(step)
	var hurtbox := _dummy_hurtbox()
	if hitbox.overlaps(hurtbox) and not dummy_state.is_defeated():
		dummy_state.apply_damage(attack_chain_state.damage_for_step(step))
		dummy_state.apply_hitstun(attack_chain_state.hitstun_for_step(step))
		dummy_knockback_state.apply_impulse(
			player_facing * attack_chain_state.knockback_for_step(step)
		)
		dummy_hit_timer = attack_chain_state.hitstun_for_step(step)
		last_attack_hit = true

	_set_web_state()

func _attack_hitbox(step: int) -> CombatBox:
	return CombatBox.new(
		Vector2(
			player_x + player_facing * attack_chain_state.hitbox_offset_for_step(step),
			player_depth
		),
		Vector2(
			attack_chain_state.hitbox_half_width_for_step(step),
			attack_chain_state.hitbox_half_depth_for_step(step)
		)
	)

func _dummy_hurtbox() -> CombatBox:
	return CombatBox.new(
		Vector2(dummy_x, dummy_depth),
		Vector2(DUMMY_HURTBOX_HALF_WIDTH, DUMMY_HURTBOX_HALF_DEPTH)
	)

func _draw() -> void:
	var canvas_width := maxf(size.x, 1280.0)
	var canvas_height := maxf(size.y, 720.0)
	var arena_top := canvas_height * 0.50
	var arena_bottom := canvas_height * 0.86

	draw_rect(Rect2(0.0, 0.0, canvas_width, canvas_height), Color("101522"))
	draw_circle(Vector2(canvas_width * 0.80, canvas_height * 0.18), 78.0, Color("27324d"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, arena_top - 48.0),
		Vector2(canvas_width, arena_top - 48.0),
		Vector2(canvas_width, arena_bottom + 70.0),
		Vector2(0.0, arena_bottom + 70.0)
	]), Color("182036"))

	for lane in range(5):
		var lane_y := lerpf(arena_top, arena_bottom, float(lane) / 4.0)
		draw_line(Vector2(0.0, lane_y), Vector2(canvas_width, lane_y), Color(0.32, 0.39, 0.55, 0.22), 2.0)

	var player_ground_feet := Vector2(player_x, lerpf(arena_top, arena_bottom, player_depth))
	var dummy_feet := Vector2(dummy_x, lerpf(arena_top, arena_bottom, dummy_depth))
	var jump_offset := movement_state.jump_offset()

	if movement_state.is_dashing():
		_draw_dash_lines(player_ground_feet)
	if dummy_knockback_state.is_active():
		_draw_dummy_knockback_lines(dummy_feet)

	if player_depth <= dummy_depth:
		_draw_fighter(player_ground_feet, Color("62d8ff"), player_facing, false, jump_offset, player_guarding)
		_draw_fighter(dummy_feet, _dummy_color(), -1.0, true)
	else:
		_draw_fighter(dummy_feet, _dummy_color(), -1.0, true)
		_draw_fighter(player_ground_feet, Color("62d8ff"), player_facing, false, jump_offset, player_guarding)

	_draw_health_bar(Vector2(50.0, 214.0), 320.0, dummy_state.hp, dummy_state.max_hp)
	_draw_combat_box(_dummy_hurtbox(), arena_top, arena_bottom, Color(1.0, 0.45, 0.52, 0.72))

	if attack_visual_timer > 0.0 and last_attack_step > 0:
		var active_hitbox := _attack_hitbox(last_attack_step)
		var box_color := Color(0.42, 1.0, 0.64, 0.82) if last_attack_hit else Color(0.35, 0.88, 1.0, 0.78)
		_draw_combat_box(active_hitbox, arena_top, arena_bottom, box_color)
		_draw_attack_effect(player_ground_feet, jump_offset)

func _draw_attack_effect(player_ground_feet: Vector2, jump_offset: float) -> void:
	var player_y := player_ground_feet.y - jump_offset
	var step_scale := 1.0 + float(maxi(0, last_attack_step - 1)) * 0.24
	var effect_center := Vector2(
		player_x + player_facing * (78.0 + float(last_attack_step) * 8.0),
		player_y - 82.0
	)
	var effect_color := Color("ffd166") if last_attack_step == 3 else Color("b8f3ff")
	var glow_color := Color(1.0, 0.72, 0.24, 0.22) if last_attack_step == 3 else Color(0.35, 0.88, 1.0, 0.20)

	draw_circle(effect_center, 30.0 * step_scale, glow_color)
	draw_arc(effect_center, 40.0 * step_scale, 0.0, TAU, 32, effect_color, 5.0 + float(last_attack_step))
	draw_line(
		Vector2(player_x + player_facing * 38.0, player_y - 68.0),
		Vector2(player_x + player_facing * (104.0 + float(last_attack_step) * 18.0), player_y - 92.0),
		effect_color,
		6.0 + float(last_attack_step)
	)
	if last_attack_step >= 2:
		draw_arc(effect_center, 54.0 * step_scale, -1.1, 1.1, 20, effect_color, 3.0)
	if last_attack_step == 3:
		draw_circle(effect_center, 12.0, Color("fff2b8"))

func _draw_combat_box(box: CombatBox, arena_top: float, arena_bottom: float, color: Color) -> void:
	var top_y := lerpf(arena_top, arena_bottom, clampf(box.top(), 0.0, 1.0))
	var bottom_y := lerpf(arena_top, arena_bottom, clampf(box.bottom(), 0.0, 1.0))
	var rect := Rect2(
		Vector2(box.left(), top_y),
		Vector2(box.right() - box.left(), maxf(4.0, bottom_y - top_y))
	)
	var fill_color := Color(color.r, color.g, color.b, 0.08)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, color, false, 2.0)

func _draw_health_bar(at: Vector2, width: float, current: int, maximum: int) -> void:
	var ratio := clampf(float(current) / float(maxi(1, maximum)), 0.0, 1.0)
	draw_rect(Rect2(at, Vector2(width, 18.0)), Color("30394f"))
	draw_rect(Rect2(at, Vector2(width * ratio, 18.0)), Color("ff6d78"))
	draw_rect(Rect2(at, Vector2(width, 18.0)), Color("e6edf8"), false, 2.0)

func _dummy_color() -> Color:
	if dummy_hit_timer > 0.0:
		return Color("fff0a8")
	if dummy_state.is_defeated():
		return Color("6f7484")
	return Color("ff7b83")

func _draw_fighter(
	ground_feet: Vector2,
	body_color: Color,
	facing: float,
	is_dummy: bool,
	vertical_offset: float = 0.0,
	guarding: bool = false
) -> void:
	var direction := 1.0 if facing >= 0.0 else -1.0
	var shadow_scale := clampf(0.75 + ((ground_feet.y / maxf(size.y, 720.0)) * 0.35), 0.78, 1.08)
	_draw_shadow_ellipse(ground_feet + Vector2(0.0, 4.0), Vector2(34.0, 10.0) * shadow_scale, Color(0.02, 0.03, 0.06, 0.45))

	var feet := ground_feet + Vector2(0.0, -vertical_offset)
	var head := feet + Vector2(0.0, -118.0)
	var torso_top := feet + Vector2(-18.0, -94.0)
	draw_circle(head, 22.0, body_color)
	draw_rect(Rect2(torso_top, Vector2(36.0, 70.0)), body_color)
	draw_line(feet + Vector2(-8.0, -30.0), feet + Vector2(-20.0, 0.0), body_color, 10.0)
	draw_line(feet + Vector2(8.0, -30.0), feet + Vector2(20.0, 0.0), body_color, 10.0)
	draw_line(feet + Vector2(direction * 15.0, -78.0), feet + Vector2(direction * 48.0, -62.0), body_color, 9.0)

	if is_dummy:
		draw_line(feet + Vector2(-38.0, -6.0), feet + Vector2(38.0, -6.0), Color("c5a46b"), 7.0)
		draw_line(feet + Vector2(0.0, -6.0), feet + Vector2(0.0, 18.0), Color("c5a46b"), 7.0)
	else:
		var weapon_start := feet + Vector2(direction * 44.0, -65.0)
		var weapon_end := feet + Vector2(direction * 82.0, -96.0)
		draw_line(weapon_start, weapon_end, Color("e9edf7"), 5.0)

	if guarding and not is_dummy:
		var shield_center := feet + Vector2(direction * 34.0, -70.0)
		var start_angle := -1.15 if direction > 0.0 else PI - 1.15
		draw_arc(shield_center, 52.0, start_angle, start_angle + 2.30, 24, Color("9cf5d4"), 7.0)

func _draw_dash_lines(ground_feet: Vector2) -> void:
	for index in range(3):
		var distance := 45.0 + float(index) * 34.0
		var alpha := 0.34 - float(index) * 0.08
		var y := ground_feet.y - 72.0 + float(index) * 24.0
		draw_line(
			Vector2(player_x - player_facing * distance, y),
			Vector2(player_x - player_facing * (distance + 58.0), y),
			Color(0.39, 0.85, 1.0, alpha),
			5.0
		)

func _draw_dummy_knockback_lines(dummy_feet: Vector2) -> void:
	var direction := signf(dummy_knockback_state.velocity)
	if is_zero_approx(direction):
		return
	for index in range(3):
		var y := dummy_feet.y - 80.0 + float(index) * 26.0
		draw_line(
			Vector2(dummy_x - direction * 38.0, y),
			Vector2(dummy_x - direction * (82.0 + float(index) * 16.0), y),
			Color(1.0, 0.82, 0.42, 0.42 - float(index) * 0.08),
			4.0
		)

func _draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _ensure_input_actions() -> void:
	_register_key_action("move_left", [KEY_A, KEY_LEFT])
	_register_key_action("move_right", [KEY_D, KEY_RIGHT])
	_register_key_action("move_up", [KEY_W, KEY_UP])
	_register_key_action("move_down", [KEY_S, KEY_DOWN])
	_register_key_action("run", [KEY_SHIFT])
	_register_key_action("jump", [KEY_SPACE])
	_register_key_action("attack", [KEY_J])
	_register_key_action("dash", [KEY_K])
	_register_key_action("guard", [KEY_L])

func _register_key_action(action_name: StringName, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)

func _player_state_name() -> String:
	if player_guarding:
		return "GUARD"
	if movement_state.is_dashing():
		return "DASH"
	if movement_state.jumping:
		return "JUMP"
	if attack_chain_state.is_attacking():
		return "ATTACK_%d" % attack_chain_state.combo_step
	if player_running:
		return "RUN"
	return "READY"

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.godotReady='true';" +
		"document.documentElement.dataset.dummyHp='%d';" % dummy_state.hp +
		"document.documentElement.dataset.dummyX='%.2f';" % dummy_x +
		"document.documentElement.dataset.dummyKnockbackVelocity='%.2f';" % dummy_knockback_state.velocity +
		"document.documentElement.dataset.playerX='%.2f';" % player_x +
		"document.documentElement.dataset.playerDepth='%.3f';" % player_depth +
		"document.documentElement.dataset.playerJumping='%s';" % _bool_text(movement_state.jumping) +
		"document.documentElement.dataset.playerJumpOffset='%.2f';" % movement_state.jump_offset() +
		"document.documentElement.dataset.playerDashing='%s';" % _bool_text(movement_state.is_dashing()) +
		"document.documentElement.dataset.playerRunning='%s';" % _bool_text(player_running) +
		"document.documentElement.dataset.playerGuarding='%s';" % _bool_text(player_guarding) +
		"document.documentElement.dataset.playerState='%s';" % _player_state_name() +
		"document.documentElement.dataset.comboStep='%d';" % attack_chain_state.combo_step +
		"document.documentElement.dataset.lastHitStep='%d';" % (last_attack_step if last_attack_hit else 0) +
		"document.documentElement.dataset.lastAttackHit='%s';" % _bool_text(last_attack_hit) +
		"document.documentElement.dataset.hitboxActive='%s';" % _bool_text(attack_visual_timer > 0.0) +
		"console.log('CUSTOM_FIGHTER_STATE dummyHp=%d combo=%d state=%s');" % [dummy_state.hp, attack_chain_state.combo_step, _player_state_name()]
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"

func _create_label(text_value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eef4ff"))
	add_child(label)
	return label