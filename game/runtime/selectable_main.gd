extends "res://game/runtime/characterized_main.gd"

const CharacterRegistry = preload("res://game/core/character/character_registry.gd")
const CharacterDefinitionClass = preload("res://game/core/character/character_definition.gd")
const CombatantStateClass = preload("res://game/core/combat/combatant_state.gd")
const CompetitiveRuntimeAuthority = preload("res://game/core/mode/competitive_runtime_authority.gd")

var player_character_registry := CharacterRegistry.new()
var player_requested_character_id := ""
var player_character_source := ""
var player_character_selection_error := ""
var player_character_selection_fallback := false
var competitive_runtime_authority := CompetitiveRuntimeAuthority.new()
var competitive_authority_active := false
var competitive_authority_admitted := false
var competitive_authority_diagnostic_codes := PackedStringArray()
var competitive_authority_fingerprint := ""

func _enter_tree() -> void:
	var registry_errors := player_character_registry.load_default()
	if not registry_errors.is_empty():
		push_error("Failed to load character registry: %s" % " | ".join(registry_errors))
		return

	var requested_id := _requested_character_id()
	player_requested_character_id = requested_id
	var selected_id := requested_id if not requested_id.is_empty() else player_character_registry.default_character_id
	competitive_authority_active = _competitive_authority_mode_active()

	if competitive_authority_active:
		_enter_competitive_authority_loadout(selected_id)
		return

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

	_finish_character_runtime_setup()

func _enter_competitive_authority_loadout(selected_id: String) -> void:
	competitive_authority_diagnostic_codes = competitive_runtime_authority.admit_registry_loadout(selected_id)
	competitive_authority_admitted = competitive_runtime_authority.admitted
	competitive_authority_fingerprint = competitive_runtime_authority.content_fingerprint()
	if not competitive_authority_admitted:
		player_character_selection_error = "competitive authority rejected: %s" % " | ".join(competitive_authority_diagnostic_codes)
		player_character_source = "competitive_authority_rejected"
		player_character = CharacterDefinitionClass.new()
		push_error(player_character_selection_error)
		return

	var character_errors: PackedStringArray = competitive_runtime_authority.apply_character_to(player_character)
	if not character_errors.is_empty() or not player_character.loaded:
		competitive_authority_admitted = false
		for error in character_errors:
			competitive_authority_diagnostic_codes.append(str(error))
		player_character_selection_error = "competitive authority materialization failed: %s" % " | ".join(character_errors)
		player_character_source = "competitive_authority_rejected"
		player_character = CharacterDefinitionClass.new()
		push_error(player_character_selection_error)
		return

	player_character_source = "competitive_authority_snapshot:%s" % competitive_authority_fingerprint
	_finish_character_runtime_setup()

func _finish_character_runtime_setup() -> void:
	var visual_errors := player_visual_profile.load_from_id(player_character.visual_profile)
	if not visual_errors.is_empty():
		push_error("Failed to load player visual profile: %s" % " | ".join(visual_errors))

	var skill_registry_errors := player_skill_registry.load_default()
	if not skill_registry_errors.is_empty():
		push_error("Failed to load skill registry: %s" % " | ".join(skill_registry_errors))

	player_state = CombatantStateClass.new(player_character.max_hp, player_character.max_mp)

func load_character_skill_for_slot(slot_name: String, expected_type: String, target_skill) -> PackedStringArray:
	if competitive_authority_active:
		var authority_errors: PackedStringArray = competitive_runtime_authority.load_skill_for_slot(
			slot_name,
			expected_type,
			target_skill
		)
		_record_runtime_skill_result(
			slot_name,
			target_skill,
			authority_errors,
			"competitive_authority_snapshot:%s" % competitive_authority_fingerprint
		)
		return authority_errors

	if not CharacterDefinitionClass.OPTIONAL_SKILL_SLOTS.has(slot_name):
		return super(slot_name, expected_type, target_skill)

	var errors := PackedStringArray()
	if not player_character.loaded:
		errors.append("player character is not loaded")
	elif not player_skill_registry.loaded:
		errors.append("player skill registry is not loaded")
	else:
		var requested_id := player_character.skill_id_for_slot(slot_name)
		if requested_id.is_empty():
			errors.append("optional character skill slot is not configured: %s" % slot_name)
		else:
			errors = player_skill_registry.load_skill(requested_id, expected_type, target_skill)

	_record_runtime_skill_result(
		slot_name,
		target_skill,
		errors,
		player_skill_registry.source_path_for_id(target_skill.skill_id) if errors.is_empty() else ""
	)
	return errors

