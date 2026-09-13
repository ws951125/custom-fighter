extends "res://game/creator/package_vfx_creator_studio.gd"

const AiSkillProposalScript = preload("res://game/ai/skill/ai_skill_proposal.gd")

var ai_skill_proposal: Variant = AiSkillProposalScript.new()
var ai_proposal_panel: PanelContainer
var ai_proposal_summary: Label
var ai_proposal_status: Label
var ai_proposal_apply_button: Button
var ai_proposal_discard_button: Button
var _web_stage_ai_proposal_callback
var _web_confirm_ai_proposal_callback
var _web_discard_ai_proposal_callback

func _ready() -> void:
	super()
	_install_ai_proposal_ui()
	_install_ai_proposal_web_bridge()
	_restore_pending_ai_proposal()
	_set_ai_proposal_web_state()

func _restore_pending_ai_proposal() -> void:
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_method("has_pending_ai_skill_proposal"):
		return
	if not bool(session.call("has_pending_ai_skill_proposal")):
		return
	var proposal: Dictionary = session.call("take_pending_ai_skill_proposal")
	var errors: PackedStringArray = stage_ai_skill_proposal(proposal)
	if not errors.is_empty():
		_set_ai_proposal_web_state(" | ".join(errors))

func _install_ai_proposal_ui() -> void:
	ai_proposal_panel = PanelContainer.new()
	ai_proposal_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ai_proposal_panel.offset_left = 42.0
	ai_proposal_panel.offset_top = -172.0
	ai_proposal_panel.offset_right = -42.0
	ai_proposal_panel.offset_bottom = -84.0
	ai_proposal_panel.visible = false
	add_child(ai_proposal_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	ai_proposal_panel.add_child(row)
	ai_proposal_summary = Label.new()
	ai_proposal_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_proposal_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(ai_proposal_summary)
	ai_proposal_status = Label.new()
	ai_proposal_status.custom_minimum_size = Vector2(220, 0)
	ai_proposal_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(ai_proposal_status)
	ai_proposal_apply_button = Button.new()
	ai_proposal_apply_button.text = "Confirm & Apply"
	ai_proposal_apply_button.pressed.connect(_on_confirm_ai_proposal)
	row.add_child(ai_proposal_apply_button)
	ai_proposal_discard_button = Button.new()
	ai_proposal_discard_button.text = "Discard"
	ai_proposal_discard_button.pressed.connect(_on_discard_ai_proposal)
	row.add_child(ai_proposal_discard_button)

func stage_ai_skill_proposal(data: Dictionary) -> PackedStringArray:
	var proposal := AiSkillProposalScript.new()
	var errors: PackedStringArray = proposal.load_from_dictionary(data)
	if not errors.is_empty():
		return errors
	if proposal.skill_type != "projectile":
		errors.append("Creator Skill Editor currently accepts projectile proposals only")
		return errors
	ai_skill_proposal = proposal
	_refresh_ai_proposal_ui()
	_set_ai_proposal_web_state()
	return PackedStringArray()

func _refresh_ai_proposal_ui() -> void:
	if ai_proposal_panel == null:
		return
	var valid: bool = ai_skill_proposal != null and ai_skill_proposal.validate().is_empty()
	ai_proposal_panel.visible = valid
	if not valid:
		return
	ai_proposal_summary.text = "%s · DMG %d · MP %d · CD %.2fs · SPD %.0f · RNG %.0f\n%s" % [ai_skill_proposal.skill_name, ai_skill_proposal.damage, ai_skill_proposal.mp_cost, ai_skill_proposal.cooldown, ai_skill_proposal.speed, ai_skill_proposal.range, ai_skill_proposal.rationale]
	ai_proposal_status.text = "REVIEW REQUIRED"
	ai_proposal_status.modulate = Color("f6cc69")
	ai_proposal_apply_button.disabled = false

func _on_confirm_ai_proposal() -> void:
	if ai_skill_proposal == null:
		return
	var confirm_errors: PackedStringArray = ai_skill_proposal.confirm()
	if not confirm_errors.is_empty() or not ai_skill_proposal.can_apply():
		ai_proposal_status.text = "BLOCKED · invalid proposal"
		ai_proposal_status.modulate = Color("ff7b86")
		_set_ai_proposal_web_state("invalid proposal")
		return
	var apply_errors: PackedStringArray = skill_draft.load_from_dictionary(ai_skill_proposal.to_skill_dictionary())
	if not apply_errors.is_empty():
		ai_skill_proposal.revoke_confirmation()
		ai_proposal_status.text = "BLOCKED · SkillDraft rejected"
		ai_proposal_status.modulate = Color("ff7b86")
		_set_ai_proposal_web_state("SkillDraft rejected proposal")
		return
	_sync_skill_controls_from_draft()
	_refresh_skill_validation(false)
	skill_draft_revision += 1
	ai_proposal_status.text = "APPLIED · user confirmed"
	ai_proposal_status.modulate = Color("7ff0b1")
	ai_proposal_apply_button.disabled = true
	_set_web_state()
	_set_ai_proposal_web_state()

func _on_discard_ai_proposal() -> void:
	if ai_skill_proposal != null:
		ai_skill_proposal.revoke_confirmation()
	ai_skill_proposal = AiSkillProposalScript.new()
	if ai_proposal_panel != null:
		ai_proposal_panel.visible = false
	_set_ai_proposal_web_state()

func _install_ai_proposal_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_stage_ai_proposal_callback = JavaScriptBridge.create_callback(_web_stage_ai_proposal)
	_web_confirm_ai_proposal_callback = JavaScriptBridge.create_callback(_web_confirm_ai_proposal)
	_web_discard_ai_proposal_callback = JavaScriptBridge.create_callback(_web_discard_ai_proposal)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterCreatorStageAiSkillProposal = _web_stage_ai_proposal_callback
	window.customFighterCreatorConfirmAiSkillProposal = _web_confirm_ai_proposal_callback
	window.customFighterCreatorDiscardAiSkillProposal = _web_discard_ai_proposal_callback

func _web_stage_ai_proposal(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not parsed is Dictionary:
		_set_ai_proposal_web_state("proposal JSON must contain one object")
		return
	var errors: PackedStringArray = stage_ai_skill_proposal(parsed)
	_set_ai_proposal_web_state(" | ".join(errors))

func _web_confirm_ai_proposal(_args: Array) -> void:
	_on_confirm_ai_proposal()

func _web_discard_ai_proposal(_args: Array) -> void:
	_on_discard_ai_proposal()

func _set_ai_proposal_web_state(error_message: String = "") -> void:
	if not OS.has_feature("web"):
		return
	var valid: bool = ai_skill_proposal != null and ai_skill_proposal.validate().is_empty()
	var confirmed: bool = valid and bool(ai_skill_proposal.user_confirmed)
	var applied: bool = valid and confirmed and ai_proposal_apply_button != null and ai_proposal_apply_button.disabled
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorAiSkillProposalReady='true';" +
		"document.documentElement.dataset.creatorAiSkillProposalValid='%s';" % ("true" if valid else "false") +
		"document.documentElement.dataset.creatorAiSkillProposalConfirmed='%s';" % ("true" if confirmed else "false") +
		"document.documentElement.dataset.creatorAiSkillProposalApplied='%s';" % ("true" if applied else "false") +
		"document.documentElement.dataset.creatorAiSkillProposalError=%s;" % JSON.stringify(error_message)
	)
