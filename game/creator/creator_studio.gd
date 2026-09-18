extends Control

const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")

var character_draft := CharacterDraft.new()
var character_draft_revision := 0
var skill_draft := SkillDraft.new()
var skill_draft_revision := 0
var current_editor := "character"

var subtitle_label: Label
var character_panel: PanelContainer
var skill_panel: PanelContainer

var id_edit: LineEdit
var name_edit: LineEdit
var archetype_edit: LineEdit
var hp_spin: SpinBox
var mp_spin: SpinBox
var speed_spin: SpinBox
var character_validation_label: Label
var character_summary_label: Label

var skill_id_edit: LineEdit
var skill_name_edit: LineEdit
var skill_type_select: OptionButton
var skill_type_note: Label
var damage_spin: SpinBox
var skill_mp_spin: SpinBox
var cooldown_spin: SpinBox
var startup_spin: SpinBox
var active_spin: SpinBox
var recovery_spin: SpinBox
var projectile_speed_spin: SpinBox
var range_spin: SpinBox
var hitstun_spin: SpinBox
var knockback_spin: SpinBox
var skill_validation_label: Label
var skill_summary_label: Label

var _web_set_name_callback
var _web_set_hp_callback
var _web_reset_callback
var _web_select_editor_callback
var _web_set_skill_name_callback
var _web_set_skill_type_callback
var _web_set_skill_damage_callback
var _web_set_skill_speed_callback
var _web_set_skill_range_callback
var _web_reset_skill_callback

func _ready() -> void:
	_build_ui()
	_sync_character_controls_from_draft()
	_sync_skill_controls_from_draft()
	_refresh_character_validation(false)
	_refresh_skill_validation(false)
	_show_editor("character")
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
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 9)
	margin.add_child(page)

	var title := Label.new()
	title.text = "CUSTOM FIGHTER · CREATOR STUDIO"
	title.add_theme_font_size_override("font_size", 30)
	page.add_child(title)

	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.modulate = Color("a9b8d8")
	page.add_child(subtitle_label)

	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 10)
	page.add_child(navigation)

	var character_button := Button.new()
	character_button.text = "Character Editor"
	character_button.pressed.connect(_on_character_editor_pressed)
	navigation.add_child(character_button)

	var skill_button := Button.new()
	skill_button.text = "Skill Editor"
	skill_button.pressed.connect(_on_skill_editor_pressed)
	navigation.add_child(skill_button)

	var training_button := Button.new()
	training_button.text = "Back to Training"
	training_button.pressed.connect(_on_training_pressed)
	navigation.add_child(training_button)

	var nav_note := Label.new()
	nav_note.text = "In-memory authoring · safe data-driven skill families"
	nav_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nav_note.modulate = Color("8292b3")
	navigation.add_child(nav_note)

	character_panel = _build_character_panel()
	character_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(character_panel)

	skill_panel = _build_skill_panel()
	skill_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(skill_panel)

func _build_character_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var editor_margin := _panel_margin(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 11)
	editor_margin.add_child(body)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 28)
	body.add_child(columns)

	var identity_column := VBoxContainer.new()
	identity_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_column.add_theme_constant_override("separation", 8)
	columns.add_child(identity_column)

	var stats_column := VBoxContainer.new()
	stats_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_column.add_theme_constant_override("separation", 8)
	columns.add_child(stats_column)

	_add_heading(identity_column, "Identity")
	id_edit = _add_text_field(identity_column, "Character ID", "Safe lowercase token, e.g. my_fighter_001")
	name_edit = _add_text_field(identity_column, "Display Name", "Shown to players")
	archetype_edit = _add_text_field(identity_column, "Archetype", "Safe token, e.g. balanced")

	var inherited := Label.new()
	inherited.text = "Approved starter defaults remain active for visual profile, animation map and U/I/O/P/B/H skill slots."
	inherited.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inherited.modulate = Color("8fa1c6")
	identity_column.add_child(inherited)

	_add_heading(stats_column, "Core Stats")
	hp_spin = _add_number_field(stats_column, "Max HP", 0.0, 10000.0, 1.0)
	mp_spin = _add_number_field(stats_column, "Max MP", 0.0, 10000.0, 1.0)
	speed_spin = _add_number_field(stats_column, "Move Speed", 0.0, 2000.0, 5.0)

	id_edit.text_changed.connect(_on_id_changed)
	name_edit.text_changed.connect(_on_name_changed)
	archetype_edit.text_changed.connect(_on_archetype_changed)
	hp_spin.value_changed.connect(_on_hp_changed)
	mp_spin.value_changed.connect(_on_mp_changed)
	speed_spin.value_changed.connect(_on_speed_changed)

	body.add_child(HSeparator.new())
	character_summary_label = _summary_label(body)
	character_validation_label = _validation_label(body)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)
	var reset_button := Button.new()
	reset_button.text = "Reset Character Draft"
	reset_button.pressed.connect(_on_reset_pressed)
	actions.add_child(reset_button)

	var note := Label.new()
	note.text = "CharacterDraft → CharacterDefinition validation"
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.modulate = Color("8292b3")
	actions.add_child(note)
	return panel

