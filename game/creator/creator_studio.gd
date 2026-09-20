extends Control

const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const CharacterAnimationDraft = preload("res://game/creator/character_editor/character_animation_draft.gd")
const CharacterAnimationAssetDraft = preload("res://game/creator/character_editor/character_animation_asset_draft.gd")
const CharacterAnimationMap = preload("res://game/core/character/character_animation_map.gd")
const CharacterAudioDraft = preload("res://game/creator/character_editor/character_audio_draft.gd")
const CharacterAudioBindings = preload("res://game/core/character/character_audio_bindings.gd")
const CharacterAudioAssetDraft = preload("res://game/creator/character_editor/character_audio_asset_draft.gd")
const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")

var character_draft := CharacterDraft.new()
var character_draft_revision := 0
var animation_draft := CharacterAnimationDraft.new()
var animation_draft_revision := 0
var animation_asset_draft := CharacterAnimationAssetDraft.new()
var animation_asset_bytes := PackedByteArray()
var animation_asset_error := ""
var animation_asset_revision := 0
var audio_draft := CharacterAudioDraft.new()
var audio_draft_revision := 0
var audio_asset_draft := CharacterAudioAssetDraft.new()
var audio_asset_bytes := PackedByteArray()
var audio_asset_error := ""
var audio_asset_revision := 0
var skill_draft := SkillDraft.new()
var skill_draft_revision := 0
var current_editor := "character"

var subtitle_label: Label
var character_panel: PanelContainer
var skill_panel: PanelContainer

