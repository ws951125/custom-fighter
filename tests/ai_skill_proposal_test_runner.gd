extends SceneTree

const AiSkillProposal = preload("res://game/ai/skill/ai_skill_proposal.gd")

func _init() -> void:
	var failures := PackedStringArray()
	_test_valid_proposal(failures)
	_test_confirmation_gate(failures)
	_test_invalid_ranges(failures)
	if failures.is_empty():
		print("AI_SKILL_PROPOSAL_TESTS_PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _valid_data() -> Dictionary:
	return {
		"proposal_id": "proposal_001",
		"source_request_id": "creator_ai_vfx_1",
		"skill_id": "ai_fireball_001",
		"skill_name": "AI Fireball",
		"skill_type": "projectile",
		"damage": 24,
		"mp_cost": 20,
		"cooldown": 2.2,
		"startup": 0.2,
		"active": 0.1,
		"recovery": 0.35,
		"speed": 620.0,
		"range": 920.0,
		"hitstun": 0.25,
		"knockback": 280.0,
		"hitbox_half_width": 30.0,
		"hitbox_half_depth": 0.08,
		"visual": "ai_vfx_generated",
		"impact_visual": "prototype_impact",
		"rationale": "Fast projectile with moderate damage and MP cost."
	}

func _test_valid_proposal(failures: PackedStringArray) -> void:
	var proposal := AiSkillProposal.new()
	_expect(proposal.load_from_dictionary(_valid_data()).is_empty(), "valid AI proposal should load", failures)
	_expect(not proposal.user_confirmed, "AI proposal must never auto-confirm", failures)
	_expect(not proposal.can_apply(), "unconfirmed AI proposal must not apply", failures)
	var skill := proposal.to_skill_dictionary()
	_expect(skill.get("damage") == 24 and skill.get("type") == "projectile", "skill dictionary should preserve proposal values", failures)

func _test_confirmation_gate(failures: PackedStringArray) -> void:
	var proposal := AiSkillProposal.new()
	proposal.load_from_dictionary(_valid_data())
	_expect(proposal.confirm().is_empty(), "valid proposal should allow explicit confirmation", failures)
	_expect(proposal.can_apply(), "confirmed valid proposal should be applicable", failures)
	proposal.revoke_confirmation()
	_expect(not proposal.can_apply(), "revoked confirmation must block apply", failures)

func _test_invalid_ranges(failures: PackedStringArray) -> void:
	var data := _valid_data()
	data["damage"] = 9999
	data["mp_cost"] = -1
	data["skill_type"] = "script"
	var proposal := AiSkillProposal.new()
	var errors := proposal.load_from_dictionary(data)
	_expect(_contains(errors, "damage must be between 0 and 500"), "oversized damage must fail closed", failures)
	_expect(_contains(errors, "mp_cost must be between 0 and 100"), "negative MP must fail closed", failures)
	_expect(_contains(errors, "skill_type is not supported"), "unknown skill type must fail closed", failures)
	_expect(not proposal.can_apply(), "invalid proposal must never apply", failures)

func _contains(errors: PackedStringArray, expected: String) -> bool:
	for error in errors:
		if expected in error:
			return true
	return false

func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
