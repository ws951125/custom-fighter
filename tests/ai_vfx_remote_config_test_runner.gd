extends SceneTree

const AiVfxProviderConfig = preload("res://game/ai/provider/ai_vfx_provider_config.gd")
const RemoteAiVfxProvider = preload("res://game/ai/remote/remote_ai_vfx_provider.gd")
const RemoteAiVfxResponseCodec = preload("res://game/ai/remote/remote_ai_vfx_response_codec.gd")
const MockAiVfxProvider = preload("res://game/ai/mock/mock_ai_vfx_provider.gd")
const AiVfxRequest = preload("res://game/ai/provider/ai_vfx_request.gd")

func _init() -> void:
	var failures := PackedStringArray()
	_test_default_config(failures)
	_test_remote_config_validation(failures)
	_test_remote_provider_boundary(failures)
	_test_remote_response_codec(failures)
	if failures.is_empty():
		print("AI_VFX_REMOTE_CONFIG_TESTS_PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_default_config(failures: PackedStringArray) -> void:
	var config := AiVfxProviderConfig.new()
	_expect(config.provider_id == "mock_ai_vfx", "default provider must remain deterministic mock", failures)
	_expect(config.validate().is_empty(), "default provider config should validate", failures)

func _test_remote_config_validation(failures: PackedStringArray) -> void:
	var missing := AiVfxProviderConfig.new()
	missing.provider_id = "remote_ai_vfx"
	_expect(_contains(missing.validate(), "requires CUSTOM_FIGHTER_AI_VFX_ENDPOINT"), "remote provider without endpoint must fail closed", failures)

	var insecure := AiVfxProviderConfig.new()
	insecure.provider_id = "remote_ai_vfx"
	insecure.remote_endpoint = "http://example.com/generate"
	_expect(_contains(insecure.validate(), "must be an https URL"), "non-HTTPS endpoint must be rejected", failures)

	var credentials := AiVfxProviderConfig.new()
	credentials.provider_id = "remote_ai_vfx"
	credentials.remote_endpoint = "https://user:secret@example.com/generate"
	_expect(_contains(credentials.validate(), "must be an https URL"), "embedded endpoint credentials must be rejected", failures)

	var valid := AiVfxProviderConfig.new()
	valid.provider_id = "remote_ai_vfx"
	valid.remote_endpoint = "https://ai.example.com/v1/vfx/generate"
	_expect(valid.validate().is_empty(), "safe HTTPS backend endpoint should validate", failures)

func _test_remote_provider_boundary(failures: PackedStringArray) -> void:
	var provider := RemoteAiVfxProvider.new("https://ai.example.com/v1/vfx/generate")
	_expect(provider.provider_id() == "remote_ai_vfx", "remote provider id should be stable", failures)
	var caps: Dictionary = provider.capabilities()
	_expect(bool(caps.get("network_required", false)), "remote provider must declare network requirement", failures)
	_expect(str(caps.get("transport", "")) == "trusted_backend", "remote provider must use trusted backend transport", failures)
	_expect(bool(caps.get("async_generation", false)), "remote provider must advertise asynchronous generation", failures)

	var request: Variant = _valid_request("req_remote_001")
	var result: Variant = provider.generate(request)
	_expect(result != null, "synchronous remote provider call must fail closed", failures)
	if result != null:
		_expect(str(result.get("status")) == "error", "synchronous remote path must never report generated content", failures)
		_expect(str(result.get("message")).contains("asynchronous"), "synchronous remote path should direct callers to generate_async", failures)

func _test_remote_response_codec(failures: PackedStringArray) -> void:
	var request: Variant = _valid_request("req_remote_codec_001")
	var mock := MockAiVfxProvider.new("remote_ai_vfx")
	var mock_result: Variant = mock.generate(request)
	_expect(mock_result != null and str(mock_result.get("status")) == "success", "fixture provider should generate a valid PNG", failures)
	if mock_result == null or str(mock_result.get("status")) != "success":
		return
	var png_bytes: PackedByteArray = mock_result.get("png_bytes")
	var codec := RemoteAiVfxResponseCodec.new()
	var proposal := {
		"proposal_id": "proposal_req_remote_codec_001",
		"source_request_id": "req_remote_codec_001",
		"skill_id": "ai_projectile_001",
		"skill_name": "AI Projectile",
		"skill_type": "projectile",
		"damage": 24, "mp_cost": 20, "cooldown": 2.0,
		"startup": 0.15, "active": 0.1, "recovery": 0.25,
		"speed": 600.0, "range": 900.0, "hitstun": 0.2, "knockback": 180.0,
		"hitbox_half_width": 24.0, "hitbox_half_depth": 0.08,
		"visual": "prototype_fireball", "impact_visual": "prototype_impact",
		"rationale": "Review before applying."
	}
	var decoded: Variant = codec.decode_response("remote_ai_vfx", request, {
		"ok": true,
		"png_base64": Marshalls.raw_to_base64(png_bytes),
		"frame_count": int(request.get("frame_count")),
		"fps": float(request.get("fps")),
		"skill_proposal": proposal
	})
	_expect(decoded != null and str(decoded.get("status")) == "success", "valid trusted-backend response should decode into a usable AI VFX result", failures)
	if decoded != null:
		var decoded_errors: PackedStringArray = decoded.call("validate_against_request", request)
		_expect(decoded_errors.is_empty(), "decoded remote result must revalidate against the original request", failures)
	var missing_proposal: Variant = codec.decode_response("remote_ai_vfx", request, {"ok": true, "png_base64": Marshalls.raw_to_base64(png_bytes), "frame_count": 4, "fps": 12.0})
	_expect(missing_proposal != null and str(missing_proposal.get("status")) == "error", "successful remote response without skill_proposal must fail closed", failures)
	var malformed: Variant = codec.decode_response("remote_ai_vfx", request, {"ok": true, "png_base64": "not-valid-png", "frame_count": 4, "fps": 12.0, "skill_proposal": proposal})
	_expect(malformed != null and str(malformed.get("status")) == "error", "malformed remote PNG data must fail closed", failures)

func _valid_request(id: String) -> Variant:
	var request := AiVfxRequest.new()
	request.request_id = id
	request.prompt = "A blue arc projectile with a bright core"
	request.generation_kind = "projectile_vfx"
	request.frame_count = 4
	request.frame_width = 32
	request.frame_height = 32
	request.fps = 12.0
	return request

func _contains(errors: PackedStringArray, text: String) -> bool:
	for error in errors:
		if str(error).contains(text):
			return true
	return false

func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