func _build_skill_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var editor_margin := _panel_margin(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	editor_margin.add_child(body)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 22)
	body.add_child(columns)

	var identity_column := VBoxContainer.new()
	identity_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_column.add_theme_constant_override("separation", 5)
	columns.add_child(identity_column)
	var combat_column := VBoxContainer.new()
	combat_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_column.add_theme_constant_override("separation", 5)
	columns.add_child(combat_column)
	var timing_column := VBoxContainer.new()
	timing_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timing_column.add_theme_constant_override("separation", 5)
	columns.add_child(timing_column)

	_add_heading(identity_column, "Skill Identity")
	skill_id_edit = _add_text_field(identity_column, "Skill ID", "Safe token, e.g. nova_bolt_001")
	skill_name_edit = _add_text_field(identity_column, "Display Name", "Shown to players")
	skill_type_select = _add_option_field(identity_column, "Skill Family", SkillDefinition.SUPPORTED_TYPES)
	skill_type_select.item_selected.connect(_on_skill_type_changed)
	skill_type_note = Label.new()
	skill_type_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_type_note.modulate = Color("8fa1c6")
	identity_column.add_child(skill_type_note)

	_add_heading(combat_column, "Combat")
	damage_spin = _add_number_field(combat_column, "Damage", 0.0, 10000.0, 1.0)
	skill_mp_spin = _add_number_field(combat_column, "MP Cost", 0.0, 10000.0, 1.0)
	projectile_speed_spin = _add_number_field(combat_column, "Speed", 0.0, 5000.0, 10.0)
	range_spin = _add_number_field(combat_column, "Range", 0.0, 5000.0, 10.0)
	hitstun_spin = _add_number_field(combat_column, "Hitstun", 0.0, 10.0, 0.01)
	knockback_spin = _add_number_field(combat_column, "Knockback", 0.0, 5000.0, 10.0)

	_add_heading(timing_column, "Timing")
	cooldown_spin = _add_number_field(timing_column, "Cooldown", 0.0, 60.0, 0.05)
	startup_spin = _add_number_field(timing_column, "Startup", 0.0, 10.0, 0.01)
	active_spin = _add_number_field(timing_column, "Active", 0.0, 10.0, 0.01)
	recovery_spin = _add_number_field(timing_column, "Recovery", 0.0, 10.0, 0.01)

	skill_id_edit.text_changed.connect(_on_skill_id_changed)
	skill_name_edit.text_changed.connect(_on_skill_name_changed)
	damage_spin.value_changed.connect(_on_skill_damage_changed)
	skill_mp_spin.value_changed.connect(_on_skill_mp_changed)
	projectile_speed_spin.value_changed.connect(_on_skill_speed_changed)
	range_spin.value_changed.connect(_on_skill_range_changed)
	hitstun_spin.value_changed.connect(_on_skill_hitstun_changed)
	knockback_spin.value_changed.connect(_on_skill_knockback_changed)
	cooldown_spin.value_changed.connect(_on_skill_cooldown_changed)
	startup_spin.value_changed.connect(_on_skill_startup_changed)
	active_spin.value_changed.connect(_on_skill_active_changed)
	recovery_spin.value_changed.connect(_on_skill_recovery_changed)

	body.add_child(HSeparator.new())
	skill_summary_label = _summary_label(body)
	skill_validation_label = _validation_label(body)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)
	var reset_button := Button.new()
	reset_button.text = "Reset Skill Draft"
	reset_button.pressed.connect(_on_skill_reset_pressed)
	actions.add_child(reset_button)
	var note := Label.new()
	note.text = "SkillDraft → SkillDefinition validation · family-specific safe defaults apply when family changes"
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.modulate = Color("8292b3")
	actions.add_child(note)
	return panel

