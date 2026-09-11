extends Control

const CombatantState = preload("res://game/core/combat/combatant_state.gd")
const MovementState = preload("res://game/core/movement/movement_state.gd")
const CombatBox = preload("res://game/core/combat/combat_box.gd")
const AttackChainState = preload("res://game/core/combat/attack_chain_state.gd")
const KnockbackState = preload("res://game/core/combat/knockback_state.gd")
const KnockdownState = preload("res://game/core/combat/knockdown_state.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillCastState = preload("res://game/core/skills/skill_cast_state.gd")
const ProjectileState = preload("res://game/core/skills/projectile_state.gd")
const DashAttackState = preload("res://game/core/skills/dash_attack_state.gd")

const MOVE_SPEED := 360.0
const DEPTH_SPEED := 0.72
const RUN_MULTIPLIER := 1.60
const GUARD_MOVE_MULTIPLIER := 0.35
const SKILL_MOVE_MULTIPLIER := 0.20
const DUMMY_HURTBOX_HALF_WIDTH := 30.0
const DUMMY_HURTBOX_HALF_DEPTH := 0.11
const FIREBALL_SKILL_PATH := "res://content/skills/fireball.sample.json"
const DASH_SLASH_SKILL_PATH := "res://content/skills/dash_slash.sample.json"

var player_x := 280.0
var player_depth := 0.58
var player_facing := 1.0
var dummy_x := 860.0
var dummy_depth := 0.58

var attack_visual_timer := 0.0
var attack_latched := false
var jump_latched := false
var dash_latched := false
var skill_1_latched := false
var skill_2_latched := false
var player_guarding := false
var player_running := false
var dummy_hit_timer := 0.0
var fireball_impact_timer := 0.0
var fireball_impact_x := 0.0
var dash_slash_impact_timer := 0.0
var dash_slash_impact_x := 0.0
var web_sync_accumulator := 0.0
var last_attack_step := 0
var last_attack_hit := false
var fireball_last_hit := false
var fireball_hit_count := 0
var dash_slash_last_hit := false
var dash_slash_hit_count := 0

var player_state := CombatantState.new(100, 100)
var dummy_state := CombatantState.new(100, 0)
var movement_state := MovementState.new()
var attack_chain_state := AttackChainState.new()
var dummy_knockback_state := KnockbackState.new()
var dummy_recovery_state := KnockdownState.new()
var fireball_skill := SkillDefinition.new()
var fireball_cast_state := SkillCastState.new()
var fireball_projectile := ProjectileState.new()
var dash_slash_skill := SkillDefinition.new()
var dash_slash_cast_state := SkillCastState.new()
var dash_slash_state := DashAttackState.new()
var status_label: Label
var skill_label: Label
var skill_2_label: Label

func _ready() -> void:
	_ensure_input_actions()
	_load_fireball_skill()
	_load_dash_slash_skill()
	_create_label("CUSTOM FIGHTER", Vector2(48, 28), 34)
	_create_label("Milestone 2 · Data-Driven Multi-Template Skills", Vector2(50, 72), 20)
	_create_label("Move: WASD / Arrows   Run: Shift   Jump: Space   Attack: J   Dash: K   Guard: L   Skill 1: U   Skill 2: I", Vector2(50, 108), 16)
	_create_label("Training goal: U = projectile fireball · I = JSON-driven dash slash · J → J → J = knockdown", Vector2(50, 138), 15)
	status_label = _create_label("", Vector2(50, 170), 16)
	skill_label = _create_label("", Vector2(50, 198), 16)
	skill_2_label = _create_label("", Vector2(50, 224), 16)
	_set_web_state()
	queue_redraw()

func _process(delta: float) -> void:
	_handle_action_edges()
	movement_state.tick(delta)
	attack_chain_state.tick(delta)
	dummy_recovery_state.tick(delta)
	fireball_cast_state.tick(delta)
	dash_slash_cast_state.tick(delta)

	if fireball_cast_state.consume_activation():
		_spawn_fireball()
	if dash_slash_cast_state.consume_activation():
		_start_dash_slash()

	var projectile_was_active := fireball_projectile.active
	fireball_projectile.tick(delta)
	if projectile_was_active:
		_resolve_fireball_collision()

	if dash_slash_state.active:
		dash_slash_state.tick(delta)
		player_x = dash_slash_state.x
		_resolve_dash_slash_collision()

	dummy_x += dummy_knockback_state.tick(delta)
	dummy_x = clampf(dummy_x, 90.0, maxf(size.x, 1280.0) - 90.0)

	var move_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if move_vector.length_squared() > 1.0:
		move_vector = move_vector.normalized()

	player_guarding = (
		Input.is_action_pressed("guard")
		and not movement_state.is_dashing()
		and not _any_skill_casting()
	)
	player_running = (
		Input.is_action_pressed("run")
		and move_vector.length_squared() > 0.01
		and not player_guarding
		and not movement_state.is_dashing()
		and not attack_chain_state.is_attacking()
		and not _any_skill_casting()
	)

	if dash_slash_state.active:
		pass
	elif movement_state.is_dashing():
		player_x += movement_state.dash_velocity() * delta
	else:
		var speed_multiplier := RUN_MULTIPLIER if player_running else 1.0
		if player_guarding:
			speed_multiplier *= GUARD_MOVE_MULTIPLIER
		if attack_chain_state.is_attacking():
			speed_multiplier *= 0.30
		if _any_skill_casting():
			speed_multiplier *= SKILL_MOVE_MULTIPLIER
		player_x += move_vector.x * MOVE_SPEED * speed_multiplier * delta
		player_depth += move_vector.y * DEPTH_SPEED * speed_multiplier * delta

	player_x = clampf(player_x, 90.0, maxf(size.x, 1280.0) - 90.0)
	if dash_slash_state.active:
		dash_slash_state.x = player_x
	player_depth = clampf(player_depth, 0.0, 1.0)
	if absf(move_vector.x) > 0.01 and not movement_state.is_dashing() and not dash_slash_state.active:
		player_facing = signf(move_vector.x)

	var attacking := Input.is_action_pressed("attack")
	if (
		attacking
		and not attack_latched
		and not player_guarding
		and not movement_state.is_dashing()
		and not _any_skill_casting()
	):
		_begin_attack()
	attack_latched = attacking

	attack_visual_timer = maxf(0.0, attack_visual_timer - delta)
	dummy_hit_timer = maxf(0.0, dummy_hit_timer - delta)
	fireball_impact_timer = maxf(0.0, fireball_impact_timer - delta)
	dash_slash_impact_timer = maxf(0.0, dash_slash_impact_timer - delta)
	player_state.tick(delta)
	dummy_state.tick(delta)

	status_label.text = "Dummy HP: %d / %d    Distance: %d    Combo: %d    Dummy: %s    Player: %s" % [
		dummy_state.hp,
		dummy_state.max_hp,
		roundi(absf(dummy_x - player_x)),
		attack_chain_state.combo_step,
		dummy_recovery_state.state_name(),
		_player_state_name()
	]
	var fireball_name := fireball_skill.skill_name if fireball_skill.loaded else "Skill unavailable"
	var dash_slash_name := dash_slash_skill.skill_name if dash_slash_skill.loaded else "Skill unavailable"
	skill_label.text = "MP: %d / %d    [U] %s    Phase: %s    Cooldown: %.2fs" % [
		player_state.mp,
		player_state.max_mp,
		fireball_name,
		fireball_cast_state.phase_name(),
		fireball_cast_state.cooldown_remaining
	]
	skill_2_label.text = "             [I] %s    Phase: %s    Cooldown: %.2fs" % [
		dash_slash_name,
		dash_slash_cast_state.phase_name(),
		dash_slash_cast_state.cooldown_remaining
	]

	web_sync_accumulator += delta
	if web_sync_accumulator >= 0.05:
		web_sync_accumulator = 0.0
		_set_web_state()
	queue_redraw()

func _handle_action_edges() -> void:
	var jump_pressed := Input.is_action_pressed("jump")
	if jump_pressed and not jump_latched and not _any_skill_casting():
		movement_state.start_jump()
		_set_web_state()
	jump_latched = jump_pressed

	var dash_pressed := Input.is_action_pressed("dash")
	if (
		dash_pressed
		and not dash_latched
		and not Input.is_action_pressed("guard")
		and not movement_state.jumping
		and not attack_chain_state.is_attacking()
		and not _any_skill_casting()
	):
		movement_state.start_dash(player_facing)
		_set_web_state()
	dash_latched = dash_pressed

	var skill_1_pressed := Input.is_action_pressed("skill_1")
	if (
		skill_1_pressed
		and not skill_1_latched
		and not Input.is_action_pressed("guard")
		and not movement_state.jumping
		and not movement_state.is_dashing()
		and not attack_chain_state.is_attacking()
		and not dash_slash_cast_state.is_casting()
	):
		_try_cast_fireball()
	skill_1_latched = skill_1_pressed

	var skill_2_pressed := Input.is_action_pressed("skill_2")
	if (
		skill_2_pressed
		and not skill_2_latched
		and not Input.is_action_pressed("guard")
		and not movement_state.jumping
		and not movement_state.is_dashing()
		and not attack_chain_state.is_attacking()
		and not fireball_cast_state.is_casting()
	):
		_try_cast_dash_slash()
	skill_2_latched = skill_2_pressed

func _load_fireball_skill() -> void:
	var errors := fireball_skill.load_from_file(FIREBALL_SKILL_PATH)
	if not errors.is_empty():
		push_error("Failed to load fireball skill: %s" % " | ".join(errors))
		return
	fireball_cast_state.configure(fireball_skill)

func _load_dash_slash_skill() -> void:
	var errors := dash_slash_skill.load_from_file(DASH_SLASH_SKILL_PATH)
	if not errors.is_empty():
		push_error("Failed to load dash slash skill: %s" % " | ".join(errors))
		return
	dash_slash_cast_state.configure(dash_slash_skill)

func _try_cast_fireball() -> void:
	if not fireball_cast_state.start_cast(player_state.mp):
		return
	player_state.spend_mp(fireball_skill.mp_cost)
	fireball_last_hit = false
	_set_web_state()

func _try_cast_dash_slash() -> void:
	if not dash_slash_cast_state.start_cast(player_state.mp):
		return
	player_state.spend_mp(dash_slash_skill.mp_cost)
	dash_slash_last_hit = false
	_set_web_state()

func _spawn_fireball() -> void:
	if not fireball_skill.loaded or fireball_skill.skill_type != "projectile":
		return
	var projectile_lifetime := (fireball_skill.range / maxf(1.0, fireball_skill.speed)) + 0.25
	fireball_projectile.spawn(
		player_x + player_facing * 62.0,
		player_depth,
		player_facing,
		fireball_skill.speed,
		fireball_skill.range,
		projectile_lifetime
	)
	_set_web_state()

func _start_dash_slash() -> void:
	if not dash_slash_skill.loaded or dash_slash_skill.skill_type != "dash":
		return
	dash_slash_state.start(
		player_x,
		player_depth,
		player_facing,
		dash_slash_skill.speed,
		dash_slash_skill.range
	)
	_set_web_state()

func _resolve_fireball_collision() -> void:
	if dummy_state.is_defeated() or not dummy_recovery_state.can_be_hit():
		return
	var projectile_box := fireball_projectile.swept_hitbox(
		fireball_skill.hitbox_half_width,
		fireball_skill.hitbox_half_depth
	)
	if not projectile_box.overlaps(_dummy_hurtbox()):
		return

	dummy_state.apply_damage(fireball_skill.damage)
	dummy_state.apply_hitstun(fireball_skill.hitstun)
	dummy_knockback_state.apply_impulse(fireball_projectile.direction * fireball_skill.knockback)
	dummy_hit_timer = fireball_skill.hitstun
	fireball_impact_timer = 0.30
	fireball_impact_x = dummy_x
	fireball_last_hit = true
	fireball_hit_count += 1
	fireball_projectile.deactivate()
	_set_web_state()

func _resolve_dash_slash_collision() -> void:
	if dash_slash_last_hit or dummy_state.is_defeated() or not dummy_recovery_state.can_be_hit():
		return
	var dash_box := dash_slash_state.swept_hitbox(
		dash_slash_skill.hitbox_half_width,
		dash_slash_skill.hitbox_half_depth
	)
	if not dash_box.overlaps(_dummy_hurtbox()):
		return

	dummy_state.apply_damage(dash_slash_skill.damage)
	dummy_state.apply_hitstun(dash_slash_skill.hitstun)
	dummy_knockback_state.apply_impulse(player_facing * dash_slash_skill.knockback)
	dummy_hit_timer = dash_slash_skill.hitstun
	dash_slash_impact_timer = 0.34
	dash_slash_impact_x = dummy_x
	dash_slash_last_hit = true
	dash_slash_hit_count += 1
	_set_web_state()

func _begin_attack() -> void:
	var step := attack_chain_state.try_start_attack()
	if step == 0:
		return

	last_attack_step = step
	last_attack_hit = false
	attack_visual_timer = attack_chain_state.visual_duration_for_step(step)

	var hitbox := _attack_hitbox(step)
	var hurtbox := _dummy_hurtbox()
	if (
		hitbox.overlaps(hurtbox)
		and not dummy_state.is_defeated()
		and dummy_recovery_state.can_be_hit()
	):
		dummy_state.apply_damage(attack_chain_state.damage_for_step(step))
		dummy_state.apply_hitstun(attack_chain_state.hitstun_for_step(step))
		dummy_knockback_state.apply_impulse(player_facing * attack_chain_state.knockback_for_step(step))
		dummy_hit_timer = attack_chain_state.hitstun_for_step(step)
		last_attack_hit = true
		if step == 3:
			dummy_recovery_state.knock_down()

	_set_web_state()

func _attack_hitbox(step: int) -> CombatBox:
	return CombatBox.new(
		Vector2(
			player_x + player_facing * attack_chain_state.hitbox_offset_for_step(step),
			player_depth
		),
		Vector2(
			attack_chain_state.hitbox_half_width_for_step(step),
			attack_chain_state.hitbox_half_depth_for_step(step)
		)
	)

func _dummy_hurtbox() -> CombatBox:
	return CombatBox.new(
		Vector2(dummy_x, dummy_depth),
		Vector2(DUMMY_HURTBOX_HALF_WIDTH, DUMMY_HURTBOX_HALF_DEPTH)
	)

func _draw() -> void:
	var canvas_width := maxf(size.x, 1280.0)
	var canvas_height := maxf(size.y, 720.0)
	var arena_top := canvas_height * 0.50
	var arena_bottom := canvas_height * 0.86

	draw_rect(Rect2(0.0, 0.0, canvas_width, canvas_height), Color("101522"))
	draw_circle(Vector2(canvas_width * 0.80, canvas_height * 0.18), 78.0, Color("27324d"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, arena_top - 48.0),
		Vector2(canvas_width, arena_top - 48.0),
		Vector2(canvas_width, arena_bottom + 70.0),
		Vector2(0.0, arena_bottom + 70.0)
	]), Color("182036"))

	for lane in range(5):
		var lane_y := lerpf(arena_top, arena_bottom, float(lane) / 4.0)
		draw_line(Vector2(0.0, lane_y), Vector2(canvas_width, lane_y), Color(0.32, 0.39, 0.55, 0.22), 2.0)

	var player_ground_feet := Vector2(player_x, lerpf(arena_top, arena_bottom, player_depth))
	var dummy_feet := Vector2(dummy_x, lerpf(arena_top, arena_bottom, dummy_depth))
	var jump_offset := movement_state.jump_offset()

	if movement_state.is_dashing():
		_draw_dash_lines(player_ground_feet)
	if dash_slash_state.active:
		_draw_dash_slash_effect(player_ground_feet)
	if dummy_knockback_state.is_active():
		_draw_dummy_knockback_lines(dummy_feet)

	if player_depth <= dummy_depth:
		_draw_fighter(player_ground_feet, Color("62d8ff"), player_facing, false, jump_offset, player_guarding)
		_draw_dummy(dummy_feet)
	else:
		_draw_dummy(dummy_feet)
		_draw_fighter(player_ground_feet, Color("62d8ff"), player_facing, false, jump_offset, player_guarding)

	_draw_fireball(arena_top, arena_bottom)
	_draw_fireball_impact(arena_top, arena_bottom)
	_draw_dash_slash_impact(arena_top, arena_bottom)

	_draw_meter(Vector2(50.0, 262.0), 320.0, dummy_state.hp, dummy_state.max_hp, Color("ff6d78"))
	_draw_meter(Vector2(50.0, 290.0), 320.0, player_state.mp, player_state.max_mp, Color("62d8ff"))
	_draw_skill_cooldown_meter(Vector2(50.0, 318.0), 155.0, fireball_cast_state, Color("ffd166"))
	_draw_skill_cooldown_meter(Vector2(215.0, 318.0), 155.0, dash_slash_cast_state, Color("9cf5d4"))
	if dummy_recovery_state.can_be_hit():
		_draw_combat_box(_dummy_hurtbox(), arena_top, arena_bottom, Color(1.0, 0.45, 0.52, 0.72))

	if attack_visual_timer > 0.0 and last_attack_step > 0:
		var active_hitbox := _attack_hitbox(last_attack_step)
		var box_color := Color(0.42, 1.0, 0.64, 0.82) if last_attack_hit else Color(0.35, 0.88, 1.0, 0.78)
		_draw_combat_box(active_hitbox, arena_top, arena_bottom, box_color)
		_draw_attack_effect(player_ground_feet, jump_offset)