var id_edit: LineEdit
var name_edit: LineEdit
var archetype_edit: LineEdit
var animation_map_edit: LineEdit
var animation_semantic_select: OptionButton
var animation_id_edit: LineEdit
var animation_asset_frame_count_spin: SpinBox
var animation_asset_fps_spin: SpinBox
var animation_asset_status_label: Label
var audio_binding_select: OptionButton
var audio_cue_edit: LineEdit
var audio_asset_status_label: Label
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
var _web_set_animation_map_callback
var _web_set_animation_semantic_callback
var _web_import_animation_png_callback
var _web_import_animation_error_callback
var _web_clear_animation_asset_callback
var _web_set_audio_binding_callback
var _web_import_audio_wav_callback
var _web_import_audio_error_callback
var _web_clear_audio_asset_callback
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
	animation_draft.load_from_id(character_draft.animation_map)
	_build_ui()
	_restore_animation_asset_from_session()
	_restore_audio_asset_from_session()
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
	animation_map_edit = _add_text_field(identity_column, "Animation Map", "Trusted content map id, e.g. ember_vanguard or storm_duelist")

	var inherited := Label.new()
	inherited.text = "Approved starter defaults remain active for visual profile and U/I/O/P/B/H skill slots. Animation Map is editable but must resolve through trusted character-animation content."
	inherited.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inherited.modulate = Color("8fa1c6")
	identity_column.add_child(inherited)

	_add_heading(stats_column, "Core Stats")
	hp_spin = _add_number_field(stats_column, "Max HP", 0.0, 10000.0, 1.0)
	mp_spin = _add_number_field(stats_column, "Max MP", 0.0, 10000.0, 1.0)
	speed_spin = _add_number_field(stats_column, "Move Speed", 0.0, 2000.0, 5.0)

	_add_heading(stats_column, "Animation Semantics")
	animation_semantic_select = _add_option_field(stats_column, "Semantic", CharacterAnimationMap.REQUIRED_SEMANTICS)
	animation_id_edit = _add_text_field(stats_column, "Animation ID", "Safe token only, e.g. custom_attack_one")
	animation_asset_frame_count_spin = _add_number_field(stats_column, "PNG Frames", 1.0, float(CharacterAnimationAssetDraft.MAX_FRAME_COUNT), 1.0)
	animation_asset_frame_count_spin.value = 1.0
	animation_asset_fps_spin = _add_number_field(stats_column, "PNG FPS", 1.0, 60.0, 1.0)
	animation_asset_fps_spin.value = 12.0
	var animation_asset_actions := HBoxContainer.new()
	animation_asset_actions.add_theme_constant_override("separation", 8)
	stats_column.add_child(animation_asset_actions)
	var choose_animation_asset_button := Button.new()
	choose_animation_asset_button.text = "Choose Animation PNG"
	choose_animation_asset_button.pressed.connect(_on_choose_animation_asset_pressed)
	animation_asset_actions.add_child(choose_animation_asset_button)
	var clear_animation_asset_button := Button.new()
	clear_animation_asset_button.text = "Clear Animation PNG"
	clear_animation_asset_button.pressed.connect(_on_clear_animation_asset_pressed)
	animation_asset_actions.add_child(clear_animation_asset_button)
	animation_asset_status_label = Label.new()
	animation_asset_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	animation_asset_status_label.modulate = Color("8292b3")
	stats_column.add_child(animation_asset_status_label)
	_refresh_animation_asset_status(false)

	_add_heading(stats_column, "Audio Cue Bindings")
	audio_binding_select = _add_option_field(stats_column, "Binding", CharacterAudioBindings.REQUIRED_BINDINGS)
	audio_cue_edit = _add_text_field(stats_column, "Cue ID", "Safe token only, e.g. nova_skill_cast")
	var audio_asset_actions := HBoxContainer.new()
	audio_asset_actions.add_theme_constant_override("separation", 8)
	stats_column.add_child(audio_asset_actions)
	var choose_audio_button := Button.new()
	choose_audio_button.text = "Choose WAV"
	choose_audio_button.pressed.connect(_on_choose_audio_pressed)
	audio_asset_actions.add_child(choose_audio_button)
	var clear_audio_button := Button.new()
	clear_audio_button.text = "Clear WAV"
	clear_audio_button.pressed.connect(_on_clear_audio_asset_pressed)
	audio_asset_actions.add_child(clear_audio_button)
	audio_asset_status_label = Label.new()
	audio_asset_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	audio_asset_status_label.modulate = Color("8292b3")
	stats_column.add_child(audio_asset_status_label)
	_refresh_audio_asset_status(false)

	id_edit.text_changed.connect(_on_id_changed)
	name_edit.text_changed.connect(_on_name_changed)
	archetype_edit.text_changed.connect(_on_archetype_changed)
	animation_map_edit.text_changed.connect(_on_animation_map_changed)
	animation_semantic_select.item_selected.connect(_on_animation_semantic_selected)
	animation_id_edit.text_changed.connect(_on_animation_id_changed)
	animation_asset_frame_count_spin.value_changed.connect(_on_animation_asset_frame_count_changed)
	animation_asset_fps_spin.value_changed.connect(_on_animation_asset_fps_changed)
	audio_binding_select.item_selected.connect(_on_audio_binding_selected)
	audio_cue_edit.text_changed.connect(_on_audio_cue_changed)
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
	animation_map_edit.text = character_draft.animation_map
	_sync_animation_controls_from_draft()
	_sync_audio_controls_from_draft()
	hp_spin.value = character_draft.max_hp
	mp_spin.value = character_draft.max_mp
	speed_spin.value = character_draft.move_speed

func _sync_animation_controls_from_draft() -> void:
	if animation_semantic_select == null or animation_id_edit == null:
		return
	var selected_index := animation_semantic_select.selected
	if selected_index < 0 or selected_index >= animation_semantic_select.item_count:
		selected_index = 0
		animation_semantic_select.select(selected_index)
	var semantic := animation_semantic_select.get_item_text(selected_index).strip_edges().to_lower()
	animation_id_edit.set_block_signals(true)
	animation_id_edit.text = animation_draft.animation_id_for_semantic(semantic)
	animation_id_edit.set_block_signals(false)

func _sync_audio_controls_from_draft() -> void:
	if audio_binding_select == null or audio_cue_edit == null:
		return
	var selected_index := audio_binding_select.selected
	if selected_index < 0 or selected_index >= audio_binding_select.item_count:
		selected_index = 0
		audio_binding_select.select(selected_index)
	var binding := audio_binding_select.get_item_text(selected_index).strip_edges().to_lower()
	audio_cue_edit.set_block_signals(true)
	audio_cue_edit.text = audio_draft.cue_for_binding(binding)
	audio_cue_edit.set_block_signals(false)

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
		"grab":
			detail = "Grab family · Actual target overlap + finite hold; Knockback is safe target offset"
		"summon":
			detail = "Summon family · One bounded actor · finite lifetime · designated target · one hit max"
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

