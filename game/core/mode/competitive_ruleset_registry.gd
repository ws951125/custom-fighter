class_name CompetitiveRulesetRegistry
extends RefCounted

const CompetitiveRulesetDefinition = preload("res://game/core/mode/competitive_ruleset_definition.gd")

const BUILTIN_RULESETS := {
	"sandbox_default": {
		"schema_version": 1,
		"id": "sandbox_default",
		"version": 1,
		"power_budget_id": "sandbox_safe_limits",
		"character_constraints_id": "schema_only",
		"skill_constraints_id": "schema_only",
		"determinism_policy_id": "deterministic_v1"
	},
	"single_player_default": {
		"schema_version": 1,
		"id": "single_player_default",
		"version": 1,
		"power_budget_id": "sandbox_safe_limits",
		"character_constraints_id": "schema_only",
		"skill_constraints_id": "schema_only",
		"determinism_policy_id": "deterministic_v1"
	},
	"competitive_standard": {
		"schema_version": 1,
		"id": "competitive_standard",
		"version": 1,
		"power_budget_id": "competitive_standard_v1",
		"character_constraints_id": "competitive_standard_v1",
		"skill_constraints_id": "competitive_standard_v1",
		"determinism_policy_id": "deterministic_v1"
	}
}

static func ruleset_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for ruleset_id in BUILTIN_RULESETS.keys():
		ids.append(str(ruleset_id))
	ids.sort()
	return ids

static func is_supported(ruleset_id: String, version: int) -> bool:
	var normalized := ruleset_id.strip_edges().to_lower()
	if not BUILTIN_RULESETS.has(normalized):
		return false
	return int(BUILTIN_RULESETS[normalized].get("version", 0)) == version

static func load_ruleset(ruleset_id: String, version: int, target) -> PackedStringArray:
	var errors := PackedStringArray()
	var normalized := ruleset_id.strip_edges().to_lower()
	if target == null:
		errors.append("competitive ruleset target must not be null")
		return errors
	if not BUILTIN_RULESETS.has(normalized):
		errors.append("unknown competitive ruleset id: %s" % normalized)
		return errors
	var raw: Dictionary = BUILTIN_RULESETS[normalized].duplicate(true)
	var supported_version := int(raw.get("version", 0))
	if version != supported_version:
		errors.append(
			"unsupported competitive ruleset version: %s@%d" % [normalized, version]
		)
		return errors
	return target.load_from_dictionary(raw)
