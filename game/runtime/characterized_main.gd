extends "res://game/runtime/coordinated_main.gd"

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterMovementTuning = preload("res://game/core/character/character_movement_tuning.gd")
const PLAYER_CHARACTER_PATH := "res://content/characters/ember_vanguard.sample.json"

var player_character := CharacterDefinition.new()
var character_movement_adjustment_frames := 0
var character_movement_integrated_seconds := 0.0
var character_movement_integrated_horizontal_distance := 0.0
var character_movement_integrated_depth_distance := 0.0
var character_last_horizontal_speed := 0.0
var character_last_depth_speed := 0.0
var character_runtime_buff_multiplier := 1.0

func _enter_tree() -> void:
	var errors := player_character.load_from_file(PLAYER_CHARACTER_PATH)
	if not errors.is_empty():
		push_error("Failed to load player character: %s" % " | ".join(errors))
		return
	player_state = CombatantState.new(player_character.max_hp, player_character.max_mp)

func _process(delta: float) -> void:
	# BuffSkillController runs at a lower process priority, so its state for this frame
	# is ready before the root runtime composes movement.
	character_runtime_buff_multiplier = _runtime_movement_multiplier()

	var before_x := player_x
	var before_depth := player_depth
	var fixed_motion_before := movement_state.is_dashing() or dash_slash_state.active

	super(delta)

	if not player_character.loaded:
		return
	if fixed_motion_before or movement_state.is_dashing() or dash_slash_state.active:
		return

	var move_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if move_vector.length_squared() <= 0.001:
		return

	var frame_delta := Vector2(player_x - before_x, player_depth - before_depth)
	var adjusted_delta := CharacterMovementTuning.adjust_frame_delta(
		frame_delta,
		player_character,
		player_running,
		player_guarding,
		character_runtime_buff_multiplier
	)
	player_x = clampf(before_x + adjusted_delta.x, 90.0, maxf(size.x, 1280.0) - 90.0)
	player_depth = clampf(before_depth + adjusted_delta.y, 0.0, 1.0)

	character_movement_adjustment_frames += 1
	character_movement_integrated_seconds += maxf(0.0, delta)
	character_movement_integrated_horizontal_distance += absf(adjusted_delta.x)
	character_movement_integrated_depth_distance += absf(adjusted_delta.y)
	if delta > 0.000001:
		character_last_horizontal_speed = absf(adjusted_delta.x) / delta
		character_last_depth_speed = absf(adjusted_delta.y) / delta
	_set_web_state()

func _runtime_movement_multiplier() -> float:
	var buff_controller = get_node_or_null("BuffSkillController")
	if buff_controller == null or not buff_controller.has_method("runtime_movement_multiplier"):
		return 1.0
	return maxf(0.0, float(buff_controller.runtime_movement_multiplier()))

func _set_web_state() -> void:
	super()
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.playerCharacterLoaded='%s';" % _bool_text(player_character.loaded) +
		"document.documentElement.dataset.playerCharacterId=%s;" % JSON.stringify(player_character.character_id) +
		"document.documentElement.dataset.playerCharacterName=%s;" % JSON.stringify(player_character.character_name) +
		"document.documentElement.dataset.playerCharacterArchetype=%s;" % JSON.stringify(player_character.archetype) +
		"document.documentElement.dataset.playerCharacterVisualProfile=%s;" % JSON.stringify(player_character.visual_profile) +
		"document.documentElement.dataset.playerHp='%d';" % player_state.hp +
		"document.documentElement.dataset.playerMaxHp='%d';" % player_state.max_hp +
		"document.documentElement.dataset.playerCharacterMaxHp='%d';" % player_character.max_hp +
		"document.documentElement.dataset.playerCharacterMaxMp='%d';" % player_character.max_mp +
		"document.documentElement.dataset.playerCharacterMoveSpeed='%.3f';" % player_character.move_speed +
		"document.documentElement.dataset.playerCharacterDepthSpeed='%.3f';" % player_character.depth_speed +
		"document.documentElement.dataset.playerCharacterRunMultiplier='%.3f';" % player_character.run_multiplier +
		"document.documentElement.dataset.playerCharacterGuardMoveMultiplier='%.3f';" % player_character.guard_move_multiplier +
		"document.documentElement.dataset.playerMovementSource='character';" +
		"document.documentElement.dataset.playerRuntimeMoveSpeed='%.3f';" % player_character.move_speed +
		"document.documentElement.dataset.playerRuntimeDepthSpeed='%.3f';" % player_character.depth_speed +
		"document.documentElement.dataset.playerRuntimeRunMultiplier='%.3f';" % player_character.run_multiplier +
		"document.documentElement.dataset.playerRuntimeGuardMoveMultiplier='%.3f';" % player_character.guard_move_multiplier +
		"document.documentElement.dataset.playerRuntimeBuffMovementMultiplier='%.3f';" % character_runtime_buff_multiplier +
		"document.documentElement.dataset.playerMovementAdjustmentFrames='%d';" % character_movement_adjustment_frames +
		"document.documentElement.dataset.playerMovementIntegratedSeconds='%.6f';" % character_movement_integrated_seconds +
		"document.documentElement.dataset.playerMovementIntegratedHorizontalDistance='%.6f';" % character_movement_integrated_horizontal_distance +
		"document.documentElement.dataset.playerMovementIntegratedDepthDistance='%.6f';" % character_movement_integrated_depth_distance +
		"document.documentElement.dataset.playerLastHorizontalSpeed='%.3f';" % character_last_horizontal_speed +
		"document.documentElement.dataset.playerLastDepthSpeed='%.6f';" % character_last_depth_speed +
		"document.documentElement.dataset.playerCharacterSkill1=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_1")) +
		"document.documentElement.dataset.playerCharacterSkill2=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_2")) +
		"document.documentElement.dataset.playerCharacterSkill3=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_3")) +
		"document.documentElement.dataset.playerCharacterSkill4=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_4")) +
		"document.documentElement.dataset.playerCharacterSkill5=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_5")) +
		"document.documentElement.dataset.playerCharacterSkill6=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_6"))
	)