func _draw_dummy(ground_feet: Vector2) -> void:
	var display_color := _dummy_color()
	if dummy_recovery_state.state_name() == "INVULNERABLE":
		var pulse := 0.48 + 0.28 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.018))
		display_color = Color(display_color.r, display_color.g, display_color.b, pulse)

	if dummy_recovery_state.is_knocked_down():
		_draw_knocked_down_dummy(ground_feet, display_color)
		return

	_draw_fighter(ground_feet, display_color, -1.0, true)
	if dummy_recovery_state.state_name() == "INVULNERABLE":
		draw_arc(ground_feet + Vector2(0.0, -68.0), 48.0, 0.0, TAU, 28, Color(0.62, 0.96, 0.86, 0.70), 4.0)

func _draw_knocked_down_dummy(ground_feet: Vector2, body_color: Color) -> void:
	_draw_shadow_ellipse(ground_feet + Vector2(0.0, 5.0), Vector2(56.0, 11.0), Color(0.02, 0.03, 0.06, 0.45))
	var body_y := ground_feet.y - 19.0
	var recovering := dummy_recovery_state.state_name() == "RECOVERING"
	var rise := 12.0 if recovering else 0.0
	draw_line(Vector2(dummy_x - 42.0, body_y - rise), Vector2(dummy_x + 38.0, body_y - rise), body_color, 18.0)
	draw_circle(Vector2(dummy_x + 50.0, body_y - 7.0 - rise), 19.0, body_color)
	draw_line(Vector2(dummy_x - 20.0, body_y - rise), Vector2(dummy_x - 50.0, body_y + 10.0), body_color, 9.0)
	draw_line(Vector2(dummy_x + 8.0, body_y - rise), Vector2(dummy_x + 31.0, body_y + 12.0), body_color, 9.0)
	if recovering:
		draw_arc(Vector2(dummy_x, body_y - 42.0), 34.0, PI, TAU, 20, Color("9cf5d4"), 4.0)

