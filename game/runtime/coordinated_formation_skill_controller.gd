extends "res://game/runtime/formation_skill_controller.gd"

const SKILL_OWNER := &"skill_4"

func _load_skill() -> void:
	if host == null or not host.has_method("load_character_skill_for_slot"):
		push_error("Failed to load formation skill: character loadout resolver unavailable")
		return
	var errors: PackedStringArray = host.load_character_skill_for_slot("skill_4", "formation", skill)
	if not errors.is_empty():
		push_error("Failed to load formation skill from character slot: %s" % " | ".join(errors))
		return
	cast_state.configure(skill)
	impact_timers.resize(skill.formation_count)

func _process(delta: float) -> void:
	super(delta)
	if host != null and not cast_state.is_casting() and not formation_state.active:
		host.skill_coordinator.release(SKILL_OWNER)

func _can_start_cast() -> bool:
	if not skill.loaded or host == null:
		return false
	if not cast_state.can_cast(host.player_state.mp):
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
