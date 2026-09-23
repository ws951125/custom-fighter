extends SceneTree

const CharacterRegistry = preload("res://game/core/character/character_registry.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const CompetitiveLoadoutSnapshot = preload("res://game/core/mode/competitive_loadout_snapshot.gd")

class StubCharacterRegistry:
	extends RefCounted

	var loaded := true
	var expected_character_id := ""
	var source_data: Dictionary = {}

	func _init(raw_data: Dictionary) -> void:
		source_data = raw_data.duplicate(true)
		expected_character_id = str(source_data.get("id", ""))

	func load_character(character_id: String, target_character) -> PackedStringArray:
		var errors := PackedStringArray()
		if character_id != expected_character_id:
			errors.append("unknown test character")
			return errors
		return target_character.load_from_dictionary(source_data)

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_reference_snapshots_are_deterministic()
	_test_ruleset_and_registry_fail_closed()
	_test_budget_rejection_blocks_authoritative_snapshot()
	_test_skill_registry_resolution_is_required()
	if failures == 0:
		print("COMPETITIVE_LOADOUT_SNAPSHOT_TESTS_PASSED")
		quit(0)
		return
	printerr("COMPETITIVE_LOADOUT_SNAPSHOT_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_reference_snapshots_are_deterministic() -> void:
	var registries: Dictionary = _default_registries()
	var character_registry = registries.get("character")
	var skill_registry = registries.get("skill")

	var first: Dictionary = CompetitiveLoadoutSnapshot.build(
		"competitive_standard",
		1,
		"ember_vanguard_001",
		character_registry,
		skill_registry
	)
	var second: Dictionary = CompetitiveLoadoutSnapshot.build(
		"competitive_standard",
		1,
		"ember_vanguard_001",
		character_registry,
		skill_registry
	)
	_check(bool(first.get("valid")), "Ember Vanguard produces authoritative competitive snapshot")
	_check(first == second, "same ruleset and registry content produce identical snapshot")
	_check(int(first.get("snapshot_version", 0)) == 1, "snapshot version is frozen")
	_check(int(first.get("fingerprint_version", 0)) == 1, "fingerprint version is frozen")
	_check(str(first.get("ruleset_id", "")) == "competitive_standard", "snapshot binds competitive ruleset")
	_check(int(first.get("ruleset_version", 0)) == 1, "snapshot binds competitive ruleset version")
	_check(str(first.get("character_id", "")) == "ember_vanguard_001", "snapshot binds resolved character id")

	var slots: Dictionary = first.get("resolved_skill_slots", {})
	_check(slots.size() == 6, "snapshot contains the six resolved Ember occupied slots")
	_check(str(slots.get("skill_1", "")) == "fireball_001", "snapshot resolves skill slot through trusted registry path")

	var stats: Dictionary = first.get("normalized_character_stats", {})
	_check(int(stats.get("max_hp", 0)) == 100, "snapshot copies authoritative validated HP")
	_check(is_equal_approx(float(stats.get("move_speed", 0.0)), 360.0), "snapshot copies authoritative validated movement")

	var budget: Dictionary = first.get("power_budget_result", {})
	_check(bool(budget.get("eligible")), "snapshot is emitted only after budget eligibility")
	_check(int(budget.get("character_score", 0)) == 2683, "snapshot carries frozen character budget result")
	_check(int(budget.get("total_score", 0)) == 15649, "snapshot carries frozen total budget result")

	var fingerprint := str(first.get("content_fingerprint", ""))
	_check(_is_sha256_hex(fingerprint), "content fingerprint is canonical SHA-256 text")

	var storm: Dictionary = CompetitiveLoadoutSnapshot.build(
		"competitive_standard",
		1,
		"storm_duelist_001",
		character_registry,
		skill_registry
	)
	_check(bool(storm.get("valid")), "Storm Duelist produces authoritative competitive snapshot")
	_check(
		str(storm.get("content_fingerprint", "")) != fingerprint,
		"different authoritative competitive content produces a different fingerprint"
	)

func _test_ruleset_and_registry_fail_closed() -> void:
	var registries: Dictionary = _default_registries()
	var character_registry = registries.get("character")
	var skill_registry = registries.get("skill")

	var wrong_version: Dictionary = CompetitiveLoadoutSnapshot.build(
		"competitive_standard",
		2,
		"ember_vanguard_001",
		character_registry,
		skill_registry
	)
	_check(not bool(wrong_version.get("valid")), "unsupported ruleset version cannot produce snapshot")
	_check(
		_contains_code(wrong_version, "RULESET_RESOLUTION_FAILED"),
		"unsupported ruleset version emits stable resolution code"
	)
	_check(str(wrong_version.get("content_fingerprint", "")).is_empty(), "failed ruleset has no fingerprint")

	var sandbox: Dictionary = CompetitiveLoadoutSnapshot.build(
		"sandbox_default",
		1,
		"ember_vanguard_001",
		character_registry,
		skill_registry
	)
	_check(not bool(sandbox.get("valid")), "sandbox ruleset cannot be promoted into competitive snapshot")
	_check(
		_contains_code(sandbox, "NONCOMPETITIVE_RULESET_POLICY"),
		"noncompetitive ruleset emits stable policy code"
	)

	var unknown_character: Dictionary = CompetitiveLoadoutSnapshot.build(
		"competitive_standard",
		1,
		"not_registered_001",
		character_registry,
		skill_registry
	)
	_check(not bool(unknown_character.get("valid")), "unregistered character cannot produce snapshot")
	_check(
		_contains_code(unknown_character, "CHARACTER_RESOLUTION_FAILED:not_registered_001"),
		"unregistered character emits stable registry-resolution code"
	)

	var unavailable: Dictionary = CompetitiveLoadoutSnapshot.build(
		"competitive_standard",
		1,
		"ember_vanguard_001",
		null,
		skill_registry
	)
	_check(not bool(unavailable.get("valid")), "missing authority registry fails closed")
	_check(
		_contains_code(unavailable, "CHARACTER_REGISTRY_UNAVAILABLE"),
		"missing authority registry emits stable code"
	)

func _test_budget_rejection_blocks_authoritative_snapshot() -> void:
	var over_budget_character := {
		"schema_version": 1,
		"id": "over_budget_fighter",
		"name": "Over Budget Fighter",
		"archetype": "balanced",
		"stats": {
			"max_hp": 161,
			"max_mp": 100,
			"move_speed": 360.0,
			"depth_speed": 0.72,
			"run_multiplier": 1.60,
			"guard_move_multiplier": 0.35
		},
		"skill_slots": {
			"skill_1": "fireball_001",
			"skill_2": "dash_slash_001",
			"skill_3": "arc_burst_001",
			"skill_4": "blade_rain_001",
			"skill_5": "battle_focus_001",
			"skill_6": "heavy_strike_001"
		},
		"visual_profile": "training_blue",
		"animation_map": "ember_vanguard"
	}
	var character_registry := StubCharacterRegistry.new(over_budget_character)
	var skill_registry := SkillRegistry.new()
	var registry_errors: PackedStringArray = skill_registry.load_default()
	_check(registry_errors.is_empty() and skill_registry.loaded, "skill registry loads for over-budget admission test")

	var rejected: Dictionary = CompetitiveLoadoutSnapshot.build(
		"competitive_standard",
		1,
		"over_budget_fighter",
		character_registry,
		skill_registry
	)
	_check(not bool(rejected.get("valid")), "over-budget character cannot become authoritative snapshot")
	_check(_contains_code(rejected, "POWER_BUDGET_REJECTED"), "budget rejection emits stable admission code")
	_check(_contains_code(rejected, "BUDGET:CHARACTER_MAX_HP_CAP"), "budget hard-cap diagnostic is preserved")
	_check(
		Dictionary(rejected.get("normalized_character_stats", {})).is_empty(),
		"rejected content exposes no admitted authoritative character values"
	)
	_check(
		Dictionary(rejected.get("normalized_skill_values", {})).is_empty(),
		"rejected content exposes no admitted authoritative skill values"
	)
	_check(str(rejected.get("content_fingerprint", "")).is_empty(), "rejected content receives no compatibility fingerprint")

func _test_skill_registry_resolution_is_required() -> void:
	var character_registry := CharacterRegistry.new()
	var character_errors: PackedStringArray = character_registry.load_default()
	_check(character_errors.is_empty() and character_registry.loaded, "character registry loads for skill resolution test")

	var skill_registry := SkillRegistry.new()
	var skill_errors: PackedStringArray = skill_registry.load_default()
	_check(skill_errors.is_empty() and skill_registry.loaded, "skill registry loads for skill resolution test")
	skill_registry.entries.erase("fireball_001")

	var rejected: Dictionary = CompetitiveLoadoutSnapshot.build(
		"competitive_standard",
		1,
		"ember_vanguard_001",
		character_registry,
		skill_registry
	)
	_check(not bool(rejected.get("valid")), "missing trusted skill registry entry blocks snapshot")
	_check(
		_contains_code(rejected, "SKILL_REGISTRY_TYPE_MISSING:fireball_001"),
		"missing trusted skill entry emits stable code"
	)
	_check(str(rejected.get("content_fingerprint", "")).is_empty(), "unresolved loadout receives no fingerprint")

func _default_registries() -> Dictionary:
	var character_registry := CharacterRegistry.new()
	var character_errors: PackedStringArray = character_registry.load_default()
	_check(character_errors.is_empty() and character_registry.loaded, "default character registry loads")

	var skill_registry := SkillRegistry.new()
	var skill_errors: PackedStringArray = skill_registry.load_default()
	_check(skill_errors.is_empty() and skill_registry.loaded, "default skill registry loads")
	return {
		"character": character_registry,
		"skill": skill_registry
	}

func _contains_code(result: Dictionary, code: String) -> bool:
	var codes: PackedStringArray = result.get("diagnostic_codes", PackedStringArray())
	return codes.has(code)

func _is_sha256_hex(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		var code := character.unicode_at(0)
		var digit := code >= 48 and code <= 57
		var lowercase_hex := code >= 97 and code <= 102
		if not digit and not lowercase_hex:
			return false
	return true

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