func _draw_fireball(arena_top: float, arena_bottom: float) -> void:
	if not fireball_projectile.active:
		return
	var center := Vector2(
		fireball_projectile.x,
		lerpf(arena_top, arena_bottom, fireball_projectile.depth) - 76.0
	)
	var direction := fireball_projectile.direction
	draw_line(center - Vector2(direction * 74.0, 0.0), center - Vector2(direction * 20.0, 0.0), Color(1.0, 0.38, 0.12, 0.32), 12.0)
	draw_circle(center, 30.0, Color(1.0, 0.30, 0.08, 0.22))
	draw_circle(center, 20.0, Color("ff7b2c"))
	draw_circle(center, 10.0, Color("ffe7a6"))
	draw_arc(center, 25.0, 0.0, TAU, 24, Color("ffd166"), 3.0)

func _draw_fireball_impact(arena_top: float, arena_bottom: float) -> void:
	if fireball_impact_timer <= 0.0:
		return
	var center := Vector2(fireball_impact_x, lerpf(arena_top, arena_bottom, dummy_depth) - 72.0)
	var progress := clampf(fireball_impact_timer / 0.30, 0.0, 1.0)
	var radius := 34.0 + (1.0 - progress) * 42.0
	draw_circle(center, radius * 0.55, Color(1.0, 0.45, 0.12, 0.12 * progress))
	draw_arc(center, radius, 0.0, TAU, 30, Color(1.0, 0.78, 0.24, progress), 5.0)

