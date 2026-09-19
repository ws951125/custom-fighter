class_name CharacterAudioDraft
extends RefCounted

const CharacterAudioBindings = preload("res://game/core/character/character_audio_bindings.gd")

var cues: Dictionary = CharacterAudioBindings.DEFAULT_CUES.duplicate(true)

func reset() -> void:
	cues = CharacterAudioBindings.DEFAULT_CUES.duplicate(true)

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	var bindings := CharacterAudioBindings.new()
	var errors: PackedStringArray = bindings.load_from_dictionary(data)
	if not errors.is_empty():
		return errors
	cues = bindings.cues.duplicate(true)
	return PackedStringArray()

func to_dictionary() -> Dictionary:
	var canonical: Dictionary = {}
	for binding in CharacterAudioBindings.REQUIRED_BINDINGS:
		canonical[binding] = str(cues.get(binding, "")).strip_edges().to_lower()
	return {
		"schema_version": CharacterAudioBindings.CURRENT_SCHEMA_VERSION,
		"cues": canonical
	}

func set_cue(binding: String, cue: String) -> bool:
	var normalized_binding := binding.strip_edges().to_lower()
	if not CharacterAudioBindings.REQUIRED_BINDINGS.has(normalized_binding):
		return false
	cues[normalized_binding] = cue.strip_edges().to_lower()
	return true

func cue_for_binding(binding: String) -> String:
	var normalized_binding := binding.strip_edges().to_lower()
	if not CharacterAudioBindings.REQUIRED_BINDINGS.has(normalized_binding):
		return ""
	return str(cues.get(normalized_binding, ""))

func validate() -> PackedStringArray:
	var bindings := CharacterAudioBindings.new()
	return bindings.load_from_dictionary(to_dictionary())

func is_valid() -> bool:
	return validate().is_empty()
