class_name CompetitiveRulesetDefinition
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const ALLOWED_FIELDS := [
	"schema_version",
	"id",
	"version",
	"power_budget_id",
	"character_constraints_id",
	"skill_constraints_id",
	"determinism_policy_id"
]
const POWER_BUDGET_IDS := ["sandbox_safe_limits", "competitive_standard_v1"]
const CHARACTER_CONSTRAINT_IDS := ["schema_only", "competitive_standard_v1"]
const SKILL_CONSTRAINT_IDS := ["schema_only", "competitive_standard_v1"]
const DETERMINISM_POLICY_IDS := ["deterministic_v1"]

var loaded := false
var ruleset_id := ""
var version := 0
var power_budget_id := ""
var character_constraints_id := ""
var skill_constraints_id := ""
var determinism_policy_id := ""

func clear() -> void:
	loaded = false
	ruleset_id = ""
	version = 0
	power_budget_id = ""
	character_constraints_id = ""
	skill_constraints_id = ""
	determinism_policy_id = ""

func load_from_dictionary(raw: Dictionary) -> PackedStringArray:
	clear()
	var errors := PackedStringArray()

	for key in raw.keys():
		if not ALLOWED_FIELDS.has(str(key)):
			errors.append("unknown competitive ruleset field: %s" % str(key))

	for field in ALLOWED_FIELDS:
		if not raw.has(field):
			errors.append("missing competitive ruleset field: %s" % field)

	if not errors.is_empty():
		return errors

	if int(raw.get("schema_version", -1)) != SUPPORTED_SCHEMA_VERSION:
		errors.append("unsupported competitive ruleset schema_version")

	var candidate_id := str(raw.get("id", "")).strip_edges().to_lower()
	if not _is_safe_token(candidate_id, 48):
		errors.append("invalid competitive ruleset id")

	var candidate_version := int(raw.get("version", 0))
	if candidate_version < 1 or candidate_version > 1000:
		errors.append("competitive ruleset version must be between 1 and 1000")

	var candidate_budget := str(raw.get("power_budget_id", "")).strip_edges().to_lower()
	if not POWER_BUDGET_IDS.has(candidate_budget):
		errors.append("unsupported power_budget_id")

	var candidate_character_constraints := str(raw.get("character_constraints_id", "")).strip_edges().to_lower()
	if not CHARACTER_CONSTRAINT_IDS.has(candidate_character_constraints):
		errors.append("unsupported character_constraints_id")

	var candidate_skill_constraints := str(raw.get("skill_constraints_id", "")).strip_edges().to_lower()
	if not SKILL_CONSTRAINT_IDS.has(candidate_skill_constraints):
		errors.append("unsupported skill_constraints_id")

	var candidate_determinism := str(raw.get("determinism_policy_id", "")).strip_edges().to_lower()
	if not DETERMINISM_POLICY_IDS.has(candidate_determinism):
		errors.append("unsupported determinism_policy_id")

	if not errors.is_empty():
		return errors

	ruleset_id = candidate_id
	version = candidate_version
	power_budget_id = candidate_budget
	character_constraints_id = candidate_character_constraints
	skill_constraints_id = candidate_skill_constraints
	determinism_policy_id = candidate_determinism
	loaded = true
	return errors

func to_dictionary() -> Dictionary:
	if not loaded:
		return {}
	return {
		"schema_version": SUPPORTED_SCHEMA_VERSION,
		"id": ruleset_id,
		"version": version,
		"power_budget_id": power_budget_id,
		"character_constraints_id": character_constraints_id,
		"skill_constraints_id": skill_constraints_id,
		"determinism_policy_id": determinism_policy_id
	}

static func _is_safe_token(value: String, max_length: int) -> bool:
	if value.is_empty() or value.length() > max_length:
		return false
	for character in value:
		var code := character.unicode_at(0)
		var safe_alpha := code >= 97 and code <= 122
		var safe_digit := code >= 48 and code <= 57
		if not safe_alpha and not safe_digit and character != "_" and character != "-":
			return false
	return true
