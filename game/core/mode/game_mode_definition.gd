class_name GameModeDefinition
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const ALLOWED_FIELDS := [
	"schema_version",
	"id",
	"display_name",
	"mode_family",
	"ruleset_id",
	"ruleset_version",
	"power_budget_id",
	"authority_policy",
	"allows_custom_content"
]
const MODE_FAMILIES := ["sandbox", "single_player", "competitive"]
const AUTHORITY_POLICIES := ["local_authoritative", "host_authoritative"]

var loaded := false
var mode_id := ""
var display_name := ""
var mode_family := ""
var ruleset_id := ""
var ruleset_version := 0
var power_budget_id := ""
var authority_policy := ""
var allows_custom_content := false

func clear() -> void:
	loaded = false
	mode_id = ""
	display_name = ""
	mode_family = ""
	ruleset_id = ""
	ruleset_version = 0
	power_budget_id = ""
	authority_policy = ""
	allows_custom_content = false

func load_from_dictionary(raw: Dictionary) -> PackedStringArray:
	clear()
	var errors := PackedStringArray()

	for key in raw.keys():
		if not ALLOWED_FIELDS.has(str(key)):
			errors.append("unknown game mode field: %s" % str(key))

	for field in ALLOWED_FIELDS:
		if not raw.has(field):
			errors.append("missing game mode field: %s" % field)

	if not errors.is_empty():
		return errors

	if int(raw.get("schema_version", -1)) != SUPPORTED_SCHEMA_VERSION:
		errors.append("unsupported game mode schema_version")

	var candidate_id := str(raw.get("id", "")).strip_edges().to_lower()
	if not _is_safe_token(candidate_id, 48):
		errors.append("invalid game mode id")

	var candidate_name := str(raw.get("display_name", "")).strip_edges()
	if candidate_name.is_empty() or candidate_name.length() > 64:
		errors.append("invalid game mode display_name")

	var candidate_family := str(raw.get("mode_family", "")).strip_edges().to_lower()
	if not MODE_FAMILIES.has(candidate_family):
		errors.append("unsupported game mode family")

	var candidate_ruleset_id := str(raw.get("ruleset_id", "")).strip_edges().to_lower()
	if not _is_safe_token(candidate_ruleset_id, 48):
		errors.append("invalid game mode ruleset_id")

	var candidate_ruleset_version := int(raw.get("ruleset_version", 0))
	if candidate_ruleset_version < 1 or candidate_ruleset_version > 1000:
		errors.append("game mode ruleset_version must be between 1 and 1000")

	var candidate_budget_id := str(raw.get("power_budget_id", "")).strip_edges().to_lower()
	if not _is_safe_token(candidate_budget_id, 48):
		errors.append("invalid game mode power_budget_id")

	var candidate_authority := str(raw.get("authority_policy", "")).strip_edges().to_lower()
	if not AUTHORITY_POLICIES.has(candidate_authority):
		errors.append("unsupported authority_policy")

	if typeof(raw.get("allows_custom_content")) != TYPE_BOOL:
		errors.append("allows_custom_content must be boolean")

	if not errors.is_empty():
		return errors

	mode_id = candidate_id
	display_name = candidate_name
	mode_family = candidate_family
	ruleset_id = candidate_ruleset_id
	ruleset_version = candidate_ruleset_version
	power_budget_id = candidate_budget_id
	authority_policy = candidate_authority
	allows_custom_content = bool(raw.get("allows_custom_content"))
	loaded = true
	return errors

func to_dictionary() -> Dictionary:
	if not loaded:
		return {}
	return {
		"schema_version": SUPPORTED_SCHEMA_VERSION,
		"id": mode_id,
		"display_name": display_name,
		"mode_family": mode_family,
		"ruleset_id": ruleset_id,
		"ruleset_version": ruleset_version,
		"power_budget_id": power_budget_id,
		"authority_policy": authority_policy,
		"allows_custom_content": allows_custom_content
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