func _draw_dash_slash_effect(player_ground_feet: Vector2) -> void:
	var center := player_ground_feet + Vector2(player_facing * 38.0, -76.0)
	for index in range(4):
		var offset := float(index) * 24.0
		var alpha := 0.62 - float(index) * 0.11
		draw_line(
			center - Vector2(player_facing * (24.0 + offset), 34.0 - offset * 0.18),
			center + Vector2(player_facing * (78.0 - offset * 0.18), 26.0 + offset * 0.10),
			Color(0.48, 1.0, 0.86, alpha),
			8.0 - float(index)
		)
	draw_arc(center, 52.0, -1.0, 1.1, 24, Color("b8ffe8"), 6.0)

func _draw_dash_slash_impact(arena_top: float, arena_bottom: float) -> void:
	if dash_slash_impact_timer <= 0.0:
		return
	var center := Vector2(dash_slash_impact_x, lerpf(arena_top, arena_bottom, dummy_depth) - 74.0)
	var progress := clampf(dash_slash_impact_timer / 0.34, 0.0, 1.0)
	var spread := 52.0 + (1.0 - progress) * 36.0
	draw_circle(center, 28.0, Color(0.48, 1.0, 0.86, 0.14 * progress))
	draw_line(center + Vector2(-spread, -spread * 0.45), center + Vector2(spread, spread * 0.45), Color(0.70, 1.0, 0.92, progress), 7.0)
	draw_line(center + Vector2(-spread * 0.72, spread * 0.58), center + Vector2(spread * 0.72, -spread * 0.58), Color(0.40, 0.92, 1.0, progress), 4.0)

