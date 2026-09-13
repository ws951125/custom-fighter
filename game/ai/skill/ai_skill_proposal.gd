class_name AiSkillProposal
extends RefCounted

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const ALLOWED_SKILL_TYPES := ["projectile", "melee", "area", "dash", "formation", "buff"]

var proposal_id := ""
var source_request_id := ""
var skill_id := ""
var skill_name := ""
var skill_type := "projectile"
var damage := 0
var mp_cost := 0
var cooldown := 0.0
var startup := 0.0
var active := 0.0
var recovery := 0.0
var speed := 0.0
var range := 0.0
var hitstun := 0.0
var knockback := 0.0
var hitbox_half_width := 0.0
var hitbox_half_depth := 0.0
var visual := ""
var impact_visual := ""
var rationale := ""
var user_confirmed := false

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	proposal_id = str(data.get("proposal_id", "")).strip_edges()
	source_request_id = str(data.get("source_request_id", "")).strip_edges()
	skill_id = str(data.get("skill_id", "")).strip_edges().to_lower()
	skill_name = str(data.get("skill_name", "")).strip_edges()
	skill_type = str(data.get("skill_type", "")).strip_edges().to_lower()
	damage = int(data.get("damage", 0))
	mp_cost = int(data.get("mp_cost", 0))
	cooldown = float(data.get("cooldown", 0.0))
	startup = float(data.get("startup", 0.0))
	active = float(data.get("active", 0.0))
	recovery = float(data.get("recovery", 0.0))
	speed = float(data.get("speed", 0.0))
	range = float(data.get("range", 0.0))
	hitstun = float(data.get("hitstun", 0.0))
	knockback = float(data.get("knockback", 0.0))
	hitbox_half_width = float(data.get("hitbox_half_width", 0.0))
	hitbox_half_depth = float(data.get("hitbox_half_depth", 0.0))
	visual = str(data.get("visual", "")).strip_edges()
	impact_visual = str(data.get("impact_visual", "")).strip_edges()
	rationale = str(data.get("rationale", "")).strip_edges()
	user_confirmed = false
	return validate()

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _is_safe_token(proposal_id): errors.append("proposal_id must be a safe token")
	if source_request_id.is_empty(): errors.append("source_request_id is required")
	if not _is_safe_token(skill_id): errors.append("skill_id must be a safe token")
	if skill_name.is_empty() or skill_name.length() > 80: errors.append("skill_name must be 1-80 characters")
	if not ALLOWED_SKILL_TYPES.has(skill_type): errors.append("skill_type is not supported")
	if damage < 0 or damage > 500: errors.append("damage must be between 0 and 500")
	if mp_cost < 0 or mp_cost > 100: errors.append("mp_cost must be between 0 and 100")
	if cooldown < 0.0 or cooldown > 60.0: errors.append("cooldown must be between 0 and 60")
	if startup < 0.0 or startup > 10.0: errors.append("startup must be between 0 and 10")
	if active < 0.0 or active > 10.0: errors.append("active must be between 0 and 10")
	if recovery < 0.0 or recovery > 10.0: errors.append("recovery must be between 0 and 10")
	if speed < 0.0 or speed > 5000.0: errors.append("speed must be between 0 and 5000")
	if range < 0.0 or range > 10000.0: errors.append("range must be between 0 and 10000")
	if hitstun < 0.0 or hitstun > 10.0: errors.append("hitstun must be between 0 and 10")
	if knockback < 0.0 or knockback > 5000.0: errors.append("knockback must be between 0 and 5000")
	if hitbox_half_width < 0.0 or hitbox_half_width > 1000.0: errors.append("hitbox_half_width must be between 0 and 1000")
	if hitbox_half_depth < 0.0 or hitbox_half_depth > 10.0: errors.append("hitbox_half_depth must be between 0 and 10")
	if rationale.length() > 1000: errors.append("rationale must be at most 1000 characters")
	return errors

func confirm() -> PackedStringArray:
	var errors := validate()
	if errors.is_empty(): user_confirmed = true
	return errors

func revoke_confirmation() -> void:
	user_confirmed = false

func can_apply() -> bool:
	return user_confirmed and validate().is_empty()

func to_skill_dictionary() -> Dictionary:
	return {
		"schema_version": SkillDefinition.CURRENT_SCHEMA_VERSION,
		"id": skill_id,
		"name": skill_name,
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

func _is_safe_token(value: String) -> bool:
	if value.is_empty(): return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null