func _on_animation_map_changed(value: String) -> void:
	character_draft.animation_map = value
	_clear_animation_asset("Animation PNG cleared because the Animation Map changed")
	var animation_errors: PackedStringArray = animation_draft.load_from_id(value)
	if animation_errors.is_empty():
		animation_draft_revision += 1
		_sync_animation_controls_from_draft()
	_refresh_character_validation()

func _on_animation_semantic_selected(_index: int) -> void:
	_sync_animation_controls_from_draft()
	_refresh_animation_asset_status(false)
	_set_web_state()

func _on_animation_id_changed(value: String) -> void:
	if animation_semantic_select == null or animation_semantic_select.selected < 0:
		return
	var semantic := animation_semantic_select.get_item_text(animation_semantic_select.selected)
	animation_draft.set_animation(semantic, value)
	animation_draft_revision += 1
	_clear_animation_asset_if_mapping_changed(semantic)
	_refresh_character_validation()

func _on_audio_binding_selected(_index: int) -> void:
	_sync_audio_controls_from_draft()
	_refresh_audio_asset_status(false)
	_set_web_state()

func _on_audio_cue_changed(value: String) -> void:
	if audio_binding_select == null or audio_binding_select.selected < 0:
		return
	var binding := audio_binding_select.get_item_text(audio_binding_select.selected)
	audio_draft.set_cue(binding, value)
	audio_draft_revision += 1
	_clear_audio_asset_if_binding_changed(binding)
	_refresh_character_validation()

func _on_animation_asset_frame_count_changed(_value: float) -> void:
	if not animation_asset_bytes.is_empty() and int(animation_asset_frame_count_spin.value) != animation_asset_draft.frame_count:
		_clear_animation_asset("Animation PNG cleared because frame_count changed")
	else:
		_set_web_state()

func _on_animation_asset_fps_changed(_value: float) -> void:
	if not animation_asset_bytes.is_empty() and not is_equal_approx(animation_asset_fps_spin.value, animation_asset_draft.fps):
		_clear_animation_asset("Animation PNG cleared because FPS changed")
	else:
		_set_web_state()

func _on_choose_animation_asset_pressed() -> void:
	if not OS.has_feature("web"):
		animation_asset_error = "Animation PNG file picker is currently enabled for the Web build"
		_refresh_animation_asset_status()
		return
	if animation_semantic_select == null or animation_semantic_select.selected < 0 or not animation_draft.validate().is_empty():
		animation_asset_error = "Fix Animation Semantics before importing PNG"
		_refresh_animation_asset_status()
		return
	var script := """
(() => {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/png,.png';
  input.style.display = 'none';
  document.body.appendChild(input);
  input.onchange = () => {
    const file = input.files && input.files[0];
    if (!file) { input.remove(); return; }
    if (file.size > %d) {
      window.customFighterCreatorAnimationImportError('Animation PNG exceeds 5 MB limit');
      input.remove();
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = String(reader.result || '');
      const image = new Image();
      image.onload = () => {
        window.customFighterCreatorImportAnimationPng(
          file.name,
          file.type || 'image/png',
          image.naturalWidth || image.width || 0,
          image.naturalHeight || image.height || 0,
          dataUrl
        );
        input.remove();
      };
      image.onerror = () => {
        window.customFighterCreatorAnimationImportError('Browser could not decode Animation PNG');
        input.remove();
      };
      image.src = dataUrl;
    };
    reader.onerror = () => {
      window.customFighterCreatorAnimationImportError('Browser could not read Animation PNG');
      input.remove();
    };
    reader.readAsDataURL(file);
  };
  input.click();
})();
""" % CharacterAnimationAssetDraft.MAX_FILE_BYTES
	JavaScriptBridge.eval(script)

func _on_clear_animation_asset_pressed() -> void:
	_clear_animation_asset("")