func _draw_attack_effect(player_ground_feet: Vector2, jump_offset: float) -> void:
	var player_y := player_ground_feet.y - jump_offset
	var step_scale := 1.0 + float(maxi(0, last_attack_step - 1)) * 0.24
	var effect_center := Vector2(
		player_x + player_facing * (78.0 + float(last_attack_step) * 8.0),
		player_y - 82.0
	)
	var effect_color := Color("ffd166") if last_attack_step == 3 else Color("b8f3ff")
	var glow_color := Color(1.0, 0.72, 0.24, 0.22) if last_attack_step == 3 else Color(0.35, 0.88, 1.0, 0.20)

	draw_circle(effect_center, 30.0 * step_scale, glow_color)
	draw_arc(effect_center, 40.0 * step_scale, 0.0, TAU, 32, effect_color, 5.0 + float(last_attack_step))
	draw_line(
		Vector2(player_x + player_facing * 38.0, player_y - 68.0),
		Vector2(player_x + player_facing * (104.0 + float(last_attack_step) * 18.0), player_y - 92.0),
		effect_color,
		6.0 + float(last_attack_step)
	)
	if last_attack_step >= 2:
		draw_arc(effect_center, 54.0 * step_scale, -1.1, 1.1, 20, effect_color, 3.0)
	if last_attack_step == 3:
		draw_circle(effect_center, 12.0, Color("fff2b8"))

