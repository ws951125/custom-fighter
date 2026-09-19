extends Node

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterVisualProfile = preload("res://game/core/character/character_visual_profile.gd")
const CharacterAnimationMap = preload("res://game/core/character/character_animation_map.gd")
const CharacterAudioBindings = preload("res://game/core/character/character_audio_bindings.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const VfxDraft = preload("res://game/creator/vfx_editor/vfx_draft.gd")
const AiSkillProposal = preload("res://game/ai/skill/ai_skill_proposal.gd")

const PREVIEW_SLOT_BY_TYPE := {
	"projectile": "skill_1",
	"dash": "skill_2",
	"area": "skill_3",
	"formation": "skill_4",
	"buff": "skill_5",
	"melee": "skill_6",
	"beam": "skill_7",
	"trap": "skill_8",
	"aura": "skill_9",
	"teleport": "skill_10",
	"counter": "skill_11",
	"grab": "skill_12",
	"summon": "skill_13"
}
const APPROVED_PREVIEW_VISUAL := "prototype_fireball"
const APPROVED_PREVIEW_IMPACT_VISUAL := "prototype_impact"
const MAX_VFX_PNG_BYTES := 5 * 1024 * 1024

var _draft_character_data: Dictionary = {}
var _draft_skill_data: Dictionary = {}
var _stored_animation_map_data: Dictionary = {}
var _stored_audio_bindings_data: Dictionary = {}
var _stored_vfx_data: Dictionary = {}
var _stored_vfx_png_bytes := PackedByteArray()
var _pending_ai_skill_proposal: Dictionary = {}
var _preview_character_data: Dictionary = {}
var _preview_skill_data: Dictionary = {}
var _preview_animation_map_data: Dictionary = {}
var _preview_audio_bindings_data: Dictionary = {}
var _preview_skill_slot := ""
var _preview_vfx_data: Dictionary = {}
var _preview_vfx_png_bytes := PackedByteArray()
var _preview_active := false
var revision := 0

func store_drafts(character_data: Dictionary, skill_data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = _validate_drafts(character_data, skill_data)
	if not errors.is_empty():
		return errors
	_draft_character_data = character_data.duplicate(true)
	_draft_skill_data = skill_data.duplicate(true)
	revision += 1
	return PackedStringArray()

func stage_preview(character_data: Dictionary, skill_data: Dictionary, animation_map_data: Dictionary = {}, audio_bindings_data: Dictionary = {}) -> PackedStringArray:
	var errors: PackedStringArray = _validate_drafts(character_data, skill_data)
	if not errors.is_empty():
		_deactivate_failed_preview()
		return errors

	var preview_character: Dictionary = character_data.duplicate(true)
	var preview_skill: Dictionary = skill_data.duplicate(true)
	var preview_type := str(preview_skill.get("type", "")).strip_edges().to_lower()
	var preview_slot := preview_slot_for_type(preview_type)
	if preview_slot.is_empty():
		errors.append("skill: creator preview has no runtime slot for type: %s" % preview_type)
		_deactivate_failed_preview()
		return errors

	var preview_slots: Dictionary = preview_character.get("skill_slots", {}).duplicate(true)
	preview_slots[preview_slot] = str(preview_skill.get("id", "")).strip_edges().to_lower()
	preview_character["skill_slots"] = preview_slots

	var preview_definition := CharacterDefinition.new()
	var preview_errors: PackedStringArray = preview_definition.load_from_dictionary(preview_character)
	if not preview_errors.is_empty():
		_deactivate_failed_preview()
		return preview_errors

	if not animation_map_data.is_empty():
		var animation_errors: PackedStringArray = _validate_animation_map_payload(animation_map_data, preview_definition.animation_map)
		for error in animation_errors:
			errors.append("character animation: %s" % error)
		if not errors.is_empty():
			_deactivate_failed_preview()
			return errors

	if not audio_bindings_data.is_empty():
		var audio_errors: PackedStringArray = _validate_audio_bindings_payload(audio_bindings_data)
		for error in audio_errors:
			errors.append("character audio: %s" % error)
		if not errors.is_empty():
			_deactivate_failed_preview()
			return errors

	if preview_type == "projectile" and has_stored_vfx():
		var vfx_errors: PackedStringArray = _validate_vfx_payload(_stored_vfx_data, _stored_vfx_png_bytes)
		for error in vfx_errors:
			errors.append("vfx: %s" % error)
		if not errors.is_empty():
			_deactivate_failed_preview()
			return errors

	_draft_character_data = character_data.duplicate(true)
	_draft_skill_data = skill_data.duplicate(true)
	if animation_map_data.is_empty():
		_stored_animation_map_data.clear()
		_preview_animation_map_data.clear()
	else:
		_stored_animation_map_data = animation_map_data.duplicate(true)
		_preview_animation_map_data = animation_map_data.duplicate(true)
	if audio_bindings_data.is_empty():
		_stored_audio_bindings_data.clear()
		_preview_audio_bindings_data.clear()
	else:
		_stored_audio_bindings_data = audio_bindings_data.duplicate(true)
		_preview_audio_bindings_data = audio_bindings_data.duplicate(true)
	_preview_character_data = preview_character
	_preview_skill_data = preview_skill
	_preview_skill_slot = preview_slot
	if preview_type == "projectile" and has_stored_vfx():
		_preview_vfx_data = _stored_vfx_data.duplicate(true)
		_preview_vfx_png_bytes = _stored_vfx_png_bytes.duplicate()
	else:
		_clear_preview_vfx()
	_preview_active = true
	revision += 1
	return PackedStringArray()

func store_animation_map_draft(animation_map_data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = _validate_animation_map_payload(animation_map_data)
	if not errors.is_empty():
		_stored_animation_map_data.clear()
		_preview_animation_map_data.clear()
		return errors
	_stored_animation_map_data = animation_map_data.duplicate(true)
	if not _preview_active:
		_preview_animation_map_data.clear()
	revision += 1
	return PackedStringArray()

func store_audio_bindings_draft(audio_bindings_data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = _validate_audio_bindings_payload(audio_bindings_data)
	if not errors.is_empty():
		_stored_audio_bindings_data.clear()
		_preview_audio_bindings_data.clear()
		return errors
	_stored_audio_bindings_data = audio_bindings_data.duplicate(true)
	if not _preview_active:
		_preview_audio_bindings_data.clear()
	revision += 1
	return PackedStringArray()

func store_vfx_draft(vfx_data: Dictionary, png_bytes: PackedByteArray) -> PackedStringArray:
	var errors: PackedStringArray = _validate_vfx_payload(vfx_data, png_bytes)
	if not errors.is_empty():
		clear_vfx_draft()
		return errors
	_stored_vfx_data = vfx_data.duplicate(true)
	_stored_vfx_png_bytes = png_bytes.duplicate()
	if not _preview_active:
		_clear_preview_vfx()
	revision += 1
	return PackedStringArray()

func store_ai_skill_proposal(proposal_data: Dictionary) -> PackedStringArray:
	var proposal := AiSkillProposal.new()
	var errors: PackedStringArray = proposal.load_from_dictionary(proposal_data)
	if not errors.is_empty():
		_pending_ai_skill_proposal.clear()
		return errors
	_pending_ai_skill_proposal = proposal_data.duplicate(true)
	revision += 1
	return PackedStringArray()

func has_pending_ai_skill_proposal() -> bool:
	return not _pending_ai_skill_proposal.is_empty()

func take_pending_ai_skill_proposal() -> Dictionary:
	var proposal := _pending_ai_skill_proposal.duplicate(true)
	_pending_ai_skill_proposal.clear()
	if not proposal.is_empty():
		revision += 1
	return proposal

func clear_vfx_draft() -> void:
	_stored_vfx_data.clear()
	_stored_vfx_png_bytes.clear()
	_clear_preview_vfx()
	revision += 1

func preview_slot_for_type(skill_type: String) -> String:
	return str(PREVIEW_SLOT_BY_TYPE.get(skill_type.strip_edges().to_lower(), ""))

func _validate_drafts(character_data: Dictionary, skill_data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var character_definition := CharacterDefinition.new()
	var character_errors: PackedStringArray = character_definition.load_from_dictionary(character_data)
	for error in character_errors:
		errors.append("character: %s" % error)

	var skill_definition := SkillDefinition.new()
	var skill_errors: PackedStringArray = skill_definition.load_from_dictionary(skill_data)
	for error in skill_errors:
		errors.append("skill: %s" % error)

	if not skill_errors.is_empty():
		return errors
	if not _is_safe_token(skill_definition.skill_id):
		errors.append("skill: id must be a safe lowercase reference token")
	if preview_slot_for_type(skill_definition.skill_type).is_empty():
		errors.append("skill: creator preview has no runtime slot for type: %s" % skill_definition.skill_type)
	if skill_definition.visual != APPROVED_PREVIEW_VISUAL:
		errors.append("skill: unsupported preview visual")
	if skill_definition.impact_visual != APPROVED_PREVIEW_IMPACT_VISUAL:
		errors.append("skill: unsupported preview impact visual")

	if character_errors.is_empty():
		var profile := CharacterVisualProfile.new()
		var profile_errors: PackedStringArray = profile.load_from_id(character_definition.visual_profile)
		for error in profile_errors:
			errors.append("character visual: %s" % error)
		var animation_map := CharacterAnimationMap.new()
		var animation_errors: PackedStringArray = animation_map.load_from_id(character_definition.animation_map)
		for error in animation_errors:
			errors.append("character animation: %s" % error)
	return errors

func _validate_animation_map_payload(animation_map_data: Dictionary, expected_id: String = "") -> PackedStringArray:
	var animation_map := CharacterAnimationMap.new()
	var errors: PackedStringArray = animation_map.load_from_dictionary(animation_map_data)
	if not errors.is_empty():
		return errors
	var normalized_expected := expected_id.strip_edges().to_lower()
	if not normalized_expected.is_empty() and animation_map.map_id != normalized_expected:
		errors.append("animation map id must match character animation_map")
	return errors

func _validate_audio_bindings_payload(audio_bindings_data: Dictionary) -> PackedStringArray:
	var bindings := CharacterAudioBindings.new()
	return bindings.load_from_dictionary(audio_bindings_data)

func _validate_vfx_payload(vfx_data: Dictionary, png_bytes: PackedByteArray) -> PackedStringArray:
	var errors := PackedStringArray()
	var draft := VfxDraft.new()
	var draft_errors: PackedStringArray = draft.load_from_dictionary(vfx_data)
	for error in draft_errors:
		errors.append(error)
	if png_bytes.is_empty():
		errors.append("PNG bytes must not be empty")
		return errors
	if png_bytes.size() > MAX_VFX_PNG_BYTES:
		errors.append("PNG exceeds 5 MB in-memory preview limit")
		return errors

	var image := Image.new()
	var decode_error: Error = image.load_png_from_buffer(png_bytes)
	if decode_error != OK:
		errors.append("PNG bytes failed runtime decode")
		return errors
	if image.get_width() != draft.image_width or image.get_height() != draft.image_height:
		errors.append("decoded PNG dimensions do not match VFX metadata")
	return errors

func has_active_preview() -> bool:
	return (
		_preview_active
		and not _preview_character_data.is_empty()
		and not _preview_skill_data.is_empty()
		and not _preview_skill_slot.is_empty()
	)

func has_stored_drafts() -> bool:
	return not _draft_character_data.is_empty() and not _draft_skill_data.is_empty()

func has_stored_animation_map() -> bool:
	return not _stored_animation_map_data.is_empty()

func has_active_animation_preview() -> bool:
	return has_active_preview() and not _preview_animation_map_data.is_empty()

func has_stored_audio_bindings() -> bool:
	return not _stored_audio_bindings_data.is_empty()

func has_active_audio_bindings_preview() -> bool:
	return has_active_preview() and not _preview_audio_bindings_data.is_empty()

func has_stored_vfx() -> bool:
	return not _stored_vfx_data.is_empty() and not _stored_vfx_png_bytes.is_empty()

func has_active_vfx_preview() -> bool:
	return has_active_preview() and not _preview_vfx_data.is_empty() and not _preview_vfx_png_bytes.is_empty()

func preview_character_data() -> Dictionary:
	return _preview_character_data.duplicate(true)

func preview_skill_data() -> Dictionary:
	return _preview_skill_data.duplicate(true)

func preview_skill_type() -> String:
	if not has_active_preview():
		return ""
	return str(_preview_skill_data.get("type", "")).strip_edges().to_lower()

func preview_skill_slot() -> String:
	return _preview_skill_slot if has_active_preview() else ""

func preview_animation_map_data() -> Dictionary:
	return _preview_animation_map_data.duplicate(true)

func preview_audio_bindings_data() -> Dictionary:
	return _preview_audio_bindings_data.duplicate(true)

func preview_vfx_data() -> Dictionary:
	return _preview_vfx_data.duplicate(true)

func preview_vfx_png_bytes() -> PackedByteArray:
	return _preview_vfx_png_bytes.duplicate()

func stored_character_draft_data() -> Dictionary:
	return _draft_character_data.duplicate(true)

func stored_skill_draft_data() -> Dictionary:
	return _draft_skill_data.duplicate(true)

func stored_animation_map_data() -> Dictionary:
	return _stored_animation_map_data.duplicate(true)

func stored_audio_bindings_data() -> Dictionary:
	return _stored_audio_bindings_data.duplicate(true)

func stored_vfx_data() -> Dictionary:
	return _stored_vfx_data.duplicate(true)

func stored_vfx_png_bytes() -> PackedByteArray:
	return _stored_vfx_png_bytes.duplicate()

func deactivate_preview() -> void:
	_preview_active = false
	_preview_skill_slot = ""
	_preview_animation_map_data.clear()
	_preview_audio_bindings_data.clear()
	_clear_preview_vfx()

func clear() -> void:
	_draft_character_data.clear()
	_draft_skill_data.clear()
	_stored_animation_map_data.clear()
	_stored_audio_bindings_data.clear()
	_stored_vfx_data.clear()
	_stored_vfx_png_bytes.clear()
	_pending_ai_skill_proposal.clear()
	_preview_character_data.clear()
	_preview_skill_data.clear()
	_preview_animation_map_data.clear()
	_preview_audio_bindings_data.clear()
	_preview_skill_slot = ""
	_clear_preview_vfx()
	_preview_active = false
	revision += 1

func _deactivate_failed_preview() -> void:
	_preview_active = false
	_preview_skill_slot = ""
	_preview_animation_map_data.clear()
	_preview_audio_bindings_data.clear()
	_clear_preview_vfx()

func _clear_preview_vfx() -> void:
	_preview_vfx_data.clear()
	_preview_vfx_png_bytes.clear()

func _is_safe_token(value: String) -> bool:
	if value.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null
