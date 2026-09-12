extends "res://game/creator/creator_studio.gd"

var preview_status_label: Label
var preview_button: Button
var _web_preview_callback
var _web_set_skill_mp_callback
var _web_set_skill_cooldown_callback

func _ready() -> void:
	super()
	_restore_session_drafts()
	_install_preview_ui()
	_install_preview_web_bridge()
	_set_preview_web_state()

func _restore_session_drafts() -> void:
	var session = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_stored_drafts():
		return
	var character_errors: PackedStringArray = character_draft.load_from_dictionary(session.stored_character_draft_data())
	var skill_errors: PackedStringArray = skill_draft.load_from_dictionary(session.stored_skill_draft_data())
	if not character_errors.is_empty() or not skill_errors.is_empty():
		push_error("Failed to restore Creator preview drafts: %s | %s" % [" | ".join(character_errors), " | ".join(skill_errors)])
		return
	_sync_character_controls_from_draft()
	_sync_skill_controls_from_draft()
	_refresh_character_validation(false)
	_refresh_skill_validation(false)

func _install_preview_ui() -> void:
	preview_status_label = Label.new()
	preview_status_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	preview_status_label.offset_left = -650.0
	preview_status_label.offset_top = -70.0
	preview_status_label.offset_right = -250.0
	preview_status_label.offset_bottom = -30.0
	preview_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preview_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_status_label.text = "Preview uses validated in-memory drafts only"
	preview_status_label.modulate = Color("8fa1c6")
	add_child(preview_status_label)

	preview_button = Button.new()
	preview_button.text = "Preview in Training"
	preview_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	preview_button.offset_left = -230.0
	preview_button.offset_top = -72.0
	preview_button.offset_right = -42.0
	preview_button.offset_bottom = -28.0
	preview_button.pressed.connect(_on_preview_pressed)
	add_child(preview_button)

func _install_preview_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_preview_callback = JavaScriptBridge.create_callback(_web_preview)
	_web_set_skill_mp_callback = JavaScriptBridge.create_callback(_web_set_skill_mp)
	_web_set_skill_cooldown_callback = JavaScriptBridge.create_callback(_web_set_skill_cooldown)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterCreatorPreview = _web_preview_callback
	window.customFighterCreatorSetSkillMpCost = _web_set_skill_mp_callback
	window.customFighterCreatorSetSkillCooldown = _web_set_skill_cooldown_callback

func _on_preview_pressed() -> void:
	var character_errors := character_draft.validate()
	var skill_errors := skill_draft.validate()
	if not character_errors.is_empty() or not skill_errors.is_empty():
		_set_preview_error("Fix invalid Character/Skill drafts before preview")
		return
	var session = get_node_or_null("/root/CreatorPreviewSession")
	if session == null:
		_set_preview_error("Creator preview session is unavailable")
		return
	var stage_errors: PackedStringArray = session.stage_preview(character_draft.to_dictionary(), skill_draft.to_dictionary())
	if not stage_errors.is_empty():
		_set_preview_error(" | ".join(stage_errors))
		return
	preview_status_label.text = "VALID · Opening Training preview"
	preview_status_label.modulate = Color("7ff0b1")
	_set_preview_web_state()
	var router = get_parent()
	if router != null and router.has_method("switch_mode"):
		router.call_deferred("switch_mode", "training")
		return
	_set_preview_error("Application router is unavailable")

func _on_training_pressed() -> void:
	var session = get_node_or_null("/root/CreatorPreviewSession")
	if session != null:
		session.deactivate_preview()
	var router = get_parent()
	if router != null and router.has_method("switch_mode"):
		router.call_deferred("switch_mode", "training")
		return
	super()

func _web_preview(_args: Array) -> void:
	_on_preview_pressed()

func _web_set_skill_mp(args: Array) -> void:
	if args.is_empty():
		return
	var value := int(args[0])
	skill_draft.mp_cost = value
	if value >= int(skill_mp_spin.min_value) and value <= int(skill_mp_spin.max_value):
		skill_mp_spin.value = value
	_refresh_skill_validation()
	_set_preview_web_state()

func _web_set_skill_cooldown(args: Array) -> void:
	if args.is_empty():
		return
	var value := float(args[0])
	skill_draft.cooldown = value
	if value >= cooldown_spin.min_value and value <= cooldown_spin.max_value:
		cooldown_spin.value = value
	_refresh_skill_validation()
	_set_preview_web_state()

func _set_preview_error(message: String) -> void:
	if preview_status_label != null:
		preview_status_label.text = "PREVIEW BLOCKED · %s" % message
		preview_status_label.modulate = Color("ff7b86")
	_set_preview_web_state(message)

func _set_web_state(character_errors: PackedStringArray = PackedStringArray(), skill_errors: PackedStringArray = PackedStringArray()) -> void:
	super(character_errors, skill_errors)
	_set_preview_web_state()

func _set_preview_web_state(error_message: String = "") -> void:
	if not OS.has_feature("web"):
		return
	var session = get_node_or_null("/root/CreatorPreviewSession")
	var session_ready := session != null
	var can_preview := character_draft.is_valid() and skill_draft.is_valid() and session_ready
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorPreviewReady='true';" +
		"document.documentElement.dataset.creatorPreviewCanLaunch='%s';" % ("true" if can_preview else "false") +
		"document.documentElement.dataset.creatorPreviewError=%s;" % JSON.stringify(error_message) +
		"document.documentElement.dataset.creatorPreviewSessionRevision='%d';" % (session.revision if session_ready else 0)
	)
