extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const TrapAttackState = preload("res://game/core/skills/trap_attack_state.gd")
const CombatBox = preload("res://game/core/combat/combat_box.gd")
const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")
const CreatorPreviewSession = preload("res://game/creator/preview/creator_preview_session.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_trap_definition_and_registry()
	_test_trap_attack_state()
	_test_optional_character_slot()
	_test_creator_preview_routing()
	if failures == 0:
		print("TRAP_TESTS_PASSED")
		quit(0)
		return
	printerr("TRAP_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_trap_definition_and_registry() -> void:
	var skill := SkillDefinition.new()
	var errors: PackedStringArray = skill.load_from_file("res://content/skills/training_trap.sample.json")
	_check(errors.is_empty() and skill.loaded, "trap sample validates: %s" % " | ".join(errors))
	_check(skill.skill_type == "trap" and skill.skill_id == "training_trap_001", "trap identity loads")
	_check(is_equal_approx(skill.range, 180.0) and is_equal_approx(skill.trap_duration, 6.0), "trap placement range and lifetime load")
	_check(is_equal_approx(skill.hitbox_half_width, 62.0) and is_equal_approx(skill.hitbox_half_depth, 0.14), "trap trigger volume loads")

	var invalid := SkillDefinition.new()
	var invalid_data := {
		"schema_version": 1, "id": "bad_trap", "name": "Bad Trap", "type": "trap",
		"damage": 1, "mp_cost": 1, "cooldown": 1.0, "startup": 0.1, "active": 0.0,
		"recovery": 0.1, "range": SkillDefinition.MAX_TRAP_RANGE + 1.0,
		"hitbox_half_width": 0.0, "hitbox_half_depth": 2.0, "trap_duration": SkillDefinition.MAX_TRAP_DURATION + 1.0,
		"visual": "prototype_fireball", "impact_visual": "prototype_impact"
	}
	var invalid_errors: PackedStringArray = invalid.load_from_dictionary(invalid_data)
	_check(_contains_fragment(invalid_errors, "trap range must be"), "oversized trap placement range fails closed")
	_check(_contains_fragment(invalid_errors, "trap active duration must be positive"), "zero trap cast active window fails closed")
	_check(_contains_fragment(invalid_errors, "trap_duration must be"), "oversized trap lifetime fails closed")
	_check(_contains_fragment(invalid_errors, "trap hitbox_half_width must be"), "invalid trap horizontal trigger volume fails closed")
	_check(_contains_fragment(invalid_errors, "trap hitbox_half_depth must be"), "invalid trap depth fails closed")

	var registry := SkillRegistry.new()
	var registry_errors: PackedStringArray = registry.load_default()
	_check(registry_errors.is_empty() and registry.loaded, "skill registry accepts trap entry")
	var resolved := SkillDefinition.new()
	var resolve_errors: PackedStringArray = registry.load_skill("training_trap_001", "trap", resolved)
	_check(resolve_errors.is_empty() and resolved.loaded, "registry resolves trap with exact type")
	var mismatch := SkillDefinition.new()
	var mismatch_errors: PackedStringArray = registry.load_skill("training_trap_001", "area", mismatch)
	_check(_contains_fragment(mismatch_errors, "expected area but registry declares trap"), "registry rejects trap/controller type mismatch")

	var cast := SkillCastState.new()
	cast.configure(skill)
	_check(cast.start_cast(100), "trap uses shared deterministic cast state")
	cast.tick(skill.startup + 0.01)
	_check(cast.consume_activation(), "trap emits shared activation boundary")

func _test_trap_attack_state() -> void:
	var trap := TrapAttackState.new()
	_check(trap.place(Vector2(400.0, 0.5), 60.0, 0.12, 2.0), "trap state places with safe parameters")
	_check(trap.active and trap.can_trigger(), "placed trap is armed")
	_check(trap.hitbox().overlaps(CombatBox.new(Vector2(445.0, 0.5), Vector2(10.0, 0.05))), "trap trigger volume overlaps target inside bounds")
	_check(not trap.hitbox().overlaps(CombatBox.new(Vector2(490.0, 0.5), Vector2(10.0, 0.05))), "trap trigger volume rejects target outside bounds")
	trap.tick(0.75)
	_check(trap.active and is_equal_approx(trap.remaining, 1.25), "trap lifetime ticks deterministically")
	_check(trap.trigger(), "trap consumes first trigger")
	_check(not trap.active and trap.triggered and not trap.expired, "trigger deactivates trap without marking expiry")
	_check(not trap.can_trigger() and not trap.trigger(), "trap cannot trigger twice")

	var expiring := TrapAttackState.new()
	_check(expiring.place(Vector2.ZERO, 20.0, 0.1, 0.5), "second trap places for expiry test")
	expiring.tick(0.6)
	_check(not expiring.active and expiring.expired and not expiring.triggered, "untriggered trap expires deterministically")
	_check(not expiring.place(Vector2.ZERO, 0.0, 0.1, 1.0), "trap rejects zero-width trigger volume")
	_check(not expiring.place(Vector2.ZERO, 20.0, 0.1, 0.0), "trap rejects zero lifetime")

func _test_optional_character_slot() -> void:
	var draft := CharacterDraft.new()
	var legacy_data: Dictionary = draft.to_dictionary()
	var legacy := CharacterDefinition.new()
	var legacy_errors: PackedStringArray = legacy.load_from_dictionary(legacy_data)
	_check(legacy_errors.is_empty() and legacy.loaded, "legacy six-slot character remains valid")
	_check(legacy.skill_id_for_slot("skill_8").is_empty(), "legacy character has no synthetic skill_8")

	var trap_data: Dictionary = legacy_data.duplicate(true)
	var slots: Dictionary = trap_data.get("skill_slots", {}).duplicate(true)
	slots["skill_8"] = "training_trap_001"
	trap_data["skill_slots"] = slots
	var trap_character := CharacterDefinition.new()
	var trap_errors: PackedStringArray = trap_character.load_from_dictionary(trap_data)
	_check(trap_errors.is_empty() and trap_character.loaded, "optional skill_8 character validates")
	_check(trap_character.skill_id_for_slot("skill_8") == "training_trap_001", "optional skill_8 round-trips")

func _test_creator_preview_routing() -> void:
	var character := CharacterDraft.new()
	var skill := SkillDraft.new()
	_check(skill.set_skill_type("trap"), "Creator accepts trap family")
	skill.skill_id = "preview_trap_001"
	skill.skill_name = "Preview Trap"
	skill.damage = 13
	skill.mp_cost = 9
	skill.cooldown = 0.6
	skill.range = 580.0
	skill.trap_duration = 4.0
	skill.set_timeline_events([
		{"id": "trap_audio", "type": "audio", "time": 0.0, "duration": 0.0, "cue": "skill_cast"}
	])
	_check(skill.validate().is_empty(), "Creator trap defaults and timeline validate")

	var session := CreatorPreviewSession.new()
	var errors: PackedStringArray = session.stage_preview(character.to_dictionary(), skill.to_dictionary())
	_check(errors.is_empty(), "Creator Preview stages trap: %s" % " | ".join(errors))
	_check(session.preview_skill_type() == "trap", "Creator Preview reports trap family")
	_check(session.preview_skill_slot() == "skill_8", "Creator Preview maps trap to skill_8")
	_check(str(session.preview_character_data().get("skill_slots", {}).get("skill_8", "")) == "preview_trap_001", "Preview-only character injects trap into skill_8")
	_check(not session.stored_character_draft_data().get("skill_slots", {}).has("skill_8"), "stored editable CharacterDraft remains unmodified by trap preview")

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
