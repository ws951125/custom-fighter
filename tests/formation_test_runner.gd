extends SceneTree

const CombatBox = preload("res://game/core/combat/combat_box.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const FormationAttackState = preload("res://game/core/skills/formation_attack_state.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_formation_definition()
	_test_formation_state()

	if failures == 0:
		print("FORMATION_TESTS_PASSED")
		quit(0)
		return

	printerr("FORMATION_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_formation_definition() -> void:
	var skill := SkillDefinition.new()
	var errors := skill.load_from_file("res://content/skills/blade_rain.sample.json")
	_check(errors.is_empty(), "blade rain definition validates: %s" % ", ".join(errors))
	_check(skill.loaded and skill.skill_type == "formation", "formation definition loads")
	_check(skill.skill_id == "blade_rain_001", "formation identity loads from JSON")
	_check(skill.damage == 14 and skill.mp_cost == 35, "formation damage and MP load from JSON")
	_check(skill.formation_count == 5, "formation count loads from JSON")
	_check(is_equal_approx(skill.formation_spacing, 110.0), "formation spacing loads from JSON")
	_check(is_equal_approx(skill.formation_interval, 0.17), "formation interval loads from JSON")
	_check(is_equal_approx(skill.formation_offset, 90.0), "formation offset loads from JSON")

	var invalid := SkillDefinition.new()
	var invalid_errors := invalid.load_from_dictionary({
		"schema_version": 1,
		"id": "bad_formation",
		"name": "Bad Formation",
		"type": "formation",
		"damage": 1,
		"mp_cost": 1,
		"cooldown": 1.0,
		"startup": 0.1,
		"active": 0.2,
		"recovery": 0.1,
		"hitbox_half_width": 0.0,
		"hitbox_half_depth": 0.0,
		"formation_count": 5,
		"formation_spacing": 0.0,
		"formation_interval": 0.17,
		"formation_offset": -1.0,
		"visual": "x",
		"impact_visual": "y"
	})
	_check(not invalid_errors.is_empty() and not invalid.loaded, "invalid formation data is rejected")

func _test_formation_state() -> void:
	var formation := FormationAttackState.new()
	_check(
		formation.start(Vector2(280.0, 0.58), 1.0, 5, 110.0, 0.17, 90.0, 42.0, 0.12, 0.90),
		"formation starts with valid schedule"
	)
	_check(formation.active and formation.emitted_count() == 0, "formation starts active before first tick")
	_check(is_equal_approx(formation.center_for(0).x, 370.0), "first formation cell uses forward offset")
	_check(is_equal_approx(formation.center_for(4).x, 810.0), "formation spacing creates final cell")

	formation.tick(0.01)
	var first_due := formation.consume_due_strikes()
	_check(first_due.size() == 1 and first_due[0] == 0, "first strike emits once at activation")
	_check(formation.consume_due_strikes().is_empty(), "due strike queue is consumable once")

	formation.tick(0.17)
	var second_due := formation.consume_due_strikes()
	_check(second_due.size() == 1 and second_due[0] == 1, "second strike follows configured interval")

	var target := CombatBox.new(Vector2(810.0, 0.58), Vector2(30.0, 0.11))
	_check(formation.strike_hitbox(4).overlaps(target), "final strike hitbox can overlap target")

	formation.tick(0.51)
	var late_due := formation.consume_due_strikes()
	_check(late_due.size() == 3, "large tick emits every newly due strike without skipping")
	_check(formation.emitted_count() == 5, "all configured strikes emit")
	_check(formation.can_hit(4), "emitted cell can hit")
	_check(formation.consume_hit(4), "formation cell consumes first hit")
	_check(not formation.consume_hit(4), "formation cell cannot hit twice")

	formation.tick(0.30)
	_check(not formation.active, "formation expires after configured active duration")
	_check(
		not formation.start(Vector2.ZERO, 1.0, 5, 110.0, 0.17, 90.0, 42.0, 0.12, 0.20),
		"formation rejects duration shorter than final strike schedule"
	)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	printerr("FAIL: %s" % label)
