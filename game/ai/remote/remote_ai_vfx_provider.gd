extends "res://game/ai/provider/ai_vfx_provider.gd"

const RemoteAiVfxResponseCodec = preload("res://game/ai/remote/remote_ai_vfx_response_codec.gd")
const RemoteAiVfxHttpClient = preload("res://game/ai/remote/remote_ai_vfx_http_client.gd")

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
		"transport": "trusted_backend",
		"async_generation": true
	}

func generate(request: Variant) -> Variant:
	var request_id := _request_id(request)
	var result := AiVfxResult.new()
	var request_error := _validate_remote_request(request)
	if not request_error.is_empty():
		result.configure_error(provider_id(), request_id, request_error)
		return result
	result.configure_error(provider_id(), request_id, "remote AI VFX generation is asynchronous; use generate_async with a scene-tree host")
	return result

func generate_async(request: Variant, host: Node, client: Variant = null) -> Variant:
	var request_id := _request_id(request)
	var result := AiVfxResult.new()
	var request_error := _validate_remote_request(request)
	if not request_error.is_empty():
		result.configure_error(provider_id(), request_id, request_error)
		return result
	var transport: Variant = client
	if transport == null:
		transport = RemoteAiVfxHttpClient.new()
	if not transport.has_method("post_json"):
		result.configure_error(provider_id(), request_id, "remote AI VFX transport does not implement post_json")
		return result
	var codec := RemoteAiVfxResponseCodec.new()
	var payload: Dictionary = codec.request_payload(request)
	if payload.is_empty():
		result.configure_error(provider_id(), request_id, "remote AI VFX request could not be serialized")
		return result
	var response: Variant = await transport.call("post_json", host, endpoint, payload)
	if not (response is Dictionary):
		result.configure_error(provider_id(), request_id, "remote AI VFX transport returned an invalid response type")
		return result
	return codec.decode_response(provider_id(), request, response)

func _validate_remote_request(request: Variant) -> String:
	if endpoint.is_empty():
		return "remote AI VFX endpoint is not configured"
	if request == null or not request.has_method("validate"):
		return "request does not satisfy the AI VFX request contract"
	var request_errors: PackedStringArray = request.call("validate")
	if not request_errors.is_empty():
		return "invalid request: %s" % " | ".join(request_errors)
	return ""

func _request_id(request: Variant) -> String:
	if request != null:
		var candidate: Variant = request.get("request_id")
		if candidate != null and not str(candidate).is_empty():
			return str(candidate)
	return "unknown_request"
