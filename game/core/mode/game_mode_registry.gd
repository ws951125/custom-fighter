class_name GameModeRegistry
extends RefCounted

const GameModeDefinition = preload("res://game/core/mode/game_mode_definition.gd")
const CompetitiveRulesetDefinition = preload("res://game/core/mode/competitive_ruleset_definition.gd")
const CompetitiveRulesetRegistry = preload("res://game/core/mode/competitive_ruleset_registry.gd")

const DEFAULT_MODE_ID := "sandbox"
const BUILTIN_MODES := {
	"sandbox": {
		"schema_version": 1,
		"id": "sandbox",
		"display_name": "Sandbox",
		"mode_family": "sandbox",
		"ruleset_id": "sandbox_default",
		"ruleset_version": 1,
		"power_budget_id": "sandbox_safe_limits",
		"authority_policy": "local_authoritative",
		"allows_custom_content": true
	},
	"single_player": {
		"schema_version": 1,
		"id": "single_player",
		"display_name": "Single Player",
		"mode_family": "single_player",
		"ruleset_id": "single_player_default",
		"ruleset_version": 1,
		"power_budget_id": "sandbox_safe_limits",
		"authority_policy": "local_authoritative",
		"allows_custom_content": true
	},
	"competitive_local": {
		"schema_version": 1,
		"id": "competitive_local",
		"display_name": "Competitive Local",
		"mode_family": "competitive",
		"ruleset_id": "competitive_standard",
		"ruleset_version": 1,
		"power_budget_id": "competitive_standard_v1",
		"authority_policy": "local_authoritative",
		"allows_custom_content": true
	},
	"competitive_hosted": {
		"schema_version": 1,
		"id": "competitive_hosted",
		"display_name": "Competitive Hosted",
		"mode_family": "competitive",
		"ruleset_id": "competitive_standard",
		"ruleset_version": 1,
		"power_budget_id": "competitive_standard_v1",
		"authority_policy": "host_authoritative",
		"allows_custom_content": true
	}
}

static func mode_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for mode_id in BUILTIN_MODES.keys():
		ids.append(str(mode_id))
	ids.sort()
	return ids

static func is_supported(mode_id: String) -> bool:
	return BUILTIN_MODES.has(mode_id.strip_edges().to_lower())

static func load_mode(mode_id: String, target) -> PackedStringArray:
	var errors := PackedStringArray()
	var normalized := mode_id.strip_edges().to_lower()
	if target == null:
		errors.append("game mode target must not be null")
		return errors
	if not BUILTIN_MODES.has(normalized):
		errors.append("unknown game mode id: %s" % normalized)
		return errors

	var raw: Dictionary = BUILTIN_MODES[normalized].duplicate(true)
	var candidate := GameModeDefinition.new()
	errors = candidate.load_from_dictionary(raw)
	if not errors.is_empty() or not candidate.loaded:
		return errors

	var ruleset := CompetitiveRulesetDefinition.new()
	var ruleset_errors: PackedStringArray = CompetitiveRulesetRegistry.load_ruleset(
		candidate.ruleset_id,
		candidate.ruleset_version,
		ruleset
	)
	for error in ruleset_errors:
		errors.append(str(error))
	if not ruleset_errors.is_empty() or not ruleset.loaded:
		return errors
	if ruleset.power_budget_id != candidate.power_budget_id:
		errors.append("game mode power_budget_id does not match referenced ruleset")
		return errors

	return target.load_from_dictionary(candidate.to_dictionary())
