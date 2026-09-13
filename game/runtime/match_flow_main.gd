extends "res://game/runtime/animation_main.gd"

var match_over := false
var match_result := ""
var match_overlay: CenterContainer
var match_result_label: Label
var restart_button: Button
var _web_restart_callback

func _ready() -> void:
	super()
	_create_match_overlay()
	_install_restart_bridge()
	_set_match_web_state()

func _process(delta: float) -> void:
	if match_over:
		return
	super(delta)
	if dummy_state.is_defeated():
		_finish_match("victory")
	elif player_state.is_defeated():
		_finish_match("defeat")

func _create_match_overlay() -> void:
	match_overlay = CenterContainer.new()
	match_overlay.name = "MatchResultOverlay"
	match_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	match_overlay.visible = false
	match_overlay.z_index = 100
	add_child(match_overlay)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440.0, 230.0)
	match_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	match_result_label = Label.new()
	match_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_result_label.add_theme_font_size_override("font_size", 34)
	layout.add_child(match_result_label)

	var hint := Label.new()
	hint.text = "重新開始會重置 HP、MP、位置、技能冷卻與所有戰鬥狀態"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)

	restart_button = Button.new()
	restart_button.text = "重新開始"
	restart_button.custom_minimum_size = Vector2(0.0, 52.0)
	restart_button.pressed.connect(_restart_match)
	layout.add_child(restart_button)

func _finish_match(result: String) -> void:
	if match_over:
		return
	match_over = true
	match_result = result
	match_result_label.text = "勝利！" if result == "victory" else "失敗"
	match_overlay.visible = true
	player_guarding = false
	player_running = false
	fireball_projectile.deactivate()
	_set_runtime_controllers_processing(false)
	_set_match_web_state()
	queue_redraw()

func _restart_match() -> void:
	var router: Variant = get_parent()
	if router != null and router.has_method("switch_mode"):
		router.call_deferred("switch_mode", "training")

func _set_runtime_controllers_processing(enabled: bool) -> void:
	for node_name in ["AreaSkillController", "FormationSkillController", "BuffSkillController", "MeleeSkillController"]:
		var controller := get_node_or_null(node_name)
		if controller != null:
			controller.set_process(enabled)

func _install_restart_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_restart_callback = JavaScriptBridge.create_callback(_web_restart_match)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterRestartMatch = _web_restart_callback

func _web_restart_match(_args: Array) -> void:
	_restart_match()

func _set_match_web_state() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.matchOver='%s';" % ("true" if match_over else "false") +
		"document.documentElement.dataset.matchResult=%s;" % JSON.stringify(match_result) +
		"document.documentElement.dataset.matchRestartReady='%s';" % ("true" if restart_button != null else "false")
	)
