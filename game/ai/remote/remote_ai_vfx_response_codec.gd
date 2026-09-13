class_name RemoteAiVfxResponseCodec
extends RefCounted

const AiVfxResult = preload("res://game/ai/provider/ai_vfx_result.gd")

func request_payload(request: Variant) -> Dictionary:
	if request == null or not request.has_method("to_dictionary"):
		return {}
	var payload: Variant = request.call("to_dictionary")
	return payload.duplicate(true) if payload is Dictionary else {}

func decode_response(provider_id: String, request: Variant, response: Dictionary) -> Variant:
	var request_id := "unknown_request"
	if request != null:
		var candidate: Variant = request.get("request_id")
		if candidate != null and not str(candidate).is_empty():
			request_id = str(candidate)
	var result := AiVfxResult.new()
	if not bool(response.get("ok", false)):
		var message := str(response.get("error", "remote AI VFX backend returned an error")).strip_edges()
		if message.is_empty():
			message = "remote AI VFX backend returned an error"
		result.configure_error(provider_id, request_id, message)
		return result
	var encoded_png := str(response.get("png_base64", ""))
	if encoded_png.is_empty():
		result.configure_error(provider_id, request_id, "remote AI VFX response is missing png_base64")
		return result
	var png_bytes: PackedByteArray = Marshalls.base64_to_raw(encoded_png)
	if png_bytes.is_empty():
		result.configure_error(provider_id, request_id, "remote AI VFX response png_base64 could not be decoded")
		return result
	var frame_count := int(response.get("frame_count", 0))
	var fps := float(response.get("fps", 0.0))
	var configure_errors: PackedStringArray = result.configure_success(provider_id, request_id, png_bytes, frame_count, fps)
	if not configure_errors.is_empty():
		var invalid := AiVfxResult.new()
		invalid.configure_error(provider_id, request_id, "invalid remote AI VFX response: %s" % " | ".join(configure_errors))
		return invalid
	if request != null and result.has_method("validate_against_request"):
		var validation_errors: PackedStringArray = result.call("validate_against_request", request)
		if not validation_errors.is_empty():
			var rejected := AiVfxResult.new()
			rejected.configure_error(provider_id, request_id, "remote AI VFX response failed validation: %s" % " | ".join(validation_errors))
			return rejected
	return result
