extends "res://game/runtime/main.gd"

const SkillCoordinator = preload("res://game/core/skills/skill_coordinator.gd")
const SKILL_1_OWNER := &"skill_1"
const SKILL_2_OWNER := &"skill_2"

var skill_coordinator := SkillCoordinator.new()

func _process(delta: float) -> void:
	_sync_builtin_skill_claims()
	super(delta)
	_sync_builtin_skill_claims()

func _try_cast_fireball() -> void:
	if not skill_coordinator.try_claim(SKILL_1_OWNER):
		return
	super()
	if not fireball_cast_state.is_casting():
		skill_coordinator.release(SKILL_1_OWNER)

func _try_cast_dash_slash() -> void:
	if not skill_coordinator.try_claim(SKILL_2_OWNER):
		return
	super()
	if not dash_slash_cast_state.is_casting() and not dash_slash_state.active:
		skill_coordinator.release(SKILL_2_OWNER)

func _sync_builtin_skill_claims() -> void:
	if skill_coordinator.is_owned_by(SKILL_1_OWNER) and not fireball_cast_state.is_casting():
		skill_coordinator.release(SKILL_1_OWNER)
	if (
		skill_coordinator.is_owned_by(SKILL_2_OWNER)
		and not dash_slash_cast_state.is_casting()
		and not dash_slash_state.active
	):
		skill_coordinator.release(SKILL_2_OWNER)

func _any_skill_casting() -> bool:
	return skill_coordinator.is_busy()

func _set_web_state() -> void:
	super()
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.skillCoordinatorBusy='%s';" % _bool_text(skill_coordinator.is_busy()) +
		"document.documentElement.dataset.skillCoordinatorOwner='%s';" % skill_coordinator.owner_name()
	)
