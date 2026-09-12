extends SceneTree

const CreatorPreviewSession = preload("res://game/creator/preview/creator_preview_session.gd")
const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")

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
	_check(str(session.preview_character_data().get("skill_slots", {}).get("skill_1", "")) == "my_projectile_001", "preview character binds authored projectile to skill_1")
	_check(int(session.preview_character_data().get("stats", {}).get("max_hp", 0)) == 180, "preview character carries authored HP")
	_check(int(session.preview_skill_data().get("damage", 0)) == 33, "preview skill carries authored damage")
	_check(int(session.preview_skill_data().get("mp_cost", 0)) == 17, "preview skill carries authored MP cost")
	_check(absf(float(session.preview_skill_data().get("cooldown", 0.0)) - 2.4) < 0.001, "preview skill carries authored cooldown")
	_check(str(session.stored_character_draft_data().get("skill_slots", {}).get("skill_1", "")) == "fireball_001", "stored editable CharacterDraft is not mutated by preview binding")

	var restored_character := CharacterDraft.new()
	var restore_character_errors: PackedStringArray = restored_character.load_from_dictionary(session.stored_character_draft_data())
	_check(restore_character_errors.is_empty() and restored_character.character_name == "Preview Nova" and restored_character.max_hp == 180, "stored character draft restores through CharacterDefinition")
	var restored_skill := SkillDraft.new()
	var restore_skill_errors: PackedStringArray = restored_skill.load_from_dictionary(session.stored_skill_draft_data())
	_check(restore_skill_errors.is_empty() and restored_skill.damage == 33 and restored_skill.mp_cost == 17, "stored skill draft restores through SkillDefinition")

	var unsafe_skill: Dictionary = skill.to_dictionary()
	unsafe_skill["id"] = "../evil.gd"
	var unsafe_errors: PackedStringArray = session.stage_preview(character.to_dictionary(), unsafe_skill)
	_check(_contains_fragment(unsafe_errors, "safe lowercase reference token"), "unsafe preview skill id fails closed")
	_check(not session.has_active_preview(), "failed stage deactivates preview")

	var unsupported_visual: Dictionary = skill.to_dictionary()
	unsupported_visual["visual"] = "user://payload"
	var visual_errors: PackedStringArray = session.stage_preview(character.to_dictionary(), unsupported_visual)
	_check(_contains_fragment(visual_errors, "unsupported preview visual"), "unapproved preview visual fails closed")

	if failures == 0:
		print("CREATOR_PREVIEW_SESSION_TESTS_PASSED")
		quit(0)
		return
	printerr("CREATOR_PREVIEW_SESSION_TEST_FAILURES=%d" % failures)
	quit(1)

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