func _draw_combat_box(box: CombatBox, arena_top: float, arena_bottom: float, color: Color) -> void:
	var top_y := lerpf(arena_top, arena_bottom, clampf(box.top(), 0.0, 1.0))
	var bottom_y := lerpf(arena_top, arena_bottom, clampf(box.bottom(), 0.0, 1.0))
	var rect := Rect2(
		Vector2(box.left(), top_y),
		Vector2(box.right() - box.left(), maxf(4.0, bottom_y - top_y))
	)
	var fill_color := Color(color.r, color.g, color.b, 0.08)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, color, false, 2.0)

func _draw_meter(at: Vector2, width: float, current: int, maximum: int, fill_color: Color) -> void:
	var ratio := clampf(float(current) / float(maxi(1, maximum)), 0.0, 1.0)
	draw_rect(Rect2(at, Vector2(width, 18.0)), Color("30394f"))
	draw_rect(Rect2(at, Vector2(width * ratio, 18.0)), fill_color)
	draw_rect(Rect2(at, Vector2(width, 18.0)), Color("e6edf8"), false, 2.0)

func _draw_skill_cooldown_meter(at: Vector2, width: float, cast_state, fill_color: Color) -> void:
	var ready_ratio := 1.0 - cast_state.cooldown_ratio()
	draw_rect(Rect2(at, Vector2(width, 12.0)), Color("30394f"))
	draw_rect(Rect2(at, Vector2(width * ready_ratio, 12.0)), fill_color)
	draw_rect(Rect2(at, Vector2(width, 12.0)), Color("e6edf8"), false, 2.0)

func _dummy_color() -> Color:
	if dummy_hit_timer > 0.0:
		return Color("fff0a8")
	if dummy_state.is_defeated():
		return Color("6f7484")
	return Color("ff7b83")

