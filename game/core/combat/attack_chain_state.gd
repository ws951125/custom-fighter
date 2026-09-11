class_name AttackChainState
extends RefCounted

const COMBO_RESET_SECONDS := 0.62
const MAX_TIMER_DELTA := 0.10

var combo_step := 0
var attack_lock_remaining := 0.0
var combo_reset_remaining := 0.0

func tick(delta: float) -> void:
	# Browser/Web builds can occasionally produce a very large frame delta after a hitch.
	# Do not let one unplayable frame consume the entire attack recovery/combo window.
	var safe_delta := minf(maxf(0.0, delta), MAX_TIMER_DELTA)
	attack_lock_remaining = maxf(0.0, attack_lock_remaining - safe_delta)
	combo_reset_remaining = maxf(0.0, combo_reset_remaining - safe_delta)
	if combo_reset_remaining <= 0.0 and attack_lock_remaining <= 0.0:
		combo_step = 0

func try_start_attack() -> int:
	if attack_lock_remaining > 0.0:
		return 0

	combo_step = (combo_step % 3) + 1
	attack_lock_remaining = recovery_for_step(combo_step)
	combo_reset_remaining = COMBO_RESET_SECONDS
	return combo_step

func is_attacking() -> bool:
	return attack_lock_remaining > 0.0

func damage_for_step(step: int) -> int:
	match step:
		1:
			return 12
		2:
			return 14
		3:
			return 20
		_:
			return 0

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