func _restore_animation_asset_from_session() -> void:
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_method("has_stored_animation_asset") or not bool(session.call("has_stored_animation_asset")):
		return
	if not session.has_method("stored_animation_asset_data") or not session.has_method("stored_animation_asset_bytes"):
		return
	var metadata: Dictionary = session.call("stored_animation_asset_data")
	var bytes: PackedByteArray = session.call("stored_animation_asset_bytes")
	var errors: PackedStringArray = animation_asset_draft.load_from_dictionary(metadata)
	if errors.is_empty():
		errors = animation_asset_draft.validate_bytes(bytes)
	if not errors.is_empty():
		_clear_animation_asset("Stored Animation PNG failed validation")
		return
	animation_asset_bytes = bytes.duplicate()
	animation_asset_error = ""
	if animation_asset_frame_count_spin != null:
		animation_asset_frame_count_spin.set_block_signals(true)
		animation_asset_frame_count_spin.value = animation_asset_draft.frame_count
		animation_asset_frame_count_spin.set_block_signals(false)
	if animation_asset_fps_spin != null:
		animation_asset_fps_spin.set_block_signals(true)
		animation_asset_fps_spin.value = animation_asset_draft.fps
		animation_asset_fps_spin.set_block_signals(false)
	_refresh_animation_asset_status(false)

func _import_animation_png_data(file_name: String, mime_type: String, width: int, height: int, data_url: String) -> void:
	if data_url.length() > 7 * 1024 * 1024:
		_clear_animation_asset("Animation PNG data URL exceeds safe transfer limit")
		return
	var marker := "base64,"
	var marker_index := data_url.find(marker)
	if marker_index < 0 or not data_url.begins_with("data:image/png"):
		_clear_animation_asset("Animation PNG import requires a base64 image/png data URL")
		return
	if animation_semantic_select == null or animation_semantic_select.selected < 0:
		_clear_animation_asset("Animation semantic selection is unavailable")
		return
	var bytes := Marshalls.base64_to_raw(data_url.substr(marker_index + marker.length()))
	var semantic := animation_semantic_select.get_item_text(animation_semantic_select.selected).strip_edges().to_lower()
	var animation_id := animation_draft.animation_id_for_semantic(semantic)
	var errors: PackedStringArray = animation_asset_draft.configure_import(
		file_name,
		mime_type,
		semantic,
		animation_id,
		width,
		height,
		int(animation_asset_frame_count_spin.value),
		animation_asset_fps_spin.value
	)
	if errors.is_empty():
		errors = animation_asset_draft.validate_bytes(bytes)
	if not errors.is_empty():
		_clear_animation_asset(" | ".join(errors))
		return
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_method("store_animation_asset_draft"):
		_clear_animation_asset("Creator preview session cannot store Animation PNG")
		return
	var store_errors: PackedStringArray = session.call("store_animation_asset_draft", animation_asset_draft.to_dictionary(), bytes)
	if not store_errors.is_empty():
		_clear_animation_asset("Preview session rejected Animation PNG: %s" % " | ".join(store_errors))
		return
	animation_asset_bytes = bytes.duplicate()
	animation_asset_error = ""
	animation_asset_revision += 1
	_refresh_animation_asset_status(false)

func _clear_animation_asset(message: String) -> void:
	animation_asset_draft.reset()
	animation_asset_bytes.clear()
	animation_asset_error = message
	animation_asset_revision += 1
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session != null and session.has_method("clear_animation_asset_draft"):
		session.call("clear_animation_asset_draft")
	_refresh_animation_asset_status(false)

func _clear_animation_asset_if_mapping_changed(semantic_name: String) -> void:
	if animation_asset_bytes.is_empty() or animation_asset_draft.semantic != semantic_name.strip_edges().to_lower():
		return
	var current_animation_id := animation_draft.animation_id_for_semantic(semantic_name)
	if current_animation_id != animation_asset_draft.animation_id:
		_clear_animation_asset("Animation PNG cleared because its bound Animation ID changed")

