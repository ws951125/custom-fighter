class_name MobileControls
extends Control

const CONTROL_LAYOUT := "landscape-v1"
const MOBILE_ACTIONS := [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"run",
	"jump",
	"attack",
	"dash",
	"guard",
	"skill_1",
	"skill_2",
	"skill_3",
	"skill_4",
	"skill_5",
	"skill_6"
]

var controls_active := false
var touch_capable := false
var last_action := ""
var _pressed_actions: Dictionary = {}
var _portrait_hint: Label
var _web_press_callback
var _web_release_callback

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	touch_capable = _detect_touch_capable()
	controls_active = _should_enable_controls()
	visible = controls_active
	if controls_active:
		_build_controls()
		resized.connect(_update_orientation_hint)
		_update_orientation_hint()
	_install_web_bridge()
	_set_web_state()

func _exit_tree() -> void:
	_release_all_actions()

func is_active() -> bool:
	return controls_active

func _detect_touch_capable() -> bool:
	if not OS.has_feature("web"):
		return false
	var result: Variant = JavaScriptBridge.eval(
		"(navigator.maxTouchPoints || 0) > 0 || (window.matchMedia && window.matchMedia('(pointer: coarse)').matches)"
	)
	return result == true

func _should_enable_controls() -> bool:
	if not OS.has_feature("web"):
		return false
	var result: Variant = JavaScriptBridge.eval(
		"(() => { const p = new URLSearchParams(window.location.search).get('mobile_controls'); if (p === '1') return true; if (p === '0') return false; return (navigator.maxTouchPoints || 0) > 0 || (window.matchMedia && window.matchMedia('(pointer: coarse)').matches); })()"
	)
	return result == true

func _build_controls() -> void:
	var left_group := Control.new()
	left_group.name = "MovementPad"
	left_group.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left_group.offset_left = 24.0
	left_group.offset_top = -286.0
	left_group.offset_right = 316.0
	left_group.offset_bottom = -20.0
	left_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_group)

	_add_action_button(left_group, "UP", "move_up", Rect2(94, 0, 86, 70), false)
	_add_action_button(left_group, "LEFT", "move_left", Rect2(0, 76, 86, 70), false)
	_add_action_button(left_group, "DOWN", "move_down", Rect2(94, 76, 86, 70), false)
	_add_action_button(left_group, "RIGHT", "move_right", Rect2(188, 76, 86, 70), false)
	_add_action_button(left_group, "RUN", "run", Rect2(47, 160, 180, 70), true)

	var right_group := Control.new()
	right_group.name = "ActionPad"
	right_group.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_group.offset_left = -560.0
	right_group.offset_top = -286.0
	right_group.offset_right = -24.0
	right_group.offset_bottom = -20.0
	right_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_group)

	var skill_actions := ["skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6"]
	for index in range(skill_actions.size()):
		_add_action_button(
			right_group,
			"S%d" % (index + 1),
			skill_actions[index],
			Rect2(float(index) * 84.0, 0, 76, 58),
			false
		)

	_add_action_button(right_group, "JUMP", "jump", Rect2(4, 78, 118, 74), true)
	_add_action_button(right_group, "ATK", "attack", Rect2(132, 78, 118, 74), true)
	_add_action_button(right_group, "DASH", "dash", Rect2(260, 78, 118, 74), false)
	_add_action_button(right_group, "GUARD", "guard", Rect2(388, 78, 132, 74), true)

	var hint := Label.new()
	hint.text = "TOUCH CONTROLS"
	hint.position = Vector2(4, 170)
	hint.size = Vector2(516, 34)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(0.82, 0.89, 1.0, 0.72)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_group.add_child(hint)

	_portrait_hint = Label.new()
	_portrait_hint.text = "Rotate phone to landscape for the best controls"
	_portrait_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_portrait_hint.offset_left = -260.0
	_portrait_hint.offset_top = 24.0
	_portrait_hint.offset_right = 260.0
	_portrait_hint.offset_bottom = 72.0
	_portrait_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_hint.add_theme_font_size_override("font_size", 18)
	_portrait_hint.modulate = Color(1.0, 0.84, 0.45, 0.95)
	_portrait_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_hint)

func _add_action_button(parent: Control, label_text: String, action_name: String, rect: Rect2, accent: bool) -> void:
	var button := Button.new()
	button.text = label_text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15 if rect.size.y < 70.0 else 17)
	button.modulate = Color(0.82, 0.92, 1.0, 0.90) if accent else Color(0.76, 0.84, 0.98, 0.82)
	button.button_down.connect(_press_action.bind(action_name))
	button.button_up.connect(_release_action.bind(action_name))
	parent.add_child(button)

func _press_action(action_name: String) -> void:
	if not controls_active or not MOBILE_ACTIONS.has(action_name):
		return
	var input_action := StringName(action_name)
	if not InputMap.has_action(input_action):
		last_action = "missing:%s" % action_name
		_set_web_state()
		return
	Input.action_press(input_action, 1.0)
	_pressed_actions[action_name] = true
	last_action = "press:%s" % action_name
	_set_web_state()

func _release_action(action_name: String) -> void:
	if not MOBILE_ACTIONS.has(action_name):
		return
	var input_action := StringName(action_name)
	if InputMap.has_action(input_action):
		Input.action_release(input_action)
	_pressed_actions.erase(action_name)
	last_action = "release:%s" % action_name
	_set_web_state()

func _release_all_actions() -> void:
	for action_name in _pressed_actions.keys():
		var input_action := StringName(str(action_name))
		if InputMap.has_action(input_action):
			Input.action_release(input_action)
	_pressed_actions.clear()
	_set_web_state()

func _update_orientation_hint() -> void:
	if _portrait_hint == null:
		return
	_portrait_hint.visible = controls_active and size.y > size.x

func _install_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_press_callback = JavaScriptBridge.create_callback(_web_press)
	_web_release_callback = JavaScriptBridge.create_callback(_web_release)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterMobilePress = _web_press_callback
	window.customFighterMobileRelease = _web_release_callback

func _web_press(args: Array) -> void:
	if args.is_empty():
		return
	_press_action(str(args[0]).strip_edges().to_lower())

func _web_release(args: Array) -> void:
	if args.is_empty():
		return
	_release_action(str(args[0]).strip_edges().to_lower())

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var pressed: Array[String] = []
	for action_name in _pressed_actions.keys():
		pressed.append(str(action_name))
	pressed.sort()
	JavaScriptBridge.eval(
		"document.documentElement.dataset.mobileControlsReady='true';" +
		"document.documentElement.dataset.mobileControlsVisible='%s';" % ("true" if controls_active else "false") +
		"document.documentElement.dataset.mobileControlsTouchCapable='%s';" % ("true" if touch_capable else "false") +
		"document.documentElement.dataset.mobileControlsLayout=%s;" % JSON.stringify(CONTROL_LAYOUT) +
		"document.documentElement.dataset.mobileControlsButtonCount='%d';" % MOBILE_ACTIONS.size() +
		"document.documentElement.dataset.mobileControlsPressed=%s;" % JSON.stringify(",".join(pressed)) +
		"document.documentElement.dataset.mobileControlsLastAction=%s;" % JSON.stringify(last_action)
	)
