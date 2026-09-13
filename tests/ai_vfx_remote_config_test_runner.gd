extends SceneTree

const AiVfxProviderConfig = preload("res://game/ai/provider/ai_vfx_provider_config.gd")
const RemoteAiVfxProvider = preload("res://game/ai/remote/remote_ai_vfx_provider.gd")
const AiVfxRequest = preload("res://game/ai/provider/ai_vfx_request.gd")

func _init() -> void:
	var failures := PackedStringArray()
	_test_default_config(failures)
	_test_remote_config_validation(failures)
	_test_remote_provider_boundary(failures)
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

	var request := AiVfxRequest.new()
	request.request_id = "req_remote_001"
	request.prompt = "A blue arc projectile with a bright core"
	request.generation_kind = "projectile_vfx"
	request.frame_count = 4
	request.frame_width = 32
	request.frame_height = 32
	request.fps = 12.0
	var result: Variant = provider.generate(request)
	_expect(result != null, "remote provider must return a fail-closed result until async transport is wired", failures)
	if result != null:
		_expect(str(result.get("status")) == "error", "unfinished transport must never report generated content", failures)
		_expect(str(result.get("provider_id")) == "remote_ai_vfx", "remote provider error must preserve provider id", failures)

func _contains(errors: PackedStringArray, text: String) -> bool:
	for error in errors:
		if str(error).contains(text):
			return true
	return false

func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
