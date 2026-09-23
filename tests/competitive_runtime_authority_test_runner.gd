extends SceneTree

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")
const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const CompetitiveRuntimeAuthority = preload("res://game/core/mode/competitive_runtime_authority.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_reference_loadout_materializes_from_authority()
	_test_raw_runtime_targets_cannot_bypass_snapshot()
	_test_wrong_mode_and_unknown_character_fail_closed()
	_test_snapshot_tamper_fails_closed()
	if failures == 0:
		print("COMPETITIVE_RUNTIME_AUTHORITY_TESTS_PASSED")
		quit(0)
		return
	printerr("COMPETITIVE_RUNTIME_AUTHORITY_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_reference_loadout_materializes_from_authority() -> void:
	var authority := CompetitiveRuntimeAuthority.new()
	var admission_errors: PackedStringArray = authority.admit_registry_loadout("ember_vanguard_001")
	_check(admission_errors.is_empty(), "reference competitive loadout admits without diagnostics")
	_check(authority.admitted, "competitive authority enters admitted state")
	_check(authority.content_fingerprint().length() == 64, "competitive authority exposes SHA-256 fingerprint")
	_check(authority.character_id() == "ember_vanguard_001", "authority character identity is snapshot-owned")

	var character := CharacterDefinition.new()
	var character_errors: PackedStringArray = authority.apply_character_to(character)
	_check(character_errors.is_empty() and character.loaded, "authority materializes admitted character")
	var expected_stats: Dictionary = authority.snapshot.get("normalized_character_stats", {})
	_check(character.max_hp == int(expected_stats.get("max_hp", -1)), "runtime HP comes from admitted snapshot")
	_check(character.max_mp == int(expected_stats.get("max_mp", -1)), "runtime MP comes from admitted snapshot")
	_check(absf(character.move_speed - float(expected_stats.get("move_speed", -1.0))) < 0.001, "runtime movement comes from admitted snapshot")

	var skill := SkillDefinition.new()
	var skill_errors: PackedStringArray = authority.load_skill_for_slot("skill_1", "projectile", skill)
	_check(skill_errors.is_empty() and skill.loaded, "authority materializes admitted skill slot")
	var skill_values: Dictionary = authority.snapshot.get("normalized_skill_values", {}).get(skill.skill_id, {})
	_check(skill.damage == int(skill_values.get("damage", -1)), "runtime skill damage comes from admitted snapshot")
	_check(skill.mp_cost == int(skill_values.get("mp_cost", -1)), "runtime skill MP cost comes from admitted snapshot")
	_check(absf(skill.cooldown - float(skill_values.get("cooldown", -1.0))) < 0.001, "runtime skill cooldown comes from admitted snapshot")

func _test_raw_runtime_targets_cannot_bypass_snapshot() -> void:
	var authority := CompetitiveRuntimeAuthority.new()
	authority.admit_registry_loadout("ember_vanguard_001")
	_check(authority.admitted, "authority admits reference loadout for raw-value bypass test")

	var forged_character := CharacterDefinition.new()
	forged_character.loaded = true
	forged_character.character_id = "forged_client_character"
	forged_character.max_hp = 9999
	forged_character.max_mp = 9999
	var character_errors: PackedStringArray = authority.apply_character_to(forged_character)
	var expected_stats: Dictionary = authority.snapshot.get("normalized_character_stats", {})
	_check(character_errors.is_empty(), "forged runtime character target is replaced without trusting its values")
	_check(forged_character.character_id == "ember_vanguard_001", "forged character identity cannot replace authority identity")
	_check(forged_character.max_hp == int(expected_stats.get("max_hp", -1)), "forged HP cannot bypass authority snapshot")
	_check(forged_character.max_mp == int(expected_stats.get("max_mp", -1)), "forged MP cannot bypass authority snapshot")

	var forged_skill := SkillDefinition.new()
	forged_skill.loaded = true
	forged_skill.skill_id = "forged_client_skill"
	forged_skill.skill_type = "projectile"
	forged_skill.damage = 999999
	forged_skill.mp_cost = 0
	forged_skill.cooldown = 0.0
	var skill_errors: PackedStringArray = authority.load_skill_for_slot("skill_1", "projectile", forged_skill)
	var authoritative_values: Dictionary = authority.snapshot.get("normalized_skill_values", {}).get(forged_skill.skill_id, {})
	_check(skill_errors.is_empty(), "forged runtime skill target is replaced without trusting its values")
	_check(forged_skill.skill_id == "fireball_001", "forged skill identity cannot replace admitted slot")
	_check(forged_skill.damage == int(authoritative_values.get("damage", -1)), "forged damage cannot bypass admitted damage")
	_check(forged_skill.mp_cost == int(authoritative_values.get("mp_cost", -1)), "forged MP cost cannot bypass admitted MP cost")
	_check(absf(forged_skill.cooldown - float(authoritative_values.get("cooldown", -1.0))) < 0.001, "forged cooldown cannot bypass admitted cooldown")

func _test_wrong_mode_and_unknown_character_fail_closed() -> void:
	var hosted := CompetitiveRuntimeAuthority.new()
	var hosted_errors: PackedStringArray = hosted.admit_registry_loadout(
		"ember_vanguard_001",
		"competitive_hosted"
	)
	_check(not hosted.admitted, "hosted authority policy cannot enter local competitive runtime")
	_check(hosted_errors.has("UNSUPPORTED_LOCAL_COMPETITIVE_MODE"), "wrong authority mode emits stable diagnostic")

	var unknown := CompetitiveRuntimeAuthority.new()
	var unknown_errors: PackedStringArray = unknown.admit_registry_loadout("unknown_fighter_001")
	_check(not unknown.admitted, "unknown character fails competitive runtime admission")
	_check(unknown_errors.has("SNAPSHOT_ADMISSION_FAILED"), "unknown character rejection is attributed to snapshot admission")
	_check(unknown_errors.has("SNAPSHOT:CHARACTER_RESOLUTION_FAILED"), "unknown character keeps stable snapshot diagnostic")
	var target := CharacterDefinition.new()
	var apply_errors: PackedStringArray = unknown.apply_character_to(target)
	_check(apply_errors.has("COMPETITIVE_AUTHORITY_NOT_ADMITTED"), "rejected authority cannot materialize combat character")

func _test_snapshot_tamper_fails_closed() -> void:
	var authority := CompetitiveRuntimeAuthority.new()
	authority.admit_registry_loadout("ember_vanguard_001")
	_check(authority.admitted, "authority admits before integrity-tamper test")

	var stats: Dictionary = authority.snapshot.get("normalized_character_stats", {}).duplicate(true)
	stats["max_hp"] = 9999
	authority.snapshot["normalized_character_stats"] = stats

	var target := CharacterDefinition.new()
	var errors: PackedStringArray = authority.apply_character_to(target)
	_check(errors.has("COMPETITIVE_SNAPSHOT_INTEGRITY_FAILED"), "post-admission snapshot tamper fails closed")
	_check(not target.loaded, "tampered snapshot cannot materialize authority combat state")
	_check(authority.content_fingerprint().is_empty(), "tampered snapshot no longer exposes valid fingerprint")

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
