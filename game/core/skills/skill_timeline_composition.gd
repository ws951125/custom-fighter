class_name SkillTimelineComposition
extends RefCounted

const SkillDefinitionScript = preload("res://game/core/skills/skill_definition.gd")

const SUPPORTED_RECIPES := ["cast_burst", "guarded_impact"]
const TIME_EPSILON := 0.0001

func append_recipe(
	existing_events: Array[Dictionary],
	recipe_id: String,
	start_time: float,
	id_prefix: String,
	visual: String,
	impact_visual: String
) -> Dictionary:
	var errors := PackedStringArray()
	var normalized_recipe := recipe_id.strip_edges().to_lower()
	var normalized_prefix := id_prefix.strip_edges().to_lower()
	var normalized_visual := visual.strip_edges().to_lower()
	var normalized_impact := impact_visual.strip_edges().to_lower()

	if not SUPPORTED_RECIPES.has(normalized_recipe):
		errors.append("unsupported timeline composition recipe: %s" % normalized_recipe)
	if start_time < 0.0 or start_time > SkillDefinitionScript.MAX_TIMELINE_SECONDS:
		errors.append("timeline composition start_time must be within the safe timeline range")
	if not _is_safe_token(normalized_prefix):
		errors.append("timeline composition id_prefix must be a safe lowercase token")
	if not _is_safe_token(normalized_visual):
		errors.append("timeline composition visual must be a safe lowercase token")
	if not _is_safe_token(normalized_impact):
		errors.append("timeline composition impact_visual must be a safe lowercase token")

	var last_start_time := -1.0
	var seen_ids := {}
	for event in existing_events:
		var event_id := str(event.get("id", ""))
		if not event_id.is_empty():
			seen_ids[event_id] = true
		last_start_time = maxf(last_start_time, float(event.get("time", -1.0)))
	if last_start_time >= 0.0 and start_time + TIME_EPSILON < last_start_time:
		errors.append("timeline composition must not start before the existing timeline tail")

	if not errors.is_empty():
		return {"events": _copy_events(existing_events), "added_count": 0, "end_time": start_time, "errors": errors}

	var recipe_events := _recipe_events(normalized_recipe, start_time, normalized_prefix, normalized_visual, normalized_impact)
	if existing_events.size() + recipe_events.size() > SkillDefinitionScript.MAX_TIMELINE_EVENTS:
		errors.append("timeline composition would exceed maximum event count: %d" % SkillDefinitionScript.MAX_TIMELINE_EVENTS)

	var end_time := start_time
	for event in recipe_events:
		var event_id := str(event.get("id", ""))
		if seen_ids.has(event_id):
			errors.append("timeline composition event id already exists: %s" % event_id)
		seen_ids[event_id] = true
		end_time = maxf(end_time, float(event.get("time", 0.0)) + float(event.get("duration", 0.0)))
	if end_time > SkillDefinitionScript.MAX_TIMELINE_SECONDS + TIME_EPSILON:
		errors.append("timeline composition would exceed maximum timeline duration")

	if not errors.is_empty():
		return {"events": _copy_events(existing_events), "added_count": 0, "end_time": start_time, "errors": errors}

	var combined := _copy_events(existing_events)
	for event in recipe_events:
		combined.append(event.duplicate(true))
	return {
		"events": combined,
		"added_count": recipe_events.size(),
		"end_time": end_time,
		"errors": errors
	}

func _recipe_events(recipe_id: String, start_time: float, id_prefix: String, visual: String, impact_visual: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if recipe_id == "cast_burst":
		events.append({"id": "%s_anim" % id_prefix, "type": "animation", "time": start_time, "duration": 0.60, "animation": "skill_2"})
		events.append({"id": "%s_vfx" % id_prefix, "type": "vfx", "time": start_time + 0.10, "duration": 0.45, "visual": visual})
		events.append({"id": "%s_audio" % id_prefix, "type": "audio", "time": start_time + 0.15, "duration": 0.0, "cue": SkillDefinitionScript.DEFAULT_TIMELINE_AUDIO_CUE})
		events.append({
			"id": "%s_hitbox" % id_prefix,
			"type": "hitbox",
			"time": start_time + 0.25,
			"duration": 0.25,
			"half_width": 32.0,
			"half_depth": 0.10,
			"offset_x": 20.0,
			"offset_depth": 0.0
		})
	elif recipe_id == "guarded_impact":
		events.append({"id": "%s_anim" % id_prefix, "type": "animation", "time": start_time, "duration": 1.20, "animation": "skill_3"})
		events.append({"id": "%s_vfx" % id_prefix, "type": "vfx", "time": start_time + 0.10, "duration": 1.00, "visual": impact_visual})
		events.append({
			"id": "%s_hitbox" % id_prefix,
			"type": "hitbox",
			"time": start_time + 0.20,
			"duration": 0.90,
			"half_width": 40.0,
			"half_depth": 0.12,
			"offset_x": 24.0,
			"offset_depth": -0.02
		})
		events.append({"id": "%s_audio" % id_prefix, "type": "audio", "time": start_time + 0.30, "duration": 0.0, "cue": SkillDefinitionScript.DEFAULT_TIMELINE_AUDIO_CUE})
		events.append({
			"id": "%s_hurtbox" % id_prefix,
			"type": "hurtbox",
			"time": start_time + 0.40,
			"duration": 0.70,
			"half_width": 22.0,
			"half_depth": 0.09,
			"offset_x": -6.0,
			"offset_depth": 0.03
		})
	return events

func _copy_events(events: Array[Dictionary]) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for event in events:
		copied.append(event.duplicate(true))
	return copied

func _is_safe_token(value: String) -> bool:
	if value.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null
