extends "res://game/runtime/coordinated_main.gd"

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const PLAYER_CHARACTER_PATH := "res://content/characters/ember_vanguard.sample.json"

var player_character := CharacterDefinition.new()

func _enter_tree() -> void:
	var errors := player_character.load_from_file(PLAYER_CHARACTER_PATH)
	if not errors.is_empty():
		push_error("Failed to load player character: %s" % " | ".join(errors))
		return
	player_state = CombatantState.new(player_character.max_hp, player_character.max_mp)

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
		"document.documentElement.dataset.playerCharacterSkill1=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_1")) +
		"document.documentElement.dataset.playerCharacterSkill2=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_2")) +
		"document.documentElement.dataset.playerCharacterSkill3=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_3")) +
		"document.documentElement.dataset.playerCharacterSkill4=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_4")) +
		"document.documentElement.dataset.playerCharacterSkill5=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_5")) +
		"document.documentElement.dataset.playerCharacterSkill6=%s;" % JSON.stringify(player_character.skill_id_for_slot("skill_6"))
	)
