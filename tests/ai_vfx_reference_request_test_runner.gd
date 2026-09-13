extends SceneTree

const AiVfxRequest = preload("res://game/ai/provider/ai_vfx_request.gd")
const Codec = preload("res://game/ai/remote/remote_ai_vfx_response_codec.gd")

func _init() -> void:
	var failures := PackedStringArray()
	var image := Image.create_empty(20, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.8, 1.0))
	var png := image.save_png_to_buffer()
	var request := AiVfxRequest.new()
	request.request_id = "ref_payload_001"
	request.prompt = "reference projectile"
	request.frame_count = 4
	request.frame_width = 32
	request.frame_height = 24
	request.fps = 12.0
	var ref_errors: PackedStringArray = request.set_reference_png("reference.png", "image/png", png)
	_check(ref_errors.is_empty(), "valid reference should be accepted", failures)
	var payload: Dictionary = Codec.new().request_payload(request)
	_check(payload.get("frame_count") == 4, "backend payload must flatten frame_count", failures)
	_check(payload.get("frame_width") == 32, "backend payload must flatten frame_width", failures)
	_check(payload.get("reference_mime_type") == "image/png", "reference MIME must be serialized", failures)
	_check(payload.get("reference_width") == 20 and payload.get("reference_height") == 18, "reference dimensions must be serialized", failures)
	var decoded: PackedByteArray = Marshalls.base64_to_raw(str(payload.get("reference_png_base64", "")))
	_check(decoded == png, "reference bytes must round-trip through base64", failures)
	if failures.is_empty():
		print("AI_VFX_REFERENCE_REQUEST_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _check(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition: failures.append(message)
