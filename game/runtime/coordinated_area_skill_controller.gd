extends "res://game/runtime/area_skill_controller.gd"

const SKILL_OWNER := &"skill_3"

func _process(delta: float) -> void:
	super(delta)
	if host != null and not cast_state.is_casting() and not area_state.active:
		host.skill_coordinator.release(SKILL_OWNER)

func _can_start_cast() -> bool:
	if not skill.loaded or cast_state.is_casting() or host == null:
		return false
	if host.player_guarding or host.movement_state.jumping or host.movement_state.is_dashing():
		return false
	if host.attack_chain_state.is_attacking():
		return false
	return host.skill_coordinator.can_claim(SKILL_OWNER)

func _try_cast() -> void:
	if not host.skill_coordinator.try_claim(SKILL_OWNER):
		return
	super()
	if not cast_state.is_casting():
		host.skill_coordinator.release(SKILL_OWNER)