func _refresh_animation_asset_status(increment_revision: bool = true) -> void:
	if increment_revision:
		animation_asset_revision += 1
	if animation_asset_status_label == null:
		return
	if not animation_asset_error.is_empty():
		animation_asset_status_label.text = "ANIMATION PNG INVALID · %s" % animation_asset_error
		animation_asset_status_label.modulate = Color("ff7b86")
	elif not animation_asset_bytes.is_empty():
		animation_asset_status_label.text = "ANIMATION PNG READY · %s → %s · %dx%d · %d frames · %.0f FPS" % [
			animation_asset_draft.semantic,
			animation_asset_draft.animation_id,
			animation_asset_draft.image_width,
			animation_asset_draft.image_height,
			animation_asset_draft.frame_count,
			animation_asset_draft.fps
		]
		animation_asset_status_label.modulate = Color("7ff0b1")
	else:
		animation_asset_status_label.text = "Optional Animation PNG · horizontal strip · ≤64 frames · ≤5 MB · memory-only"
		animation_asset_status_label.modulate = Color("8292b3")
	_set_web_state()

func _on_choose_audio_pressed() -> void:
	if not OS.has_feature("web"):
		audio_asset_error = "WAV file picker is currently enabled for the Web build"
		_refresh_audio_asset_status()
		return
	if audio_binding_select == null or audio_binding_select.selected < 0 or not audio_draft.validate().is_empty():
		audio_asset_error = "Fix Audio Cue Bindings before importing WAV"
		_refresh_audio_asset_status()
		return
	var script := """
(() => {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'audio/wav,.wav';
  input.style.display = 'none';
  document.body.appendChild(input);
  input.onchange = () => {
    const file = input.files && input.files[0];
    if (!file) { input.remove(); return; }
    if (file.size > %d) {
      window.customFighterCreatorAudioImportError('WAV exceeds 512 KB limit');
      input.remove();
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      window.customFighterCreatorImportWav(file.name, file.type || 'audio/wav', String(reader.result || ''));
      input.remove();
    };
    reader.onerror = () => {
      window.customFighterCreatorAudioImportError('Browser could not read WAV');
      input.remove();
    };
    reader.readAsDataURL(file);
  };
  input.click();
})();
""" % CharacterAudioAssetDraft.MAX_FILE_BYTES
	JavaScriptBridge.eval(script)

func _on_clear_audio_asset_pressed() -> void:
	_clear_audio_asset("")

func _restore_audio_asset_from_session() -> void:
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_method("has_stored_audio_asset") or not bool(session.call("has_stored_audio_asset")):
		return
	if not session.has_method("stored_audio_asset_data") or not session.has_method("stored_audio_asset_bytes"):
		return
	var metadata: Dictionary = session.call("stored_audio_asset_data")
	var bytes: PackedByteArray = session.call("stored_audio_asset_bytes")
	var errors: PackedStringArray = audio_asset_draft.load_from_dictionary(metadata)
	if errors.is_empty():
		errors = audio_asset_draft.validate_bytes(bytes)
	if not errors.is_empty():
		_clear_audio_asset("Stored WAV failed validation")
		return
	audio_asset_bytes = bytes.duplicate()
	audio_asset_error = ""

func _import_audio_wav_data(file_name: String, mime_type: String, data_url: String) -> void:
	if data_url.length() > 768 * 1024:
		_clear_audio_asset("WAV data URL exceeds safe transfer limit")
		return
	var marker := "base64,"
	var marker_index := data_url.find(marker)
	if marker_index < 0 or not data_url.begins_with("data:audio/"):
		_clear_audio_asset("WAV import requires a base64 audio data URL")
		return
	var bytes := Marshalls.base64_to_raw(data_url.substr(marker_index + marker.length()))
	if audio_binding_select == null or audio_binding_select.selected < 0:
		_clear_audio_asset("Audio binding selection is unavailable")
		return
	var binding := audio_binding_select.get_item_text(audio_binding_select.selected).strip_edges().to_lower()
	var cue := audio_draft.cue_for_binding(binding)
	var errors: PackedStringArray = audio_asset_draft.configure_import(file_name, mime_type, binding, cue, bytes)
	if not errors.is_empty():
		_clear_audio_asset(" | ".join(errors))
		return
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_method("store_audio_asset_draft"):
		_clear_audio_asset("Creator preview session cannot store WAV")
		return
	var store_errors: PackedStringArray = session.call("store_audio_asset_draft", audio_asset_draft.to_dictionary(), bytes)
	if not store_errors.is_empty():
		_clear_audio_asset("Preview session rejected WAV: %s" % " | ".join(store_errors))
		return
	audio_asset_bytes = bytes.duplicate()
	audio_asset_error = ""
	audio_asset_revision += 1
	_refresh_audio_asset_status(false)

