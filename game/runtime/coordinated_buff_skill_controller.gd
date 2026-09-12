extends "res://game/runtime/buff_skill_controller.gd"

const SKILL_OWNER := &"skill_5"

func _load_skill() -> void:
	if host == null or not host.has_method("load_character_skill_for_slot"):
		push_error("Failed to load buff skill: character loadout resolver unavailable")
		return
	var errors: PackedStringArray = host.load_character_skill_for_slot("skill_5", "buff", skill)
	if not errors.is_empty():
		push_error("Failed to load buff skill from character slot: %s" % " | ".join(errors))
		return
	cast_state.configure(skill)

func _ready() -> void:
	super()
	# Tick the buff state before the root runtime composes this frame's movement.
	# This makes CharacterDefinition × Buff deterministic across browser runners.
	process_priority = -100

func _process(delta: float) -> void:
	super(delta)
	if host != null and not cast_state.is_casting():
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

func _apply_movement_boost() -> void:
	# The coordinated character runtime owns final movement composition.
	# Keeping this as a no-op prevents a second coordinate mutation after the
	# CharacterDefinition movement adapter has already produced the final delta.
	pass

func runtime_movement_multiplier() -> float:
	return buff_state.movement_multiplier()
