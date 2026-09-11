extends Control

const CombatantState = preload("res://game/core/combat/combatant_state.gd")
const MovementState = preload("res://game/core/movement/movement_state.gd")

const MOVE_SPEED := 360.0
const DEPTH_SPEED := 0.72
const RUN_MULTIPLIER := 1.60
const GUARD_MOVE_MULTIPLIER := 0.35
const ATTACK_DAMAGE := 20
const ATTACK_REACH_X := 128.0
const ATTACK_REACH_DEPTH := 0.20

var player_x := 280.0
var player_depth := 0.58
var player_facing := 1.0
var dummy_x := 860.0
var dummy_depth := 0.58

var attack_timer := 0.0
var attack_latched := false
var jump_latched := false
var dash_latched := false
var player_guarding := false
var player_running := false
var dummy_hit_timer := 0.0
var web_sync_accumulator := 0.0

var dummy_state := CombatantState.new(100, 0)
var movement_state := MovementState.new()
var status_label: Label

func _ready() -> void:
	_ensure_input_actions()
	_create_label("CUSTOM FIGHTER", Vector2(48, 28), 34)
	_create_label("Milestone 1 · Movement actions", Vector2(50, 72), 20)
	_create_label("Move: WASD / Arrows   Run: Shift   Jump: Space   Attack: J   Dash: K   Guard: L", Vector2(50, 108), 16)
	_create_label("Training goal: move freely, then approach the dummy and land a hit", Vector2(50, 138), 15)
	status_label = _create_label("", Vector2(50, 174), 17)

	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	_handle_action_edges()
	movement_state.tick(delta)

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
	)

	if movement_state.is_dashing():
		player_x += movement_state.dash_velocity() * delta
	else:
		var speed_multiplier := RUN_MULTIPLIER if player_running else 1.0
		if player_guarding:
			speed_multiplier *= GUARD_MOVE_MULTIPLIER
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

	attack_timer = maxf(0.0, attack_timer - delta)
	dummy_hit_timer = maxf(0.0, dummy_hit_timer - delta)
	dummy_state.tick(delta)

	status_label.text = "Dummy HP: %d / %d    Distance: %d    State: %s" % [
		dummy_state.hp,
		dummy_state.max_hp,
		roundi(absf(dummy_x - player_x)),
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
	):
		movement_state.start_dash(player_facing)
		_set_web_state()
	dash_latched = dash_pressed

func _begin_attack() -> void:
	attack_timer = 0.22
	var facing_dummy := signf(dummy_x - player_x) == player_facing or absf(dummy_x - player_x) < 1.0
	var in_horizontal_range := absf(dummy_x - player_x) <= ATTACK_REACH_X
	var in_depth_range := absf(dummy_depth - player_depth) <= ATTACK_REACH_DEPTH

	if facing_dummy and in_horizontal_range and in_depth_range and not dummy_state.is_defeated():
		dummy_state.apply_damage(ATTACK_DAMAGE)
		dummy_state.apply_hitstun(0.20)
		dummy_hit_timer = 0.20
		_set_web_state()

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

	if player_depth <= dummy_depth:
		_draw_fighter(player_ground_feet, Color("62d8ff"), player_facing, false, jump_offset, player_guarding)
		_draw_fighter(dummy_feet, _dummy_color(), -1.0, true)
	else:
		_draw_fighter(dummy_feet, _dummy_color(), -1.0, true)
		_draw_fighter(player_ground_feet, Color("62d8ff"), player_facing, false, jump_offset, player_guarding)

	_draw_health_bar(Vector2(50.0, 214.0), 320.0, dummy_state.hp, dummy_state.max_hp)

	if attack_timer > 0.0:
		var player_y := player_ground_feet.y - jump_offset
		var effect_center := Vector2(player_x + player_facing * 86.0, player_y - 82.0)
		draw_circle(effect_center, 34.0, Color(0.35, 0.88, 1.0, 0.20))
		draw_arc(effect_center, 43.0, 0.0, TAU, 32, Color("b8f3ff"), 5.0)
		draw_line(
			Vector2(player_x + player_facing * 38.0, player_y - 68.0),
			Vector2(player_x + player_facing * 112.0, player_y - 92.0),
			Color("e8fbff"),
			7.0
		)

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
	if player_running:
		return "RUN"
	return "READY"

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.godotReady='true';" +
		"document.documentElement.dataset.dummyHp='%d';" % dummy_state.hp +
		"document.documentElement.dataset.playerX='%.2f';" % player_x +
		"document.documentElement.dataset.playerDepth='%.3f';" % player_depth +
		"document.documentElement.dataset.playerJumping='%s';" % _bool_text(movement_state.jumping) +
		"document.documentElement.dataset.playerJumpOffset='%.2f';" % movement_state.jump_offset() +
		"document.documentElement.dataset.playerDashing='%s';" % _bool_text(movement_state.is_dashing()) +
		"document.documentElement.dataset.playerRunning='%s';" % _bool_text(player_running) +
		"document.documentElement.dataset.playerGuarding='%s';" % _bool_text(player_guarding) +
		"document.documentElement.dataset.playerState='%s';" % _player_state_name() +
		"console.log('CUSTOM_FIGHTER_STATE dummyHp=%d state=%s');" % [dummy_state.hp, _player_state_name()]
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
