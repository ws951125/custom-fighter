extends "res://game/creator/creator_studio.gd"

var preview_status_label: Label
var preview_button: Button
var vfx_button: Button
var _web_preview_callback
var _web_set_skill_mp_callback
var _web_set_skill_cooldown_callback
var _web_open_vfx_callback

func _ready() -> void:
	super()
	_restore_session_drafts()
	_install_preview_ui()
	_refresh_preview_binding_status()
	_install_preview_web_bridge()
	_set_preview_web_state()

func _restore_session_drafts() -> void:
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_method("has_stored_drafts") or not bool(session.call("has_stored_drafts")):
		return
	var character_data: Dictionary = session.call("stored_character_draft_data")
	var skill_data: Dictionary = session.call("stored_skill_draft_data")
	var character_errors: PackedStringArray = character_draft.load_from_dictionary(character_data)
	var skill_errors: PackedStringArray = skill_draft.load_from_dictionary(skill_data)
	var animation_errors := PackedStringArray()
	if session.has_method("has_stored_animation_map") and bool(session.call("has_stored_animation_map")) and session.has_method("stored_animation_map_data"):
		animation_errors = animation_draft.load_from_dictionary(session.call("stored_animation_map_data"))
	else:
		animation_errors = animation_draft.load_from_id(character_draft.animation_map)
	if not character_errors.is_empty() or not skill_errors.is_empty() or not animation_errors.is_empty():
		push_error("Failed to restore Creator preview drafts: %s | %s | %s" % [" | ".join(character_errors), " | ".join(skill_errors), " | ".join(animation_errors)])
		return
	_sync_character_controls_from_draft()
	_sync_skill_controls_from_draft()
	_refresh_character_validation(false)
	_refresh_skill_validation(false)

func _install_preview_ui() -> void:
	vfx_button = Button.new()
	vfx_button.text = "VFX Creator"
	vfx_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	vfx_button.offset_left = 42.0
	vfx_button.offset_top = -72.0
	vfx_button.offset_right = 190.0
	vfx_button.offset_bottom = -28.0
	vfx_button.pressed.connect(_on_vfx_pressed)
	add_child(vfx_button)

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

func _refresh_preview_binding_status() -> void:
	if preview_status_label == null:
		return
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	var vfx_bound := false
	if session != null and session.has_method("has_stored_vfx"):
		vfx_bound = bool(session.call("has_stored_vfx"))
	preview_status_label.text = "VALID VFX bound to Skill 1 · Preview uses in-memory drafts" if vfx_bound else "Preview uses validated in-memory drafts · prototype VFX fallback"
	preview_status_label.modulate = Color("7ff0b1") if vfx_bound else Color("8fa1c6")

func _install_preview_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_preview_callback = JavaScriptBridge.create_callback(_web_preview)
	_web_set_skill_mp_callback = JavaScriptBridge.create_callback(_web_set_skill_mp)
	_web_set_skill_cooldown_callback = JavaScriptBridge.create_callback(_web_set_skill_cooldown)
	_web_open_vfx_callback = JavaScriptBridge.create_callback(_web_open_vfx)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterCreatorPreview = _web_preview_callback
	window.customFighterCreatorSetSkillMpCost = _web_set_skill_mp_callback
	window.customFighterCreatorSetSkillCooldown = _web_set_skill_cooldown_callback
	window.customFighterCreatorOpenVfx = _web_open_vfx_callback

func _on_preview_pressed() -> void:
	var character_errors := _validate_character_authoring()
	var skill_errors := skill_draft.validate()
	if not character_errors.is_empty() or not skill_errors.is_empty():
		_set_preview_error("Fix invalid Character/Skill drafts before preview")
		return
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session == null:
		_set_preview_error("Creator preview session is unavailable")
		return
	var stage_errors: PackedStringArray = session.call("stage_preview", character_draft.to_dictionary(), skill_draft.to_dictionary(), animation_draft.to_dictionary())
	if not stage_errors.is_empty():
		_set_preview_error(" | ".join(stage_errors))
		return
	preview_status_label.text = "VALID · Opening Training preview"
	preview_status_label.modulate = Color("7ff0b1")
	_set_preview_web_state()
	var router: Variant = get_parent()
	if router != null and router.has_method("switch_mode"):
		router.call_deferred("switch_mode", "training")
		return
	_set_preview_error("Application router is unavailable")

