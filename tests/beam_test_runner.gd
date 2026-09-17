extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const BeamAttackState = preload("res://game/core/skills/beam_attack_state.gd")
const CombatBox = preload("res://game/core/combat/combat_box.gd")
const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")
const CreatorPreviewSession = preload("res://game/creator/preview/creator_preview_session.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_beam_definition_and_registry()
	_test_beam_attack_state()
	_test_optional_character_slot()
	_test_creator_preview_routing()
	if failures == 0:
		print("BEAM_TESTS_PASSED")
		quit(0)
		return
	printerr("BEAM_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_beam_definition_and_registry() -> void:
	var skill := SkillDefinition.new()
	var errors: PackedStringArray = skill.load_from_file("res://content/skills/training_beam.sample.json")
	_check(errors.is_empty() and skill.loaded, "beam sample validates: %s" % " | ".join(errors))
	_check(skill.skill_type == "beam" and skill.skill_id == "training_beam_001", "beam identity loads")
	_check(is_equal_approx(skill.range, 720.0) and is_equal_approx(skill.active, 0.32), "beam range and active window load")
	_check(is_equal_approx(skill.hitbox_half_width, 24.0) and is_equal_approx(skill.hitbox_half_depth, 0.10), "beam bounded spatial parameters load")

	var invalid := SkillDefinition.new()
	var invalid_data := {
		"schema_version": 1, "id": "bad_beam", "name": "Bad Beam", "type": "beam",
		"damage": 1, "mp_cost": 1, "cooldown": 1.0, "startup": 0.1, "active": 0.0,
		"recovery": 0.1, "range": SkillDefinition.MAX_BEAM_RANGE + 1.0,
		"hitbox_half_width": 0.0, "hitbox_half_depth": 2.0,
		"visual": "prototype_fireball", "impact_visual": "prototype_impact"
	}
	var invalid_errors: PackedStringArray = invalid.load_from_dictionary(invalid_data)
	_check(_contains_fragment(invalid_errors, "beam range must be"), "oversized beam range fails closed")
	_check(_contains_fragment(invalid_errors, "beam active duration must be positive"), "zero beam active window fails closed")
	_check(_contains_fragment(invalid_errors, "beam hitbox_half_width must be"), "invalid beam horizontal padding fails closed")
	_check(_contains_fragment(invalid_errors, "beam hitbox_half_depth must be"), "invalid beam depth fails closed")

	var registry := SkillRegistry.new()
	var registry_errors: PackedStringArray = registry.load_default()
	_check(registry_errors.is_empty() and registry.loaded, "skill registry accepts beam entry")
	var resolved := SkillDefinition.new()
	var resolve_errors: PackedStringArray = registry.load_skill("training_beam_001", "beam", resolved)
	_check(resolve_errors.is_empty() and resolved.loaded, "registry resolves beam with exact type")
	var mismatch := SkillDefinition.new()
	var mismatch_errors: PackedStringArray = registry.load_skill("training_beam_001", "projectile", mismatch)
	_check(_contains_fragment(mismatch_errors, "expected projectile but registry declares beam"), "registry rejects beam/controller type mismatch")

	var cast := SkillCastState.new()
	cast.configure(skill)
	_check(cast.start_cast(100), "beam uses shared deterministic cast state")
	cast.tick(skill.startup + 0.01)
	_check(cast.consume_activation(), "beam emits shared activation boundary")

func _test_beam_attack_state() -> void:
	var beam := BeamAttackState.new()
	_check(beam.start(Vector2(100.0, 0.5), 1.0, 300.0, 20.0, 0.10, 0.30), "beam state starts with safe parameters")
	_check(beam.active and is_equal_approx(beam.endpoint.x, 400.0), "beam endpoint is deterministic")
	_check(is_equal_approx(beam.center.x, 250.0), "beam collision center spans origin to endpoint")
	_check(beam.hitbox().overlaps(CombatBox.new(Vector2(390.0, 0.5), Vector2(10.0, 0.05))), "beam hitbox reaches target inside range")
	_check(not beam.hitbox().overlaps(CombatBox.new(Vector2(460.0, 0.5), Vector2(10.0, 0.05))), "beam hitbox rejects target beyond bounded range")
	_check(beam.can_hit() and beam.consume_hit(), "beam consumes first hit")
	_check(not beam.can_hit() and not beam.consume_hit(), "beam cannot multi-hit after first consumption")
	beam.tick(0.31)
	_check(not beam.active, "beam active window ends deterministically")

	var left := BeamAttackState.new()
	_check(left.start(Vector2(500.0, 0.5), -1.0, 200.0, 12.0, 0.08, 0.20), "beam supports left facing")
	_check(is_equal_approx(left.endpoint.x, 300.0) and is_equal_approx(left.center.x, 400.0), "left beam geometry mirrors deterministically")
	_check(not left.start(Vector2.ZERO, 1.0, 0.0, 1.0, 0.1, 0.1), "beam rejects zero range")

func _test_optional_character_slot() -> void:
	var draft := CharacterDraft.new()
	var legacy_data: Dictionary = draft.to_dictionary()
	var legacy := CharacterDefinition.new()
	var legacy_errors: PackedStringArray = legacy.load_from_dictionary(legacy_data)
	_check(legacy_errors.is_empty() and legacy.loaded, "legacy six-slot character remains valid")
	_check(legacy.skill_id_for_slot("skill_7").is_empty(), "legacy character has no synthetic skill_7")

	var beam_data: Dictionary = legacy_data.duplicate(true)
	var slots: Dictionary = beam_data.get("skill_slots", {}).duplicate(true)
	slots["skill_7"] = "training_beam_001"
	beam_data["skill_slots"] = slots
	var beam_character := CharacterDefinition.new()
	var beam_errors: PackedStringArray = beam_character.load_from_dictionary(beam_data)
	_check(beam_errors.is_empty() and beam_character.loaded, "optional skill_7 character validates")
	_check(beam_character.skill_id_for_slot("skill_7") == "training_beam_001", "optional skill_7 round-trips")

func _test_creator_preview_routing() -> void:
	var character := CharacterDraft.new()
	var skill := SkillDraft.new()
	_check(skill.set_skill_type("beam"), "Creator accepts beam family")
	skill.skill_id = "preview_beam_001"
	skill.skill_name = "Preview Beam"
	skill.damage = 12
	skill.mp_cost = 11
	skill.cooldown = 0.6
	skill.set_timeline_events([
		{"id": "beam_audio", "type": "audio", "time": 0.0, "duration": 0.0, "cue": "skill_cast"}
	])
	_check(skill.validate().is_empty(), "Creator beam defaults and timeline validate")

	var session := CreatorPreviewSession.new()
	var errors: PackedStringArray = session.stage_preview(character.to_dictionary(), skill.to_dictionary())
	_check(errors.is_empty(), "Creator Preview stages beam: %s" % " | ".join(errors))
	_check(session.preview_skill_type() == "beam", "Creator Preview reports beam family")
	_check(session.preview_skill_slot() == "skill_7", "Creator Preview maps beam to skill_7")
	_check(str(session.preview_character_data().get("skill_slots", {}).get("skill_7", "")) == "preview_beam_001", "Preview-only character injects beam into skill_7")
	_check(not session.stored_character_draft_data().get("skill_slots", {}).has("skill_7"), "stored editable CharacterDraft remains six-slot and unmodified")

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