func _panel_margin(panel: PanelContainer) -> MarginContainer:
	var editor_margin := MarginContainer.new()
	editor_margin.add_theme_constant_override("margin_left", 20)
	editor_margin.add_theme_constant_override("margin_right", 20)
	editor_margin.add_theme_constant_override("margin_top", 14)
	editor_margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(editor_margin)
	return editor_margin

func _add_heading(parent: Control, text_value: String) -> void:
	var heading := Label.new()
	heading.text = text_value
	heading.add_theme_font_size_override("font_size", 19)
	parent.add_child(heading)

func _add_text_field(parent: Control, label_text: String, placeholder: String) -> LineEdit:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 2)
	parent.add_child(field)
	var label := Label.new()
	label.text = label_text
	field.add_child(label)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 34)
	field.add_child(edit)
	return edit

func _add_option_field(parent: Control, label_text: String, values: Array) -> OptionButton:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 2)
	parent.add_child(field)
	var label := Label.new()
	label.text = label_text
	field.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(0, 34)
	for value in values:
		option.add_item(str(value))
	field.add_child(option)
	return option

func _add_number_field(parent: Control, label_text: String, minimum: float, maximum: float, step_value: float) -> SpinBox:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 2)
	parent.add_child(field)
	var label := Label.new()
	label.text = label_text
	field.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step_value
	spin.allow_greater = true
	spin.custom_minimum_size = Vector2(0, 32)
	field.add_child(spin)
	return spin

func _summary_label(parent: Control) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color("b8c7e6")
	parent.add_child(label)
	return label

func _validation_label(parent: Control) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(0, 54)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _sync_character_controls_from_draft() -> void:
	id_edit.text = character_draft.character_id
	name_edit.text = character_draft.character_name
	archetype_edit.text = character_draft.archetype
	hp_spin.value = character_draft.max_hp
	mp_spin.value = character_draft.max_mp
	speed_spin.value = character_draft.move_speed

func _sync_skill_controls_from_draft() -> void:
	skill_id_edit.text = skill_draft.skill_id
	skill_name_edit.text = skill_draft.skill_name
	var type_index := SkillDefinition.SUPPORTED_TYPES.find(skill_draft.skill_type)
	if type_index >= 0:
		skill_type_select.select(type_index)
	damage_spin.value = skill_draft.damage
	skill_mp_spin.value = skill_draft.mp_cost
	cooldown_spin.value = skill_draft.cooldown
	startup_spin.value = skill_draft.startup
	active_spin.value = skill_draft.active
	recovery_spin.value = skill_draft.recovery
	projectile_speed_spin.value = skill_draft.speed
	range_spin.value = skill_draft.range
	hitstun_spin.value = skill_draft.hitstun
	knockback_spin.value = skill_draft.knockback
	_refresh_skill_family_note()

func _refresh_skill_family_note() -> void:
	if skill_type_note == null:
		return
	var detail := "Common data fields + timeline"
	match skill_draft.skill_type:
		"projectile", "dash":
			detail = "Motion family · Speed + Range + hitbox defaults"
		"melee":
			detail = "Close-range family · Range + active hitbox defaults"
		"area":
			detail = "Area family · active spatial hitbox defaults"
		"formation":
			detail = "Formation family · Count/Spacing/Interval safe defaults"
		"buff":
			detail = "Buff family · Duration/multiplier safe defaults"
		"beam":
			detail = "Beam family · Bounded range + one-hit active volume"
		"trap":
			detail = "Trap family · Bounded placement + finite trigger lifetime"
		"aura":
			detail = "Aura family · Caster-following bounded finite volume"
		"teleport":
			detail = "Teleport family · Bounded displacement clamped to arena safety"
		"counter":
			detail = "Counter family · Finite incoming-hit window + bounded retaliation source"
	skill_type_note.text = "Family: %s\n%s\nVisual: %s · Impact: %s" % [skill_draft.skill_type.to_upper(), detail, skill_draft.visual, skill_draft.impact_visual]

func _on_character_editor_pressed() -> void:
	_show_editor("character")

func _on_skill_editor_pressed() -> void:
	_show_editor("skill")

