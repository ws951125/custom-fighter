extends SceneTree

const CharacterDraft = preload("res://game/creator/character_editor/character_draft.gd")
const CharacterDefinition = preload("res://game/core/character/character_definition.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var draft := CharacterDraft.new()
	_check(draft.is_valid(), "starter character draft validates")
	var data := draft.to_dictionary()
	_check(str(data.get("id", "")) == "my_fighter_001", "draft serializes id")
	_check(str(data.get("name", "")) == "My Fighter", "draft serializes display name")
	_check(int(data.get("stats", {}).get("max_hp", 0)) == 100, "draft serializes HP")
	_check(str(data.get("visual_profile", "")) == "training_blue", "draft preserves approved visual profile")
	_check(str(data.get("animation_map", "")) == "ember_vanguard", "draft preserves approved animation map")
	_check(str(data.get("skill_slots", {}).get("skill_6", "")) == "heavy_strike_001", "draft preserves full skill loadout")

	var definition := CharacterDefinition.new()
	var definition_errors := definition.load_from_dictionary(data)
	_check(definition_errors.is_empty() and definition.loaded, "draft feeds runtime CharacterDefinition contract")

	draft.character_name = ""
	var blank_name_errors := draft.validate()
	_check(_contains_error(blank_name_errors, "name must not be empty"), "blank creator name fails closed")

	draft.character_name = "Nova Smith"
	_check(draft.is_valid(), "valid creator name restores valid draft")

	draft.max_hp = 0
	var bad_hp_errors := draft.validate()
	_check(_contains_error(bad_hp_errors, "max_hp must be between 1 and 10000"), "invalid creator HP fails closed")

	draft.max_hp = 180
	draft.character_id = "../evil.gd"
	var unsafe_id_errors := draft.validate()
	_check(_contains_error(unsafe_id_errors, "id must be a safe lowercase reference token"), "unsafe creator id is rejected")

	draft.reset()
	_check(draft.is_valid(), "reset restores valid starter character")
	_check(draft.character_name == "My Fighter" and draft.max_hp == 100, "reset restores starter values")

	if failures == 0:
		print("CREATOR_CHARACTER_DRAFT_TESTS_PASSED")
		quit(0)
		return
	printerr("CREATOR_CHARACTER_DRAFT_TEST_FAILURES=%d" % failures)
	quit(1)

func _contains_error(errors: PackedStringArray, expected: String) -> bool:
	for error in errors:
		if error == expected:
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