func _record_runtime_skill_result(
	slot_name: String,
	target_skill,
	errors: PackedStringArray,
	source: String
) -> void:
	if errors.is_empty():
		player_runtime_skill_ids[slot_name] = target_skill.skill_id
		player_runtime_skill_sources[slot_name] = source
		player_runtime_skill_types[slot_name] = target_skill.skill_type
		player_runtime_skill_errors.erase(slot_name)
	else:
		player_runtime_skill_ids.erase(slot_name)
		player_runtime_skill_sources.erase(slot_name)
		player_runtime_skill_types.erase(slot_name)
		player_runtime_skill_errors[slot_name] = " | ".join(errors)

func _competitive_authority_mode_active() -> bool:
	var router: Variant = get_parent()
	if router == null:
		return false
	return str(router.get("app_mode")).strip_edges().to_lower() == CompetitiveRuntimeAuthority.LOCAL_MODE_ID

func _requested_character_id() -> String:
	if not OS.has_feature("web"):
		return ""
	var result = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('character') || ''")
	return str(result).strip_edges()

func _set_web_state() -> void:
	super()
	if not OS.has_feature("web"):
		return
	var authority_snapshot: Dictionary = competitive_runtime_authority.snapshot if competitive_authority_admitted else {}
	JavaScriptBridge.eval(
		"document.documentElement.dataset.playerCharacterRegistryLoaded='%s';" % _bool_text(player_character_registry.loaded) +
		"document.documentElement.dataset.playerCharacterRegistryDefault=%s;" % JSON.stringify(player_character_registry.default_character_id) +
		"document.documentElement.dataset.playerRequestedCharacterId=%s;" % JSON.stringify(player_requested_character_id) +
		"document.documentElement.dataset.playerSelectedCharacterId=%s;" % JSON.stringify(player_character.character_id) +
		"document.documentElement.dataset.playerCharacterSource=%s;" % JSON.stringify(player_character_source) +
		"document.documentElement.dataset.playerCharacterSelectionFallback='%s';" % _bool_text(player_character_selection_fallback) +
		"document.documentElement.dataset.playerCharacterSelectionError=%s;" % JSON.stringify(player_character_selection_error) +
		"document.documentElement.dataset.competitiveAuthorityActive='%s';" % _bool_text(competitive_authority_active) +
		"document.documentElement.dataset.competitiveAuthorityAdmitted='%s';" % _bool_text(competitive_authority_admitted) +
		"document.documentElement.dataset.competitiveAuthorityFingerprint=%s;" % JSON.stringify(competitive_authority_fingerprint) +
		"document.documentElement.dataset.competitiveAuthorityRulesetId=%s;" % JSON.stringify(str(authority_snapshot.get("ruleset_id", ""))) +
		"document.documentElement.dataset.competitiveAuthorityRulesetVersion='%d';" % int(authority_snapshot.get("ruleset_version", 0)) +
		"document.documentElement.dataset.competitiveAuthorityPowerBudgetId=%s;" % JSON.stringify(str(authority_snapshot.get("power_budget_id", ""))) +
		"document.documentElement.dataset.competitiveAuthorityCharacterId=%s;" % JSON.stringify(str(authority_snapshot.get("character_id", ""))) +
		"document.documentElement.dataset.competitiveAuthorityDiagnostics=%s;" % JSON.stringify(",".join(competitive_authority_diagnostic_codes))
	)