func _show_editor(editor_name: String) -> void:
	current_editor = "skill" if editor_name == "skill" else "character"
	character_panel.visible = current_editor == "character"
	skill_panel.visible = current_editor == "skill"
	subtitle_label.text = (
		"V2 · Skill Editor — safe data-only family authoring + live SkillDefinition validation"
		if current_editor == "skill"
		else "M4 · Character Editor — data-only draft + live CharacterDefinition validation"
	)
	_set_web_state()

func _on_id_changed(value: String) -> void:
	character_draft.character_id = value
	_refresh_character_validation()

func _on_name_changed(value: String) -> void:
	character_draft.character_name = value
	_refresh_character_validation()

func _on_archetype_changed(value: String) -> void:
	character_draft.archetype = value
	_refresh_character_validation()

func _on_hp_changed(value: float) -> void:
	character_draft.max_hp = roundi(value)
	_refresh_character_validation()

func _on_mp_changed(value: float) -> void:
	character_draft.max_mp = roundi(value)
	_refresh_character_validation()

func _on_speed_changed(value: float) -> void:
	character_draft.move_speed = value
	_refresh_character_validation()

func _on_reset_pressed() -> void:
	character_draft.reset()
	character_draft_revision += 1
	_sync_character_controls_from_draft()
	_refresh_character_validation(false)

func _on_skill_id_changed(value: String) -> void:
	skill_draft.skill_id = value
	_refresh_skill_validation()

func _on_skill_name_changed(value: String) -> void:
	skill_draft.skill_name = value
	_refresh_skill_validation()

func _on_skill_type_changed(index: int) -> void:
	if index < 0 or index >= skill_type_select.item_count:
		return
	var requested_type := skill_type_select.get_item_text(index)
	if not skill_draft.set_skill_type(requested_type):
		return
	_sync_skill_controls_from_draft()
	_refresh_skill_validation()

func _on_skill_damage_changed(value: float) -> void:
	skill_draft.damage = roundi(value)
	_refresh_skill_validation()

func _on_skill_mp_changed(value: float) -> void:
	skill_draft.mp_cost = roundi(value)
	_refresh_skill_validation()

func _on_skill_cooldown_changed(value: float) -> void:
	skill_draft.cooldown = value
	_refresh_skill_validation()

func _on_skill_startup_changed(value: float) -> void:
	skill_draft.startup = value
	_refresh_skill_validation()

func _on_skill_active_changed(value: float) -> void:
	skill_draft.active = value
	_refresh_skill_validation()

func _on_skill_recovery_changed(value: float) -> void:
	skill_draft.recovery = value
	_refresh_skill_validation()

func _on_skill_speed_changed(value: float) -> void:
	skill_draft.speed = value
	_refresh_skill_validation()

func _on_skill_range_changed(value: float) -> void:
	skill_draft.range = value
	_refresh_skill_validation()

func _on_skill_hitstun_changed(value: float) -> void:
	skill_draft.hitstun = value
	_refresh_skill_validation()

func _on_skill_knockback_changed(value: float) -> void:
	skill_draft.knockback = value
	_refresh_skill_validation()

func _on_skill_reset_pressed() -> void:
	skill_draft.reset()
	skill_draft_revision += 1
	_sync_skill_controls_from_draft()
	_refresh_skill_validation(false)

func _on_training_pressed() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = window.location.pathname;")
		return
	get_tree().change_scene_to_file("res://game/runtime/main.tscn")

func _refresh_character_validation(increment_revision: bool = true) -> void:
	if increment_revision:
		character_draft_revision += 1
	var errors := character_draft.validate()
	var valid := errors.is_empty()
	character_validation_label.text = "VALID · Character draft passes runtime schema" if valid else "INVALID · %s" % " | ".join(errors)
	character_validation_label.modulate = Color("7ff0b1") if valid else Color("ff7b86")
	character_summary_label.text = "Character: %s · %s · HP %d · MP %d · Move %.0f" % [
		character_draft.character_id,
		character_draft.character_name,
		character_draft.max_hp,
		character_draft.max_mp,
		character_draft.move_speed
	]
	_set_web_state(errors)

