extends SceneTree

const CreatorPreviewSession = preload("res://game/creator/preview/creator_preview_session.gd")
const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const CharacterAnimationMap = preload("res://game/core/character/character_animation_map.gd")
const CharacterAudioBindings = preload("res://game/core/character/character_audio_bindings.gd")
const CharacterAudioAssetDraft = preload("res://game/creator/character_editor/character_audio_asset_draft.gd")
const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")
const VfxDraft = preload("res://game/creator/vfx_editor/vfx_draft.gd")

const FAMILY_SLOT_MAP := {
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

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := CreatorPreviewSession.new()
	var character := CharacterDraft.new()
	var skill := SkillDraft.new()
	character.character_name = "Preview Nova"
	character.max_hp = 180
	skill.skill_name = "Nova Bolt"
	skill.damage = 33
	skill.mp_cost = 17
	skill.cooldown = 2.4

	var errors: PackedStringArray = session.stage_preview(character.to_dictionary(), skill.to_dictionary())
	_check(errors.is_empty(), "valid Creator drafts stage successfully")
	_check(session.has_active_preview(), "valid stage activates preview")
	_check(session.has_stored_drafts(), "valid stage retains editable drafts")
	_check(session.preview_skill_type() == "projectile", "preview reports projectile family")
	_check(session.preview_skill_slot() == "skill_1", "projectile preview resolves to skill_1")
	_check(str(session.preview_character_data().get("skill_slots", {}).get("skill_1", "")) == "my_projectile_001", "preview character binds authored projectile to skill_1")
	_check(int(session.preview_character_data().get("stats", {}).get("max_hp", 0)) == 180, "preview character carries authored HP")
	_check(int(session.preview_skill_data().get("damage", 0)) == 33, "preview skill carries authored damage")
	_check(int(session.preview_skill_data().get("mp_cost", 0)) == 17, "preview skill carries authored MP cost")
	_check(absf(float(session.preview_skill_data().get("cooldown", 0.0)) - 2.4) < 0.001, "preview skill carries authored cooldown")
	_check(str(session.stored_character_draft_data().get("skill_slots", {}).get("skill_1", "")) == "fireball_001", "stored editable CharacterDraft is not mutated by preview binding")

	var animation_map := CharacterAnimationMap.new()
	var animation_load_errors: PackedStringArray = animation_map.load_from_id("ember_vanguard")
	_check(animation_load_errors.is_empty(), "trusted animation map loads for preview-session test")
	var authored_animation_data: Dictionary = {
		"schema_version": CharacterAnimationMap.CURRENT_SCHEMA_VERSION,
		"id": animation_map.map_id,
		"animations": animation_map.animations.duplicate(true)
	}
	var authored_animations: Dictionary = authored_animation_data.get("animations", {}).duplicate(true)
	authored_animations["ready"] = "preview_ready_custom"
	authored_animation_data["animations"] = authored_animations
	var authored_animation_errors: PackedStringArray = session.stage_preview(
		character.to_dictionary(),
		skill.to_dictionary(),
		authored_animation_data
	)
	_check(authored_animation_errors.is_empty(), "validated per-semantic animation mapping stages in Creator Preview")
	_check(session.has_active_animation_preview(), "staged semantic mapping activates animation preview override")
	_check(session.has_stored_animation_map(), "staged semantic mapping is preserved in session")
	_check(
		str(session.preview_animation_map_data().get("animations", {}).get("ready", "")) == "preview_ready_custom",
		"preview session preserves authored ready animation token"
	)

	var authored_audio_data: Dictionary = CharacterAudioBindings.default_dictionary()
	var authored_audio_cues: Dictionary = authored_audio_data.get("cues", {}).duplicate(true)
	authored_audio_cues["skill_cast"] = "preview_cast_custom"
	authored_audio_data["cues"] = authored_audio_cues
	var authored_audio_errors: PackedStringArray = session.stage_preview(
		character.to_dictionary(),
		skill.to_dictionary(),
		authored_animation_data,
		authored_audio_data
	)
	_check(authored_audio_errors.is_empty(), "validated audio cue bindings stage in Creator Preview")
	_check(session.has_active_audio_bindings_preview(), "staged audio bindings activate preview override")
	_check(session.has_stored_audio_bindings(), "staged audio bindings are preserved in session")
	_check(
		str(session.preview_audio_bindings_data().get("cues", {}).get("skill_cast", "")) == "preview_cast_custom",
		"preview session preserves authored skill_cast cue"
	)

	var unsafe_audio_data: Dictionary = authored_audio_data.duplicate(true)
	var unsafe_audio_cues: Dictionary = unsafe_audio_data.get("cues", {}).duplicate(true)
	unsafe_audio_cues["skill_cast"] = "../evil.wav"
	unsafe_audio_data["cues"] = unsafe_audio_cues
	var unsafe_audio_errors: PackedStringArray = session.stage_preview(
		character.to_dictionary(),
		skill.to_dictionary(),
		authored_animation_data,
		unsafe_audio_data
	)
	_check(_contains_fragment(unsafe_audio_errors, "safe lowercase token"), "unsafe audio cue fails closed in preview session")
	_check(not session.has_active_preview(), "unsafe audio bindings cannot activate preview")
	_check(not session.has_active_audio_bindings_preview(), "unsafe audio bindings clear stale active audio override")

	var restore_audio_errors: PackedStringArray = session.stage_preview(
		character.to_dictionary(),
		skill.to_dictionary(),
		authored_animation_data,
		authored_audio_data
	)
	_check(restore_audio_errors.is_empty() and session.has_active_audio_bindings_preview(), "valid audio preview restores after fail-closed case")

	var wav_bytes := _pcm_wav(8000, 1, 8, 800)
	var audio_asset := CharacterAudioAssetDraft.new()
	var audio_asset_errors: PackedStringArray = audio_asset.configure_import(
		"preview-cast.wav", "audio/wav", "skill_cast", "preview_cast_custom", wav_bytes
	)
	_check(audio_asset_errors.is_empty(), "test WAV asset validates before session storage")
	var store_audio_asset_errors: PackedStringArray = session.store_audio_asset_draft(audio_asset.to_dictionary(), wav_bytes)
	_check(store_audio_asset_errors.is_empty(), "validated WAV audio asset stores in preview session")
	_check(session.has_stored_audio_asset(), "stored WAV audio asset is available across Creator/Preview navigation")
	_check(str(session.stored_audio_asset_data().get("binding", "")) == "skill_cast", "stored WAV keeps binding metadata")
	_check(str(session.stored_audio_asset_data().get("cue_id", "")) == "preview_cast_custom", "stored WAV keeps cue token metadata")
	_check(session.stored_audio_asset_bytes().size() == wav_bytes.size(), "stored WAV keeps bytes in memory")

	var tampered_wav := wav_bytes.duplicate()
	tampered_wav[4] = 0
	var tampered_store_errors: PackedStringArray = session.store_audio_asset_draft(audio_asset.to_dictionary(), tampered_wav)
	_check(not tampered_store_errors.is_empty(), "tampered WAV bytes fail closed in preview session")
	_check(not session.has_stored_audio_asset(), "invalid WAV clears stale stored audio asset")

	var restore_asset_errors: PackedStringArray = session.store_audio_asset_draft(audio_asset.to_dictionary(), wav_bytes)
	_check(restore_asset_errors.is_empty() and session.has_stored_audio_asset(), "valid WAV can be restored after fail-closed case")

	var mismatched_animation_data: Dictionary = authored_animation_data.duplicate(true)
	mismatched_animation_data["id"] = "storm_duelist"
	var mismatch_errors: PackedStringArray = session.stage_preview(
		character.to_dictionary(),
		skill.to_dictionary(),
		mismatched_animation_data
	)
	_check(_contains_fragment(mismatch_errors, "animation map id must match character animation_map"), "mismatched animation map id fails closed")
	_check(not session.has_active_preview(), "mismatched animation map deactivates failed preview")
	_check(not session.has_active_animation_preview(), "mismatched animation map clears stale active animation override")

	var unsafe_animation_data: Dictionary = authored_animation_data.duplicate(true)
	var unsafe_animations: Dictionary = unsafe_animation_data.get("animations", {}).duplicate(true)
	unsafe_animations["attack_1"] = "../evil.gd"
	unsafe_animation_data["animations"] = unsafe_animations
	var unsafe_animation_errors: PackedStringArray = session.stage_preview(
		character.to_dictionary(),
		skill.to_dictionary(),
		unsafe_animation_data
	)
	_check(_contains_fragment(unsafe_animation_errors, "safe lowercase token"), "unsafe animation token fails closed in preview session")
	_check(not session.has_active_preview(), "unsafe animation payload cannot activate preview")

	var restore_animation_errors: PackedStringArray = session.stage_preview(
		character.to_dictionary(),
		skill.to_dictionary(),
		authored_animation_data
	)
	_check(restore_animation_errors.is_empty() and session.has_active_animation_preview(), "valid authored animation preview restores after fail-closed cases")

	var restored_character := CharacterDraft.new()
	var restore_character_errors: PackedStringArray = restored_character.load_from_dictionary(session.stored_character_draft_data())
	_check(restore_character_errors.is_empty() and restored_character.character_name == "Preview Nova" and restored_character.max_hp == 180, "stored character draft restores through CharacterDefinition")
	var restored_skill := SkillDraft.new()
	var restore_skill_errors: PackedStringArray = restored_skill.load_from_dictionary(session.stored_skill_draft_data())
	_check(restore_skill_errors.is_empty() and restored_skill.damage == 33 and restored_skill.mp_cost == 17, "stored skill draft restores through SkillDefinition")

	_test_all_family_slots(session, character)
	var restore_projectile_errors: PackedStringArray = session.stage_preview(character.to_dictionary(), skill.to_dictionary())
	_check(restore_projectile_errors.is_empty() and session.preview_skill_slot() == "skill_1", "projectile preview restores after family routing coverage")

	var strip_image := Image.create(16, 4, false, Image.FORMAT_RGBA8)
	strip_image.fill(Color("ff7733"))
	var strip_bytes: PackedByteArray = strip_image.save_png_to_buffer()
	var vfx := VfxDraft.new()
	var vfx_config_errors: PackedStringArray = vfx.configure_import("ci-strip.png", "image/png", 16, 4)
	vfx.frame_count = 4
	vfx.scale = 2.0
	vfx.offset_x = 12.0
	vfx.offset_y = -8.0
	vfx.fps = 20.0
	_check(vfx_config_errors.is_empty() and vfx.validate().is_empty(), "test VFX draft is valid")

	var store_vfx_errors: PackedStringArray = session.store_vfx_draft(vfx.to_dictionary(), strip_bytes)
	_check(store_vfx_errors.is_empty(), "valid PNG VFX stores in preview session")
	var proposal := {
		"proposal_id": "proposal_session_001", "source_request_id": "req_session_001",
		"skill_id": "ai_projectile_001", "skill_name": "AI Projectile", "skill_type": "projectile",
		"damage": 24, "mp_cost": 20, "cooldown": 2.0, "startup": 0.15, "active": 0.1, "recovery": 0.25,
		"speed": 600.0, "range": 900.0, "hitstun": 0.2, "knockback": 180.0,
		"hitbox_half_width": 24.0, "hitbox_half_depth": 0.08,
		"visual": "prototype_fireball", "impact_visual": "prototype_impact", "rationale": "Review before applying."
	}
	var proposal_errors: PackedStringArray = session.store_ai_skill_proposal(proposal)
	_check(proposal_errors.is_empty(), "valid AI skill proposal stores in preview session")
	_check(session.has_pending_ai_skill_proposal(), "stored AI skill proposal is pending")
	var taken_proposal: Dictionary = session.take_pending_ai_skill_proposal()
	_check(str(taken_proposal.get("proposal_id", "")) == "proposal_session_001", "pending AI proposal can be handed to Creator")
	_check(not session.has_pending_ai_skill_proposal(), "AI proposal handoff is single-consume")
	_check(session.has_stored_vfx(), "stored VFX binding is available before preview")
	_check(int(session.stored_vfx_data().get("frame_count", 0)) == 4, "stored VFX keeps authored frame count")
	_check(session.stored_vfx_png_bytes().size() == strip_bytes.size(), "stored VFX keeps PNG bytes in memory")

	var vfx_stage_errors: PackedStringArray = session.stage_preview(character.to_dictionary(), skill.to_dictionary())
	_check(vfx_stage_errors.is_empty(), "valid stored VFX stages with Creator projectile preview")
	_check(session.has_active_vfx_preview(), "projectile Creator preview activates stored VFX binding")
	_check(int(session.preview_vfx_data().get("frame_count", 0)) == 4, "active VFX preview keeps frame metadata")
	_check(absf(float(session.preview_vfx_data().get("scale", 0.0)) - 2.0) < 0.001, "active VFX preview keeps authored scale")
	_check(session.preview_vfx_png_bytes().size() == strip_bytes.size(), "active VFX preview keeps PNG bytes")

	var melee_with_stored_vfx := SkillDraft.new()
	melee_with_stored_vfx.set_skill_type("melee")
	melee_with_stored_vfx.skill_id = "preview_melee_vfx_guard_001"
	var melee_vfx_stage_errors: PackedStringArray = session.stage_preview(character.to_dictionary(), melee_with_stored_vfx.to_dictionary())
	_check(melee_vfx_stage_errors.is_empty(), "non-projectile preview remains valid while a projectile VFX draft is stored")
	_check(session.has_stored_vfx(), "non-projectile preview does not delete stored projectile VFX draft")
	_check(not session.has_active_vfx_preview(), "non-projectile preview does not bind projectile-only VFX runtime")

	var invalid_vfx: Dictionary = vfx.to_dictionary()
	invalid_vfx["image_width"] = 32
	var invalid_vfx_errors: PackedStringArray = session.store_vfx_draft(invalid_vfx, strip_bytes)
	_check(_contains_fragment(invalid_vfx_errors, "decoded PNG dimensions do not match VFX metadata"), "dimension-mismatched VFX fails closed")
	_check(not session.has_stored_vfx(), "invalid VFX clears stale stored binding")
	_check(not session.has_active_vfx_preview(), "invalid VFX clears stale active binding")

	var no_vfx_stage_errors: PackedStringArray = session.stage_preview(character.to_dictionary(), skill.to_dictionary())
	_check(no_vfx_stage_errors.is_empty() and session.has_active_preview(), "Creator preview remains usable without VFX")
	_check(not session.has_active_vfx_preview(), "preview without stored VFX uses default projectile visual")

	var unsafe_skill: Dictionary = skill.to_dictionary()
	unsafe_skill["id"] = "../evil.gd"
	var unsafe_errors: PackedStringArray = session.stage_preview(character.to_dictionary(), unsafe_skill)
	_check(_contains_fragment(unsafe_errors, "safe lowercase reference token"), "unsafe preview skill id fails closed")
	_check(not session.has_active_preview(), "failed stage deactivates preview")
	_check(session.preview_skill_slot().is_empty(), "failed stage clears stale preview slot")

	var unsupported_visual: Dictionary = skill.to_dictionary()
	unsupported_visual["visual"] = "user://payload"
	var visual_errors: PackedStringArray = session.stage_preview(character.to_dictionary(), unsupported_visual)
	_check(_contains_fragment(visual_errors, "unsupported preview visual"), "unapproved preview visual fails closed")

	var unsupported_type: Dictionary = skill.to_dictionary()
	unsupported_type["type"] = "scripted_actor"
	var unsupported_type_errors: PackedStringArray = session.stage_preview(character.to_dictionary(), unsupported_type)
	_check(_contains_fragment(unsupported_type_errors, "unsupported skill type: scripted_actor"), "unsupported future family fails closed before routing")
	_check(not session.has_active_preview(), "unsupported family cannot activate preview")

	if failures == 0:
		print("CREATOR_PREVIEW_SESSION_TESTS_PASSED")
		quit(0)
		return
	printerr("CREATOR_PREVIEW_SESSION_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_all_family_slots(session: CreatorPreviewSession, character: CharacterDraft) -> void:
	var original_character: Dictionary = character.to_dictionary()
	var original_slots: Dictionary = original_character.get("skill_slots", {}).duplicate(true)
	for family in FAMILY_SLOT_MAP.keys():
		var draft := SkillDraft.new()
		_check(draft.set_skill_type(family), "test draft accepts family %s" % family)
		draft.skill_id = "preview_%s_001" % family
		draft.skill_name = "Preview %s" % family.capitalize()
		var errors: PackedStringArray = session.stage_preview(original_character, draft.to_dictionary())
		_check(errors.is_empty(), "Creator preview stages family %s: %s" % [family, " | ".join(errors)])
		var expected_slot := str(FAMILY_SLOT_MAP[family])
		_check(session.preview_skill_type() == family, "preview reports family %s" % family)
		_check(session.preview_skill_slot() == expected_slot, "family %s routes to %s" % [family, expected_slot])
		var preview_slots: Dictionary = session.preview_character_data().get("skill_slots", {})
		_check(str(preview_slots.get(expected_slot, "")) == draft.skill_id, "family %s binds authored id to %s" % [family, expected_slot])
		for slot_name in original_slots.keys():
			if slot_name == expected_slot:
				continue
			_check(str(preview_slots.get(slot_name, "")) == str(original_slots.get(slot_name, "")), "family %s leaves %s unchanged" % [family, slot_name])
		var stored_slots: Dictionary = session.stored_character_draft_data().get("skill_slots", {})
		for slot_name in original_slots.keys():
			_check(str(stored_slots.get(slot_name, "")) == str(original_slots.get(slot_name, "")), "stored CharacterDraft stays unchanged for %s/%s" % [family, slot_name])

func _pcm_wav(sample_rate: int, channels: int, bits: int, data_size: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	_append_ascii(bytes, "RIFF")
	_append_u32(bytes, 36 + data_size)
	_append_ascii(bytes, "WAVE")
	_append_ascii(bytes, "fmt ")
	_append_u32(bytes, 16)
	_append_u16(bytes, 1)
	_append_u16(bytes, channels)
	_append_u32(bytes, sample_rate)
	var block_align := channels * bits / 8
	_append_u32(bytes, sample_rate * block_align)
	_append_u16(bytes, block_align)
	_append_u16(bytes, bits)
	_append_ascii(bytes, "data")
	_append_u32(bytes, data_size)
	for index in range(data_size):
		bytes.append(128 if bits == 8 else 0)
	return bytes

func _append_ascii(bytes: PackedByteArray, value: String) -> void:
	for index in range(value.length()):
		bytes.append(value.unicode_at(index))

func _append_u16(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xff)
	bytes.append((value >> 8) & 0xff)

func _append_u32(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xff)
	bytes.append((value >> 8) & 0xff)
	bytes.append((value >> 16) & 0xff)
	bytes.append((value >> 24) & 0xff)

func _contains_fragment(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