func _clear_audio_asset(message: String) -> void:
	audio_asset_draft.reset()
	audio_asset_bytes.clear()
	audio_asset_error = message
	audio_asset_revision += 1
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session != null and session.has_method("clear_audio_asset_draft"):
		session.call("clear_audio_asset_draft")
	_refresh_audio_asset_status(false)

func _clear_audio_asset_if_binding_changed(binding_name: String) -> void:
	if audio_asset_bytes.is_empty() or audio_asset_draft.binding != binding_name.strip_edges().to_lower():
		return
	var current_cue := audio_draft.cue_for_binding(binding_name)
	if current_cue != audio_asset_draft.cue_id:
		_clear_audio_asset("WAV cleared because its bound Cue ID changed")

func _refresh_audio_asset_status(increment_revision: bool = true) -> void:
	if increment_revision:
		audio_asset_revision += 1
	if audio_asset_status_label == null:
		return
	if not audio_asset_error.is_empty():
		audio_asset_status_label.text = "WAV INVALID · %s" % audio_asset_error
		audio_asset_status_label.modulate = Color("ff7b86")
	elif not audio_asset_bytes.is_empty():
		audio_asset_status_label.text = "WAV READY · %s → %s · %d ms · %d Hz · %d-bit · %d ch" % [
			audio_asset_draft.binding, audio_asset_draft.cue_id, audio_asset_draft.duration_ms,
			audio_asset_draft.sample_rate, audio_asset_draft.bits_per_sample, audio_asset_draft.channels
		]
		audio_asset_status_label.modulate = Color("7ff0b1")
	else:
		audio_asset_status_label.text = "Optional WAV · PCM only · ≤ 3 s · ≤ 512 KB · package-safe"
		audio_asset_status_label.modulate = Color("8292b3")
	_set_web_state()

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
	animation_draft.load_from_id(character_draft.animation_map)
	animation_draft_revision += 1
	audio_draft.reset()
	audio_draft_revision += 1
	_clear_animation_asset("")
	_clear_audio_asset("")
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

func _validate_character_authoring() -> PackedStringArray:
	var errors: PackedStringArray = character_draft.validate()
	var animation_errors: PackedStringArray = animation_draft.validate()
	for error in animation_errors:
		errors.append("animation draft: %s" % error)
	if animation_draft.map_id != character_draft.animation_map.strip_edges().to_lower():
		errors.append("animation draft id must match character animation_map")
	var audio_errors: PackedStringArray = audio_draft.validate()
	for error in audio_errors:
		errors.append("audio draft: %s" % error)
	return errors

