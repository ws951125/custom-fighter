class_name SkillDraft
extends RefCounted

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")

var skill_id := "my_projectile_001"
var skill_name := "My Projectile"
var skill_type := "projectile"
var damage := 18
var mp_cost := 25
var cooldown := 1.8
var startup := 0.22
var active := 0.08
var recovery := 0.30
var speed := 560.0
var range := 900.0
var hitstun := 0.22
var knockback := 260.0
var hitbox_half_width := 28.0
var hitbox_half_depth := 0.08
var visual := "prototype_fireball"
var impact_visual := "prototype_impact"

func reset() -> void:
	skill_id = "my_projectile_001"
	skill_name = "My Projectile"
	skill_type = "projectile"
	damage = 18
	mp_cost = 25
	cooldown = 1.8
	startup = 0.22
	active = 0.08
	recovery = 0.30
	speed = 560.0
	range = 900.0
	hitstun = 0.22
	knockback = 260.0
	hitbox_half_width = 28.0
	hitbox_half_depth = 0.08
	visual = "prototype_fireball"
	impact_visual = "prototype_impact"

func to_dictionary() -> Dictionary:
	return {
		"schema_version": SkillDefinition.CURRENT_SCHEMA_VERSION,
		"id": skill_id.strip_edges().to_lower(),
		"name": skill_name.strip_edges(),
		"type": skill_type,
		"damage": damage,
		"mp_cost": mp_cost,
		"cooldown": cooldown,
		"startup": startup,
		"active": active,
		"recovery": recovery,
		"speed": speed,
		"range": range,
		"hitstun": hitstun,
		"knockback": knockback,
		"hitbox_half_width": hitbox_half_width,
		"hitbox_half_depth": hitbox_half_depth,
		"visual": visual,
		"impact_visual": impact_visual
	}

func validate() -> PackedStringArray:
	var definition := SkillDefinition.new()
	var errors: PackedStringArray = definition.load_from_dictionary(to_dictionary())
	if not _is_safe_token(skill_id.strip_edges().to_lower()):
		errors.append("id must be a safe lowercase reference token")
	if skill_type != "projectile":
		errors.append("creator projectile draft type must remain projectile")
	return errors

func is_valid() -> bool:
	return validate().is_empty()

func _is_safe_token(value: String) -> bool:
	if value.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null
