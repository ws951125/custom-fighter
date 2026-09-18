extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const CounterState = preload("res://game/core/skills/counter_state.gd")
const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")
const CreatorPreviewSession = preload("res://game/creator/preview/creator_preview_session.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_counter_definition_and_registry()
	_test_counter_state()
	_test_optional_character_slot()
	_test_creator_preview_routing()
	if failures == 0:
		print("COUNTER_TESTS_PASSED")
		quit(0)
		return
	printerr("COUNTER_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_counter_definition_and_registry() -> void:
	var skill := SkillDefinition.new()
	var errors: PackedStringArray = skill.load_from_file("res://content/skills/training_counter.sample.json")
	_check(errors.is_empty() and skill.loaded, "counter sample validates: %s" % " | ".join(errors))
	_check(skill.skill_type == "counter" and skill.skill_id == "training_counter_001", "counter identity loads")
	_check(is_equal_approx(skill.active, 1.5), "counter finite active window loads")
	_check(is_equal_approx(skill.range, 180.0) and is_equal_approx(skill.hitbox_half_depth, 0.14), "counter bounded source volume loads")

	var invalid_window := SkillDefinition.new()
	var invalid_window_data := _counter_data()
	invalid_window_data["active"] = SkillDefinition.MAX_COUNTER_WINDOW + 0.01
	var invalid_window_errors: PackedStringArray = invalid_window.load_from_dictionary(invalid_window_data)
	_check(_contains_fragment(invalid_window_errors, "counter active window must be"), "oversized counter window fails closed")

	var invalid_range := SkillDefinition.new()
	var invalid_range_data := _counter_data()
	invalid_range_data["range"] = 0.0
	var invalid_range_errors: PackedStringArray = invalid_range.load_from_dictionary(invalid_range_data)
	_check(_contains_fragment(invalid_range_errors, "counter range must be"), "zero counter range fails closed")

	var invalid_depth := SkillDefinition.new()
	var invalid_depth_data := _counter_data()
	invalid_depth_data["hitbox_half_depth"] = 0.0
	var invalid_depth_errors: PackedStringArray = invalid_depth.load_from_dictionary(invalid_depth_data)
	_check(_contains_fragment(invalid_depth_errors, "counter hitbox_half_depth must be"), "zero counter depth fails closed")

	var registry := SkillRegistry.new()
	var registry_errors: PackedStringArray = registry.load_default()
	_check(registry_errors.is_empty() and registry.loaded, "skill registry accepts counter entry")
	var resolved := SkillDefinition.new()
	var resolve_errors: PackedStringArray = registry.load_skill("training_counter_001", "counter", resolved)
	_check(resolve_errors.is_empty() and resolved.loaded, "registry resolves counter with exact type")
	var mismatch := SkillDefinition.new()
	var mismatch_errors: PackedStringArray = registry.load_skill("training_counter_001", "melee", mismatch)
	_check(_contains_fragment(mismatch_errors, "expected melee but registry declares counter"), "registry rejects counter/controller type mismatch")

	var cast := SkillCastState.new()
	cast.configure(skill)
	_check(cast.start_cast(100), "counter uses shared deterministic cast state")
	cast.tick(skill.startup + 0.01)
	_check(cast.consume_activation(), "counter emits shared activation boundary")

func _test_counter_state() -> void:
	var counter := CounterState.new()
	_check(counter.start(1.5), "counter window starts")
	_check(counter.active and not counter.triggered and counter.activation_count == 1, "counter starts armed")
	counter.tick(0.25)
	_check(counter.active and is_equal_approx(counter.remaining, 1.25), "counter window ticks deterministically")

	var player := Vector2(400.0, 0.50)
	_check(not counter.can_intercept(player, Vector2(700.0, 0.50), 180.0, 0.14), "counter rejects source outside horizontal range")
	_check(not counter.can_intercept(player, Vector2(520.0, 0.80), 180.0, 0.14), "counter rejects source outside depth range")
	_check(counter.can_intercept(player, Vector2(520.0, 0.55), 180.0, 0.14), "counter accepts in-range incoming hit")
	_check(counter.intercept(player, Vector2(520.0, 0.55), 180.0, 0.14), "counter consumes actual in-range incoming hit")
	_check(not counter.active and counter.triggered and counter.trigger_count == 1, "counter closes after one trigger")
	_check(counter.last_source.is_equal_approx(Vector2(520.0, 0.55)), "counter records triggering source")
	_check(not counter.intercept(player, Vector2(510.0, 0.50), 180.0, 0.14), "counter cannot trigger twice in one activation")

	var expired := CounterState.new()
	_check(expired.start(0.2), "short counter window starts")
	expired.tick(0.3)
	_check(not expired.active and expired.trigger_count == 0, "expired counter never auto-retaliates")

func _test_optional_character_slot() -> void:
	var draft := CharacterDraft.new()
	var legacy_data: Dictionary = draft.to_dictionary()
	var legacy := CharacterDefinition.new()
	var legacy_errors: PackedStringArray = legacy.load_from_dictionary(legacy_data)
	_check(legacy_errors.is_empty() and legacy.loaded, "legacy six-slot character remains valid")
	_check(legacy.skill_id_for_slot("skill_11").is_empty(), "legacy character has no synthetic skill_11")

	var counter_data: Dictionary = legacy_data.duplicate(true)
	var slots: Dictionary = counter_data.get("skill_slots", {}).duplicate(true)
	slots["skill_11"] = "training_counter_001"
	counter_data["skill_slots"] = slots
	var counter_character := CharacterDefinition.new()
	var counter_errors: PackedStringArray = counter_character.load_from_dictionary(counter_data)
	_check(counter_errors.is_empty() and counter_character.loaded, "optional skill_11 character validates")
	_check(counter_character.skill_id_for_slot("skill_11") == "training_counter_001", "optional skill_11 round-trips")

func _test_creator_preview_routing() -> void:
	var character := CharacterDraft.new()
	var skill := SkillDraft.new()
	_check(skill.set_skill_type("counter"), "Creator accepts counter family")
	skill.skill_id = "preview_counter_001"
	skill.skill_name = "Preview Counter"
	skill.damage = 13
	skill.mp_cost = 9
	skill.cooldown = 0.6
	skill.range = 170.0
	skill.set_timeline_events([
		{"id": "counter_audio", "type": "audio", "time": 0.0, "duration": 0.0, "cue": "skill_cast"}
	])
	_check(skill.validate().is_empty(), "Creator counter defaults and timeline validate")

	var session := CreatorPreviewSession.new()
	var errors: PackedStringArray = session.stage_preview(character.to_dictionary(), skill.to_dictionary())
	_check(errors.is_empty(), "Creator Preview stages counter: %s" % " | ".join(errors))
	_check(session.preview_skill_type() == "counter", "Creator Preview reports counter family")
	_check(session.preview_skill_slot() == "skill_11", "Creator Preview maps counter to skill_11")
	_check(str(session.preview_character_data().get("skill_slots", {}).get("skill_11", "")) == "preview_counter_001", "Preview-only character injects counter into skill_11")
	_check(not session.stored_character_draft_data().get("skill_slots", {}).has("skill_11"), "stored editable CharacterDraft remains unmodified by counter preview")

func _counter_data() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "test_counter",
		"name": "Test Counter",
		"type": "counter",
		"damage": 12,
		"mp_cost": 10,
		"cooldown": 1.0,
		"startup": 0.08,
		"active": 1.0,
		"recovery": 0.2,
		"speed": 0.0,
		"range": 180.0,
		"hitstun": 0.18,
		"knockback": 120.0,
		"hitbox_half_width": 42.0,
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