func _refresh_character_validation(increment_revision: bool = true) -> void:
	if increment_revision:
		character_draft_revision += 1
	var errors := _validate_character_authoring()
	var valid := errors.is_empty()
	character_validation_label.text = "VALID · Character draft passes runtime schema" if valid else "INVALID · %s" % " | ".join(errors)
	character_validation_label.modulate = Color("7ff0b1") if valid else Color("ff7b86")
	character_summary_label.text = "Character: %s · %s · HP %d · MP %d · Move %.0f · Anim %s" % [
		character_draft.character_id,
		character_draft.character_name,
		character_draft.max_hp,
		character_draft.max_mp,
		character_draft.move_speed,
		character_draft.animation_map
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
	_web_set_animation_map_callback = JavaScriptBridge.create_callback(_web_set_animation_map)
	_web_set_animation_semantic_callback = JavaScriptBridge.create_callback(_web_set_animation_semantic)
	_web_import_animation_png_callback = JavaScriptBridge.create_callback(_web_import_animation_png)
	_web_import_animation_error_callback = JavaScriptBridge.create_callback(_web_import_animation_error)
	_web_clear_animation_asset_callback = JavaScriptBridge.create_callback(_web_clear_animation_asset)
	_web_set_audio_binding_callback = JavaScriptBridge.create_callback(_web_set_audio_binding)
	_web_import_audio_wav_callback = JavaScriptBridge.create_callback(_web_import_audio_wav)
	_web_import_audio_error_callback = JavaScriptBridge.create_callback(_web_import_audio_error)
	_web_clear_audio_asset_callback = JavaScriptBridge.create_callback(_web_clear_audio_asset)
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
	window.customFighterCreatorSetAnimationMap = _web_set_animation_map_callback
	window.customFighterCreatorSetAnimationSemantic = _web_set_animation_semantic_callback
	window.customFighterCreatorImportAnimationPng = _web_import_animation_png_callback
	window.customFighterCreatorAnimationImportError = _web_import_animation_error_callback
	window.customFighterCreatorClearAnimationAsset = _web_clear_animation_asset_callback
	window.customFighterCreatorSetAudioBinding = _web_set_audio_binding_callback
	window.customFighterCreatorImportWav = _web_import_audio_wav_callback
	window.customFighterCreatorAudioImportError = _web_import_audio_error_callback
	window.customFighterCreatorClearAudioAsset = _web_clear_audio_asset_callback
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

func _web_set_animation_map(args: Array) -> void:
	if args.is_empty():
		return
	animation_map_edit.text = str(args[0])
	_on_animation_map_changed(animation_map_edit.text)

func _web_set_animation_semantic(args: Array) -> void:
	if args.size() < 2:
		return
	var requested_semantic := str(args[0]).strip_edges().to_lower()
	var semantic_index := CharacterAnimationMap.REQUIRED_SEMANTICS.find(requested_semantic)
	if semantic_index < 0:
		return
	animation_semantic_select.select(semantic_index)
	_sync_animation_controls_from_draft()
	animation_id_edit.set_block_signals(true)
	animation_id_edit.text = str(args[1])
	animation_id_edit.set_block_signals(false)
	_on_animation_id_changed(animation_id_edit.text)

func _web_import_animation_png(args: Array) -> void:
	if args.size() < 5:
		_clear_animation_asset("Animation PNG bridge requires name, MIME type, width, height and data URL")
		return
	_import_animation_png_data(str(args[0]), str(args[1]), int(args[2]), int(args[3]), str(args[4]))

func _web_import_animation_error(args: Array) -> void:
	_clear_animation_asset(str(args[0]) if not args.is_empty() else "Browser Animation PNG import failed")

func _web_clear_animation_asset(_args: Array) -> void:
	_clear_animation_asset("")

func _web_set_audio_binding(args: Array) -> void:
	if args.size() < 2:
		return
	var requested_binding := str(args[0]).strip_edges().to_lower()
	var binding_index := CharacterAudioBindings.REQUIRED_BINDINGS.find(requested_binding)
	if binding_index < 0:
		return
	audio_binding_select.select(binding_index)
	_sync_audio_controls_from_draft()
	audio_cue_edit.set_block_signals(true)
	audio_cue_edit.text = str(args[1])
	audio_cue_edit.set_block_signals(false)
	_on_audio_cue_changed(audio_cue_edit.text)

func _web_import_audio_wav(args: Array) -> void:
	if args.size() < 3:
		_clear_audio_asset("WAV bridge requires name, MIME type and data URL")
		return
	_import_audio_wav_data(str(args[0]), str(args[1]), str(args[2]))

func _web_import_audio_error(args: Array) -> void:
	_clear_audio_asset(str(args[0]) if not args.is_empty() else "Browser WAV import failed")

func _web_clear_audio_asset(_args: Array) -> void:
	_clear_audio_asset("")

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
	if current_character_errors.is_empty():
		current_character_errors = _validate_character_authoring()
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
		"document.documentElement.dataset.creatorDraftAnimationMap=%s;" % JSON.stringify(character_draft.animation_map) +
		"document.documentElement.dataset.creatorAnimationDraftRevision='%d';" % animation_draft_revision +
		"document.documentElement.dataset.creatorAnimationDraftValid='%s';" % ("true" if animation_draft.validate().is_empty() else "false") +
		"document.documentElement.dataset.creatorAnimationDraftMapId=%s;" % JSON.stringify(animation_draft.map_id) +
		"document.documentElement.dataset.creatorAnimationDraftSemantic=%s;" % JSON.stringify(animation_semantic_select.get_item_text(animation_semantic_select.selected).strip_edges().to_lower() if animation_semantic_select != null and animation_semantic_select.selected >= 0 else "") +
		"document.documentElement.dataset.creatorAnimationDraftAnimationId=%s;" % JSON.stringify(animation_id_edit.text if animation_id_edit != null else "") +
		"document.documentElement.dataset.creatorAnimationDraftJson=%s;" % JSON.stringify(JSON.stringify(animation_draft.to_dictionary(), "", true)) +
		"document.documentElement.dataset.creatorAnimationAssetRevision='%d';" % animation_asset_revision +
		"document.documentElement.dataset.creatorAnimationAssetValid='%s';" % ("true" if not animation_asset_bytes.is_empty() and animation_asset_error.is_empty() else "false") +
		"document.documentElement.dataset.creatorAnimationAssetError=%s;" % JSON.stringify(animation_asset_error) +
		"document.documentElement.dataset.creatorAnimationAssetSemantic=%s;" % JSON.stringify(animation_asset_draft.semantic) +
		"document.documentElement.dataset.creatorAnimationAssetAnimationId=%s;" % JSON.stringify(animation_asset_draft.animation_id) +
		"document.documentElement.dataset.creatorAnimationAssetFile=%s;" % JSON.stringify(animation_asset_draft.file_name) +
		"document.documentElement.dataset.creatorAnimationAssetBytes='%d';" % animation_asset_bytes.size() +
		"document.documentElement.dataset.creatorAnimationAssetWidth='%d';" % animation_asset_draft.image_width +
		"document.documentElement.dataset.creatorAnimationAssetHeight='%d';" % animation_asset_draft.image_height +
		"document.documentElement.dataset.creatorAnimationAssetFrameCount='%d';" % animation_asset_draft.frame_count +
		"document.documentElement.dataset.creatorAnimationAssetFps='%.3f';" % animation_asset_draft.fps +
		"document.documentElement.dataset.creatorAudioDraftRevision='%d';" % audio_draft_revision +
		"document.documentElement.dataset.creatorAudioDraftValid='%s';" % ("true" if audio_draft.validate().is_empty() else "false") +
		"document.documentElement.dataset.creatorAudioDraftBinding=%s;" % JSON.stringify(audio_binding_select.get_item_text(audio_binding_select.selected).strip_edges().to_lower() if audio_binding_select != null and audio_binding_select.selected >= 0 else "") +
		"document.documentElement.dataset.creatorAudioDraftCue=%s;" % JSON.stringify(audio_cue_edit.text if audio_cue_edit != null else "") +
		"document.documentElement.dataset.creatorAudioDraftJson=%s;" % JSON.stringify(JSON.stringify(audio_draft.to_dictionary(), "", true)) +
		"document.documentElement.dataset.creatorAudioAssetRevision='%d';" % audio_asset_revision +
		"document.documentElement.dataset.creatorAudioAssetValid='%s';" % ("true" if not audio_asset_bytes.is_empty() and audio_asset_error.is_empty() else "false") +
		"document.documentElement.dataset.creatorAudioAssetError=%s;" % JSON.stringify(audio_asset_error) +
		"document.documentElement.dataset.creatorAudioAssetBinding=%s;" % JSON.stringify(audio_asset_draft.binding) +
		"document.documentElement.dataset.creatorAudioAssetCue=%s;" % JSON.stringify(audio_asset_draft.cue_id) +
		"document.documentElement.dataset.creatorAudioAssetFile=%s;" % JSON.stringify(audio_asset_draft.file_name) +
		"document.documentElement.dataset.creatorAudioAssetBytes='%d';" % audio_asset_bytes.size() +
		"document.documentElement.dataset.creatorAudioAssetDurationMs='%d';" % audio_asset_draft.duration_ms +
		"document.documentElement.dataset.creatorAudioAssetSampleRate='%d';" % audio_asset_draft.sample_rate +
		"document.documentElement.dataset.creatorAudioAssetChannels='%d';" % audio_asset_draft.channels +
		"document.documentElement.dataset.creatorAudioAssetBits='%d';" % audio_asset_draft.bits_per_sample +
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
