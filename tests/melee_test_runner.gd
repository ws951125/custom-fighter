extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const MeleeAttackState = preload("res://game/core/skills/melee_attack_state.gd")
const SkillCoordinator = preload("res://game/core/skills/skill_coordinator.gd")
const CombatBox = preload("res://game/core/combat/combat_box.gd")
const AttackChainState = preload("res://game/core/combat/attack_chain_state.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_melee_definition()
	_test_melee_state()
	_test_combo_playable_frame_time()
	_test_skill_coordinator()

	if failures == 0:
		print("MELEE_COMBO_AND_COORDINATOR_TESTS_PASSED")
		quit(0)
		return

	printerr("MELEE_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_melee_definition() -> void:
	var skill := SkillDefinition.new()
	var errors := skill.load_from_file("res://content/skills/heavy_strike.sample.json")
	_check(errors.is_empty(), "heavy strike definition validates: %s" % ", ".join(errors))
	_check(skill.loaded and skill.skill_type == "melee", "melee definition loads")
	_check(skill.skill_id == "heavy_strike_001", "melee identity loads from JSON")
	_check(skill.damage == 24 and skill.mp_cost == 18, "melee damage and MP load from JSON")
	_check(is_equal_approx(skill.cooldown, 2.2), "melee cooldown loads from JSON")
	_check(is_equal_approx(skill.range, 72.0), "melee forward range loads from JSON")
	_check(is_equal_approx(skill.hitbox_half_width, 54.0), "melee width loads from JSON")
	_check(is_equal_approx(skill.hitbox_half_depth, 0.10), "melee depth loads from JSON")
	_check(is_equal_approx(skill.hitstun, 0.28) and is_equal_approx(skill.knockback, 360.0), "melee reaction data loads from JSON")

	var invalid := SkillDefinition.new()
	var invalid_errors := invalid.load_from_dictionary({
		"schema_version": 1,
		"id": "bad_melee",
		"name": "Bad Melee",
		"type": "melee",
		"damage": 10,
		"mp_cost": 1,
		"cooldown": 1.0,
		"startup": 0.1,
		"active": 0.0,
		"recovery": 0.1,
		"range": 0.0,
		"hitbox_half_width": 0.0,
		"hitbox_half_depth": 0.0,
		"visual": "x",
		"impact_visual": "y"
	})
	_check(not invalid_errors.is_empty() and not invalid.loaded, "invalid melee data is rejected")

func _test_melee_state() -> void:
	var melee := MeleeAttackState.new()
	_check(not melee.active, "melee starts inactive")
	_check(melee.start(Vector2(100.0, 0.5), 1.0, 72.0, 54.0, 0.10, 0.14), "melee starts with valid geometry")
	_check(melee.active and melee.activation_count == 1, "melee activation is recorded")
	_check(is_equal_approx(melee.center.x, 172.0) and is_equal_approx(melee.center.y, 0.5), "melee center offsets in facing direction")

	var in_range := CombatBox.new(Vector2(205.0, 0.5), Vector2(25.0, 0.05))
	var out_of_range := CombatBox.new(Vector2(300.0, 0.5), Vector2(25.0, 0.05))
	var wrong_depth := CombatBox.new(Vector2(205.0, 0.9), Vector2(25.0, 0.05))
	_check(melee.hitbox().overlaps(in_range), "melee hitbox reaches target in front")
	_check(not melee.hitbox().overlaps(out_of_range), "melee hitbox rejects distant target")
	_check(not melee.hitbox().overlaps(wrong_depth), "melee hitbox rejects wrong depth")
	_check(melee.consume_hit(), "melee consumes first hit")
	_check(not melee.consume_hit(), "melee cannot hit twice in one activation")
	melee.tick(0.20)
	_check(not melee.active, "melee expires after active window")

	_check(melee.start(Vector2(100.0, 0.5), -1.0, 72.0, 54.0, 0.10, 0.14), "melee can face left")
	_check(is_equal_approx(melee.center.x, 28.0), "left-facing melee offsets left")
	_check(not melee.start(Vector2.ZERO, 1.0, 0.0, 54.0, 0.10, 0.14), "melee rejects zero forward offset")

func _test_combo_playable_frame_time() -> void:
	var chain := AttackChainState.new()
	_check(chain.try_start_attack() == 1, "combo regression starts step one")
	var full_window := chain.combo_reset_remaining
	chain.tick(chain.recovery_for_step(1))
	_check(not chain.is_attacking(), "step one recovery completes")
	_check(is_equal_approx(chain.combo_reset_remaining, full_window), "attack recovery does not consume combo input window")

	chain.tick(0.40)
	_check(chain.combo_step == 1, "single 400ms low-FPS frame does not erase combo")
	_check(
		chain.combo_reset_remaining >= full_window - AttackChainState.MAX_COMBO_TIMER_DELTA - 0.001,
		"low-FPS frame consumes at most the per-frame combo budget"
	)
	_check(chain.try_start_attack() == 2, "combo can continue after low-FPS frame")
	_check(chain.buffer_attack(), "next combo input can buffer during recovery")
	chain.tick(0.40)
	_check(chain.combo_step == 3, "buffered finisher resolves across recovery hitch")
	_check(chain.consume_buffered_attack_step() == 3, "buffered finisher emits one execution step")

	var expiry := AttackChainState.new()
	_check(expiry.try_start_attack() == 1, "combo expiry test starts")
	expiry.tick(expiry.recovery_for_step(1))
	for index in range(7):
		expiry.tick(0.10)
	_check(expiry.combo_step == 0, "combo still resets after enough playable input time")

func _test_skill_coordinator() -> void:
	var coordinator := SkillCoordinator.new()
	var projectile := StringName("skill_1")
	var area := StringName("skill_3")

	_check(not coordinator.is_busy(), "skill coordinator starts unlocked")
	_check(not coordinator.can_claim(StringName()), "skill coordinator rejects empty owner")
	_check(coordinator.try_claim(projectile), "first skill atomically claims coordinator")
	_check(coordinator.is_busy() and coordinator.is_owned_by(projectile), "coordinator reports active owner")
	_check(coordinator.claim_count() == 1, "first acquisition increments claim telemetry")
	_check(coordinator.last_claimed_owner_name() == "skill_1", "claim telemetry persists owner identity")
	_check(not coordinator.try_claim(area), "second simultaneous skill is rejected")
	_check(coordinator.rejection_count() == 1, "rejected simultaneous claim is counted")
	_check(coordinator.last_rejected_owner_name() == "skill_3", "rejected owner telemetry persists")
	coordinator.release(area)
	_check(coordinator.is_owned_by(projectile), "non-owner cannot release coordinator")
	_check(coordinator.try_claim(projectile), "current owner may reassert its claim")
	_check(coordinator.claim_count() == 1, "owner reassertion is not a second acquisition")
	coordinator.release(projectile)
	_check(not coordinator.is_busy() and coordinator.owner_name().is_empty(), "owner release unlocks coordinator")
	_check(coordinator.last_claimed_owner_name() == "skill_1", "release preserves audit telemetry")
	_check(coordinator.try_claim(area), "next skill can claim after release")
	_check(coordinator.claim_count() == 2, "next acquisition increments claim telemetry")
	coordinator.reset()
	_check(not coordinator.is_busy(), "coordinator reset clears stale owner")
	_check(coordinator.claim_count() == 0 and coordinator.rejection_count() == 0, "coordinator reset clears telemetry")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	printerr("FAIL: %s" % label)
