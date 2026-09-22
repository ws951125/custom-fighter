class_name OpponentBehaviorProfiles
extends RefCounted

const OpponentBehaviorProfile = preload("res://game/core/ai/opponent_behavior_profile.gd")

const DEFAULT_PROFILE_ID := "training_balanced"
const PROFILE_LABELS := {
	"training_cautious": "Easy · Cautious",
	"training_balanced": "Normal · Balanced",
	"training_pressure": "Hard · Pressure"
}
const BUILTIN_PROFILES := {
	"training_cautious": {
		"schema_version": 1,
		"id": "training_cautious",
		"reaction_interval": 0.45,
		"preferred_min_distance": 150.0,
		"preferred_max_distance": 240.0,
		"depth_tolerance": 0.12,
		"basic_attack_range": 150.0,
		"guard_policy": "when_threatened",
		"allow_basic_attack": true,
		"preferred_skill_slot": ""
	},
	"training_balanced": {
		"schema_version": 1,
		"id": "training_balanced",
		"reaction_interval": 0.25,
		"preferred_min_distance": 110.0,
		"preferred_max_distance": 180.0,
		"depth_tolerance": 0.10,
		"basic_attack_range": 150.0,
		"guard_policy": "when_threatened",
		"allow_basic_attack": true,
		"preferred_skill_slot": ""
	},
	"training_pressure": {
		"schema_version": 1,
		"id": "training_pressure",
		"reaction_interval": 0.15,
		"preferred_min_distance": 70.0,
		"preferred_max_distance": 130.0,
		"depth_tolerance": 0.08,
		"basic_attack_range": 120.0,
		"guard_policy": "never",
		"allow_basic_attack": true,
		"preferred_skill_slot": "skill_1"
	}
}

static func profile_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for profile_id in BUILTIN_PROFILES.keys():
		ids.append(str(profile_id))
	ids.sort()
	return ids

static func is_supported(profile_id: String) -> bool:
	return BUILTIN_PROFILES.has(profile_id.strip_edges().to_lower())

static func normalize_profile_id(profile_id: String) -> String:
	var normalized := profile_id.strip_edges().to_lower()
	if is_supported(normalized):
		return normalized
	return DEFAULT_PROFILE_ID

static func display_label(profile_id: String) -> String:
	var normalized := normalize_profile_id(profile_id)
	return str(PROFILE_LABELS.get(normalized, normalized))

static func load_profile(profile_id: String, target) -> PackedStringArray:
	var errors := PackedStringArray()
	var normalized := profile_id.strip_edges().to_lower()
	if target == null:
		errors.append("opponent behavior target must not be null")
		return errors
	if not BUILTIN_PROFILES.has(normalized):
		errors.append("unknown opponent behavior profile: %s" % normalized)
		return errors
	var raw: Dictionary = BUILTIN_PROFILES[normalized].duplicate(true)
	return target.load_from_dictionary(raw)
