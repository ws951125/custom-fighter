class_name AttackChainState
extends RefCounted

const COMBO_RESET_SECONDS := 0.62
const HITCH_THRESHOLD_SECONDS := 0.50
const HITCH_COMBO_TIMER_DELTA := 0.10

var combo_step := 0
var attack_lock_remaining := 0.0
var combo_reset_remaining := 0.0
var damage_multiplier := 1.0
var attack_buffered := false
var buffered_step_ready := 0

func tick(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	var previous_attack_lock := attack_lock_remaining
	# Preserve normal timing exactly. Only treat a single frame over 500ms as a browser
	# hitch, because the player had no usable input frames during that pause.
	var combo_delta := safe_delta
	if safe_delta > HITCH_THRESHOLD_SECONDS:
		combo_delta = HITCH_COMBO_TIMER_DELTA
	attack_lock_remaining = maxf(0.0, attack_lock_remaining - safe_delta)
	combo_reset_remaining = maxf(0.0, combo_reset_remaining - combo_delta)

	# A combo input accepted during recovery is intentional player input. Resolve it as
	# soon as recovery ends, even if a long browser frame also crossed the old timer edge.
	# This makes the combat model resilient to Web/low-FPS hitches without lengthening the
	# normal unbuffered combo window.
	if previous_attack_lock > 0.0 and attack_lock_remaining <= 0.0 and attack_buffered:
		attack_buffered = false
		buffered_step_ready = _start_next_attack()
		return

	if combo_reset_remaining <= 0.0 and attack_lock_remaining <= 0.0:
		combo_step = 0
		attack_buffered = false

func try_start_attack() -> int:
	if attack_lock_remaining > 0.0:
		return 0
	return _start_next_attack()

func buffer_attack() -> bool:
	if attack_lock_remaining <= 0.0:
		return false
	if combo_step <= 0 or combo_reset_remaining <= 0.0:
		return false
	attack_buffered = true
	return true

func consume_buffered_attack_step() -> int:
	var step := buffered_step_ready
	buffered_step_ready = 0
	return step

func has_buffered_attack() -> bool:
	return attack_buffered

func _start_next_attack() -> int:
	combo_step = (combo_step % 3) + 1
	attack_lock_remaining = recovery_for_step(combo_step)
	combo_reset_remaining = COMBO_RESET_SECONDS
	return combo_step

func is_attacking() -> bool:
	return attack_lock_remaining > 0.0

func set_damage_multiplier(value: float) -> void:
	damage_multiplier = maxf(0.0, value)

func damage_for_step(step: int) -> int:
	var base_damage := 0
	match step:
		1:
			base_damage = 12
		2:
			base_damage = 14
		3:
			base_damage = 20
		_:
			base_damage = 0
	return roundi(float(base_damage) * damage_multiplier)

func hitbox_half_width_for_step(step: int) -> float:
	match step:
		1:
			return 60.0
		2:
			return 68.0
		3:
			return 82.0
		_:
			return 0.0

func hitbox_offset_for_step(step: int) -> float:
	match step:
		1:
			return 74.0
		2:
			return 82.0
		3:
			return 92.0
		_:
			return 0.0

func hitbox_half_depth_for_step(step: int) -> float:
	match step:
		1:
			return 0.12
		2:
			return 0.13
		3:
			return 0.16
		_:
			return 0.0

func hitstun_for_step(step: int) -> float:
	match step:
		1:
			return 0.12
		2:
			return 0.16
		3:
			return 0.28
		_:
			return 0.0

func knockback_for_step(step: int) -> float:
	match step:
		1:
			return 120.0
		2:
			return 170.0
		3:
			return 430.0
		_:
			return 0.0

func recovery_for_step(step: int) -> float:
	match step:
		1:
			return 0.14
		2:
			return 0.16
		3:
			return 0.24
		_:
			return 0.0

func visual_duration_for_step(step: int) -> float:
	match step:
		1:
			return 0.18
		2:
			return 0.20
		3:
			return 0.30
		_:
			return 0.0
