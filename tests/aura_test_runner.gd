extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const AuraAttackState = preload("res://game/core/skills/aura_attack_state.gd")
const CombatBox = preload("res://game/core/combat/combat_box.gd")
const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")
const CreatorPreviewSession = preload("res://game/creator/preview/creator_preview_session.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_aura_definition_and_registry()
	_test_aura_attack_state()
	_test_optional_character_slot()
	_test_creator_preview_routing()
	if failures == 0:
		print("AURA_TESTS_PASSED")
		quit(0)
		return
	printerr("AURA_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_aura_definition_and_registry() -> void:
	var skill := SkillDefinition.new()
	var errors: PackedStringArray = skill.load_from_file("res://content/skills/training_aura.sample.json")
	_check(errors.is_empty() and skill.loaded, "aura sample validates: %s" % " | ".join(errors))
	_check(skill.skill_type == "aura" and skill.skill_id == "training_aura_001", "aura identity loads")
	_check(is_equal_approx(skill.aura_duration, 4.0), "aura duration loads")
	_check(is_equal_approx(skill.hitbox_half_width, 120.0) and is_equal_approx(skill.hitbox_half_depth, 0.18), "aura volume loads")

	var invalid := SkillDefinition.new()
	var invalid_data := {
		"schema_version": 1, "id": "bad_aura", "name": "Bad Aura", "type": "aura",
		"damage": 1, "mp_cost": 1, "cooldown": 1.0, "startup": 0.1, "active": 0.0,
		"recovery": 0.1, "range": 0.0,
		"hitbox_half_width": 0.0, "hitbox_half_depth": 2.0,
		"aura_duration": SkillDefinition.MAX_AURA_DURATION + 1.0,
		"visual": "prototype_fireball", "impact_visual": "prototype_impact"
	}
	var invalid_errors: PackedStringArray = invalid.load_from_dictionary(invalid_data)
	_check(_contains_fragment(invalid_errors, "aura active duration must be positive"), "zero aura active window fails closed")
	_check(_contains_fragment(invalid_errors, "aura_duration must be"), "oversized aura duration fails closed")
	_check(_contains_fragment(invalid_errors, "aura hitbox_half_width must be"), "invalid aura horizontal volume fails closed")
	_check(_contains_fragment(invalid_errors, "aura hitbox_half_depth must be"), "invalid aura depth fails closed")

	var registry := SkillRegistry.new()
	var registry_errors: PackedStringArray = registry.load_default()
	_check(registry_errors.is_empty() and registry.loaded, "skill registry accepts aura entry")
	var resolved := SkillDefinition.new()
	var resolve_errors: PackedStringArray = registry.load_skill("training_aura_001", "aura", resolved)
	_check(resolve_errors.is_empty() and resolved.loaded, "registry resolves aura with exact type")
	var mismatch := SkillDefinition.new()
	var mismatch_errors: PackedStringArray = registry.load_skill("training_aura_001", "area", mismatch)
	_check(_contains_fragment(mismatch_errors, "expected area but registry declares aura"), "registry rejects aura/controller type mismatch")

	var cast := SkillCastState.new()
	cast.configure(skill)
	_check(cast.start_cast(100), "aura uses shared deterministic cast state")
	cast.tick(skill.startup + 0.01)
	_check(cast.consume_activation(), "aura emits shared activation boundary")

func _test_aura_attack_state() -> void:
	var aura := AuraAttackState.new()
	_check(aura.start(Vector2(400.0, 0.5), 120.0, 0.18, 2.0), "aura starts with safe parameters")
	_check(aura.active and aura.can_hit(), "started aura is active and can hit")
	_check(aura.hitbox().overlaps(CombatBox.new(Vector2(500.0, 0.5), Vector2(10.0, 0.05))), "aura overlaps target inside bounds")
	_check(not aura.hitbox().overlaps(CombatBox.new(Vector2(540.0, 0.5), Vector2(10.0, 0.05))), "aura rejects target outside bounds")
	aura.follow(Vector2(450.0, 0.55))
	_check(aura.center.is_equal_approx(Vector2(450.0, 0.55)), "active aura follows owner center deterministically")
	aura.tick(0.75)
	_check(aura.active and is_equal_approx(aura.remaining, 1.25), "aura lifetime ticks deterministically")
	_check(aura.consume_hit(), "aura consumes first hit")
	_check(aura.active and aura.hit_consumed, "single hit does not end aura lifetime")
	_check(not aura.can_hit() and not aura.consume_hit(), "aura cannot damage twice during one activation")
	aura.tick(1.5)
	_check(not aura.active and is_zero_approx(aura.remaining), "aura expires deterministically")

	var invalid := AuraAttackState.new()
	_check(not invalid.start(Vector2.ZERO, 0.0, 0.1, 1.0), "aura rejects zero width")
	_check(not invalid.start(Vector2.ZERO, 20.0, 0.0, 1.0), "aura rejects zero depth")
	_check(not invalid.start(Vector2.ZERO, 20.0, 0.1, 0.0), "aura rejects zero duration")

func _test_optional_character_slot() -> void:
	var draft := CharacterDraft.new()
	var legacy_data: Dictionary = draft.to_dictionary()
	var legacy := CharacterDefinition.new()
	var legacy_errors: PackedStringArray = legacy.load_from_dictionary(legacy_data)
	_check(legacy_errors.is_empty() and legacy.loaded, "legacy six-slot character remains valid")
	_check(legacy.skill_id_for_slot("skill_9").is_empty(), "legacy character has no synthetic skill_9")

	var aura_data: Dictionary = legacy_data.duplicate(true)
	var slots: Dictionary = aura_data.get("skill_slots", {}).duplicate(true)
	slots["skill_9"] = "training_aura_001"
	aura_data["skill_slots"] = slots
	var aura_character := CharacterDefinition.new()
	var aura_errors: PackedStringArray = aura_character.load_from_dictionary(aura_data)
	_check(aura_errors.is_empty() and aura_character.loaded, "optional skill_9 character validates")
	_check(aura_character.skill_id_for_slot("skill_9") == "training_aura_001", "optional skill_9 round-trips")

func _test_creator_preview_routing() -> void:
	var character := CharacterDraft.new()
	var skill := SkillDraft.new()
	_check(skill.set_skill_type("aura"), "Creator accepts aura family")
	skill.skill_id = "preview_aura_001"
	skill.skill_name = "Preview Aura"
	skill.damage = 13
	skill.mp_cost = 9
	skill.cooldown = 0.6
	skill.aura_duration = 4.5
	skill.set_timeline_events([
		{"id": "aura_audio", "type": "audio", "time": 0.0, "duration": 0.0, "cue": "skill_cast"}
	])
	_check(skill.validate().is_empty(), "Creator aura defaults and timeline validate")

	var session := CreatorPreviewSession.new()
	var errors: PackedStringArray = session.stage_preview(character.to_dictionary(), skill.to_dictionary())
	_check(errors.is_empty(), "Creator Preview stages aura: %s" % " | ".join(errors))
	_check(session.preview_skill_type() == "aura", "Creator Preview reports aura family")
	_check(session.preview_skill_slot() == "skill_9", "Creator Preview maps aura to skill_9")
	_check(str(session.preview_character_data().get("skill_slots", {}).get("skill_9", "")) == "preview_aura_001", "Preview-only character injects aura into skill_9")
	_check(not session.stored_character_draft_data().get("skill_slots", {}).has("skill_9"), "stored editable CharacterDraft remains unmodified by aura preview")

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
