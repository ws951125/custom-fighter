class_name CharacterDraft
extends RefCounted

const CharacterDefinition = preload("res://game/core/character/character_definition.gd")

var character_id := "my_fighter_001"
var character_name := "My Fighter"
var archetype := "balanced"
var max_hp := 100
var max_mp := 100
var move_speed := 360.0
var depth_speed := 0.72
var run_multiplier := 1.60
var guard_move_multiplier := 0.35
var visual_profile := "training_blue"
var animation_map := "ember_vanguard"
var skill_slots: Dictionary = {
	"skill_1": "fireball_001",
	"skill_2": "dash_slash_001",
	"skill_3": "arc_burst_001",
	"skill_4": "blade_rain_001",
	"skill_5": "battle_focus_001",
	"skill_6": "heavy_strike_001"
}

func reset() -> void:
	character_id = "my_fighter_001"
	character_name = "My Fighter"
	archetype = "balanced"
	max_hp = 100
	max_mp = 100
	move_speed = 360.0
	depth_speed = 0.72
	run_multiplier = 1.60
	guard_move_multiplier = 0.35
	visual_profile = "training_blue"
	animation_map = "ember_vanguard"
	skill_slots = {
		"skill_1": "fireball_001",
		"skill_2": "dash_slash_001",
		"skill_3": "arc_burst_001",
		"skill_4": "blade_rain_001",
		"skill_5": "battle_focus_001",
		"skill_6": "heavy_strike_001"
	}

func to_dictionary() -> Dictionary:
	return {
		"schema_version": CharacterDefinition.CURRENT_SCHEMA_VERSION,
		"id": character_id.strip_edges().to_lower(),
		"name": character_name.strip_edges(),
		"archetype": archetype.strip_edges().to_lower(),
		"stats": {
			"max_hp": max_hp,
			"max_mp": max_mp,
			"move_speed": move_speed,
			"depth_speed": depth_speed,
			"run_multiplier": run_multiplier,
			"guard_move_multiplier": guard_move_multiplier
		},
		"skill_slots": skill_slots.duplicate(true),
		"visual_profile": visual_profile.strip_edges().to_lower(),
		"animation_map": animation_map.strip_edges().to_lower()
	}

func validate() -> PackedStringArray:
	var definition := CharacterDefinition.new()
	return definition.load_from_dictionary(to_dictionary())

func is_valid() -> bool:
	return validate().is_empty()
