extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const BuffState = preload("res://game/core/skills/buff_state.gd")
const AttackChainState = preload("res://game/core/combat/attack_chain_state.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_buff_definition()
	_test_buff_state()
	_test_attack_damage_multiplier()

	if failures == 0:
		print("BUFF_TESTS_PASSED")
		quit(0)
		return

	printerr("BUFF_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_buff_definition() -> void:
	var skill := SkillDefinition.new()
	var errors := skill.load_from_file("res://content/skills/battle_focus.sample.json")
	_check(errors.is_empty(), "battle focus definition validates: %s" % ", ".join(errors))
	_check(skill.loaded and skill.skill_type == "buff", "buff definition loads")
	_check(skill.skill_id == "battle_focus_001", "buff identity loads from JSON")
	_check(skill.mp_cost == 25 and skill.damage == 0, "buff MP and zero direct damage load from JSON")
	_check(is_equal_approx(skill.buff_duration, 3.2), "buff duration loads from JSON")
	_check(is_equal_approx(skill.move_speed_multiplier, 1.45), "buff movement multiplier loads from JSON")
	_check(is_equal_approx(skill.basic_attack_damage_multiplier, 1.50), "buff attack multiplier loads from JSON")

	var invalid := SkillDefinition.new()
	var invalid_errors := invalid.load_from_dictionary({
		"schema_version": 1,
		"id": "bad_buff",
		"name": "Bad Buff",
		"type": "buff",
		"damage": 0,
		"mp_cost": 1,
		"cooldown": 1.0,
		"startup": 0.1,
		"active": 0.1,
		"recovery": 0.1,
		"buff_duration": 0.0,
		"move_speed_multiplier": 0.9,
		"basic_attack_damage_multiplier": 0.8,
		"visual": "x",
		"impact_visual": "y"
	})
	_check(not invalid_errors.is_empty() and not invalid.loaded, "invalid buff data is rejected")

func _test_buff_state() -> void:
	var buff := BuffState.new()
	_check(not buff.active, "buff starts inactive")
	_check(buff.start(3.2, 1.45, 1.50), "buff starts with valid multipliers")
	_check(buff.active and buff.activation_count == 1, "buff activation is recorded")
	_check(is_equal_approx(buff.movement_multiplier(), 1.45), "active buff exposes movement multiplier")
	_check(is_equal_approx(buff.attack_multiplier(), 1.50), "active buff exposes attack multiplier")
	buff.tick(1.0)
	_check(buff.active and buff.remaining > 2.1, "buff duration ticks down")
	buff.tick(2.3)
	_check(not buff.active and is_zero_approx(buff.remaining), "buff expires after configured duration")
	_check(is_equal_approx(buff.movement_multiplier(), 1.0), "expired buff restores movement multiplier")
	_check(is_equal_approx(buff.attack_multiplier(), 1.0), "expired buff restores attack multiplier")
	_check(not buff.start(0.0, 1.2, 1.2), "buff rejects zero duration")
	_check(not buff.start(1.0, 0.9, 1.2), "buff rejects movement multiplier below baseline")

func _test_attack_damage_multiplier() -> void:
	var chain := AttackChainState.new()
	_check(chain.damage_for_step(1) == 12, "attack damage starts at baseline")
	chain.set_damage_multiplier(1.50)
	_check(chain.damage_for_step(1) == 18, "buffed step one damage scales")
	_check(chain.damage_for_step(2) == 21, "buffed step two damage scales")
	_check(chain.damage_for_step(3) == 30, "buffed step three damage scales")
	chain.set_damage_multiplier(1.0)
	_check(chain.damage_for_step(1) == 12, "attack damage returns to baseline")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	printerr("FAIL: %s" % label)
