extends SceneTree

const CharacterAudioBindings = preload("res://game/core/character/character_audio_bindings.gd")
const CharacterAudioDraft = preload("res://game/creator/character_editor/character_audio_draft.gd")

func _init() -> void:
	var failures := PackedStringArray()
	_test_defaults(failures)
	_test_custom_round_trip(failures)
	_test_rejects_unsafe_cue(failures)
	_test_rejects_missing_binding(failures)
	_test_rejects_unknown_binding(failures)
	_test_draft_fixed_vocabulary(failures)
	if failures.is_empty():
		print("CHARACTER_AUDIO_BINDINGS_TESTS_PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_defaults(failures: PackedStringArray) -> void:
	var bindings := CharacterAudioBindings.new()
	var errors: PackedStringArray = bindings.load_defaults()
	_expect(errors.is_empty(), "default audio bindings should validate", failures)
	_expect(bindings.loaded, "default audio bindings should load", failures)
	_expect(bindings.cue_for_binding("skill_cast") == "skill_cast", "default skill_cast cue should remain backwards compatible", failures)

func _test_custom_round_trip(failures: PackedStringArray) -> void:
	var data := CharacterAudioBindings.default_dictionary()
	var cues: Dictionary = data.get("cues", {})
	cues["skill_cast"] = "nova_cast"
	cues["skill_impact"] = "nova_impact"
	var bindings := CharacterAudioBindings.new()
	var errors: PackedStringArray = bindings.load_from_dictionary(data)
	_expect(errors.is_empty(), "custom safe cue bindings should validate", failures)
	_expect(bindings.cue_for_binding("skill_cast") == "nova_cast", "custom skill_cast cue should load", failures)
	var reloaded := CharacterAudioBindings.new()
	var reload_errors: PackedStringArray = reloaded.load_from_dictionary(bindings.to_dictionary())
	_expect(reload_errors.is_empty(), "serialized cue bindings should reload", failures)
	_expect(JSON.stringify(bindings.to_dictionary()) == JSON.stringify(reloaded.to_dictionary()), "audio binding round trip should be deterministic", failures)

func _test_rejects_unsafe_cue(failures: PackedStringArray) -> void:
	var data := CharacterAudioBindings.default_dictionary()
	var cues: Dictionary = data.get("cues", {})
	cues["skill_cast"] = "../payload.wav"
	var bindings := CharacterAudioBindings.new()
	var errors: PackedStringArray = bindings.load_from_dictionary(data)
	_expect(_contains(errors, "safe lowercase token"), "path-like audio cue must fail closed", failures)

func _test_rejects_missing_binding(failures: PackedStringArray) -> void:
	var data := CharacterAudioBindings.default_dictionary()
	var cues: Dictionary = data.get("cues", {})
	cues.erase("hit_received")
	var bindings := CharacterAudioBindings.new()
	var errors: PackedStringArray = bindings.load_from_dictionary(data)
	_expect(_contains(errors, "missing required audio binding: hit_received"), "missing fixed audio binding must fail closed", failures)

func _test_rejects_unknown_binding(failures: PackedStringArray) -> void:
	var data := CharacterAudioBindings.default_dictionary()
	var cues: Dictionary = data.get("cues", {})
	cues["script"] = "payload"
	var bindings := CharacterAudioBindings.new()
	var errors: PackedStringArray = bindings.load_from_dictionary(data)
	_expect(_contains(errors, "unsupported audio_bindings.cues field: script"), "unknown audio binding must fail closed", failures)

func _test_draft_fixed_vocabulary(failures: PackedStringArray) -> void:
	var draft := CharacterAudioDraft.new()
	_expect(draft.set_cue("skill_cast", "creator_cast"), "known binding should be editable", failures)
	_expect(not draft.set_cue("arbitrary_callback", "payload"), "unknown binding should not mutate draft", failures)
	_expect(draft.validate().is_empty(), "safe edited audio draft should validate", failures)
	draft.set_cue("skill_cast", "https://evil")
	_expect(_contains(draft.validate(), "safe lowercase token"), "unsafe edited cue should invalidate draft", failures)

func _contains(errors: PackedStringArray, text: String) -> bool:
	for error in errors:
		if str(error).contains(text):
			return true
	return false

func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
