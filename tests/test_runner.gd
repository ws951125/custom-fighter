extends SceneTree

const CombatMath = preload("res://game/core/combat/combat_math.gd")
const CombatantState = preload("res://game/core/combat/combatant_state.gd")
const CombatBox = preload("res://game/core/combat/combat_box.gd")
const AttackChainState = preload("res://game/core/combat/attack_chain_state.gd")
const KnockbackState = preload("res://game/core/combat/knockback_state.gd")
const KnockdownState = preload("res://game/core/combat/knockdown_state.gd")
const MovementState = preload("res://game/core/movement/movement_state.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const ProjectileState = preload("res://game/core/skills/projectile_state.gd")
const DashAttackState = preload("res://game/core/skills/dash_attack_state.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_combat_math()
	_test_combatant_state()
	_test_combat_boxes()
	_test_attack_chain()
	_test_knockback_state()
	_test_knockdown_state()
	_test_movement_state()
	_test_skill_definition()
	_test_skill_cast_state()
	_test_projectile_state()
	_test_dash_attack_state()

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

func _test_combatant_state() -> void:
	var fighter := CombatantState.new(100, 50)
	_check(fighter.hp == 100 and fighter.mp == 50, "combatant initializes resources")
	_check(fighter.apply_damage(30) == 30 and fighter.hp == 70, "combatant applies damage")
	_check(fighter.apply_damage(20, true) == 7 and fighter.hp == 63, "guard reduces damage")
	_check(fighter.restore_hp(100) == 37 and fighter.hp == 100, "healing clamps to max HP")
	_check(fighter.spend_mp(20) and fighter.mp == 30, "combatant spends MP")
	_check(not fighter.spend_mp(31) and fighter.mp == 30, "combatant rejects insufficient MP")
	fighter.apply_hitstun(0.25)
	fighter.tick(0.10)
	_check(is_equal_approx(fighter.hitstun_remaining, 0.15), "hitstun ticks down")
	fighter.apply_damage(999)
	_check(fighter.hp == 0 and fighter.is_defeated(), "combatant defeat clamps HP")

func _test_combat_boxes() -> void:
	var hitbox := CombatBox.new(Vector2(100.0, 0.50), Vector2(40.0, 0.12))
	var overlapping_hurtbox := CombatBox.new(Vector2(138.0, 0.58), Vector2(20.0, 0.08))
	var separated_x := CombatBox.new(Vector2(180.0, 0.50), Vector2(20.0, 0.08))
	var separated_depth := CombatBox.new(Vector2(110.0, 0.90), Vector2(20.0, 0.08))

	_check(hitbox.overlaps(overlapping_hurtbox), "hitbox overlaps hurtbox")
	_check(not hitbox.overlaps(separated_x), "hitbox rejects horizontal miss")
	_check(not hitbox.overlaps(separated_depth), "hitbox rejects depth miss")
	_check(is_equal_approx(hitbox.left(), 60.0) and is_equal_approx(hitbox.right(), 140.0), "combat box horizontal bounds")

func _test_attack_chain() -> void:
	var chain := AttackChainState.new()
	_check(chain.combo_step == 0 and not chain.is_attacking(), "attack chain starts idle")
	_check(chain.try_start_attack() == 1, "combo starts at step one")
	_check(chain.damage_for_step(1) == 12, "step one damage")
	_check(chain.try_start_attack() == 0, "attack lock rejects mash during recovery")
	chain.tick(0.15)
	_check(chain.try_start_attack() == 2, "combo advances to step two")
	_check(chain.damage_for_step(2) == 14, "step two damage")
	chain.tick(0.17)
	_check(chain.try_start_attack() == 3, "combo advances to step three")
	_check(chain.damage_for_step(3) == 20, "step three damage")
	_check(chain.knockback_for_step(3) > chain.knockback_for_step(2), "finisher has stronger knockback")
	_check(chain.hitbox_half_width_for_step(3) > chain.hitbox_half_width_for_step(1), "finisher has larger hitbox")
	chain.tick(0.25)
	chain.tick(0.40)
	_check(chain.combo_step == 0, "combo resets after timeout")

func _test_knockback_state() -> void:
	var knockback := KnockbackState.new()
	knockback.apply_impulse(430.0)
	_check(knockback.is_active() and is_equal_approx(knockback.last_impulse, 430.0), "knockback accepts impulse")
	var first_displacement := knockback.tick(0.10)
	_check(first_displacement > 40.0, "knockback produces displacement")
	_check(knockback.velocity > 0.0 and knockback.velocity < 430.0, "knockback drag reduces velocity")
	knockback.tick(0.50)
	_check(not knockback.is_active(), "knockback settles to rest")

func _test_knockdown_state() -> void:
	var recovery := KnockdownState.new()
	_check(recovery.state_name() == "READY" and recovery.can_be_hit(), "knockdown starts ready")
	_check(recovery.knock_down(), "knockdown can start")
	_check(recovery.state_name() == "DOWN" and recovery.is_knocked_down(), "knockdown enters down phase")
	_check(not recovery.can_be_hit() and recovery.is_invulnerable(), "down phase is protected")
	_check(not recovery.knock_down(), "knockdown cannot restart while protected")
	recovery.tick(KnockdownState.DOWN_SECONDS + 0.01)
	_check(recovery.state_name() == "RECOVERING", "knockdown advances to recovery")
	_check(recovery.is_knocked_down() and not recovery.can_be_hit(), "recovery remains protected")
	recovery.tick(KnockdownState.RECOVERY_SECONDS + 0.01)
	_check(recovery.state_name() == "INVULNERABLE", "recovery advances to standing invulnerability")
	_check(not recovery.is_knocked_down() and recovery.is_invulnerable(), "standing protection is not a down pose")
	recovery.tick(KnockdownState.INVULNERABLE_SECONDS + 0.01)
	_check(recovery.state_name() == "READY", "invulnerability expires")
	_check(recovery.can_be_hit() and not recovery.is_invulnerable(), "fighter becomes hittable after recovery")

func _test_movement_state() -> void:
	var movement := MovementState.new()
	_check(not movement.jumping and not movement.is_dashing(), "movement starts grounded")
	_check(movement.start_jump(), "jump starts")
	_check(not movement.start_jump(), "double jump rejected")
	movement.tick(0.13)
	_check(movement.jumping and movement.jump_offset() > 0.0, "jump arc rises")
	movement.tick(0.50)
	_check(not movement.jumping and is_zero_approx(movement.jump_offset()), "jump returns to ground")
	_check(movement.start_dash(1.0), "dash starts")
	_check(movement.is_dashing() and movement.dash_velocity() > 0.0, "dash moves right")
	_check(not movement.start_dash(-1.0), "dash cannot restart while active")
	movement.tick(0.20)
	_check(not movement.is_dashing(), "dash duration completes")
	_check(not movement.can_dash(), "dash cooldown remains")
	movement.tick(0.30)
	_check(movement.can_dash(), "dash cooldown completes")
	_check(movement.start_dash(-1.0) and movement.dash_velocity() < 0.0, "dash supports left direction")

func _load_fireball_definition():
	var skill := SkillDefinition.new()
	var errors := skill.load_from_file("res://content/skills/fireball.sample.json")
	_check(errors.is_empty(), "fireball definition validates: %s" % ", ".join(errors))
	return skill

func _load_dash_slash_definition():
	var skill := SkillDefinition.new()
	var errors := skill.load_from_file("res://content/skills/dash_slash.sample.json")
	_check(errors.is_empty(), "dash slash definition validates: %s" % ", ".join(errors))
	return skill

func _test_skill_definition() -> void:
	var skill = _load_fireball_definition()
	_check(skill.loaded, "skill definition marks valid data as loaded")
	_check(skill.skill_id == "fireball_001" and skill.skill_type == "projectile", "skill identity loads from JSON")
	_check(skill.skill_name == "Training Fireball", "skill display name loads from JSON")
	_check(skill.damage == 18 and skill.mp_cost == 25, "skill damage and MP load from JSON")
	_check(is_equal_approx(skill.cooldown, 1.8) and is_equal_approx(skill.startup, 0.22), "skill timing loads from JSON")
	_check(is_equal_approx(skill.speed, 560.0) and is_equal_approx(skill.range, 900.0), "projectile motion loads from JSON")
	_check(is_equal_approx(skill.hitbox_half_width, 28.0), "projectile hitbox loads from JSON")

	var dash_skill = _load_dash_slash_definition()
	_check(dash_skill.loaded and dash_skill.skill_type == "dash", "dash skill loads through the same schema")
	_check(dash_skill.damage == 16 and dash_skill.mp_cost == 20, "dash damage and MP load from JSON")
	_check(is_equal_approx(dash_skill.speed, 1000.0) and is_equal_approx(dash_skill.range, 260.0), "dash motion loads from JSON")
	_check(is_equal_approx(dash_skill.hitbox_half_width, 44.0), "dash hitbox loads from JSON")

	var invalid := SkillDefinition.new()
	var invalid_errors := invalid.load_from_dictionary({"schema_version": 1})
	_check(not invalid_errors.is_empty() and not invalid.loaded, "invalid skill data is rejected")

	var invalid_dash := SkillDefinition.new()
	var invalid_dash_errors := invalid_dash.load_from_dictionary({
		"schema_version": 1, "id": "bad_dash", "name": "Bad Dash", "type": "dash",
		"damage": 1, "mp_cost": 1, "cooldown": 1.0, "startup": 0.1, "active": 0.1,
		"recovery": 0.1, "speed": 0, "range": 0, "hitbox_half_width": 0,
		"hitbox_half_depth": 0, "visual": "x", "impact_visual": "y"
	})
	_check(not invalid_dash_errors.is_empty() and not invalid_dash.loaded, "invalid dash motion data is rejected")

func _test_skill_cast_state() -> void:
	var skill = _load_fireball_definition()
	var cast := SkillCastState.new()
	cast.configure(skill)
	_check(cast.phase_name() == "READY" and cast.can_cast(100), "skill cast starts ready")
	_check(not cast.can_cast(skill.mp_cost - 1), "skill cast rejects insufficient MP")
	_check(cast.start_cast(100), "skill cast starts with enough MP")
	_check(cast.phase_name() == "STARTUP", "skill cast enters startup")
	_check(is_equal_approx(cast.cooldown_remaining, skill.cooldown), "skill cast starts cooldown")
	_check(not cast.start_cast(100), "skill cast rejects recast while active")
	cast.tick(skill.startup - 0.01)
	_check(cast.phase_name() == "STARTUP" and not cast.consume_activation(), "startup does not activate early")
	cast.tick(0.02)
	_check(cast.phase_name() == "ACTIVE", "startup advances to active")
	_check(cast.consume_activation(), "active transition emits one activation event")
	_check(not cast.consume_activation(), "activation event is consumed once")
	cast.tick(skill.active + skill.recovery + 0.10)
	_check(cast.phase_name() == "READY", "skill cast returns to ready after recovery")
	_check(cast.cooldown_remaining > 0.0 and not cast.can_cast(100), "cooldown continues after animation recovery")
	cast.tick(skill.cooldown)
	_check(cast.can_cast(100), "skill becomes castable after cooldown")

	var dash_skill = _load_dash_slash_definition()
	var dash_cast := SkillCastState.new()
	dash_cast.configure(dash_skill)
	_check(dash_cast.start_cast(100), "generic cast state accepts dash template")
	dash_cast.tick(dash_skill.startup + 0.01)
	_check(dash_cast.consume_activation(), "dash template receives the generic activation event")

func _test_projectile_state() -> void:
	var projectile := ProjectileState.new()
	_check(projectile.spawn(0.0, 0.50, 1.0, 560.0, 900.0, 2.0), "projectile spawns with valid motion data")
	projectile.tick(0.10)
	_check(projectile.active and projectile.x > 50.0, "projectile advances by speed")
	var swept_box := projectile.swept_hitbox(28.0, 0.08)
	var crossed_target := CombatBox.new(Vector2(50.0, 0.50), Vector2(4.0, 0.05))
	_check(swept_box.overlaps(crossed_target), "projectile swept hitbox catches crossed target")
	projectile.deactivate()
	_check(not projectile.active, "projectile can deactivate after impact")
	_check(projectile.spawn(0.0, 0.50, -1.0, 100.0, 10.0, 2.0), "projectile can spawn facing left")
	projectile.tick(0.20)
	_check(projectile.x < 0.0 and not projectile.active, "projectile expires at configured range")

func _test_dash_attack_state() -> void:
	var dash := DashAttackState.new()
	_check(dash.start(100.0, 0.50, 1.0, 1000.0, 260.0), "dash attack starts with valid motion data")
	dash.tick(0.10)
	_check(dash.active and is_equal_approx(dash.x, 200.0), "dash attack advances by configured speed")
	var swept_box := dash.swept_hitbox(44.0, 0.10)
	var crossed_target := CombatBox.new(Vector2(150.0, 0.50), Vector2(4.0, 0.05))
	_check(swept_box.overlaps(crossed_target), "dash swept hitbox catches crossed target")
	dash.tick(0.20)
	_check(not dash.active and is_equal_approx(dash.travelled, 260.0), "dash attack stops at configured range")
	_check(dash.start(360.0, 0.50, -1.0, 800.0, 80.0), "dash attack can start facing left")
	dash.tick(0.10)
	_check(is_equal_approx(dash.x, 280.0) and not dash.active, "left dash respects configured range")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	printerr("FAIL: %s" % label)
