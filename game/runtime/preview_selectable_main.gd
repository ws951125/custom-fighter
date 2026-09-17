extends "res://game/runtime/selectable_main.gd"

const PreviewCharacterDefinition = preload("res://game/core/character/character_definition.gd")
const PreviewCombatantState = preload("res://game/core/combat/combatant_state.gd")

func _enter_tree() -> void:
	super()
	var session: Variant = _creator_preview_session()
	if not _preview_session_active(session):
		return

	var preview_character := PreviewCharacterDefinition.new()
	var character_data: Dictionary = _preview_character_data(session)
	var preview_errors: PackedStringArray = preview_character.load_from_dictionary(character_data)
	if not preview_errors.is_empty():
		player_character_selection_error = "creator preview rejected: %s" % " | ".join(preview_errors)
		player_character_selection_fallback = true
		_deactivate_preview_session(session)
		push_error(player_character_selection_error)
		return

	player_character = preview_character
	player_requested_character_id = preview_character.character_id
	player_character_source = "creator_preview_session"
	player_character_selection_error = ""
	player_character_selection_fallback = false

	var visual_errors: PackedStringArray = player_visual_profile.load_from_id(player_character.visual_profile)
	if not visual_errors.is_empty():
		player_character_selection_error = "creator preview visual rejected: %s" % " | ".join(visual_errors)
		player_character_selection_fallback = true
		_deactivate_preview_session(session)
		push_error(player_character_selection_error)
		return

	player_state = PreviewCombatantState.new(player_character.max_hp, player_character.max_mp)

func load_character_skill_for_slot(slot_name: String, expected_type: String, target_skill) -> PackedStringArray:
	var session: Variant = _creator_preview_session()
	var preview_slot := _preview_skill_slot(session)
	if not _preview_session_active(session) or preview_slot.is_empty() or slot_name != preview_slot:
		return super(slot_name, expected_type, target_skill)

	var errors: PackedStringArray = PackedStringArray()
	if not player_character.loaded:
		errors.append("player character is not loaded")
	else:
		var skill_data: Dictionary = _preview_skill_data(session)
		errors = target_skill.load_from_dictionary(skill_data)
		if errors.is_empty() and target_skill.skill_type != expected_type:
			errors.append("creator preview skill type mismatch: expected %s, got %s" % [expected_type, target_skill.skill_type])
		if errors.is_empty() and target_skill.skill_id != player_character.skill_id_for_slot(slot_name):
			errors.append("creator preview skill id does not match character %s" % slot_name)

	if errors.is_empty():
		player_runtime_skill_ids[slot_name] = target_skill.skill_id
		player_runtime_skill_sources[slot_name] = "creator_preview_session"
		player_runtime_skill_types[slot_name] = target_skill.skill_type
		player_runtime_skill_errors.erase(slot_name)
	else:
		player_runtime_skill_ids.erase(slot_name)
		player_runtime_skill_sources.erase(slot_name)
		player_runtime_skill_types.erase(slot_name)
		player_runtime_skill_errors[slot_name] = " | ".join(errors)
	return errors

func _set_web_state() -> void:
	super()
	if not OS.has_feature("web"):
		return
	var session: Variant = _creator_preview_session()
	var active: bool = _preview_session_active(session)
	var skill_data: Dictionary = _preview_skill_data(session) if active else {}
	var preview_slot := _preview_skill_slot(session) if active else ""
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorPreviewActive='%s';" % ("true" if active else "false") +
		"document.documentElement.dataset.creatorPreviewRuntimeSkillId=%s;" % JSON.stringify(str(skill_data.get("id", ""))) +
		"document.documentElement.dataset.creatorPreviewRuntimeSkillType=%s;" % JSON.stringify(str(skill_data.get("type", "")).strip_edges().to_lower()) +
		"document.documentElement.dataset.creatorPreviewRuntimeSkillSlot=%s;" % JSON.stringify(preview_slot) +
		"document.documentElement.dataset.creatorPreviewRuntimeSkillDamage='%d';" % int(skill_data.get("damage", 0)) +
		"document.documentElement.dataset.creatorPreviewRuntimeSkillMpCost='%d';" % int(skill_data.get("mp_cost", 0)) +
		"document.documentElement.dataset.creatorPreviewRuntimeSkillCooldown='%.3f';" % float(skill_data.get("cooldown", 0.0)) +
		"document.documentElement.dataset.playerCharacterSkill7=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_7")) +
		"document.documentElement.dataset.playerRuntimeSkill7=%s;" % JSON.stringify(str(player_runtime_skill_ids.get("skill_7", ""))) +
		"document.documentElement.dataset.playerRuntimeSkill7Type=%s;" % JSON.stringify(str(player_runtime_skill_types.get("skill_7", ""))) +
		"document.documentElement.dataset.playerRuntimeSkill7Source=%s;" % JSON.stringify(str(player_runtime_skill_sources.get("skill_7", "")))
	)

func _creator_preview_session() -> Variant:
	return get_node_or_null("/root/CreatorPreviewSession")

func _preview_session_active(session: Variant) -> bool:
	return session != null and session.has_method("has_active_preview") and bool(session.call("has_active_preview"))

func _preview_character_data(session: Variant) -> Dictionary:
	if session == null or not session.has_method("preview_character_data"):
		return {}
	var value: Variant = session.call("preview_character_data")
	return value if typeof(value) == TYPE_DICTIONARY else {}

func _preview_skill_data(session: Variant) -> Dictionary:
	if session == null or not session.has_method("preview_skill_data"):
		return {}
	var value: Variant = session.call("preview_skill_data")
	return value if typeof(value) == TYPE_DICTIONARY else {}

func _preview_skill_slot(session: Variant) -> String:
	if session == null or not session.has_method("preview_skill_slot"):
		return ""
	return str(session.call("preview_skill_slot"))

func _deactivate_preview_session(session: Variant) -> void:
	if session != null and session.has_method("deactivate_preview"):
		session.call("deactivate_preview")
