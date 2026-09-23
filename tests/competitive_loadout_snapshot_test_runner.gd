extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillRegistry = preload("res://game/core/skills/skill_registry.gd")
const CompetitiveLoadoutSnapshotBuilder = preload("res://game/core/mode/competitive_loadout_snapshot_builder.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_reference_snapshot_and_fingerprint()
	_test_ruleset_and_registry_fail_closed()
	_test_canonical_fingerprint_ordering()
	_test_presentation_only_fields_are_not_authoritative()
	if failures == 0:
		print("COMPETITIVE_LOADOUT_SNAPSHOT_TESTS_PASSED")
		quit(0)
		return
	printerr("COMPETITIVE_LOADOUT_SNAPSHOT_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_reference_snapshot_and_fingerprint() -> void:
	var first: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry("ember_vanguard_001")
	var second: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry("ember_vanguard_001")
	_check(bool(first.get("accepted")), "Ember Vanguard registry loadout is admitted")
	_check(first == second, "same registry content produces identical snapshot result")

	var snapshot: Dictionary = first.get("snapshot", {})
	var fingerprint := str(snapshot.get("content_fingerprint", ""))
	_check(int(snapshot.get("snapshot_schema_version", 0)) == 1, "snapshot schema version is frozen")
	_check(str(snapshot.get("ruleset_id", "")) == "competitive_standard", "snapshot binds competitive ruleset")
	_check(int(snapshot.get("ruleset_version", 0)) == 1, "snapshot binds competitive ruleset version")
	_check(str(snapshot.get("power_budget_id", "")) == "competitive_standard_v1", "snapshot binds power budget id")
	_check(int(snapshot.get("power_budget_version", 0)) == 1, "snapshot binds power budget version")
	_check(str(snapshot.get("determinism_policy_id", "")) == "deterministic_v1", "snapshot binds determinism policy")
	_check(str(snapshot.get("character_id", "")) == "ember_vanguard_001", "snapshot identifies resolved character")
	_check(fingerprint.length() == 64, "snapshot fingerprint is SHA-256 hex")
	_check(fingerprint == str(second.get("snapshot", {}).get("content_fingerprint", "")), "fingerprint is stable across repeated builds")

	var budget: Dictionary = snapshot.get("power_budget_result", {})
	_check(bool(budget.get("eligible")), "snapshot contains eligible power-budget result")
	_check(int(budget.get("total_score", 0)) == 15649, "snapshot freezes admitted Ember power score")

	var slots: Dictionary = snapshot.get("resolved_skill_slots", {})
	_check(str(slots.get("skill_1", "")) == "fireball_001", "snapshot stores resolved skill-slot mapping")
	var skills: Dictionary = snapshot.get("normalized_skill_values", {})
	_check(skills.has("fireball_001"), "snapshot stores normalized resolved skill values")

	var storm: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry("storm_duelist_001")
	_check(bool(storm.get("accepted")), "Storm Duelist registry loadout is admitted")
	_check(
		str(storm.get("snapshot", {}).get("content_fingerprint", "")) != fingerprint,
		"different authoritative loadout yields different fingerprint"
	)

func _test_ruleset_and_registry_fail_closed() -> void:
	var wrong_version: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry(
		"ember_vanguard_001",
		"competitive_standard",
		2
	)
	_check(not bool(wrong_version.get("accepted")), "unsupported ruleset version fails closed")
	_check(_contains_code(wrong_version, "RULESET_RESOLUTION_FAILED"), "version mismatch emits stable resolution code")
	_check(wrong_version.get("snapshot", {}).is_empty(), "failed ruleset resolution emits no authoritative snapshot")

	var sandbox_ruleset: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry(
		"ember_vanguard_001",
		"sandbox_default",
		1
	)
	_check(not bool(sandbox_ruleset.get("accepted")), "sandbox ruleset cannot mint competitive snapshot")
	_check(
		_contains_code(sandbox_ruleset, "UNSUPPORTED_COMPETITIVE_RULESET"),
		"noncompetitive ruleset emits stable rejection code"
	)

	var unknown_character: Dictionary = CompetitiveLoadoutSnapshotBuilder.build_from_registry(
		"unknown_fighter_001"
	)
	_check(not bool(unknown_character.get("accepted")), "unknown registry character fails closed")
	_check(
		_contains_code(unknown_character, "CHARACTER_RESOLUTION_FAILED"),
		"unknown character emits stable registry-resolution code"
	)

func _test_canonical_fingerprint_ordering() -> void:
	var first := {
		"b": 2,
		"a": {
			"y": [3, 2, 1],
			"x": 1
		}
	}
	var second := {
		"a": {
			"x": 1,
			"y": [3, 2, 1]
		},
		"b": 2
	}
	var first_hash := CompetitiveLoadoutSnapshotBuilder._sha256_canonical(first)
	var second_hash := CompetitiveLoadoutSnapshotBuilder._sha256_canonical(second)
	_check(first_hash == second_hash, "dictionary insertion order does not change canonical fingerprint")

	var changed_nested: Dictionary = second.get("a", {})
	changed_nested["y"] = [3, 2, 0]
	second["a"] = changed_nested
	var changed_hash := CompetitiveLoadoutSnapshotBuilder._sha256_canonical(second)
	_check(changed_hash != first_hash, "authoritative value change changes canonical fingerprint")

func _test_presentation_only_fields_are_not_authoritative() -> void:
	var registry := SkillRegistry.new()
	var registry_errors: PackedStringArray = registry.load_default()
	_check(registry_errors.is_empty() and registry.loaded, "skill registry loads for presentation-boundary test")

	var skill := SkillDefinition.new()
	var skill_errors: PackedStringArray = registry.load_skill(
		"fireball_001",
		registry.registered_type_for_id("fireball_001"),
		skill
	)
	_check(skill_errors.is_empty() and skill.loaded, "reference skill resolves for presentation-boundary test")

	var authoritative_before: Dictionary = CompetitiveLoadoutSnapshotBuilder._normalized_skill(skill)
	var fingerprint_before := CompetitiveLoadoutSnapshotBuilder._sha256_canonical(authoritative_before)
	skill.visual = "presentation_only_changed"
	skill.impact_visual = "presentation_only_impact_changed"
	var authoritative_after_visual: Dictionary = CompetitiveLoadoutSnapshotBuilder._normalized_skill(skill)
	var fingerprint_after_visual := CompetitiveLoadoutSnapshotBuilder._sha256_canonical(authoritative_after_visual)
	_check(
		fingerprint_after_visual == fingerprint_before,
		"presentation-only visual changes do not change authority fingerprint payload"
	)

	skill.damage += 1
	var authoritative_after_damage: Dictionary = CompetitiveLoadoutSnapshotBuilder._normalized_skill(skill)
	var fingerprint_after_damage := CompetitiveLoadoutSnapshotBuilder._sha256_canonical(authoritative_after_damage)
	_check(
		fingerprint_after_damage != fingerprint_before,
		"authoritative combat-value change changes authority fingerprint payload"
	)

func _contains_code(result: Dictionary, code: String) -> bool:
	var codes: PackedStringArray = result.get("diagnostic_codes", PackedStringArray())
	return codes.has(code)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