func _draw_fighter(
	ground_feet: Vector2,
	body_color: Color,
	facing: float,
	is_dummy: bool,
	vertical_offset: float = 0.0,
	guarding: bool = false
) -> void:
	var direction := 1.0 if facing >= 0.0 else -1.0
	var shadow_scale := clampf(0.75 + ((ground_feet.y / maxf(size.y, 720.0)) * 0.35), 0.78, 1.08)
	_draw_shadow_ellipse(ground_feet + Vector2(0.0, 4.0), Vector2(34.0, 10.0) * shadow_scale, Color(0.02, 0.03, 0.06, 0.45))

	var feet := ground_feet + Vector2(0.0, -vertical_offset)
	var head := feet + Vector2(0.0, -118.0)
	var torso_top := feet + Vector2(-18.0, -94.0)
	draw_circle(head, 22.0, body_color)
	draw_rect(Rect2(torso_top, Vector2(36.0, 70.0)), body_color)
	draw_line(feet + Vector2(-8.0, -30.0), feet + Vector2(-20.0, 0.0), body_color, 10.0)
	draw_line(feet + Vector2(8.0, -30.0), feet + Vector2(20.0, 0.0), body_color, 10.0)
	draw_line(feet + Vector2(direction * 15.0, -78.0), feet + Vector2(direction * 48.0, -62.0), body_color, 9.0)

	if is_dummy:
		draw_line(feet + Vector2(-38.0, -6.0), feet + Vector2(38.0, -6.0), Color("c5a46b"), 7.0)
		draw_line(feet + Vector2(0.0, -6.0), feet + Vector2(0.0, 18.0), Color("c5a46b"), 7.0)
	else:
		var weapon_start := feet + Vector2(direction * 44.0, -65.0)
		var weapon_end := feet + Vector2(direction * 82.0, -96.0)
		draw_line(weapon_start, weapon_end, Color("e9edf7"), 5.0)

	if guarding and not is_dummy:
		var shield_center := feet + Vector2(direction * 34.0, -70.0)
		var start_angle := -1.15 if direction > 0.0 else PI - 1.15
		draw_arc(shield_center, 52.0, start_angle, start_angle + 2.30, 24, Color("9cf5d4"), 7.0)

func _draw_dash_lines(ground_feet: Vector2) -> void:
	for index in range(3):
		var distance := 45.0 + float(index) * 34.0
		var alpha := 0.34 - float(index) * 0.08
		var y := ground_feet.y - 72.0 + float(index) * 24.0
		draw_line(
			Vector2(player_x - player_facing * distance, y),
			Vector2(player_x - player_facing * (distance + 58.0), y),
			Color(0.39, 0.85, 1.0, alpha),
			5.0
		)

func _draw_dummy_knockback_lines(dummy_feet: Vector2) -> void:
	var direction := signf(dummy_knockback_state.velocity)
	if is_zero_approx(direction):
		return
	for index in range(3):
		var y := dummy_feet.y - 80.0 + float(index) * 26.0
		draw_line(
			Vector2(dummy_x - direction * 38.0, y),
			Vector2(dummy_x - direction * (82.0 + float(index) * 16.0), y),
			Color(1.0, 0.82, 0.42, 0.42 - float(index) * 0.08),
			4.0
		)

func _draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _ensure_input_actions() -> void:
	_register_key_action("move_left", [KEY_A, KEY_LEFT])
	_register_key_action("move_right", [KEY_D, KEY_RIGHT])
	_register_key_action("move_up", [KEY_W, KEY_UP])
	_register_key_action("move_down", [KEY_S, KEY_DOWN])
	_register_key_action("run", [KEY_SHIFT])
	_register_key_action("jump", [KEY_SPACE])
	_register_key_action("attack", [KEY_J])
	_register_key_action("dash", [KEY_K])
	_register_key_action("guard", [KEY_L])
	_register_key_action("skill_1", [KEY_U])
	_register_key_action("skill_2", [KEY_I])

func _register_key_action(action_name: StringName, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)

func _any_skill_casting() -> bool:
	return fireball_cast_state.is_casting() or dash_slash_cast_state.is_casting() or dash_slash_state.active

func _player_state_name() -> String:
	if dash_slash_state.active:
		return "DASH_SLASH"
	if dash_slash_cast_state.is_casting():
		return "SKILL_2_%s" % dash_slash_cast_state.phase_name()
	if fireball_cast_state.is_casting():
		return "SKILL_%s" % fireball_cast_state.phase_name()
	if player_guarding:
		return "GUARD"
	if movement_state.is_dashing():
		return "DASH"
	if movement_state.jumping:
		return "JUMP"
	if attack_chain_state.is_attacking():
		return "ATTACK_%d" % attack_chain_state.combo_step
	if player_running:
		return "RUN"
	return "READY"

