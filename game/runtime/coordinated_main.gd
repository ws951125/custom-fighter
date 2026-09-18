extends "res://game/runtime/main.gd"

const SkillCoordinator = preload("res://game/core/skills/skill_coordinator.gd")
const SKILL_1_OWNER := &"skill_1"
const SKILL_2_OWNER := &"skill_2"
const SKILL_3_OWNER := &"skill_3"
const SKILL_4_OWNER := &"skill_4"
const SKILL_5_OWNER := &"skill_5"
const SKILL_6_OWNER := &"skill_6"
const SKILL_7_OWNER := &"skill_7"
const SKILL_8_OWNER := &"skill_8"
const SKILL_9_OWNER := &"skill_9"
const SKILL_10_OWNER := &"skill_10"
const SKILL_11_OWNER := &"skill_11"
const SKILL_12_OWNER := &"skill_12"

var skill_coordinator := SkillCoordinator.new()

func _process(delta: float) -> void:
	# Reconcile from the previous rendered frame before the base runtime samples
	# movement/basic-attack input, then reconcile built-in skills again after they tick.
	# Child controllers still release eagerly themselves; this central pass makes ownership
	# deterministic even when browser frame ordering/hitches delay a child release callback.
	_sync_skill_claims()
	super(delta)
	_sync_skill_claims()

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

func _sync_skill_claims() -> void:
	if skill_coordinator.is_owned_by(SKILL_1_OWNER) and not fireball_cast_state.is_casting():
		skill_coordinator.release(SKILL_1_OWNER)
	if (
		skill_coordinator.is_owned_by(SKILL_2_OWNER)
		and not dash_slash_cast_state.is_casting()
		and not dash_slash_state.active
	):
		skill_coordinator.release(SKILL_2_OWNER)

	var area_controller = get_node_or_null("AreaSkillController")
	if (
		skill_coordinator.is_owned_by(SKILL_3_OWNER)
		and (
			area_controller == null
			or (
				not area_controller.cast_state.is_casting()
				and not area_controller.area_state.active
			)
		)
	):
		skill_coordinator.release(SKILL_3_OWNER)

	var formation_controller = get_node_or_null("FormationSkillController")
	if (
		skill_coordinator.is_owned_by(SKILL_4_OWNER)
		and (
			formation_controller == null
			or (
				not formation_controller.cast_state.is_casting()
				and not formation_controller.formation_state.active
			)
		)
	):
		skill_coordinator.release(SKILL_4_OWNER)

	var buff_controller = get_node_or_null("BuffSkillController")
	if (
		skill_coordinator.is_owned_by(SKILL_5_OWNER)
		and (buff_controller == null or not buff_controller.cast_state.is_casting())
	):
		skill_coordinator.release(SKILL_5_OWNER)

	var melee_controller = get_node_or_null("MeleeSkillController")
	if (
		skill_coordinator.is_owned_by(SKILL_6_OWNER)
		and (
			melee_controller == null
			or (
				not melee_controller.cast_state.is_casting()
				and not melee_controller.melee_state.active
			)
		)
	):
		skill_coordinator.release(SKILL_6_OWNER)

	var beam_controller = get_node_or_null("BeamSkillController")
	if (
		skill_coordinator.is_owned_by(SKILL_7_OWNER)
		and (
			beam_controller == null
			or (
				not beam_controller.cast_state.is_casting()
				and not beam_controller.beam_state.active
			)
		)
	):
		skill_coordinator.release(SKILL_7_OWNER)

	var trap_controller = get_node_or_null("TrapSkillController")
	if (
		skill_coordinator.is_owned_by(SKILL_8_OWNER)
		and (trap_controller == null or not trap_controller.cast_state.is_casting())
	):
		skill_coordinator.release(SKILL_8_OWNER)

	var aura_controller = get_node_or_null("AuraSkillController")
	if (
		skill_coordinator.is_owned_by(SKILL_9_OWNER)
		and (aura_controller == null or not aura_controller.cast_state.is_casting())
	):
		skill_coordinator.release(SKILL_9_OWNER)

	var teleport_controller = get_node_or_null("TeleportSkillController")
	if (
		skill_coordinator.is_owned_by(SKILL_10_OWNER)
		and (teleport_controller == null or not teleport_controller.cast_state.is_casting())
	):
		skill_coordinator.release(SKILL_10_OWNER)

	var counter_controller = get_node_or_null("CounterSkillController")
	if (
		skill_coordinator.is_owned_by(SKILL_11_OWNER)
		and (
			counter_controller == null
			or (
				not counter_controller.cast_state.is_casting()
				and not counter_controller.counter_state.active
			)
		)
	):
		skill_coordinator.release(SKILL_11_OWNER)

	var grab_controller = get_node_or_null("GrabSkillController")
	if (
		skill_coordinator.is_owned_by(SKILL_12_OWNER)
		and (
			grab_controller == null
			or (
				not grab_controller.cast_state.is_casting()
				and not grab_controller.grab_state.active
			)
		)
	):
		skill_coordinator.release(SKILL_12_OWNER)

func _any_skill_casting() -> bool:
	return skill_coordinator.is_busy()

func _set_web_state() -> void:
	super()
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.skillCoordinatorBusy='%s';" % _bool_text(skill_coordinator.is_busy()) +
		"document.documentElement.dataset.skillCoordinatorOwner='%s';" % skill_coordinator.owner_name() +
		"document.documentElement.dataset.skillCoordinatorLastClaimed='%s';" % skill_coordinator.last_claimed_owner_name() +
		"document.documentElement.dataset.skillCoordinatorLastRejected='%s';" % skill_coordinator.last_rejected_owner_name() +
		"document.documentElement.dataset.skillCoordinatorClaimCount='%d';" % skill_coordinator.claim_count() +
		"document.documentElement.dataset.skillCoordinatorRejectionCount='%d';" % skill_coordinator.rejection_count()
	)
