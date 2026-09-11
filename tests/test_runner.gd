extends SceneTree

const CombatMath = preload("res://game/core/combat/combat_math.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_combat_math()
	_test_skill_fixture()

	if failures == 0:
		print("ALL_TESTS_PASSED")
		quit(0)
		return

	printerr("TEST_FAILURES=%d" % failures)
	quit(1)

func _test_combat_math() -> void:
	_check(CombatMath.calculate_damage(100.0) == 100, "base damage")
	_check(CombatMath.calculate_damage(100.0, 1.5, 1.0) == 150, "attack multiplier")
	_check(CombatMath.calculate_damage(100.0, 1.0, 2.0) == 50, "defense multiplier")
	_check(CombatMath.calculate_damage(-10.0) == 0, "negative damage clamp")
	_check(CombatMath.can_cast(20.0, 20.0, 0.0), "cast with exact MP")
	_check(not CombatMath.can_cast(19.0, 20.0, 0.0), "reject insufficient MP")
	_check(not CombatMath.can_cast(100.0, 20.0, 0.1), "reject active cooldown")
	_check(is_equal_approx(CombatMath.remaining_mp(50.0, 20.0), 30.0), "remaining MP")
	_check(is_equal_approx(CombatMath.knockback_direction(10.0, 20.0), 1.0), "right knockback")
	_check(is_equal_approx(CombatMath.knockback_direction(20.0, 10.0), -1.0), "left knockback")

func _test_skill_fixture() -> void:
	var raw := FileAccess.get_file_as_string("res://content/skills/fireball.sample.json")
	_check(not raw.is_empty(), "skill fixture exists")
	if raw.is_empty():
		return

	var parsed = JSON.parse_string(raw)
	_check(typeof(parsed) == TYPE_DICTIONARY, "skill fixture parses as dictionary")
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var required_fields := [
		"schema_version", "id", "name", "type", "damage", "mp_cost", "cooldown",
		"startup", "active", "recovery", "visual", "impact_visual"
	]
	for field in required_fields:
		_check(parsed.has(field), "skill fixture field: %s" % field)

	_check(parsed.get("type", "") == "projectile", "skill fixture type")
	_check(float(parsed.get("damage", -1)) > 0.0, "skill fixture positive damage")
	_check(float(parsed.get("cooldown", -1)) >= 0.0, "skill fixture non-negative cooldown")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return

	failures += 1
	printerr("FAIL: %s" % label)
