extends SceneTree

const CharacterAnimationDraft = preload("res://game/creator/character_editor/character_animation_draft.gd")
const CharacterAnimationMap = preload("res://game/core/character/character_animation_map.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var draft := CharacterAnimationDraft.new()
	_check(draft.is_valid(), "starter animation draft validates")
	_check(draft.map_id == "ember_vanguard", "starter animation draft loads Ember map")
	_check(draft.animation_id_for_semantic("ready") == "ember_ready", "starter ready semantic loads")

	var set_errors: PackedStringArray = draft.set_animation("attack_1", "custom_attack_one")
	_check(set_errors.is_empty(), "safe semantic animation token is accepted")
	_check(draft.animation_id_for_semantic("attack_1") == "custom_attack_one", "authored semantic value is retained")

	var serialized := draft.to_dictionary()
	var runtime := CharacterAnimationMap.new()
	var runtime_errors: PackedStringArray = runtime.load_from_dictionary(serialized)
	_check(runtime_errors.is_empty() and runtime.loaded, "animation draft feeds runtime animation-map contract")
	_check(runtime.animation_id_for_semantic("attack_1") == "custom_attack_one", "runtime receives authored semantic mapping")

	var invalid_semantic_errors: PackedStringArray = draft.set_animation("script", "evil")
	_check(_contains_fragment(invalid_semantic_errors, "unsupported animation semantic"), "unknown semantic fails closed")

	var invalid_token_errors: PackedStringArray = draft.set_animation("attack_1", "../evil.gd")
	_check(_contains_fragment(invalid_token_errors, "safe lowercase token"), "path-like animation token fails closed")
	_check(not draft.is_valid(), "invalid authored token leaves draft invalid for explicit correction")

	var restore_errors: PackedStringArray = draft.load_from_id("storm_duelist")
	_check(restore_errors.is_empty() and draft.is_valid(), "trusted Storm map restores draft")
	_check(draft.map_id == "storm_duelist", "Storm map id is restored")
	_check(draft.animation_id_for_semantic("attack_1") == "storm_attack_1", "Storm semantic values are restored")

	var bad_map := draft.to_dictionary()
	bad_map["script"] = "res://evil.gd"
	var bad_map_errors: PackedStringArray = draft.load_from_dictionary(bad_map)
	_check(_contains_fragment(bad_map_errors, "unsupported animation_map field: script"), "executable-style field is rejected")

	if failures == 0:
		print("CREATOR_CHARACTER_ANIMATION_DRAFT_TESTS_PASSED")
		quit(0)
		return
	printerr("CREATOR_CHARACTER_ANIMATION_DRAFT_TEST_FAILURES=%d" % failures)
	quit(1)

func _contains_fragment(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
