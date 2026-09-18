extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const TeleportState = preload("res://game/core/skills/teleport_state.gd")
const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")
const CreatorPreviewSession = preload("res://game/creator/preview/creator_preview_session.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_teleport_definition_and_registry()
	_test_teleport_state()
	_test_optional_character_slot()
	_test_creator_preview_routing()
	if failures == 0:
		print("TELEPORT_TESTS_PASSED")
		quit(0)
		return
	printerr("TELEPORT_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_teleport_definition_and_registry() -> void:
	var skill := SkillDefinition.new()
	var errors: PackedStringArray = skill.load_from_file("res://content/skills/training_teleport.sample.json")
	_check(errors.is_empty() and skill.loaded, "teleport sample validates: %s" % " | ".join(errors))
	_check(skill.skill_type == "teleport" and skill.skill_id == "training_teleport_001", "teleport identity loads")
	_check(is_equal_approx(skill.range, 360.0), "teleport range loads")
	_check(is_zero_approx(skill.active), "teleport supports instantaneous active phase")

	var invalid_zero := SkillDefinition.new()
	var zero_data := _teleport_data()
	zero_data["range"] = 0.0
	var zero_errors: PackedStringArray = invalid_zero.load_from_dictionary(zero_data)
	_check(_contains_fragment(zero_errors, "teleport range must be"), "zero teleport range fails closed")

	var invalid_large := SkillDefinition.new()
	var large_data := _teleport_data()
	large_data["range"] = SkillDefinition.MAX_TELEPORT_RANGE + 1.0
	var large_errors: PackedStringArray = invalid_large.load_from_dictionary(large_data)
	_check(_contains_fragment(large_errors, "teleport range must be"), "oversized teleport range fails closed")

	var registry := SkillRegistry.new()
	var registry_errors: PackedStringArray = registry.load_default()
	_check(registry_errors.is_empty() and registry.loaded, "skill registry accepts teleport entry")
	var resolved := SkillDefinition.new()
	var resolve_errors: PackedStringArray = registry.load_skill("training_teleport_001", "teleport", resolved)
	_check(resolve_errors.is_empty() and resolved.loaded, "registry resolves teleport with exact type")
	var mismatch := SkillDefinition.new()
	var mismatch_errors: PackedStringArray = registry.load_skill("training_teleport_001", "dash", mismatch)
	_check(_contains_fragment(mismatch_errors, "expected dash but registry declares teleport"), "registry rejects teleport/controller type mismatch")

	var cast := SkillCastState.new()
	cast.configure(skill)
	_check(cast.start_cast(100), "teleport uses shared deterministic cast state")
	cast.tick(skill.startup + 0.01)
	_check(cast.consume_activation(), "teleport emits shared activation boundary even with zero active duration")

func _test_teleport_state() -> void:
	var state := TeleportState.new()
	_check(state.resolve(280.0, 1.0, 360.0, 90.0, 1190.0), "teleport resolves valid rightward destination")
	_check(is_equal_approx(state.last_start_x, 280.0), "teleport records start")
	_check(is_equal_approx(state.last_destination_x, 640.0), "teleport resolves exact rightward destination")
	_check(is_equal_approx(state.last_distance, 360.0), "teleport records exact traveled distance")
	_check(is_equal_approx(state.last_direction, 1.0) and state.activation_count == 1, "teleport records deterministic rightward activation")

	_check(state.resolve(640.0, -1.0, 200.0, 90.0, 1190.0), "teleport resolves valid leftward destination")
	_check(is_equal_approx(state.last_destination_x, 440.0), "teleport resolves exact leftward destination")
	_check(is_equal_approx(state.last_direction, -1.0) and state.activation_count == 2, "teleport records deterministic leftward activation")

	_check(state.resolve(1100.0, 1.0, 360.0, 90.0, 1190.0), "teleport resolves near arena boundary")
	_check(is_equal_approx(state.last_destination_x, 1190.0), "teleport clamps destination to safe arena boundary")
	_check(is_equal_approx(state.last_distance, 90.0), "teleport reports actual clamped travel distance")

	var invalid := TeleportState.new()
	_check(not invalid.resolve(280.0, 1.0, 0.0, 90.0, 1190.0), "teleport rejects zero requested distance")
	_check(not invalid.resolve(280.0, 1.0, 360.0, 100.0, 100.0), "teleport rejects invalid arena bounds")
	_check(invalid.activation_count == 0, "rejected teleport does not count as activation")

func _test_optional_character_slot() -> void:
	var draft := CharacterDraft.new()
	var legacy_data: Dictionary = draft.to_dictionary()
	var legacy := CharacterDefinition.new()
	var legacy_errors: PackedStringArray = legacy.load_from_dictionary(legacy_data)
	_check(legacy_errors.is_empty() and legacy.loaded, "legacy six-slot character remains valid")
	_check(legacy.skill_id_for_slot("skill_10").is_empty(), "legacy character has no synthetic skill_10")

	var teleport_data: Dictionary = legacy_data.duplicate(true)
	var slots: Dictionary = teleport_data.get("skill_slots", {}).duplicate(true)
	slots["skill_10"] = "training_teleport_001"
	teleport_data["skill_slots"] = slots
	var teleport_character := CharacterDefinition.new()
	var teleport_errors: PackedStringArray = teleport_character.load_from_dictionary(teleport_data)
	_check(teleport_errors.is_empty() and teleport_character.loaded, "optional skill_10 character validates")
	_check(teleport_character.skill_id_for_slot("skill_10") == "training_teleport_001", "optional skill_10 round-trips")

func _test_creator_preview_routing() -> void:
	var character := CharacterDraft.new()
	var skill := SkillDraft.new()
	_check(skill.set_skill_type("teleport"), "Creator accepts teleport family")
	skill.skill_id = "preview_teleport_001"
	skill.skill_name = "Preview Teleport"
	skill.mp_cost = 9
	skill.cooldown = 0.6
	skill.range = 340.0
	skill.set_timeline_events([
		{"id": "teleport_audio", "type": "audio", "time": 0.0, "duration": 0.0, "cue": "skill_cast"}
	])
	_check(skill.validate().is_empty(), "Creator teleport defaults and timeline validate")

	var session := CreatorPreviewSession.new()
	var errors: PackedStringArray = session.stage_preview(character.to_dictionary(), skill.to_dictionary())
	_check(errors.is_empty(), "Creator Preview stages teleport: %s" % " | ".join(errors))
	_check(session.preview_skill_type() == "teleport", "Creator Preview reports teleport family")
	_check(session.preview_skill_slot() == "skill_10", "Creator Preview maps teleport to skill_10")
	_check(str(session.preview_character_data().get("skill_slots", {}).get("skill_10", "")) == "preview_teleport_001", "Preview-only character injects teleport into skill_10")
	_check(not session.stored_character_draft_data().get("skill_slots", {}).has("skill_10"), "stored editable CharacterDraft remains unmodified by teleport preview")

func _teleport_data() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "test_teleport",
		"name": "Test Teleport",
		"type": "teleport",
		"damage": 0,
		"mp_cost": 10,
		"cooldown": 1.0,
		"startup": 0.1,
		"active": 0.0,
		"recovery": 0.2,
		"speed": 0.0,
		"range": 360.0,
		"hitstun": 0.0,
		"knockback": 0.0,
		"hitbox_half_width": 24.0,
		"hitbox_half_depth": 0.08,
		"visual": "prototype_fireball",
		"impact_visual": "prototype_impact"
	}

func _contains_fragment(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if str(error).contains(fragment):
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
