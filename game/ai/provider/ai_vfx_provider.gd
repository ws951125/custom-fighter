class_name AiVfxProvider
extends RefCounted

const AiVfxResult = preload("res://game/ai/provider/ai_vfx_result.gd")

func provider_id() -> String:
	return "unconfigured_provider"

func capabilities() -> Dictionary:
	return {
		"generation_kinds": PackedStringArray(),
		"reference_image": false,
		"max_frame_count": 0,
		"max_frame_width": 0,
		"max_frame_height": 0
	}

func generate(request: Variant) -> Variant:
	var result := AiVfxResult.new()
	var request_id := "unknown_request"
	if request != null:
		var candidate: Variant = request.get("request_id")
		if candidate != null and not str(candidate).is_empty():
			request_id = str(candidate)
	result.configure_error(provider_id(), request_id, "provider does not implement generate")
	return result