func _refresh_skill_validation(increment_revision: bool = true) -> void:
	if increment_revision:
		skill_draft_revision += 1
	var errors := skill_draft.validate()
	var valid := errors.is_empty()
	skill_validation_label.text = "VALID · %s draft passes runtime schema" % skill_draft.skill_type.capitalize() if valid else "INVALID · %s" % " | ".join(errors)
	skill_validation_label.modulate = Color("7ff0b1") if valid else Color("ff7b86")
	skill_summary_label.text = "%s: %s · %s · DMG %d · MP %d · Speed %.0f · Range %.0f" % [
		skill_draft.skill_type.capitalize(),
		skill_draft.skill_id,
		skill_draft.skill_name,
		skill_draft.damage,
		skill_draft.mp_cost,
		skill_draft.speed,
		skill_draft.range
	]
	_refresh_skill_family_note()
	_set_web_state(PackedStringArray(), errors)

func _install_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_set_name_callback = JavaScriptBridge.create_callback(_web_set_name)
	_web_set_hp_callback = JavaScriptBridge.create_callback(_web_set_hp)
	_web_reset_callback = JavaScriptBridge.create_callback(_web_reset)
	_web_select_editor_callback = JavaScriptBridge.create_callback(_web_select_editor)
	_web_set_skill_name_callback = JavaScriptBridge.create_callback(_web_set_skill_name)
	_web_set_skill_type_callback = JavaScriptBridge.create_callback(_web_set_skill_type)
	_web_set_skill_damage_callback = JavaScriptBridge.create_callback(_web_set_skill_damage)
	_web_set_skill_speed_callback = JavaScriptBridge.create_callback(_web_set_skill_speed)
	_web_set_skill_range_callback = JavaScriptBridge.create_callback(_web_set_skill_range)
	_web_reset_skill_callback = JavaScriptBridge.create_callback(_web_reset_skill)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterCreatorSetName = _web_set_name_callback
	window.customFighterCreatorSetMaxHp = _web_set_hp_callback
	window.customFighterCreatorResetDraft = _web_reset_callback
	window.customFighterCreatorSelectEditor = _web_select_editor_callback
	window.customFighterCreatorSetSkillName = _web_set_skill_name_callback
	window.customFighterCreatorSetSkillType = _web_set_skill_type_callback
	window.customFighterCreatorSetSkillDamage = _web_set_skill_damage_callback
	window.customFighterCreatorSetSkillSpeed = _web_set_skill_speed_callback
	window.customFighterCreatorSetSkillRange = _web_set_skill_range_callback
	window.customFighterCreatorResetSkillDraft = _web_reset_skill_callback

func _web_set_name(args: Array) -> void:
	if args.is_empty():
		return
	name_edit.text = str(args[0])
	_on_name_changed(name_edit.text)

func _web_set_hp(args: Array) -> void:
	if args.is_empty():
		return
	var requested_hp := int(args[0])
	character_draft.max_hp = requested_hp
	if requested_hp >= int(hp_spin.min_value) and requested_hp <= int(hp_spin.max_value):
		hp_spin.value = requested_hp
	_refresh_character_validation()

func _web_reset(_args: Array) -> void:
	_on_reset_pressed()

func _web_select_editor(args: Array) -> void:
	if args.is_empty():
		return
	_show_editor(str(args[0]).strip_edges().to_lower())

func _web_set_skill_name(args: Array) -> void:
	if args.is_empty():
		return
	skill_name_edit.text = str(args[0])
	_on_skill_name_changed(skill_name_edit.text)

func _web_set_skill_type(args: Array) -> void:
	if args.is_empty():
		return
	var requested_type := str(args[0]).strip_edges().to_lower()
	var index := SkillDefinition.SUPPORTED_TYPES.find(requested_type)
	if index < 0:
		return
	skill_type_select.select(index)
	_on_skill_type_changed(index)

func _web_set_skill_damage(args: Array) -> void:
	if args.is_empty():
		return
	var value := int(args[0])
	skill_draft.damage = value
	if value >= int(damage_spin.min_value) and value <= int(damage_spin.max_value):
		damage_spin.value = value
	_refresh_skill_validation()

func _web_set_skill_speed(args: Array) -> void:
	if args.is_empty():
		return
	var value := float(args[0])
	skill_draft.speed = value
	if value >= projectile_speed_spin.min_value and value <= projectile_speed_spin.max_value:
		projectile_speed_spin.value = value
	_refresh_skill_validation()

func _web_set_skill_range(args: Array) -> void:
	if args.is_empty():
		return
	var value := float(args[0])
	skill_draft.range = value
	if value >= range_spin.min_value and value <= range_spin.max_value:
		range_spin.value = value
	_refresh_skill_validation()

func _web_reset_skill(_args: Array) -> void:
	_on_skill_reset_pressed()

