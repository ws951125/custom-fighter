extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const GrabState = preload("res://game/core/skills/grab_state.gd")
const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")
const CreatorPreviewSession = preload("res://game/creator/preview/creator_preview_session.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_grab_definition_and_registry()
	_test_grab_state()
	_test_optional_character_slot()
	_test_creator_preview_routing()
	if failures == 0:
		print("GRAB_TESTS_PASSED")
		quit(0)
		return
	printerr("GRAB_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_grab_definition_and_registry() -> void:
	var skill := SkillDefinition.new()
	var errors: PackedStringArray = skill.load_from_file("res://content/skills/training_grab.sample.json")
	_check(errors.is_empty() and skill.loaded, "grab sample validates: %s" % " | ".join(errors))
	_check(skill.skill_type == "grab" and skill.skill_id == "training_grab_001", "grab identity loads")
	_check(is_equal_approx(skill.range, 120.0), "grab bounded source offset loads")
	_check(is_equal_approx(skill.active, 0.65), "grab finite hold window loads")
	_check(is_equal_approx(skill.knockback, 56.0), "grab bounded target offset loads")
	_check(is_equal_approx(skill.hitbox_half_width, 54.0) and is_equal_approx(skill.hitbox_half_depth, 0.14), "grab bounded source volume loads")

	var invalid_window := SkillDefinition.new()
	var invalid_window_data := _grab_data()
	invalid_window_data["active"] = SkillDefinition.MAX_GRAB_WINDOW + 0.01
	_check(_contains_fragment(invalid_window.load_from_dictionary(invalid_window_data), "grab active window must be"), "oversized grab window fails closed")

	var invalid_range := SkillDefinition.new()
	var invalid_range_data := _grab_data()
	invalid_range_data["range"] = SkillDefinition.MAX_GRAB_RANGE + 0.01
	_check(_contains_fragment(invalid_range.load_from_dictionary(invalid_range_data), "grab range must be"), "oversized grab range fails closed")

	var invalid_offset := SkillDefinition.new()
	var invalid_offset_data := _grab_data()
	invalid_offset_data["knockback"] = SkillDefinition.MAX_GRAB_OFFSET + 0.01
	_check(_contains_fragment(invalid_offset.load_from_dictionary(invalid_offset_data), "grab target offset must be"), "oversized grab target offset fails closed")

	var invalid_depth := SkillDefinition.new()
	var invalid_depth_data := _grab_data()
	invalid_depth_data["hitbox_half_depth"] = 0.0
	_check(_contains_fragment(invalid_depth.load_from_dictionary(invalid_depth_data), "grab hitbox_half_depth must be"), "zero grab depth fails closed")

	var registry := SkillRegistry.new()
	var registry_errors: PackedStringArray = registry.load_default()
	_check(registry_errors.is_empty() and registry.loaded, "skill registry accepts grab entry")
	var resolved := SkillDefinition.new()
	var resolve_errors: PackedStringArray = registry.load_skill("training_grab_001", "grab", resolved)
	_check(resolve_errors.is_empty() and resolved.loaded, "registry resolves grab with exact type")
	var mismatch := SkillDefinition.new()
	var mismatch_errors: PackedStringArray = registry.load_skill("training_grab_001", "melee", mismatch)
	_check(_contains_fragment(mismatch_errors, "expected melee but registry declares grab"), "registry rejects grab/controller type mismatch")

	var cast := SkillCastState.new()
	cast.configure(skill)
	_check(cast.start_cast(100), "grab uses shared deterministic cast state")
	cast.tick(skill.startup + 0.01)
	_check(cast.consume_activation(), "grab emits shared activation boundary")

func _test_grab_state() -> void:
	var grab := GrabState.new()
	var player := Vector2(400.0, 0.50)
	var target_half := Vector2(30.0, 0.11)
	_check(not grab.try_capture(player, Vector2(760.0, 0.50), target_half, 1.0, 120.0, 54.0, 0.14, 0.65, 56.0, 90.0, 1190.0), "grab rejects target without actual source-volume overlap")
	_check(not grab.active and grab.capture_count == 0, "failed grab causes no control state")
	_check(not grab.try_capture(player, Vector2(520.0, 0.90), target_half, 1.0, 120.0, 54.0, 0.14, 0.65, 56.0, 90.0, 1190.0), "grab rejects target outside bounded depth overlap")
	_check(not grab.try_capture(player, Vector2(520.0, 0.50), target_half, 1.0, 120.0, 54.0, 0.14, 0.65, 56.0, 500.0, 500.0), "grab fails closed on invalid arena geometry")
	_check(not grab.try_capture(Vector2(1050.0, 0.50), Vector2(1200.0, 0.50), target_half, 1.0, 120.0, 54.0, 0.14, 0.65, 56.0, 90.0, 1190.0), "grab rejects target center outside arena even when source volume would overlap")
	_check(not grab.try_capture(Vector2(1100.0, 0.50), Vector2(1180.0, 0.50), target_half, 1.0, 120.0, 54.0, 0.14, 0.65, 56.0, 90.0, 1190.0), "grab rejects source center outside arena")
	_check(grab.try_capture(player, Vector2(520.0, 0.55), target_half, 1.0, 120.0, 54.0, 0.14, 0.65, 56.0, 90.0, 1190.0), "grab accepts an actually overlapping eligible target")
	_check(grab.active and grab.captured and grab.activation_count == 1 and grab.capture_count == 1, "grab starts one finite capture")
	_check(grab.last_target_start.is_equal_approx(Vector2(520.0, 0.55)), "grab records actual captured target position")
	_check(grab.last_target_destination.is_equal_approx(Vector2(456.0, 0.50)), "grab resolves bounded target anchor")
	_check(not grab.try_capture(player, Vector2(520.0, 0.55), target_half, 1.0, 120.0, 54.0, 0.14, 0.65, 56.0, 90.0, 1190.0), "active grab rejects a second capture attempt")
	_check(grab.capture_count == 1 and grab.captured, "second attempt cannot clear or duplicate the active capture")
	grab.tick(0.25)
	_check(grab.active and is_equal_approx(grab.remaining, 0.40), "grab hold window ticks deterministically")
	var moved_anchor := grab.anchored_target_position(Vector2(410.0, 0.52), 1.0, 56.0, 90.0, 1190.0)
	_check(moved_anchor.is_equal_approx(Vector2(466.0, 0.52)), "active grab follows bounded player anchor")
	grab.tick(0.50)
	_check(not grab.active and grab.capture_count == 1, "grab expires without repeated capture")

func _test_optional_character_slot() -> void:
	var draft := CharacterDraft.new()
	var legacy_data: Dictionary = draft.to_dictionary()
	var legacy := CharacterDefinition.new()
	var legacy_errors: PackedStringArray = legacy.load_from_dictionary(legacy_data)
	_check(legacy_errors.is_empty() and legacy.loaded, "legacy six-slot character remains valid")
	_check(legacy.skill_id_for_slot("skill_12").is_empty(), "legacy character has no synthetic skill_12")
	var grab_data: Dictionary = legacy_data.duplicate(true)
	var slots: Dictionary = grab_data.get("skill_slots", {}).duplicate(true)
	slots["skill_12"] = "training_grab_001"
	grab_data["skill_slots"] = slots
	var grab_character := CharacterDefinition.new()
	var grab_errors: PackedStringArray = grab_character.load_from_dictionary(grab_data)
	_check(grab_errors.is_empty() and grab_character.loaded, "optional skill_12 character validates")
	_check(grab_character.skill_id_for_slot("skill_12") == "training_grab_001", "optional skill_12 round-trips")

func _test_creator_preview_routing() -> void:
	var character := CharacterDraft.new()
	var skill := SkillDraft.new()
	_check(skill.set_skill_type("grab"), "Creator accepts grab family")
	skill.skill_id = "preview_grab_001"
	skill.skill_name = "Preview Grab"
	skill.damage = 13
	skill.mp_cost = 9
	skill.cooldown = 0.6
	skill.set_timeline_events([
		{"id": "grab_audio", "type": "audio", "time": 0.0, "duration": 0.0, "cue": "skill_cast"}
	])
	_check(skill.validate().is_empty(), "Creator grab defaults and timeline validate")
	var session := CreatorPreviewSession.new()
	var errors: PackedStringArray = session.stage_preview(character.to_dictionary(), skill.to_dictionary())
	_check(errors.is_empty(), "Creator Preview stages grab: %s" % " | ".join(errors))
	_check(session.preview_skill_type() == "grab", "Creator Preview reports grab family")
	_check(session.preview_skill_slot() == "skill_12", "Creator Preview maps grab to skill_12")
	_check(str(session.preview_character_data().get("skill_slots", {}).get("skill_12", "")) == "preview_grab_001", "Preview-only character injects grab into skill_12")
	_check(not session.stored_character_draft_data().get("skill_slots", {}).has("skill_12"), "stored editable CharacterDraft remains unmodified by grab preview")

func _grab_data() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "test_grab",
		"name": "Test Grab",
		"type": "grab",
		"damage": 12,
		"mp_cost": 10,
		"cooldown": 1.0,
		"startup": 0.08,
		"active": 0.65,
		"recovery": 0.2,
		"speed": 0.0,
		"range": 120.0,
		"hitstun": 0.65,
		"knockback": 56.0,
		"hitbox_half_width": 54.0,
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
