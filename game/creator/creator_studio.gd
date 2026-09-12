extends Control

const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")

var draft := CharacterDraft.new()
var draft_revision := 0

var id_edit: LineEdit
var name_edit: LineEdit
var archetype_edit: LineEdit
var hp_spin: SpinBox
var mp_spin: SpinBox
var speed_spin: SpinBox
var validation_label: Label
var summary_label: Label

var _web_set_name_callback
var _web_set_hp_callback
var _web_reset_callback

func _ready() -> void:
	_build_ui()
	_sync_controls_from_draft()
	_refresh_validation(false)
	_install_web_bridge()
	_set_web_state()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0b1020")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var title := Label.new()
	title.text = "CUSTOM FIGHTER · CREATOR STUDIO"
	title.add_theme_font_size_override("font_size", 32)
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "M4 · Character Editor Foundation — data-only draft + live CharacterDefinition validation"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.modulate = Color("a9b8d8")
	page.add_child(subtitle)

	var editor_panel := PanelContainer.new()
	editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(editor_panel)

	var editor_margin := MarginContainer.new()
	editor_margin.add_theme_constant_override("margin_left", 22)
	editor_margin.add_theme_constant_override("margin_right", 22)
	editor_margin.add_theme_constant_override("margin_top", 18)
	editor_margin.add_theme_constant_override("margin_bottom", 18)
	editor_panel.add_child(editor_margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	editor_margin.add_child(body)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 28)
	body.add_child(columns)

	var identity_column := VBoxContainer.new()
	identity_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_column.add_theme_constant_override("separation", 10)
	columns.add_child(identity_column)

	var stats_column := VBoxContainer.new()
	stats_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_column.add_theme_constant_override("separation", 10)
	columns.add_child(stats_column)

	var identity_heading := Label.new()
	identity_heading.text = "Identity"
	identity_heading.add_theme_font_size_override("font_size", 20)
	identity_column.add_child(identity_heading)

	id_edit = _add_text_field(identity_column, "Character ID", "Safe lowercase token, e.g. my_fighter_001")
	name_edit = _add_text_field(identity_column, "Display Name", "Shown to players")
	archetype_edit = _add_text_field(identity_column, "Archetype", "Safe token, e.g. balanced")

	var inherited := Label.new()
	inherited.text = "Starter draft keeps approved defaults for visual profile, animation map and U/I/O/P/B/H skill slots."
	inherited.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inherited.modulate = Color("8fa1c6")
	identity_column.add_child(inherited)

	var stats_heading := Label.new()
	stats_heading.text = "Core Stats"
	stats_heading.add_theme_font_size_override("font_size", 20)
	stats_column.add_child(stats_heading)

	hp_spin = _add_number_field(stats_column, "Max HP", 0.0, 10000.0, 1.0)
	mp_spin = _add_number_field(stats_column, "Max MP", 0.0, 10000.0, 1.0)
	speed_spin = _add_number_field(stats_column, "Move Speed", 0.0, 2000.0, 5.0)

	id_edit.text_changed.connect(_on_id_changed)
	name_edit.text_changed.connect(_on_name_changed)
	archetype_edit.text_changed.connect(_on_archetype_changed)
	hp_spin.value_changed.connect(_on_hp_changed)
	mp_spin.value_changed.connect(_on_mp_changed)
	speed_spin.value_changed.connect(_on_speed_changed)

	var separator := HSeparator.new()
	body.add_child(separator)

	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.modulate = Color("b8c7e6")
	body.add_child(summary_label)

	validation_label = Label.new()
	validation_label.custom_minimum_size = Vector2(0, 78)
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(validation_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)

	var reset_button := Button.new()
	reset_button.text = "Reset Draft"
	reset_button.pressed.connect(_on_reset_pressed)
	actions.add_child(reset_button)

	var training_button := Button.new()
	training_button.text = "Back to Training"
	training_button.pressed.connect(_on_training_pressed)
	actions.add_child(training_button)

	var scope_note := Label.new()
	scope_note.text = "Slice 1: in-memory draft only · Save/export and Skill Editor follow in later M4 slices."
	scope_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scope_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scope_note.modulate = Color("8292b3")
	actions.add_child(scope_note)

func _add_text_field(parent: Control, label_text: String, placeholder: String) -> LineEdit:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 4)
	parent.add_child(field)

	var label := Label.new()
	label.text = label_text
	field.add_child(label)

	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 38)
	field.add_child(edit)
	return edit

