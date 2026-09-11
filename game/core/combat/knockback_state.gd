class_name KnockbackState
extends RefCounted

const DRAG_PER_SECOND := 1200.0

var velocity := 0.0
var last_impulse := 0.0

func apply_impulse(impulse: float) -> void:
	last_impulse = impulse
	velocity += impulse

func tick(delta: float) -> float:
	var safe_delta := maxf(0.0, delta)
	var displacement := velocity * safe_delta
	velocity = move_toward(velocity, 0.0, DRAG_PER_SECOND * safe_delta)
	if absf(velocity) < 0.01:
		velocity = 0.0
	return displacement

func is_active() -> bool:
	return not is_zero_approx(velocity)