func _set_web_state() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.godotReady='true';" +
		"document.documentElement.dataset.dummyHp='%d';" % dummy_state.hp +
		"document.documentElement.dataset.dummyX='%.2f';" % dummy_x +
		"document.documentElement.dataset.dummyKnockbackVelocity='%.2f';" % dummy_knockback_state.velocity +
		"document.documentElement.dataset.dummyRecoveryState='%s';" % dummy_recovery_state.state_name() +
		"document.documentElement.dataset.dummyCanBeHit='%s';" % _bool_text(dummy_recovery_state.can_be_hit()) +
		"document.documentElement.dataset.dummyKnockedDown='%s';" % _bool_text(dummy_recovery_state.is_knocked_down()) +
		"document.documentElement.dataset.dummyInvulnerable='%s';" % _bool_text(dummy_recovery_state.is_invulnerable()) +
		"document.documentElement.dataset.playerX='%.2f';" % player_x +
		"document.documentElement.dataset.playerDepth='%.3f';" % player_depth +
		"document.documentElement.dataset.playerMp='%d';" % player_state.mp +
		"document.documentElement.dataset.playerMaxMp='%d';" % player_state.max_mp +
		"document.documentElement.dataset.playerJumping='%s';" % _bool_text(movement_state.jumping) +
		"document.documentElement.dataset.playerJumpOffset='%.2f';" % movement_state.jump_offset() +
		"document.documentElement.dataset.playerDashing='%s';" % _bool_text(movement_state.is_dashing()) +
		"document.documentElement.dataset.playerRunning='%s';" % _bool_text(player_running) +
		"document.documentElement.dataset.playerGuarding='%s';" % _bool_text(player_guarding) +
		"document.documentElement.dataset.playerState='%s';" % _player_state_name() +
		"document.documentElement.dataset.comboStep='%d';" % attack_chain_state.combo_step +
		"document.documentElement.dataset.lastHitStep='%d';" % (last_attack_step if last_attack_hit else 0) +
		"document.documentElement.dataset.lastAttackHit='%s';" % _bool_text(last_attack_hit) +
		"document.documentElement.dataset.hitboxActive='%s';" % _bool_text(attack_visual_timer > 0.0) +
		"document.documentElement.dataset.skillLoaded='%s';" % _bool_text(fireball_skill.loaded) +
		"document.documentElement.dataset.skillId='%s';" % fireball_skill.skill_id +
		"document.documentElement.dataset.skillPhase='%s';" % fireball_cast_state.phase_name() +
		"document.documentElement.dataset.skillCooldown='%.3f';" % fireball_cast_state.cooldown_remaining +
		"document.documentElement.dataset.skillCanCast='%s';" % _bool_text(fireball_cast_state.can_cast(player_state.mp) and not dash_slash_cast_state.is_casting()) +
		"document.documentElement.dataset.projectileActive='%s';" % _bool_text(fireball_projectile.active) +
		"document.documentElement.dataset.projectileX='%.2f';" % fireball_projectile.x +
		"document.documentElement.dataset.lastSkillHit='%s';" % _bool_text(fireball_last_hit) +
		"document.documentElement.dataset.skillHitCount='%d';" % fireball_hit_count +
		"document.documentElement.dataset.dashSkillLoaded='%s';" % _bool_text(dash_slash_skill.loaded) +
		"document.documentElement.dataset.dashSkillId='%s';" % dash_slash_skill.skill_id +
		"document.documentElement.dataset.dashSkillPhase='%s';" % dash_slash_cast_state.phase_name() +
		"document.documentElement.dataset.dashSkillCooldown='%.3f';" % dash_slash_cast_state.cooldown_remaining +
		"document.documentElement.dataset.dashSkillCanCast='%s';" % _bool_text(dash_slash_cast_state.can_cast(player_state.mp) and not fireball_cast_state.is_casting()) +
		"document.documentElement.dataset.dashSkillActive='%s';" % _bool_text(dash_slash_state.active) +
		"document.documentElement.dataset.dashSkillTravelled='%.2f';" % dash_slash_state.travelled +
		"document.documentElement.dataset.lastDashSkillHit='%s';" % _bool_text(dash_slash_last_hit) +
		"document.documentElement.dataset.dashSkillHitCount='%d';" % dash_slash_hit_count +
		"console.log('CUSTOM_FIGHTER_STATE dummyHp=%d mp=%d combo=%d skill1=%s skill2=%s recovery=%s state=%s');" % [dummy_state.hp, player_state.mp, attack_chain_state.combo_step, fireball_cast_state.phase_name(), dash_slash_cast_state.phase_name(), dummy_recovery_state.state_name(), _player_state_name()]
	)

func _bool_text(value: bool) -> String:
	return "true" if value else "false"

func _create_label(text_value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eef4ff"))
	add_child(label)
	return label
