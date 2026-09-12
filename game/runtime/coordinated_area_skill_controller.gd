extends "res://game/runtime/area_skill_controller.gd"

const SKILL_OWNER := &"skill_3"

func _load_skill() -> void:
	if host == null or not host.has_method("load_character_skill_for_slot"):
		push_error("Failed to load area skill: character loadout resolver unavailable")
		return
	var errors := host.load_character_skill_for_slot("skill_3", "area", skill)
	if not errors.is_empty():
		push_error("Failed to load area skill from character slot: %s" % " | ".join(errors))
		return
	cast_state.configure(skill)

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
