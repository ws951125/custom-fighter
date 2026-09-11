extends Control

var player_x := 280.0
var enemy_x := 980.0
var attack_timer := 0.0
var attack_latched := false

func _ready() -> void:
	_create_label("CUSTOM FIGHTER", Vector2(48, 36), 36)
	_create_label("Milestone 0 · Online prototype", Vector2(50, 84), 20)
	_create_label("Move: A / D or ← / →    Attack preview: J", Vector2(50, 132), 18)
	_create_label("Next: combat prototype, hitboxes, HP/MP and training dummy", Vector2(50, 164), 16)

	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.documentElement.dataset.godotReady='true'; console.log('CUSTOM_FIGHTER_READY');")

	queue_redraw()

func _process(delta: float) -> void:
	var move_axis := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_axis -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_axis += 1.0

	player_x += move_axis * 360.0 * delta
	player_x = clampf(player_x, 90.0, maxf(size.x, 1280.0) - 90.0)

	var attacking := Input.is_key_pressed(KEY_J)
	if attacking and not attack_latched:
		attack_timer = 0.20
	attack_latched = attacking
	attack_timer = maxf(0.0, attack_timer - delta)

	queue_redraw()

func _draw() -> void:
	var canvas_width := maxf(size.x, 1280.0)
	var canvas_height := maxf(size.y, 720.0)
	var floor_y := canvas_height * 0.76

	draw_rect(Rect2(0.0, 0.0, canvas_width, canvas_height), Color("101522"))
	draw_circle(Vector2(canvas_width * 0.78, canvas_height * 0.20), 82.0, Color("27324d"))
	draw_rect(Rect2(0.0, floor_y, canvas_width, canvas_height - floor_y), Color("182036"))
	draw_line(Vector2(0.0, floor_y), Vector2(canvas_width, floor_y), Color("586a95"), 3.0)

	_draw_fighter(Vector2(player_x, floor_y), Color("62d8ff"), true)
	_draw_fighter(Vector2(enemy_x, floor_y), Color("ff7b83"), false)

	if attack_timer > 0.0:
		var effect_center := Vector2(player_x + 92.0, floor_y - 82.0)
		draw_circle(effect_center, 38.0, Color(0.35, 0.88, 1.0, 0.22))
		draw_arc(effect_center, 46.0, 0.0, TAU, 32, Color("b8f3ff"), 5.0)
		draw_line(Vector2(player_x + 44.0, floor_y - 70.0), Vector2(player_x + 112.0, floor_y - 92.0), Color("e8fbff"), 7.0)

func _draw_fighter(feet: Vector2, body_color: Color, facing_right: bool) -> void:
	var direction := 1.0 if facing_right else -1.0
	var head := feet + Vector2(0.0, -118.0)
	var torso_top := feet + Vector2(-18.0, -94.0)

	draw_circle(head, 22.0, body_color)
	draw_rect(Rect2(torso_top, Vector2(36.0, 70.0)), body_color)
	draw_line(feet + Vector2(-8.0, -30.0), feet + Vector2(-20.0, 0.0), body_color, 10.0)
	draw_line(feet + Vector2(8.0, -30.0), feet + Vector2(20.0, 0.0), body_color, 10.0)
	draw_line(feet + Vector2(direction * 15.0, -78.0), feet + Vector2(direction * 48.0, -62.0), body_color, 9.0)

	var weapon_start := feet + Vector2(direction * 44.0, -65.0)
	var weapon_end := feet + Vector2(direction * 82.0, -96.0)
	draw_line(weapon_start, weapon_end, Color("e9edf7"), 5.0)

func _create_label(text_value: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eef4ff"))
	add_child(label)
