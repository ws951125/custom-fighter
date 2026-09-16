extends "res://game/creator/ai_skill_proposal_creator_studio.gd"

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SPATIAL_TIMELINE_FIELDS := ["half_width", "half_depth", "offset_x", "offset_depth"]
const WEB_TIMELINE_EDITABLE_FIELDS := ["type", "time", "duration", "half_width", "half_depth", "offset_x", "offset_depth"]

var timeline_panel: PanelContainer
var timeline_event_list: ItemList
var timeline_type: OptionButton
var timeline_time: SpinBox
var timeline_duration: SpinBox
var timeline_status: Label
var timeline_spatial_row: HBoxContainer
var timeline_half_width: SpinBox
var timeline_half_depth: SpinBox
var timeline_offset_x: SpinBox
var timeline_offset_depth: SpinBox
var _web_add_timeline_event_callback
var _web_remove_timeline_event_callback
var _web_move_timeline_event_callback
var _web_update_timeline_event_callback
var _web_clear_timeline_callback

func _ready() -> void:
	super()
	_install_timeline_editor()
	_install_timeline_web_bridge()
	_refresh_timeline_editor()

func _install_timeline_editor() -> void:
	timeline_panel = PanelContainer.new()
	timeline_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	timeline_panel.offset_left = 42.0
	timeline_panel.offset_top = -326.0
	timeline_panel.offset_right = -42.0
	timeline_panel.offset_bottom = -178.0
	add_child(timeline_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	timeline_panel.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)
	var heading := Label.new()
	heading.text = "Timeline"
	heading.custom_minimum_size = Vector2(86, 0)
	row.add_child(heading)
	timeline_event_list = ItemList.new()
	timeline_event_list.custom_minimum_size = Vector2(250, 64)
	timeline_event_list.select_mode = ItemList.SELECT_SINGLE
	timeline_event_list.item_selected.connect(_on_timeline_selected)
	row.add_child(timeline_event_list)
	timeline_type = OptionButton.new()
	for event_type in SkillDefinition.SUPPORTED_TIMELINE_EVENT_TYPES:
		timeline_type.add_item(event_type)
	timeline_type.item_selected.connect(_on_timeline_type_changed)
	row.add_child(timeline_type)
	timeline_time = _timeline_spin(0.0, SkillDefinition.MAX_TIMELINE_SECONDS)
	timeline_time.value_changed.connect(_on_timeline_time_changed)
	row.add_child(timeline_time)
	timeline_duration = _timeline_spin(0.0, SkillDefinition.MAX_TIMELINE_SECONDS)
	timeline_duration.value_changed.connect(_on_timeline_duration_changed)
	row.add_child(timeline_duration)
	for spec in [["+ Event", _on_timeline_add], ["Remove", _on_timeline_remove], ["↑", _on_timeline_up], ["↓", _on_timeline_down], ["Clear", _on_timeline_clear]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(spec[1])
		row.add_child(button)
	timeline_status = Label.new()
	timeline_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(timeline_status)

	timeline_spatial_row = HBoxContainer.new()
	timeline_spatial_row.add_theme_constant_override("separation", 8)
	stack.add_child(timeline_spatial_row)
	_add_timeline_label(timeline_spatial_row, "Spatial", 86.0)
	_add_timeline_label(timeline_spatial_row, "Half W")
	timeline_half_width = _timeline_spin(0.01, SkillDefinition.MAX_TIMELINE_SPATIAL_HALF_WIDTH, 1.0)
	timeline_half_width.value_changed.connect(_on_timeline_half_width_changed)
	timeline_spatial_row.add_child(timeline_half_width)
	_add_timeline_label(timeline_spatial_row, "Half Depth")
	timeline_half_depth = _timeline_spin(0.001, SkillDefinition.MAX_TIMELINE_SPATIAL_HALF_DEPTH, 0.01)
	timeline_half_depth.value_changed.connect(_on_timeline_half_depth_changed)
	timeline_spatial_row.add_child(timeline_half_depth)
	_add_timeline_label(timeline_spatial_row, "Offset X")
	timeline_offset_x = _timeline_spin(-SkillDefinition.MAX_TIMELINE_SPATIAL_OFFSET_X, SkillDefinition.MAX_TIMELINE_SPATIAL_OFFSET_X, 1.0)
	timeline_offset_x.value_changed.connect(_on_timeline_offset_x_changed)
	timeline_spatial_row.add_child(timeline_offset_x)
	_add_timeline_label(timeline_spatial_row, "Offset Depth")
	timeline_offset_depth = _timeline_spin(-SkillDefinition.MAX_TIMELINE_SPATIAL_OFFSET_DEPTH, SkillDefinition.MAX_TIMELINE_SPATIAL_OFFSET_DEPTH, 0.01)
	timeline_offset_depth.value_changed.connect(_on_timeline_offset_depth_changed)
	timeline_spatial_row.add_child(timeline_offset_depth)
	timeline_spatial_row.visible = false

func _add_timeline_label(parent: Control, text: String, minimum_width: float = 0.0) -> void:
	var label := Label.new()
	label.text = text
	if minimum_width > 0.0:
		label.custom_minimum_size = Vector2(minimum_width, 0)
	parent.add_child(label)

func _timeline_spin(minimum: float, maximum: float, step_value: float = 0.01) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step_value
	spin.custom_minimum_size = Vector2(92, 0)
	return spin

func _selected_timeline_index() -> int:
	var selected := timeline_event_list.get_selected_items()
	return -1 if selected.is_empty() else int(selected[0])

func _next_timeline_id() -> String:
	var suffix := 1
	while true:
		var candidate := "event_%02d" % suffix
		var used := false
		for event in skill_draft.timeline_events:
			if str(event.get("id", "")) == candidate:
				used = true
				break
		if not used:
			return candidate
		suffix += 1
	return "event"

func _is_spatial_timeline_type(event_type: String) -> bool:
	return SkillDefinition.TIMELINE_SPATIAL_EVENT_TYPES.has(event_type)

func _normalize_timeline_event_payload(event: Dictionary) -> Dictionary:
	var normalized: Dictionary = event.duplicate(true)
	var event_type := str(normalized.get("type", "")).strip_edges().to_lower()
	normalized["type"] = event_type
	if _is_spatial_timeline_type(event_type):
		normalized["half_width"] = float(normalized.get("half_width", skill_draft.hitbox_half_width if skill_draft != null else SkillDefinition.DEFAULT_TIMELINE_SPATIAL_HALF_WIDTH))
		normalized["half_depth"] = float(normalized.get("half_depth", skill_draft.hitbox_half_depth if skill_draft != null else SkillDefinition.DEFAULT_TIMELINE_SPATIAL_HALF_DEPTH))
		normalized["offset_x"] = float(normalized.get("offset_x", 0.0))
		normalized["offset_depth"] = float(normalized.get("offset_depth", 0.0))
	else:
		for key in SPATIAL_TIMELINE_FIELDS:
			normalized.erase(key)
	return normalized

func _store_timeline_events(events: Array[Dictionary]) -> void:
	var normalized: Array[Dictionary] = []
	for event in events:
		normalized.append(_normalize_timeline_event_payload(event))
	skill_draft.set_timeline_events(normalized)

func _on_timeline_add() -> void:
	if skill_draft.timeline_events.size() >= SkillDefinition.MAX_TIMELINE_EVENTS:
		return
	var events: Array[Dictionary] = []
	for event in skill_draft.timeline_events:
		events.append(event.duplicate(true))
	var time_value := 0.0
	if not events.is_empty():
		var last: Dictionary = events[-1]
		time_value = float(last.get("time", 0.0))
	events.append({"id": _next_timeline_id(), "type": "vfx", "time": time_value, "duration": 0.0})
	_store_timeline_events(events)
	_refresh_skill_validation()
	_refresh_timeline_editor(events.size() - 1)

func _on_timeline_remove() -> void:
	var index := _selected_timeline_index()
	if index < 0:
		return
	var events: Array[Dictionary] = []
	for event in skill_draft.timeline_events:
		events.append(event.duplicate(true))
	events.remove_at(index)
	_store_timeline_events(events)
	_refresh_skill_validation()
	_refresh_timeline_editor(mini(index, events.size() - 1))

func _move_timeline_event(index: int, target: int) -> void:
	if index < 0 or target < 0 or target >= skill_draft.timeline_events.size():
		return
	var events: Array[Dictionary] = []
	for event in skill_draft.timeline_events:
		events.append(event.duplicate(true))
	var moved := events[index]
	events.remove_at(index)
	events.insert(target, moved)
	# Reordering is deterministic but still validated: invalid chronological order is visible and fails closed.
	_store_timeline_events(events)
	_refresh_skill_validation()
	_refresh_timeline_editor(target)

func _on_timeline_up() -> void:
	var index := _selected_timeline_index()
	_move_timeline_event(index, index - 1)

func _on_timeline_down() -> void:
	var index := _selected_timeline_index()
	_move_timeline_event(index, index + 1)

func _on_timeline_clear() -> void:
	skill_draft.clear_timeline()
	_refresh_skill_validation()
	_refresh_timeline_editor()

func _on_timeline_selected(index: int) -> void:
	_refresh_timeline_editor(index)

func _update_selected_timeline_field(key: String, value: Variant) -> void:
	var index := _selected_timeline_index()
	if index < 0:
		return
	var events: Array[Dictionary] = []
	for event in skill_draft.timeline_events:
		events.append(event.duplicate(true))
	events[index][key] = value
	_store_timeline_events(events)
	_refresh_skill_validation()
	_refresh_timeline_editor(index)

func _on_timeline_type_changed(index: int) -> void:
	_update_selected_timeline_field("type", timeline_type.get_item_text(index))

func _on_timeline_time_changed(value: float) -> void:
	_update_selected_timeline_field("time", value)

func _on_timeline_duration_changed(value: float) -> void:
	_update_selected_timeline_field("duration", value)

func _on_timeline_half_width_changed(value: float) -> void:
	_update_selected_timeline_field("half_width", value)

func _on_timeline_half_depth_changed(value: float) -> void:
	_update_selected_timeline_field("half_depth", value)

func _on_timeline_offset_x_changed(value: float) -> void:
	_update_selected_timeline_field("offset_x", value)

func _on_timeline_offset_depth_changed(value: float) -> void:
	_update_selected_timeline_field("offset_depth", value)

func _refresh_timeline_editor(select_index: int = -1) -> void:
	if timeline_event_list == null:
		return
	timeline_event_list.clear()
	for event in skill_draft.timeline_events:
		var item_text := "%s · %s · %.2fs + %.2fs" % [event.get("id", ""), event.get("type", ""), float(event.get("time", 0.0)), float(event.get("duration", 0.0))]
		if _is_spatial_timeline_type(str(event.get("type", ""))):
			item_text += " · %.1fx%.3f @ %.1f/%.3f" % [float(event.get("half_width", SkillDefinition.DEFAULT_TIMELINE_SPATIAL_HALF_WIDTH)), float(event.get("half_depth", SkillDefinition.DEFAULT_TIMELINE_SPATIAL_HALF_DEPTH)), float(event.get("offset_x", 0.0)), float(event.get("offset_depth", 0.0))]
		timeline_event_list.add_item(item_text)
	timeline_spatial_row.visible = false
	if select_index >= 0 and select_index < skill_draft.timeline_events.size():
		timeline_event_list.select(select_index)
		var event: Dictionary = skill_draft.timeline_events[select_index]
		var event_type := str(event.get("type", ""))
		var type_index := SkillDefinition.SUPPORTED_TIMELINE_EVENT_TYPES.find(event_type)
		if type_index >= 0:
			timeline_type.select(type_index)
		timeline_time.set_value_no_signal(float(event.get("time", 0.0)))
		timeline_duration.set_value_no_signal(float(event.get("duration", 0.0)))
		if _is_spatial_timeline_type(event_type):
			timeline_spatial_row.visible = true
			timeline_half_width.set_value_no_signal(float(event.get("half_width", SkillDefinition.DEFAULT_TIMELINE_SPATIAL_HALF_WIDTH)))
			timeline_half_depth.set_value_no_signal(float(event.get("half_depth", SkillDefinition.DEFAULT_TIMELINE_SPATIAL_HALF_DEPTH)))
			timeline_offset_x.set_value_no_signal(float(event.get("offset_x", 0.0)))
			timeline_offset_depth.set_value_no_signal(float(event.get("offset_depth", 0.0)))
	var errors := skill_draft.validate()
	timeline_status.text = "%d/%d events · %s" % [skill_draft.timeline_events.size(), SkillDefinition.MAX_TIMELINE_EVENTS, "VALID" if errors.is_empty() else "INVALID"]
	timeline_status.modulate = Color("7ff0b1") if errors.is_empty() else Color("ff7b86")
	_set_timeline_web_state(errors)

func _install_timeline_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_add_timeline_event_callback = JavaScriptBridge.create_callback(_web_add_timeline_event)
	_web_remove_timeline_event_callback = JavaScriptBridge.create_callback(_web_remove_timeline_event)
	_web_move_timeline_event_callback = JavaScriptBridge.create_callback(_web_move_timeline_event)
	_web_update_timeline_event_callback = JavaScriptBridge.create_callback(_web_update_timeline_event)
	_web_clear_timeline_callback = JavaScriptBridge.create_callback(_web_clear_timeline)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterCreatorTimelineAdd = _web_add_timeline_event_callback
	window.customFighterCreatorTimelineRemove = _web_remove_timeline_event_callback
	window.customFighterCreatorTimelineMove = _web_move_timeline_event_callback
	window.customFighterCreatorTimelineUpdate = _web_update_timeline_event_callback
	window.customFighterCreatorTimelineClear = _web_clear_timeline_callback

func _apply_web_timeline_patch(event: Dictionary, patch: Dictionary) -> Dictionary:
	var updated: Dictionary = event.duplicate(true)
	for key in WEB_TIMELINE_EDITABLE_FIELDS:
		if patch.has(key):
			updated[key] = patch[key]
	return _normalize_timeline_event_payload(updated)

func _web_add_timeline_event(args: Array) -> void:
	_on_timeline_add()
	var index := skill_draft.timeline_events.size() - 1
	if index >= 0 and not args.is_empty():
		var parsed: Variant = JSON.parse_string(str(args[0]))
		if parsed is Dictionary:
			var events: Array[Dictionary] = []
			for event in skill_draft.timeline_events:
				events.append(event.duplicate(true))
			events[index] = _apply_web_timeline_patch(events[index], parsed)
			_store_timeline_events(events)
			_refresh_skill_validation()
			_refresh_timeline_editor(index)

func _web_remove_timeline_event(args: Array) -> void:
	if args.is_empty():
		return
	var index := int(args[0])
	if index < 0 or index >= skill_draft.timeline_events.size():
		return
	timeline_event_list.select(index)
	_on_timeline_remove()

func _web_move_timeline_event(args: Array) -> void:
	if args.size() < 2:
		return
	_move_timeline_event(int(args[0]), int(args[1]))

func _web_update_timeline_event(args: Array) -> void:
	if args.size() < 2:
		return
	var index := int(args[0])
	var parsed: Variant = JSON.parse_string(str(args[1]))
	if index < 0 or index >= skill_draft.timeline_events.size() or not parsed is Dictionary:
		return
	var events: Array[Dictionary] = []
	for event in skill_draft.timeline_events:
		events.append(event.duplicate(true))
	events[index] = _apply_web_timeline_patch(events[index], parsed)
	_store_timeline_events(events)
	_refresh_skill_validation()
	_refresh_timeline_editor(index)

func _web_clear_timeline(_args: Array) -> void:
	_on_timeline_clear()

func _set_timeline_web_state(errors: PackedStringArray = PackedStringArray()) -> void:
	if not OS.has_feature("web"):
		return
	var current_errors := errors
	if current_errors.is_empty() and not skill_draft.is_valid():
		current_errors = skill_draft.validate()
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorTimelineReady='true';" +
		"document.documentElement.dataset.creatorTimelineCount='%d';" % skill_draft.timeline_events.size() +
		"document.documentElement.dataset.creatorTimelineValid='%s';" % ("true" if current_errors.is_empty() else "false") +
		"document.documentElement.dataset.creatorTimelineEvents=%s;" % JSON.stringify(JSON.stringify(skill_draft.timeline_events)) +
		"document.documentElement.dataset.creatorTimelineError=%s;" % JSON.stringify(" | ".join(current_errors))
	)
