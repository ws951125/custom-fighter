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
		"async_generation": true,
		"readiness_probe": true
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

func check_readiness(host: Node, client: Variant = null) -> Dictionary:
	if endpoint.is_empty():
		return {"ok": false, "configured": false, "error": "remote AI VFX endpoint is not configured"}
	var transport: Variant = client
	if transport == null:
		transport = RemoteAiVfxHttpClient.new()
	if not transport.has_method("get_json"):
		return {"ok": false, "configured": false, "error": "remote AI VFX transport does not implement get_json"}
	var response: Variant = await transport.call("get_json", host, _health_endpoint())
	if not (response is Dictionary):
		return {"ok": false, "configured": false, "error": "remote AI VFX readiness returned an invalid response type"}
	var data: Dictionary = response
	if not bool(data.get("ok", false)):
		return {"ok": false, "configured": false, "error": str(data.get("error", "trusted AI backend readiness check failed"))}
	var ai_value: Variant = data.get("ai", {})
	if not (ai_value is Dictionary):
		return {"ok": false, "configured": false, "error": "trusted AI backend readiness response is missing ai metadata"}
	var ai: Dictionary = ai_value
	if not ai.has("configured"):
		return {"ok": false, "configured": false, "error": "trusted AI backend readiness response is missing configured state"}
	return {
		"ok": true,
		"configured": bool(ai.get("configured", false)),
		"provider": str(ai.get("provider", "")),
		"model": str(ai.get("model", "")),
		"health_endpoint": _health_endpoint()
	}

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

func _health_endpoint() -> String:
	var scheme_index := endpoint.find("://")
	if scheme_index < 0:
		return ""
	var path_index := endpoint.find("/", scheme_index + 3)
	var origin := endpoint if path_index < 0 else endpoint.substr(0, path_index)
	return "%s/healthz" % origin

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
