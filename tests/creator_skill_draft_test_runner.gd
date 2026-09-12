extends SceneTree

const SkillDraft = preload("res://game/creator/skill_editor/skill_draft.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var draft := SkillDraft.new()
	_check(draft.is_valid(), "starter projectile skill draft validates")
	var data := draft.to_dictionary()
	_check(str(data.get("id", "")) == "my_projectile_001", "draft serializes id")
	_check(str(data.get("name", "")) == "My Projectile", "draft serializes name")
	_check(str(data.get("type", "")) == "projectile", "draft serializes projectile type")
	_check(int(data.get("damage", 0)) == 18, "draft serializes damage")
	_check(int(data.get("mp_cost", 0)) == 25, "draft serializes MP cost")
	_check(is_equal_approx(float(data.get("speed", 0.0)), 560.0), "draft serializes projectile speed")
	_check(is_equal_approx(float(data.get("range", 0.0)), 900.0), "draft serializes projectile range")
	_check(str(data.get("visual", "")) == "prototype_fireball", "draft preserves safe starter visual")

	var definition := SkillDefinition.new()
	var definition_errors := definition.load_from_dictionary(data)
	_check(definition_errors.is_empty() and definition.loaded, "draft feeds runtime SkillDefinition contract")
	_check(definition.skill_type == "projectile", "runtime contract sees projectile type")

	draft.skill_name = ""
	_check(_contains_error(draft.validate(), "name must not be empty"), "blank skill name fails closed")

	draft.skill_name = "Nova Bolt"
	draft.speed = 0.0
	_check(_contains_error(draft.validate(), "projectile speed must be positive"), "zero projectile speed fails closed")

	draft.speed = 700.0
	draft.range = 0.0
	_check(_contains_error(draft.validate(), "projectile range must be positive"), "zero projectile range fails closed")

	draft.range = 1050.0
	draft.skill_id = "../evil.gd"
	_check(_contains_error(draft.validate(), "id must be a safe lowercase reference token"), "unsafe creator skill id is rejected")

	draft.skill_id = "nova_bolt_001"
	draft.skill_type = "melee"
	_check(_contains_error(draft.validate(), "creator projectile draft type must remain projectile"), "creator template type cannot be switched outside projectile slice")

	draft.reset()
	_check(draft.is_valid(), "reset restores valid starter projectile")
	_check(draft.skill_name == "My Projectile" and draft.damage == 18 and is_equal_approx(draft.speed, 560.0), "reset restores starter values")

	if failures == 0:
		print("CREATOR_SKILL_DRAFT_TESTS_PASSED")
		quit(0)
		return
	printerr("CREATOR_SKILL_DRAFT_TEST_FAILURES=%d" % failures)
	quit(1)

func _contains_error(errors: PackedStringArray, expected: String) -> bool:
	for error in errors:
		if error == expected:
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
