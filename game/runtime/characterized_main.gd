extends "res://game/runtime/coordinated_main.gd"

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const CharacterMovementTuning = preload("res://game/core/character/character_movement_tuning.gd")
const CharacterVisualProfile = preload("res://game/core/character/character_visual_profile.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const PLAYER_CHARACTER_PATH := "res://content/characters/ember_vanguard.sample.json"

var player_character := CharacterDefinition.new()
var player_visual_profile := CharacterVisualProfile.new()
var player_skill_registry := SkillRegistry.new()
var player_runtime_skill_ids: Dictionary = {}
var player_runtime_skill_sources: Dictionary = {}
var player_runtime_skill_types: Dictionary = {}
var player_runtime_skill_errors: Dictionary = {}
var character_movement_adjustment_frames := 0
var character_movement_integrated_seconds := 0.0
var character_movement_integrated_horizontal_distance := 0.0
var character_movement_integrated_depth_distance := 0.0
var character_last_horizontal_speed := 0.0
var character_last_depth_speed := 0.0
var character_runtime_buff_multiplier := 1.0
var character_profile_render_calls := 0

func _enter_tree() -> void:
	var errors := player_character.load_from_file(PLAYER_CHARACTER_PATH)
	if not errors.is_empty():
		push_error("Failed to load player character: %s" % " | ".join(errors))
		return

	var visual_errors := player_visual_profile.load_from_id(player_character.visual_profile)
	if not visual_errors.is_empty():
		push_error("Failed to load player visual profile: %s" % " | ".join(visual_errors))

	var registry_errors := player_skill_registry.load_default()
	if not registry_errors.is_empty():
		push_error("Failed to load skill registry: %s" % " | ".join(registry_errors))

	player_state = CombatantState.new(player_character.max_hp, player_character.max_mp)

func _load_fireball_skill() -> void:
	var errors := load_character_skill_for_slot("skill_1", "projectile", fireball_skill)
	if not errors.is_empty():
		push_error("Failed to load character skill_1: %s" % " | ".join(errors))
		return
	fireball_cast_state.configure(fireball_skill)

func _load_dash_slash_skill() -> void:
	var errors := load_character_skill_for_slot("skill_2", "dash", dash_slash_skill)
	if not errors.is_empty():
		push_error("Failed to load character skill_2: %s" % " | ".join(errors))
		return
	dash_slash_cast_state.configure(dash_slash_skill)

func load_character_skill_for_slot(slot_name: String, expected_type: String, target_skill) -> PackedStringArray:
	var errors := PackedStringArray()
	if not CharacterDefinition.REQUIRED_SKILL_SLOTS.has(slot_name):
		errors.append("unknown character skill slot: %s" % slot_name)
	elif not player_character.loaded:
		errors.append("player character is not loaded")
	elif not player_skill_registry.loaded:
		errors.append("player skill registry is not loaded")
	else:
		var requested_id := player_character.skill_id_for_slot(slot_name)
		errors = player_skill_registry.load_skill(requested_id, expected_type, target_skill)

	if errors.is_empty():
		player_runtime_skill_ids[slot_name] = target_skill.skill_id
		player_runtime_skill_sources[slot_name] = player_skill_registry.source_path_for_id(target_skill.skill_id)
		player_runtime_skill_types[slot_name] = target_skill.skill_type
		player_runtime_skill_errors.erase(slot_name)
	else:
		player_runtime_skill_ids.erase(slot_name)
		player_runtime_skill_sources.erase(slot_name)
		player_runtime_skill_types.erase(slot_name)
		player_runtime_skill_errors[slot_name] = " | ".join(errors)
	return errors

func _runtime_loadout_ready() -> bool:
	if not player_character.loaded or not player_skill_registry.loaded:
		return false
	for slot in CharacterDefinition.REQUIRED_SKILL_SLOTS:
		var expected_id := player_character.skill_id_for_slot(slot)
		if str(player_runtime_skill_ids.get(slot, "")) != expected_id:
			return false
	return true

func _runtime_skill_id(slot_name: String) -> String:
	return str(player_runtime_skill_ids.get(slot_name, ""))

func _runtime_skill_source(slot_name: String) -> String:
	return str(player_runtime_skill_sources.get(slot_name, ""))

func _runtime_skill_type(slot_name: String) -> String:
	return str(player_runtime_skill_types.get(slot_name, ""))

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

func _draw_fighter(
	ground_feet: Vector2,
	body_color: Color,
	facing: float,
	is_dummy: bool,
	vertical_offset: float = 0.0,
	guarding: bool = false
) -> void:
	if is_dummy or not player_visual_profile.loaded:
		super(ground_feet, body_color, facing, is_dummy, vertical_offset, guarding)
		return

	character_profile_render_calls += 1
	var profile := player_visual_profile
	var direction := 1.0 if facing >= 0.0 else -1.0
	var shadow_scale := clampf(0.75 + ((ground_feet.y / maxf(size.y, 720.0)) * 0.35), 0.78, 1.08)
	_draw_shadow_ellipse(
		ground_feet + Vector2(0.0, 4.0),
		Vector2(profile.shadow_half_width, profile.shadow_half_height) * shadow_scale,
		Color(0.02, 0.03, 0.06, 0.45)
	)

	var feet := ground_feet + Vector2(0.0, -vertical_offset)
	var head := feet + Vector2(0.0, -profile.body_height)
	var torso_top_y := -(profile.body_height - profile.head_radius - 2.0)
	var torso_top := feet + Vector2(-profile.torso_width * 0.5, torso_top_y)
	var body := profile.body_color()
	var accent := profile.accent_color()

	draw_circle(head, profile.head_radius, body)
	draw_rect(Rect2(torso_top, Vector2(profile.torso_width, profile.torso_height)), body)
	var accent_height := maxf(4.0, profile.torso_height * 0.08)
	draw_rect(
		Rect2(
			torso_top + Vector2(0.0, profile.torso_height * 0.44),
			Vector2(profile.torso_width, accent_height)
		),
		accent
	)

	draw_line(
		feet + Vector2(-profile.leg_spread * 0.4, -profile.leg_length),
		feet + Vector2(-profile.leg_spread, 0.0),
		body,
		profile.leg_width
	)
	draw_line(
		feet + Vector2(profile.leg_spread * 0.4, -profile.leg_length),
		feet + Vector2(profile.leg_spread, 0.0),
		body,
		profile.leg_width
	)

	var arm_start := feet + Vector2(
		direction * profile.torso_width * 0.4167,
		torso_top_y + profile.torso_height * 0.23
	)
	var arm_end := feet + Vector2(
		direction * profile.arm_reach,
		torso_top_y + profile.torso_height * 0.46
	)
	draw_line(arm_start, arm_end, body, profile.arm_width)

	var weapon_start := arm_end + Vector2(-direction * 4.0, -3.0)
	var weapon_vector := Vector2(direction * 0.775, -0.632).normalized() * profile.weapon_length
	draw_line(weapon_start, weapon_start + weapon_vector, profile.weapon_color(), profile.weapon_width)

	if guarding:
		var shield_center := feet + Vector2(direction * minf(profile.arm_reach, 52.0) * 0.71, torso_top_y + profile.torso_height * 0.34)
		var shield_radius := maxf(28.0, profile.arm_reach + 4.0)
		var start_angle := -1.15 if direction > 0.0 else PI - 1.15
		draw_arc(shield_center, shield_radius, start_angle, start_angle + 2.30, 24, profile.guard_color(), 7.0)

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
		"document.documentElement.dataset.playerVisualProfileLoaded='%s';" % _bool_text(player_visual_profile.loaded) +
		"document.documentElement.dataset.playerVisualProfileId=%s;" % JSON.stringify(player_visual_profile.profile_id) +
		"document.documentElement.dataset.playerVisualProfileBodyColor=%s;" % JSON.stringify(player_visual_profile.body_color_hex) +
		"document.documentElement.dataset.playerVisualProfileAccentColor=%s;" % JSON.stringify(player_visual_profile.accent_color_hex) +
		"document.documentElement.dataset.playerVisualProfileHeadRadius='%.3f';" % player_visual_profile.head_radius +
		"document.documentElement.dataset.playerVisualProfileTorsoWidth='%.3f';" % player_visual_profile.torso_width +
		"document.documentElement.dataset.playerVisualProfileTorsoHeight='%.3f';" % player_visual_profile.torso_height +
		"document.documentElement.dataset.playerVisualProfileWeaponLength='%.3f';" % player_visual_profile.weapon_length +
		"document.documentElement.dataset.playerVisualProfileRenderCalls='%d';" % character_profile_render_calls +
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
		"document.documentElement.dataset.playerCharacterSkill6=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_6")) +
		"document.documentElement.dataset.playerSkillRegistryLoaded='%s';" % _bool_text(player_skill_registry.loaded) +
		"document.documentElement.dataset.playerSkillLoadoutReady='%s';" % _bool_text(_runtime_loadout_ready()) +
		"document.documentElement.dataset.playerRuntimeSkill1=%s;" % JSON.stringify(_runtime_skill_id("skill_1")) +
		"document.documentElement.dataset.playerRuntimeSkill2=%s;" % JSON.stringify(_runtime_skill_id("skill_2")) +
		"document.documentElement.dataset.playerRuntimeSkill3=%s;" % JSON.stringify(_runtime_skill_id("skill_3")) +
		"document.documentElement.dataset.playerRuntimeSkill4=%s;" % JSON.stringify(_runtime_skill_id("skill_4")) +
		"document.documentElement.dataset.playerRuntimeSkill5=%s;" % JSON.stringify(_runtime_skill_id("skill_5")) +
		"document.documentElement.dataset.playerRuntimeSkill6=%s;" % JSON.stringify(_runtime_skill_id("skill_6")) +
		"document.documentElement.dataset.playerRuntimeSkill1Type=%s;" % JSON.stringify(_runtime_skill_type("skill_1")) +
		"document.documentElement.dataset.playerRuntimeSkill2Type=%s;" % JSON.stringify(_runtime_skill_type("skill_2")) +
		"document.documentElement.dataset.playerRuntimeSkill3Type=%s;" % JSON.stringify(_runtime_skill_type("skill_3")) +
		"document.documentElement.dataset.playerRuntimeSkill4Type=%s;" % JSON.stringify(_runtime_skill_type("skill_4")) +
		"document.documentElement.dataset.playerRuntimeSkill5Type=%s;" % JSON.stringify(_runtime_skill_type("skill_5")) +
		"document.documentElement.dataset.playerRuntimeSkill6Type=%s;" % JSON.stringify(_runtime_skill_type("skill_6")) +
		"document.documentElement.dataset.playerRuntimeSkill1Source=%s;" % JSON.stringify(_runtime_skill_source("skill_1")) +
		"document.documentElement.dataset.playerRuntimeSkill2Source=%s;" % JSON.stringify(_runtime_skill_source("skill_2")) +
		"document.documentElement.dataset.playerRuntimeSkill3Source=%s;" % JSON.stringify(_runtime_skill_source("skill_3")) +
		"document.documentElement.dataset.playerRuntimeSkill4Source=%s;" % JSON.stringify(_runtime_skill_source("skill_4")) +
		"document.documentElement.dataset.playerRuntimeSkill5Source=%s;" % JSON.stringify(_runtime_skill_source("skill_5")) +
		"document.documentElement.dataset.playerRuntimeSkill6Source=%s;" % JSON.stringify(_runtime_skill_source("skill_6"))
	)
