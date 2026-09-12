extends "res://game/runtime/characterized_main.gd"

const CharacterRegistry = preload("res://game/core/character/character_registry.gd")
const CharacterDefinitionClass = preload("res://game/core/character/character_definition.gd")
const CombatantStateClass = preload("res://game/core/combat/combatant_state.gd")

var player_character_registry := CharacterRegistry.new()
var player_requested_character_id := ""
var player_character_source := ""
var player_character_selection_error := ""
var player_character_selection_fallback := false

func _enter_tree() -> void:
	var registry_errors := player_character_registry.load_default()
	if not registry_errors.is_empty():
		push_error("Failed to load character registry: %s" % " | ".join(registry_errors))
		return

	var requested_id := _requested_character_id()
	player_requested_character_id = requested_id
	var selected_id := requested_id if not requested_id.is_empty() else player_character_registry.default_character_id
	var character_errors := player_character_registry.load_character(selected_id, player_character)
	if not character_errors.is_empty() and selected_id != player_character_registry.default_character_id:
		player_character_selection_error = " | ".join(character_errors)
		player_character_selection_fallback = true
		player_character = CharacterDefinitionClass.new()
		selected_id = player_character_registry.default_character_id
		character_errors = player_character_registry.load_character(selected_id, player_character)

	if not character_errors.is_empty():
		push_error("Failed to load player character: %s" % " | ".join(character_errors))
		return
	player_character_source = player_character_registry.source_path_for_id(player_character.character_id)

	var visual_errors := player_visual_profile.load_from_id(player_character.visual_profile)
	if not visual_errors.is_empty():
		push_error("Failed to load player visual profile: %s" % " | ".join(visual_errors))

	var skill_registry_errors := player_skill_registry.load_default()
	if not skill_registry_errors.is_empty():
		push_error("Failed to load skill registry: %s" % " | ".join(skill_registry_errors))

	player_state = CombatantStateClass.new(player_character.max_hp, player_character.max_mp)

func _requested_character_id() -> String:
	if not OS.has_feature("web"):
		return ""
	var result = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('character') || ''")
	return str(result).strip_edges()

func _set_web_state() -> void:
	super()
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.playerCharacterRegistryLoaded='%s';" % _bool_text(player_character_registry.loaded) +
		"document.documentElement.dataset.playerCharacterRegistryDefault=%s;" % JSON.stringify(player_character_registry.default_character_id) +
		"document.documentElement.dataset.playerRequestedCharacterId=%s;" % JSON.stringify(player_requested_character_id) +
		"document.documentElement.dataset.playerSelectedCharacterId=%s;" % JSON.stringify(player_character.character_id) +
		"document.documentElement.dataset.playerCharacterSource=%s;" % JSON.stringify(player_character_source) +
		"document.documentElement.dataset.playerCharacterSelectionFallback='%s';" % _bool_text(player_character_selection_fallback) +
		"document.documentElement.dataset.playerCharacterSelectionError=%s;" % JSON.stringify(player_character_selection_error)
	)