func _on_vfx_pressed() -> void:
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_method("store_drafts"):
		_set_preview_error("Creator preview session cannot preserve drafts for VFX editing")
		return
	var animation_store_errors: PackedStringArray = session.call("store_animation_map_draft", animation_draft.to_dictionary()) if session.has_method("store_animation_map_draft") else PackedStringArray(["Creator preview session cannot preserve animation draft"])
	if not animation_store_errors.is_empty():
		_set_preview_error("Fix invalid Animation draft before opening VFX Creator")
		return
	var store_errors: PackedStringArray = session.call("store_drafts", character_draft.to_dictionary(), skill_draft.to_dictionary())
	if not store_errors.is_empty():
		_set_preview_error("Fix invalid Character/Skill drafts before opening VFX Creator")
		return
	var router: Variant = get_parent()
	if router != null and router.has_method("switch_mode"):
		router.call_deferred("switch_mode", "vfx")
		return
	_set_preview_error("Application router is unavailable")

func _on_training_pressed() -> void:
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session != null and session.has_method("deactivate_preview"):
		session.call("deactivate_preview")
	var router: Variant = get_parent()
	if router != null and router.has_method("switch_mode"):
		router.call_deferred("switch_mode", "training")
		return
	super()

func _web_preview(_args: Array) -> void:
	_on_preview_pressed()

func _web_open_vfx(_args: Array) -> void:
	_on_vfx_pressed()

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
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	var session_ready := session != null
	var can_preview := character_draft.is_valid() and skill_draft.is_valid() and session_ready
	var vfx_bound := false
	var vfx_frame_count := 0
	var vfx_scale := 1.0
	var vfx_offset_x := 0.0
	var vfx_offset_y := 0.0
	if session_ready and session.has_method("has_stored_vfx"):
		vfx_bound = bool(session.call("has_stored_vfx"))
	if vfx_bound and session.has_method("stored_vfx_data"):
		var vfx_data: Dictionary = session.call("stored_vfx_data")
		vfx_frame_count = int(vfx_data.get("frame_count", 0))
		vfx_scale = float(vfx_data.get("scale", 1.0))
		var offset_value: Variant = vfx_data.get("offset", {})
		if offset_value is Dictionary:
			var offset: Dictionary = offset_value
			vfx_offset_x = float(offset.get("x", 0.0))
			vfx_offset_y = float(offset.get("y", 0.0))
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorPreviewReady='true';" +
		"document.documentElement.dataset.creatorPreviewCanLaunch='%s';" % ("true" if can_preview else "false") +
		"document.documentElement.dataset.creatorVfxNavigationReady='true';" +
		"document.documentElement.dataset.creatorPreviewVfxBound='%s';" % ("true" if vfx_bound else "false") +
		"document.documentElement.dataset.creatorPreviewVfxFrameCount='%d';" % vfx_frame_count +
		"document.documentElement.dataset.creatorPreviewVfxScale='%.3f';" % vfx_scale +
		"document.documentElement.dataset.creatorPreviewVfxOffsetX='%.3f';" % vfx_offset_x +
		"document.documentElement.dataset.creatorPreviewVfxOffsetY='%.3f';" % vfx_offset_y +
		"document.documentElement.dataset.creatorPreviewError=%s;" % JSON.stringify(error_message) +
		"document.documentElement.dataset.creatorPreviewSessionRevision='%d';" % (int(session.get("revision")) if session_ready else 0)
	)
