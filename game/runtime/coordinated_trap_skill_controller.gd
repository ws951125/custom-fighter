extends "res://game/runtime/trap_skill_controller.gd"

const SKILL_OWNER := &"skill_8"

func _load_skill() -> void:
	if host == null or not host.has_method("load_character_skill_for_slot"):
		return
	var character: Variant = host.get("player_character")
	if character == null or not character.has_method("skill_id_for_slot"):
		return
	var requested_id := str(character.call("skill_id_for_slot", "skill_8"))
	if requested_id.is_empty():
		return
	var errors: PackedStringArray = host.load_character_skill_for_slot("skill_8", "trap", skill)
	if not errors.is_empty():
		push_error("Failed to load trap skill from character slot: %s" % " | ".join(errors))
		return
	cast_state.configure(skill)

func _process(delta: float) -> void:
	super(delta)
	if host != null and not cast_state.is_casting():
		host.skill_coordinator.release(SKILL_OWNER)

func _can_start_cast() -> bool:
	if not skill.loaded or host == null or cast_state.is_casting() or trap_state.active:
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
