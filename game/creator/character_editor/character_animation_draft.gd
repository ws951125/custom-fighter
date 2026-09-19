class_name CharacterAnimationDraft
extends RefCounted

const CharacterAnimationMap = preload("res://game/core/character/character_animation_map.gd")

var map_id := "ember_vanguard"
var animations: Dictionary = {}

func _init() -> void:
	load_from_id(map_id)

func load_from_id(reference_id: String) -> PackedStringArray:
	var source := CharacterAnimationMap.new()
	var errors: PackedStringArray = source.load_from_id(reference_id)
	if not errors.is_empty():
		return errors
	map_id = source.map_id
	animations = source.animations.duplicate(true)
	return PackedStringArray()

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	var source := CharacterAnimationMap.new()
	var errors: PackedStringArray = source.load_from_dictionary(data)
	if not errors.is_empty():
		return errors
	map_id = source.map_id
	animations = source.animations.duplicate(true)
	return PackedStringArray()

func set_animation(semantic: String, animation_id: String) -> PackedStringArray:
	var normalized_semantic := semantic.strip_edges().to_lower()
	if not CharacterAnimationMap.REQUIRED_SEMANTICS.has(normalized_semantic):
		return PackedStringArray(["unsupported animation semantic: %s" % normalized_semantic])
	animations[normalized_semantic] = animation_id.strip_edges().to_lower()
	return validate()

func animation_id_for_semantic(semantic: String) -> String:
	var normalized_semantic := semantic.strip_edges().to_lower()
	return str(animations.get(normalized_semantic, ""))

func to_dictionary() -> Dictionary:
	return {
		"schema_version": CharacterAnimationMap.CURRENT_SCHEMA_VERSION,
		"id": map_id.strip_edges().to_lower(),
		"animations": animations.duplicate(true)
	}

func validate() -> PackedStringArray:
	var definition := CharacterAnimationMap.new()
	return definition.load_from_dictionary(to_dictionary())

func is_valid() -> bool:
	return validate().is_empty()
