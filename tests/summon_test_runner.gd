extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const SummonState = preload("res://game/core/skills/summon_state.gd")
const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")
const CreatorPreviewSession = preload("res://game/creator/preview/creator_preview_session.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_summon_definition_and_registry()
	_test_summon_state()
	_test_optional_character_slot()
	_test_creator_preview_routing()
	if failures == 0:
		print("SUMMON_TESTS_PASSED")
		quit(0)
		return
	printerr("SUMMON_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_summon_definition_and_registry() -> void:
	var skill := SkillDefinition.new()
	var errors: PackedStringArray = skill.load_from_file("res://content/skills/training_summon.sample.json")
	_check(errors.is_empty() and skill.loaded, "summon sample validates: %s" % " | ".join(errors))
	_check(skill.skill_type == "summon" and skill.skill_id == "training_summon_001", "summon identity loads")
	_check(is_equal_approx(skill.range, 150.0), "summon bounded spawn offset loads")
	_check(is_equal_approx(skill.speed, 320.0), "summon bounded actor speed loads")
	_check(is_equal_approx(skill.active, 3.0), "summon finite lifetime loads")
	_check(is_equal_approx(skill.hitbox_half_width, 38.0) and is_equal_approx(skill.hitbox_half_depth, 0.14), "summon bounded actor volume loads")

	var invalid_lifetime := SkillDefinition.new()
	var invalid_lifetime_data := _summon_data()
	invalid_lifetime_data["active"] = SkillDefinition.MAX_SUMMON_LIFETIME + 0.01
	_check(_contains_fragment(invalid_lifetime.load_from_dictionary(invalid_lifetime_data), "summon lifetime must be"), "oversized summon lifetime fails closed")

	var invalid_range := SkillDefinition.new()
	var invalid_range_data := _summon_data()
	invalid_range_data["range"] = SkillDefinition.MAX_SUMMON_RANGE + 0.01
	_check(_contains_fragment(invalid_range.load_from_dictionary(invalid_range_data), "summon spawn range must be"), "oversized summon spawn range fails closed")

	var invalid_speed := SkillDefinition.new()
	var invalid_speed_data := _summon_data()
	invalid_speed_data["speed"] = SkillDefinition.MAX_SUMMON_SPEED + 0.01
	_check(_contains_fragment(invalid_speed.load_from_dictionary(invalid_speed_data), "summon speed must be"), "oversized summon actor speed fails closed")

	var registry := SkillRegistry.new()
	var registry_errors: PackedStringArray = registry.load_default()
	_check(registry_errors.is_empty() and registry.loaded, "skill registry accepts summon entry")
	var resolved := SkillDefinition.new()
	var resolve_errors: PackedStringArray = registry.load_skill("training_summon_001", "summon", resolved)
	_check(resolve_errors.is_empty() and resolved.loaded, "registry resolves summon with exact type")
	var mismatch := SkillDefinition.new()
	var mismatch_errors: PackedStringArray = registry.load_skill("training_summon_001", "melee", mismatch)
	_check(_contains_fragment(mismatch_errors, "expected melee but registry declares summon"), "registry rejects summon/controller type mismatch")

	var cast := SkillCastState.new()
	cast.configure(skill)
	_check(cast.start_cast(100), "summon uses shared deterministic cast state")
	cast.tick(skill.startup + 0.01)
	_check(cast.consume_activation(), "summon emits shared activation boundary")

func _test_summon_state() -> void:
	var summon := SummonState.new()
	var owner := Vector2(400.0, 0.50)
	var target_half := Vector2(30.0, 0.11)
	_check(not summon.start(owner, 1.0, 150.0, 3.0, 500.0, 500.0), "summon fails closed on invalid arena geometry")
	_check(not summon.start(Vector2(1100.0, 0.50), 1.0, 150.0, 3.0, 90.0, 1190.0), "summon rejects spawn outside arena bounds")
	_check(summon.start(owner, 1.0, 150.0, 3.0, 90.0, 1190.0), "summon starts at validated bounded spawn")
	_check(summon.active and summon.activation_count == 1, "summon starts exactly one active actor")
	_check(summon.spawn_position.is_equal_approx(Vector2(550.0, 0.50)), "summon records deterministic spawn position")
	_check(not summon.start(owner, 1.0, 150.0, 3.0, 90.0, 1190.0), "active summon rejects second actor instance")
	var first_hit := summon.tick(0.5, Vector2(760.0, 0.50), target_half, true, 320.0, 38.0, 0.14, 90.0, 1190.0)
	_check(first_hit, "summon deterministic travel reaches eligible target overlap")
	_check(summon.hit_consumed and summon.hit_count == 1, "summon consumes at most one hit")
	_check(summon.position.x > summon.spawn_position.x and summon.position.x <= 760.0, "summon moves toward only the designated target")
	var second_hit := summon.tick(0.2, Vector2(760.0, 0.50), target_half, true, 320.0, 38.0, 0.14, 90.0, 1190.0)
	_check(not second_hit and summon.hit_count == 1, "summon cannot hit twice during one actor lifetime")
	summon.tick(3.0, Vector2(760.0, 0.50), target_half, true, 320.0, 38.0, 0.14, 90.0, 1190.0)
	_check(not summon.active and summon.hit_count == 1, "summon expires and cleans up deterministically")

	var gated := SummonState.new()
	_check(gated.start(owner, 1.0, 150.0, 1.0, 90.0, 1190.0), "second summon fixture starts")
	var blocked_hit := gated.tick(0.5, Vector2(760.0, 0.50), target_half, false, 320.0, 38.0, 0.14, 90.0, 1190.0)
	_check(not blocked_hit and not gated.hit_consumed, "ineligible target overlap cannot consume summon hit")
	var eligible_hit := gated.tick(0.01, Vector2(710.0, 0.50), target_half, true, 320.0, 38.0, 0.14, 90.0, 1190.0)
	_check(eligible_hit and gated.hit_count == 1, "same bounded actor can hit once after target becomes eligible")

func _test_optional_character_slot() -> void:
	var draft := CharacterDraft.new()
	var legacy_data: Dictionary = draft.to_dictionary()
	var legacy := CharacterDefinition.new()
	var legacy_errors: PackedStringArray = legacy.load_from_dictionary(legacy_data)
	_check(legacy_errors.is_empty() and legacy.loaded, "legacy six-slot character remains valid")
	_check(legacy.skill_id_for_slot("skill_13").is_empty(), "legacy character has no synthetic skill_13")
	var summon_data: Dictionary = legacy_data.duplicate(true)
	var slots: Dictionary = summon_data.get("skill_slots", {}).duplicate(true)
	slots["skill_13"] = "training_summon_001"
	summon_data["skill_slots"] = slots
	var summon_character := CharacterDefinition.new()
	var summon_errors: PackedStringArray = summon_character.load_from_dictionary(summon_data)
	_check(summon_errors.is_empty() and summon_character.loaded, "optional skill_13 character validates")
	_check(summon_character.skill_id_for_slot("skill_13") == "training_summon_001", "optional skill_13 round-trips")

func _test_creator_preview_routing() -> void:
	var character := CharacterDraft.new()
	var skill := SkillDraft.new()
	_check(skill.set_skill_type("summon"), "Creator accepts summon family")
	skill.skill_id = "preview_summon_001"
	skill.skill_name = "Preview Summon"
	skill.damage = 13
	skill.mp_cost = 9
	skill.cooldown = 0.6
	skill.set_timeline_events([
		{"id": "summon_audio", "type": "audio", "time": 0.0, "duration": 0.0, "cue": "skill_cast"}
	])
	_check(skill.validate().is_empty(), "Creator summon defaults and timeline validate")
	var session := CreatorPreviewSession.new()
	var errors: PackedStringArray = session.stage_preview(character.to_dictionary(), skill.to_dictionary())
	_check(errors.is_empty(), "Creator Preview stages summon: %s" % " | ".join(errors))
	_check(session.preview_skill_type() == "summon", "Creator Preview reports summon family")
	_check(session.preview_skill_slot() == "skill_13", "Creator Preview maps summon to skill_13")
	_check(str(session.preview_character_data().get("skill_slots", {}).get("skill_13", "")) == "preview_summon_001", "Preview-only character injects summon into skill_13")
	_check(not session.stored_character_draft_data().get("skill_slots", {}).has("skill_13"), "stored editable CharacterDraft remains unmodified by summon preview")

func _summon_data() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "test_summon",
		"name": "Test Summon",
		"type": "summon",
		"damage": 12,
		"mp_cost": 10,
		"cooldown": 1.0,
		"startup": 0.12,
		"active": 3.0,
		"recovery": 0.24,
		"speed": 320.0,
		"range": 150.0,
		"hitstun": 0.22,
		"knockback": 0.0,
		"hitbox_half_width": 38.0,
		"hitbox_half_depth": 0.14,
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
