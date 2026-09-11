class_name KnockdownState
extends RefCounted

const DOWN_SECONDS := 0.55
const RECOVERY_SECONDS := 0.28
const INVULNERABLE_SECONDS := 0.45

enum Phase {
	READY,
	DOWN,
	RECOVERING,
	INVULNERABLE,
}

var phase: Phase = Phase.READY
var remaining := 0.0

func knock_down() -> bool:
	if phase != Phase.READY:
		return false
	phase = Phase.DOWN
	remaining = DOWN_SECONDS
	return true

func tick(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	if phase == Phase.READY or safe_delta <= 0.0:
		return

	remaining -= safe_delta
	while remaining <= 0.0 and phase != Phase.READY:
		var carry := -remaining
		match phase:
			Phase.DOWN:
				phase = Phase.RECOVERING
				remaining = RECOVERY_SECONDS - carry
			Phase.RECOVERING:
				phase = Phase.INVULNERABLE
				remaining = INVULNERABLE_SECONDS - carry
			Phase.INVULNERABLE:
				phase = Phase.READY
				remaining = 0.0
			_:
				phase = Phase.READY
				remaining = 0.0

func can_be_hit() -> bool:
	return phase == Phase.READY

func is_knocked_down() -> bool:
	return phase == Phase.DOWN or phase == Phase.RECOVERING

func is_invulnerable() -> bool:
	return phase != Phase.READY

func state_name() -> String:
	match phase:
		Phase.DOWN:
			return "DOWN"
		Phase.RECOVERING:
			return "RECOVERING"
		Phase.INVULNERABLE:
			return "INVULNERABLE"
		_:
			return "READY"
