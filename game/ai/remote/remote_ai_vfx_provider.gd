extends "res://game/ai/provider/ai_vfx_provider.gd"

var endpoint := ""

func _init(configured_endpoint: String = "") -> void:
	endpoint = configured_endpoint.strip_edges()

func provider_id() -> String:
	return "remote_ai_vfx"

func capabilities() -> Dictionary:
	return {
		"generation_kinds": PackedStringArray(["projectile_vfx"]),
		"reference_image": true,
		"max_frame_count": 64,
		"max_frame_width": 1024,
		"max_frame_height": 1024,
		"network_required": true,
		"deterministic": false,
		"transport": "trusted_backend"
	}

func generate(request: Variant) -> Variant:
	var request_id := "unknown_request"
	if request != null:
		var candidate: Variant = request.get("request_id")
		if candidate != null and not str(candidate).is_empty():
			request_id = str(candidate)
	var result := AiVfxResult.new()
	if endpoint.is_empty():
		result.configure_error(provider_id(), request_id, "remote AI VFX endpoint is not configured")
		return result
	if request == null or not request.has_method("validate"):
		result.configure_error(provider_id(), request_id, "request does not satisfy the AI VFX request contract")
		return result
	var request_errors: PackedStringArray = request.call("validate")
	if not request_errors.is_empty():
		result.configure_error(provider_id(), request_id, "invalid request: %s" % " | ".join(request_errors))
		return result
	result.configure_error(provider_id(), request_id, "remote AI VFX transport requires the asynchronous backend client implemented by the next slice")
	return result
