extends Control

const CombatantState = preload("res://game/core/combat/combatant_state.gd")

const MOVE_SPEED := 360.0
const DEPTH_SPEED := 0.72
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
var dummy_hit_timer := 0.0
var dummy_state := CombatantState.new(100, 0)
var status_label: Label

func _ready() -> void:
	_ensure_input_actions()
	_create_label("CUSTOM FIGHTER", Vector2(48, 30), 34)
	_create_label("Milestone 1 · Combat foundation", Vector2(50, 76), 20)
	_create_label("Move: WASD / Arrow Keys    Attack: J", Vector2(50, 116), 18)
	_create_label("Training goal: approach the dummy and land a hit", Vector2(50, 146), 16)
	status_label = _create_label("", Vector2(50, 182), 17)

	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	var move_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if move_vector.length_squared() > 1.0:
		move_vector = move_vector.normalized()

	player_x += move_vector.x * MOVE_SPEED * delta
	player_depth += move_vector.y * DEPTH_SPEED * delta
	player_x = clampf(player_x, 90.0, maxf(size.x, 1280.0) - 90.0)
	player_depth = clampf(player_depth, 0.0, 1.0)
	if absf(move_vector.x) > 0.01:
		player_facing = signf(move_vector.x)

	var attacking := Input.is_action_pressed("attack")
	if attacking and not attack_latched:
		_begin_attack()
	attack_latched = attacking

	attack_timer = maxf(0.0, attack_timer - delta)
	dummy_hit_timer = maxf(0.0, dummy_hit_timer - delta)
	dummy_state.tick(delta)

	status_label.text = "Dummy HP: %d / %d    Distance: %d" % [
		dummy_state.hp,
		dummy_state.max_hp,
		roundi(absf(dummy_x - player_x))
	]
	queue_redraw()

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

	var player_feet := Vector2(player_x, lerpf(arena_top, arena_bottom, player_depth))
	var dummy_feet := Vector2(dummy_x, lerpf(arena_top, arena_bottom, dummy_depth))

	if player_depth <= dummy_depth:
		_draw_fighter(player_feet, Color("62d8ff"), player_facing, false)
		_draw_fighter(dummy_feet, _dummy_color(), -1.0, true)
	else:
		_draw_fighter(dummy_feet, _dummy_color(), -1.0, true)
		_draw_fighter(player_feet, Color("62d8ff"), player_facing, false)

	_draw_health_bar(Vector2(50.0, 220.0), 320.0, dummy_state.hp, dummy_state.max_hp)

	if attack_timer > 0.0:
		var player_y := player_feet.y
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

func _draw_fighter(feet: Vector2, body_color: Color, facing: float, is_dummy: bool) -> void:
	var direction := 1.0 if facing >= 0.0 else -1.0
	var shadow_scale := clampf(0.75 + ((feet.y / maxf(size.y, 720.0)) * 0.35), 0.78, 1.08)
	draw_ellipse(feet + Vector2(0.0, 4.0), Vector2(34.0, 10.0) * shadow_scale, Color(0.02, 0.03, 0.06, 0.45))

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

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
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
	_register_key_action("attack", [KEY_J])

func _register_key_action(action_name: StringName, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.godotReady='true'; document.documentElement.dataset.dummyHp='%d'; console.log('CUSTOM_FIGHTER_STATE dummyHp=%d');" % [dummy_state.hp, dummy_state.hp]
	)

func _create_label(text_value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eef4ff"))
	add_child(label)
	return label