func _set_web_state(character_errors: PackedStringArray = PackedStringArray(), skill_errors: PackedStringArray = PackedStringArray()) -> void:
	if not OS.has_feature("web"):
		return
	var current_character_errors := character_errors
	if current_character_errors.is_empty() and not character_draft.is_valid():
		current_character_errors = character_draft.validate()
	var current_skill_errors := skill_errors
	if current_skill_errors.is_empty() and not skill_draft.is_valid():
		current_skill_errors = skill_draft.validate()
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorStudioReady='true';" +
		"document.documentElement.dataset.creatorEditor=%s;" % JSON.stringify(current_editor) +
		"document.documentElement.dataset.creatorDraftRevision='%d';" % character_draft_revision +
		"document.documentElement.dataset.creatorDraftValid='%s';" % ("true" if current_character_errors.is_empty() else "false") +
		"document.documentElement.dataset.creatorDraftId=%s;" % JSON.stringify(character_draft.character_id) +
		"document.documentElement.dataset.creatorDraftName=%s;" % JSON.stringify(character_draft.character_name) +
		"document.documentElement.dataset.creatorDraftArchetype=%s;" % JSON.stringify(character_draft.archetype) +
		"document.documentElement.dataset.creatorDraftMaxHp='%d';" % character_draft.max_hp +
		"document.documentElement.dataset.creatorDraftMaxMp='%d';" % character_draft.max_mp +
		"document.documentElement.dataset.creatorDraftMoveSpeed='%.3f';" % character_draft.move_speed +
		"document.documentElement.dataset.creatorDraftError=%s;" % JSON.stringify(" | ".join(current_character_errors)) +
		"document.documentElement.dataset.creatorSkillDraftRevision='%d';" % skill_draft_revision +
		"document.documentElement.dataset.creatorSkillDraftValid='%s';" % ("true" if current_skill_errors.is_empty() else "false") +
		"document.documentElement.dataset.creatorSkillDraftId=%s;" % JSON.stringify(skill_draft.skill_id) +
		"document.documentElement.dataset.creatorSkillDraftName=%s;" % JSON.stringify(skill_draft.skill_name) +
		"document.documentElement.dataset.creatorSkillDraftType=%s;" % JSON.stringify(skill_draft.skill_type) +
		"document.documentElement.dataset.creatorSkillDraftDamage='%d';" % skill_draft.damage +
		"document.documentElement.dataset.creatorSkillDraftMpCost='%d';" % skill_draft.mp_cost +
		"document.documentElement.dataset.creatorSkillDraftCooldown='%.3f';" % skill_draft.cooldown +
		"document.documentElement.dataset.creatorSkillDraftStartup='%.3f';" % skill_draft.startup +
		"document.documentElement.dataset.creatorSkillDraftActive='%.3f';" % skill_draft.active +
		"document.documentElement.dataset.creatorSkillDraftRecovery='%.3f';" % skill_draft.recovery +
		"document.documentElement.dataset.creatorSkillDraftSpeed='%.3f';" % skill_draft.speed +
		"document.documentElement.dataset.creatorSkillDraftRange='%.3f';" % skill_draft.range +
		"document.documentElement.dataset.creatorSkillDraftHitstun='%.3f';" % skill_draft.hitstun +
		"document.documentElement.dataset.creatorSkillDraftKnockback='%.3f';" % skill_draft.knockback +
		"document.documentElement.dataset.creatorSkillDraftFormationCount='%d';" % skill_draft.formation_count +
		"document.documentElement.dataset.creatorSkillDraftFormationSpacing='%.3f';" % skill_draft.formation_spacing +
		"document.documentElement.dataset.creatorSkillDraftFormationInterval='%.3f';" % skill_draft.formation_interval +
		"document.documentElement.dataset.creatorSkillDraftFormationOffset='%.3f';" % skill_draft.formation_offset +
		"document.documentElement.dataset.creatorSkillDraftBuffDuration='%.3f';" % skill_draft.buff_duration +
		"document.documentElement.dataset.creatorSkillDraftMoveSpeedMultiplier='%.3f';" % skill_draft.move_speed_multiplier +
		"document.documentElement.dataset.creatorSkillDraftBasicDamageMultiplier='%.3f';" % skill_draft.basic_attack_damage_multiplier +
		"document.documentElement.dataset.creatorSkillDraftError=%s;" % JSON.stringify(" | ".join(current_skill_errors))
	)
