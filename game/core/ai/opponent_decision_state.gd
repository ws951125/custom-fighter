class_name OpponentDecisionState
extends RefCounted

const OpponentBehaviorProfile = preload("res://game/core/ai/opponent_behavior_profile.gd")

const ALLOWED_SNAPSHOT_FIELDS := [
	"decision_tick",
	"opponent_x",
	"opponent_depth",
	"player_x",
	"player_depth",
	"opponent_actionable",
	"guard_ready",
	"threatened",
	"basic_attack_ready",
	"ready_skill_slots"
]
const REQUIRED_SNAPSHOT_FIELDS := ALLOWED_SNAPSHOT_FIELDS

func decide(profile, snapshot: Dictionary) -> Dictionary:
	if not decision_errors(profile, snapshot).is_empty():
		return idle_intent()
	if not bool(snapshot.get("opponent_actionable", false)):
		return idle_intent()

	var opponent_x := float(snapshot.get("opponent_x", 0.0))
	var opponent_depth := float(snapshot.get("opponent_depth", 0.0))
	var player_x := float(snapshot.get("player_x", 0.0))
	var player_depth := float(snapshot.get("player_depth", 0.0))
	var horizontal_delta := player_x - opponent_x
	var depth_delta := player_depth - opponent_depth
	var horizontal_distance := absf(horizontal_delta)

	if bool(snapshot.get("threatened", false)) and bool(snapshot.get("guard_ready", false)) and profile.guard_policy == "when_threatened":
		return _guard_intent()

	if absf(depth_delta) > profile.depth_tolerance:
		return _movement_intent(0.0, _sign_axis(depth_delta))

	if horizontal_distance > profile.preferred_max_distance:
		return _movement_intent(_sign_axis(horizontal_delta), 0.0)

	if horizontal_distance < profile.preferred_min_distance:
		return _movement_intent(-_sign_axis(horizontal_delta), 0.0)

	var ready_skill_slots: Array = snapshot.get("ready_skill_slots", [])
	if not profile.preferred_skill_slot.is_empty() and ready_skill_slots.has(profile.preferred_skill_slot):
		return _skill_intent(profile.preferred_skill_slot)

	if profile.allow_basic_attack and bool(snapshot.get("basic_attack_ready", false)) and horizontal_distance <= profile.basic_attack_range:
		return _basic_attack_intent()

	return idle_intent()

func decision_errors(profile, snapshot: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if profile == null or not profile.loaded:
		errors.append("opponent behavior profile must be loaded")
		return errors

	for raw_key in snapshot.keys():
		var key := str(raw_key)
		if not ALLOWED_SNAPSHOT_FIELDS.has(key):
			errors.append("unsupported opponent decision snapshot field: %s" % key)
	for field in REQUIRED_SNAPSHOT_FIELDS:
		if not snapshot.has(field):
			errors.append("missing opponent decision snapshot field: %s" % field)
	if not errors.is_empty():
		return errors

	if typeof(snapshot.get("decision_tick")) != TYPE_INT or int(snapshot.get("decision_tick", -1)) < 0:
		errors.append("decision_tick must be a non-negative integer")
	for field in ["opponent_x", "opponent_depth", "player_x", "player_depth"]:
		var value = snapshot.get(field)
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			errors.append("%s must be numeric" % field)
	for field in ["opponent_actionable", "guard_ready", "threatened", "basic_attack_ready"]:
		if typeof(snapshot.get(field)) != TYPE_BOOL:
			errors.append("%s must be a boolean" % field)

	if not errors.is_empty():
		return errors

	var opponent_x := float(snapshot.get("opponent_x", 0.0))
	var player_x := float(snapshot.get("player_x", 0.0))
	var opponent_depth := float(snapshot.get("opponent_depth", 0.0))
	var player_depth := float(snapshot.get("player_depth", 0.0))
	if absf(opponent_x) > 100000.0 or absf(player_x) > 100000.0:
		errors.append("opponent/player x must stay inside bounded world coordinates")
	if opponent_depth < 0.0 or opponent_depth > 1.0 or player_depth < 0.0 or player_depth > 1.0:
		errors.append("opponent/player depth must be between 0 and 1")

	var raw_ready_slots = snapshot.get("ready_skill_slots")
	if typeof(raw_ready_slots) != TYPE_ARRAY:
		errors.append("ready_skill_slots must be an array")
		return errors
	var ready_slots: Array = raw_ready_slots
	if ready_slots.size() > OpponentBehaviorProfile.SUPPORTED_SKILL_SLOTS.size():
		errors.append("ready_skill_slots exceeds supported slot count")
		return errors
	var seen := {}
	for raw_slot in ready_slots:
		if typeof(raw_slot) != TYPE_STRING:
			errors.append("ready_skill_slots entries must be strings")
			continue
		var slot := str(raw_slot).strip_edges().to_lower()
		if not OpponentBehaviorProfile.SUPPORTED_SKILL_SLOTS.has(slot):
			errors.append("unsupported ready skill slot: %s" % slot)
		elif seen.has(slot):
			errors.append("duplicate ready skill slot: %s" % slot)
		else:
			seen[slot] = true
	return errors

func idle_intent() -> Dictionary:
	return {
		"move_x": 0.0,
		"move_depth": 0.0,
		"guard": false,
		"basic_attack": false,
		"skill_slot": "",
		"idle": true
	}

func _movement_intent(move_x: float, move_depth: float) -> Dictionary:
	var intent := idle_intent()
	intent["move_x"] = clampf(move_x, -1.0, 1.0)
	intent["move_depth"] = clampf(move_depth, -1.0, 1.0)
	intent["idle"] = false
	return intent

func _guard_intent() -> Dictionary:
	var intent := idle_intent()
	intent["guard"] = true
	intent["idle"] = false
	return intent

func _basic_attack_intent() -> Dictionary:
	var intent := idle_intent()
	intent["basic_attack"] = true
	intent["idle"] = false
	return intent

func _skill_intent(skill_slot: String) -> Dictionary:
	var intent := idle_intent()
	intent["skill_slot"] = skill_slot
	intent["idle"] = false
	return intent

func _sign_axis(value: float) -> float:
	if value > 0.0:
		return 1.0
	if value < 0.0:
		return -1.0
	return 0.0