func _add_number_field(parent: Control, label_text: String, minimum: float, maximum: float, step_value: float) -> SpinBox:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 4)
	parent.add_child(field)

	var label := Label.new()
	label.text = label_text
	field.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step_value
	spin.allow_greater = true
	spin.custom_minimum_size = Vector2(0, 38)
	field.add_child(spin)
	return spin

func _sync_controls_from_draft() -> void:
	id_edit.text = draft.character_id
	name_edit.text = draft.character_name
	archetype_edit.text = draft.archetype
	hp_spin.value = draft.max_hp
	mp_spin.value = draft.max_mp
	speed_spin.value = draft.move_speed

func _on_id_changed(value: String) -> void:
	draft.character_id = value
	_refresh_validation()

func _on_name_changed(value: String) -> void:
	draft.character_name = value
	_refresh_validation()

func _on_archetype_changed(value: String) -> void:
	draft.archetype = value
	_refresh_validation()

func _on_hp_changed(value: float) -> void:
	draft.max_hp = roundi(value)
	_refresh_validation()

func _on_mp_changed(value: float) -> void:
	draft.max_mp = roundi(value)
	_refresh_validation()

func _on_speed_changed(value: float) -> void:
	draft.move_speed = value
	_refresh_validation()

func _on_reset_pressed() -> void:
	draft.reset()
	draft_revision += 1
	_sync_controls_from_draft()
	_refresh_validation(false)

func _on_training_pressed() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = window.location.pathname;")
		return
	get_tree().change_scene_to_file("res://game/runtime/main.tscn")

func _refresh_validation(increment_revision: bool = true) -> void:
	if increment_revision:
		draft_revision += 1
	var errors := draft.validate()
	var valid := errors.is_empty()
	validation_label.text = "VALID · Ready for later preview/save slices" if valid else "INVALID · %s" % " | ".join(errors)
	validation_label.modulate = Color("7ff0b1") if valid else Color("ff7b86")
	summary_label.text = "Draft: %s · %s · HP %d · MP %d · Move %.0f" % [
		draft.character_id,
		draft.character_name,
		draft.max_hp,
		draft.max_mp,
		draft.move_speed
	]
	_set_web_state(errors)

func _install_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_set_name_callback = JavaScriptBridge.create_callback(_web_set_name)
	_web_set_hp_callback = JavaScriptBridge.create_callback(_web_set_hp)
	_web_reset_callback = JavaScriptBridge.create_callback(_web_reset)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterCreatorSetName = _web_set_name_callback
	window.customFighterCreatorSetMaxHp = _web_set_hp_callback
	window.customFighterCreatorResetDraft = _web_reset_callback

func _web_set_name(args: Array) -> void:
	if args.is_empty():
		return
	name_edit.text = str(args[0])
	_on_name_changed(name_edit.text)

func _web_set_hp(args: Array) -> void:
	if args.is_empty():
		return
	var requested_hp := int(args[0])
	draft.max_hp = requested_hp
	if requested_hp >= int(hp_spin.min_value) and requested_hp <= int(hp_spin.max_value):
		hp_spin.value = requested_hp
	_refresh_validation()

func _web_reset(_args: Array) -> void:
	_on_reset_pressed()

func _set_web_state(errors: PackedStringArray = PackedStringArray()) -> void:
	if not OS.has_feature("web"):
		return
	var current_errors := errors
	if current_errors.is_empty() and not draft.is_valid():
		current_errors = draft.validate()
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorStudioReady='true';" +
		"document.documentElement.dataset.creatorEditor='character';" +
		"document.documentElement.dataset.creatorDraftRevision='%d';" % draft_revision +
		"document.documentElement.dataset.creatorDraftValid='%s';" % ("true" if current_errors.is_empty() else "false") +
		"document.documentElement.dataset.creatorDraftId=%s;" % JSON.stringify(draft.character_id) +
		"document.documentElement.dataset.creatorDraftName=%s;" % JSON.stringify(draft.character_name) +
		"document.documentElement.dataset.creatorDraftArchetype=%s;" % JSON.stringify(draft.archetype) +
		"document.documentElement.dataset.creatorDraftMaxHp='%d';" % draft.max_hp +
		"document.documentElement.dataset.creatorDraftMaxMp='%d';" % draft.max_mp +
		"document.documentElement.dataset.creatorDraftMoveSpeed='%.3f';" % draft.move_speed +
		"document.documentElement.dataset.creatorDraftError=%s;" % JSON.stringify(" | ".join(current_errors))
	)
