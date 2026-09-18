extends SceneTree

const SkillDefinition = preload("res://game/core/skills/skill_definition.gd")
const SkillTimelineRuntime = preload("res://game/core/skills/skill_timeline_runtime.gd")
const SkillTimelineComposition = preload("res://game/core/skills/skill_timeline_composition.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_supported_recipes_expand_to_existing_vocabulary()
	_test_fail_closed_bounds_and_append_policy()
	_test_composed_events_run_through_existing_runtime()
	if failures == 0:
		print("SKILL_TIMELINE_COMPOSITION_TESTS_PASSED")
		quit(0)
		return
	printerr("SKILL_TIMELINE_COMPOSITION_TEST_FAILURES=%d" % failures)
	quit(1)

func _test_supported_recipes_expand_to_existing_vocabulary() -> void:
	var builder := SkillTimelineComposition.new()
	_check(SkillTimelineComposition.SUPPORTED_RECIPES == ["cast_burst", "guarded_impact"], "composition recipes are explicit allow-list")

	var cast_result := builder.append_recipe([], "cast_burst", 0.0, "cast_burst_01", "prototype_fireball", "prototype_impact")
	_check(_errors(cast_result).is_empty(), "cast_burst expands")
	_check(int(cast_result.get("added_count", 0)) == 4, "cast_burst adds four events")
	var cast_events := _events(cast_result)
	_check(_types(cast_events) == ["animation", "vfx", "audio", "hitbox"], "cast_burst uses only approved existing event vocabulary")
	_check(_all_ids_safe(cast_events), "cast_burst emits safe deterministic ids")

	var guarded_result := builder.append_recipe([], "guarded_impact", 0.0, "guarded_impact_01", "prototype_fireball", "prototype_impact")
	_check(_errors(guarded_result).is_empty(), "guarded_impact expands")
	_check(int(guarded_result.get("added_count", 0)) == 5, "guarded_impact adds five events")
	var guarded_events := _events(guarded_result)
	_check(_types(guarded_events) == ["animation", "vfx", "hitbox", "audio", "hurtbox"], "guarded_impact uses only approved existing event vocabulary")
	_check(str(guarded_events[0].get("animation", "")) == "skill_3", "guarded composition animation is declarative token")
	_check(str(guarded_events[1].get("visual", "")) == "prototype_impact", "guarded composition reuses approved impact visual token")
	_check(is_equal_approx(float(guarded_events[2].get("half_width", 0.0)), 40.0), "guarded composition has bounded hitbox payload")
	_check(is_equal_approx(float(guarded_events[4].get("half_depth", 0.0)), 0.09), "guarded composition has bounded hurtbox payload")

func _test_fail_closed_bounds_and_append_policy() -> void:
	var builder := SkillTimelineComposition.new()
	var unknown := builder.append_recipe([], "script", 0.0, "script_01", "prototype_fireball", "prototype_impact")
	_check(_contains(_errors(unknown), "unsupported timeline composition recipe"), "unknown recipe fails closed")
	_check(_events(unknown).is_empty(), "unknown recipe does not mutate timeline")

	var unsafe_prefix := builder.append_recipe([], "cast_burst", 0.0, "../evil", "prototype_fireball", "prototype_impact")
	_check(_contains(_errors(unsafe_prefix), "id_prefix must be a safe lowercase token"), "unsafe composition prefix fails closed")

	var unsafe_visual := builder.append_recipe([], "cast_burst", 0.0, "cast_burst_01", "https://evil", "prototype_impact")
	_check(_contains(_errors(unsafe_visual), "visual must be a safe lowercase token"), "unsafe composition visual fails closed")

	var existing: Array[Dictionary] = [
		{"id": "existing_audio", "type": "audio", "time": 1.0, "duration": 0.0, "cue": "skill_cast"}
	]
	var backwards := builder.append_recipe(existing, "cast_burst", 0.5, "cast_burst_01", "prototype_fireball", "prototype_impact")
	_check(_contains(_errors(backwards), "must not start before the existing timeline tail"), "composition cannot silently reorder existing timeline")
	_check(_events(backwards).size() == 1, "backwards composition leaves existing timeline unchanged")

	var duplicate_existing: Array[Dictionary] = [
		{"id": "cast_burst_01_anim", "type": "animation", "time": 0.0, "duration": 0.1, "animation": "skill_1"}
	]
	var duplicate := builder.append_recipe(duplicate_existing, "cast_burst", 0.0, "cast_burst_01", "prototype_fireball", "prototype_impact")
	_check(_contains(_errors(duplicate), "event id already exists"), "composition duplicate ids fail closed")
	_check(_events(duplicate).size() == 1, "duplicate composition leaves existing timeline unchanged")

	var near_limit: Array[Dictionary] = []
	for index in range(61):
		near_limit.append({"id": "existing_%02d" % index, "type": "audio", "time": 0.0, "duration": 0.0, "cue": "skill_cast"})
	var overflow := builder.append_recipe(near_limit, "cast_burst", 0.0, "cast_burst_01", "prototype_fireball", "prototype_impact")
	_check(_contains(_errors(overflow), "exceed maximum event count"), "composition event-count overflow fails closed")
	_check(_events(overflow).size() == 61, "event-count failure leaves existing timeline unchanged")

	var too_late := builder.append_recipe([], "guarded_impact", 29.0, "guarded_impact_01", "prototype_fireball", "prototype_impact")
	_check(_contains(_errors(too_late), "exceed maximum timeline duration"), "composition beyond 30-second cap fails closed")

func _test_composed_events_run_through_existing_runtime() -> void:
	var builder := SkillTimelineComposition.new()
	var result := builder.append_recipe([], "guarded_impact", 0.0, "guarded_impact_01", "prototype_fireball", "prototype_impact")
	var composed_events := _events(result)
	var data := {
		"schema_version": 1,
		"id": "composition_runtime_001",
		"name": "Composition Runtime",
		"type": "projectile",
		"damage": 10,
		"mp_cost": 5,
		"cooldown": 1.0,
		"startup": 0.1,
		"active": 0.2,
		"recovery": 0.2,
		"speed": 700.0,
		"range": 900.0,
		"hitstun": 0.1,
		"knockback": 80.0,
		"hitbox_half_width": 24.0,
		"hitbox_half_depth": 0.08,
		"visual": "prototype_fireball",
		"impact_visual": "prototype_impact",
		"timeline": {
			"schema_version": SkillDefinition.TIMELINE_SCHEMA_VERSION,
			"events": composed_events
		}
	}
	var skill := SkillDefinition.new()
	var errors: PackedStringArray = skill.load_from_dictionary(data)
	_check(errors.is_empty() and skill.loaded, "composed events validate through SkillDefinition: %s" % " | ".join(errors))
	_check(skill.timeline_events.size() == 5, "composition persists as ordinary timeline events only")

	var runtime := SkillTimelineRuntime.new()
	runtime.configure(skill)
	_check(runtime.start(), "existing SkillTimelineRuntime starts composed timeline")
	var initial_transitions := runtime.consume_transitions()
	_check(initial_transitions.size() == 1 and str(initial_transitions[0].get("event", {}).get("type", "")) == "animation", "composition begins with deterministic animation transition")

	runtime.tick(0.45)
	var transitions := runtime.consume_transitions()
	var transition_types: Array[String] = []
	for transition in transitions:
		var event: Dictionary = transition.get("event", {})
		transition_types.append(str(event.get("type", "")))
	_check(transition_types.has("vfx") and transition_types.has("hitbox") and transition_types.has("audio") and transition_types.has("hurtbox"), "existing runtime emits all composed event starts")
	_check(runtime.active_events("animation").size() == 1, "composed animation is active")
	_check(runtime.active_events("vfx").size() == 1, "composed VFX is active")
	_check(runtime.active_events("hitbox").size() == 1, "composed hitbox is active")
	_check(runtime.active_events("hurtbox").size() == 1, "composed hurtbox is active")
	_check(runtime.active_events("script").is_empty(), "composition cannot create executable script events")

	runtime.tick(1.0)
	runtime.consume_transitions()
	_check(not runtime.is_running(), "composed timeline finishes deterministically")
	_check(runtime.active_events().is_empty(), "composed timeline leaves no active events after completion")

func _events(result: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var raw: Variant = result.get("events", [])
	if raw is Array:
		for value in raw:
			if value is Dictionary:
				events.append(value)
	return events

func _errors(result: Dictionary) -> PackedStringArray:
	var raw: Variant = result.get("errors", PackedStringArray())
	if raw is PackedStringArray:
		return raw
	return PackedStringArray(["invalid composition result errors payload"])

func _types(events: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for event in events:
		result.append(str(event.get("type", "")))
	return result

func _all_ids_safe(events: Array[Dictionary]) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	for event in events:
		if regex.search(str(event.get("id", ""))) == null:
			return false
	return true

func _contains(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if str(error).contains(fragment):
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % label)
