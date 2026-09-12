extends "res://game/ai/provider/ai_vfx_provider.gd"

const AiVfxResult = preload("res://game/ai/provider/ai_vfx_result.gd")

const MAX_MOCK_FRAMES := 8
const MAX_MOCK_FRAME_DIMENSION := 128

var configured_provider_id := "mock_ai_vfx"

func _init(provider_name: String = "mock_ai_vfx") -> void:
	configured_provider_id = provider_name.strip_edges().to_lower()

func provider_id() -> String:
	return configured_provider_id

func capabilities() -> Dictionary:
	return {
		"generation_kinds": PackedStringArray(["projectile_vfx"]),
		"reference_image": true,
		"max_frame_count": MAX_MOCK_FRAMES,
		"max_frame_width": MAX_MOCK_FRAME_DIMENSION,
		"max_frame_height": MAX_MOCK_FRAME_DIMENSION,
		"network_required": false,
		"deterministic": true
	}

func generate(request: Variant) -> Variant:
	var request_id := "unknown_request"
	if request != null:
		var candidate: Variant = request.get("request_id")
		if candidate != null and not str(candidate).is_empty():
			request_id = str(candidate)
	var result := AiVfxResult.new()
	if request == null or not request.has_method("validate"):
		result.configure_error(provider_id(), request_id, "request does not satisfy the AI VFX request contract")
		return result
	var request_errors: PackedStringArray = request.call("validate")
	if not request_errors.is_empty():
		result.configure_error(provider_id(), request_id, "invalid request: %s" % " | ".join(request_errors))
		return result
	var requested_frames := int(request.get("frame_count"))
	var requested_width := int(request.get("frame_width"))
	var requested_height := int(request.get("frame_height"))
	if requested_frames > MAX_MOCK_FRAMES or requested_width > MAX_MOCK_FRAME_DIMENSION or requested_height > MAX_MOCK_FRAME_DIMENSION:
		result.configure_error(provider_id(), request_id, "request exceeds mock provider capability")
		return result
	var total_width := requested_frames * requested_width
	var image := Image.create(total_width, requested_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var prompt_text := str(request.get("prompt"))
	var seed := absi(prompt_text.hash())
	var reference_bytes: Variant = request.get("reference_png_bytes")
	if reference_bytes is PackedByteArray:
		seed += reference_bytes.size() * 17
	_draw_deterministic_strip(image, requested_frames, requested_width, requested_height, seed)
	var png_bytes: PackedByteArray = image.save_png_to_buffer()
	result.configure_success(provider_id(), request_id, png_bytes, requested_frames, float(request.get("fps")))
	return result

func _draw_deterministic_strip(image: Image, frames: int, width: int, height: int, seed: int) -> void:
	var radius := max(2, mini(width, height) / 4)
	for frame in range(frames):
		var hue := fmod(float((seed + frame * 73) % 360) / 360.0, 1.0)
		var body := Color.from_hsv(hue, 0.72, 0.95, 0.95)
		var core := Color.from_hsv(fmod(hue + 0.12, 1.0), 0.28, 1.0, 1.0)
		var center_x := frame * width + int(width / 2) + int((frame % 3) - 1)
		var center_y := int(height / 2)
		for y in range(height):
			for local_x in range(width):
				var global_x := frame * width + local_x
				var dx := global_x - center_x
				var dy := y - center_y
				var distance_sq := dx * dx + dy * dy
				if distance_sq <= radius * radius:
					image.set_pixel(global_x, y, core if distance_sq <= int(radius * radius / 3) else body)
