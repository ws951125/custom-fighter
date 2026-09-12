extends SceneTree

const AiVfxRequest = preload("res://game/ai/provider/ai_vfx_request.gd")
const AiVfxResult = preload("res://game/ai/provider/ai_vfx_result.gd")
const AiVfxProviderRegistry = preload("res://game/ai/provider/ai_vfx_provider_registry.gd")
const MockAiVfxProvider = preload("res://game/ai/mock/mock_ai_vfx_provider.gd")
const VfxDraft = preload("res://game/creator/vfx_editor/vfx_draft.gd")

func _init() -> void:
	var failures := PackedStringArray()
	_test_valid_request_and_reference(failures)
	_test_invalid_request_fails_closed(failures)
	_test_mock_provider_generation(failures)
	_test_provider_registry_swap(failures)
	_test_malformed_result_fails_closed(failures)
	if failures.is_empty():
		print("AI_VFX_PROVIDER_TESTS_PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_valid_request_and_reference(failures: PackedStringArray) -> void:
	var request := _valid_request("req_reference_001")
	var reference := Image.create(12, 10, false, Image.FORMAT_RGBA8)
	reference.fill(Color(0.2, 0.6, 1.0, 1.0))
	var png: PackedByteArray = reference.save_png_to_buffer()
	var errors: PackedStringArray = request.set_reference_png("fighter_ref.png", "image/png", png)
	_expect(errors.is_empty(), "valid reference PNG should pass request validation", failures)
	_expect(request.has_reference(), "request should report reference presence", failures)
	_expect(request.reference_width == 12 and request.reference_height == 10, "reference dimensions should come from decoded PNG", failures)
	var serialized: Dictionary = request.to_dictionary()
	var reference_meta: Dictionary = serialized.get("reference", {})
	_expect(bool(reference_meta.get("present", false)), "serialized request should expose reference metadata", failures)
	_expect(int(reference_meta.get("byte_count", 0)) == png.size(), "serialized reference byte_count should match in-memory PNG", failures)

func _test_invalid_request_fails_closed(failures: PackedStringArray) -> void:
	var request := _valid_request("../unsafe")
	request.prompt = ""
	request.frame_count = 65
	var errors: PackedStringArray = request.validate()
	_expect(_contains(errors, "request_id must be a safe lowercase reference token"), "unsafe request id must be rejected", failures)
	_expect(_contains(errors, "prompt must not be empty"), "blank prompt must be rejected", failures)
	_expect(_contains(errors, "frame_count must be between 1 and 64"), "oversized frame count must be rejected", failures)

	var invalid_reference := _valid_request("req_bad_reference_001")
	var invalid_bytes := PackedByteArray([1, 2, 3, 4, 5])
	var reference_errors: PackedStringArray = invalid_reference.set_reference_png("bad.png", "image/png", invalid_bytes)
	_expect(_contains(reference_errors, "reference PNG bytes failed runtime decode"), "invalid reference bytes must fail closed", failures)

func _test_mock_provider_generation(failures: PackedStringArray) -> void:
	var request := _valid_request("req_mock_001")
	var provider := MockAiVfxProvider.new()
	var result: Variant = provider.generate(request)
	_expect(result != null, "mock provider should return a result object", failures)
	if result == null:
		return
	var result_errors: PackedStringArray = result.validate_against_request(request)
	_expect(result_errors.is_empty(), "mock provider result should validate against request", failures)
	_expect(str(result.get("provider_id")) == "mock_ai_vfx", "mock provider id should be preserved", failures)
	_expect(int(result.get("frame_count")) == 4, "mock provider should preserve requested frame count", failures)
	_expect(int(result.get("image_width")) == 128 and int(result.get("image_height")) == 32, "mock provider should create requested horizontal strip dimensions", failures)
	var result_png: PackedByteArray = result.get("png_bytes")
	_expect(not result_png.is_empty(), "mock provider should return PNG bytes in memory", failures)

	var draft := VfxDraft.new()
	var draft_errors: PackedStringArray = draft.load_from_dictionary(result.to_vfx_draft_dictionary())
	_expect(draft_errors.is_empty(), "mock provider output should revalidate through VfxDraft", failures)
	_expect(draft.frame_count == 4 and draft.frame_width() == 32, "VfxDraft should derive generated frame geometry", failures)

	var second: Variant = provider.generate(request)
	var second_png: PackedByteArray = second.get("png_bytes")
	_expect(result_png == second_png, "mock provider should be deterministic for the same request", failures)

func _test_provider_registry_swap(failures: PackedStringArray) -> void:
	var registry := AiVfxProviderRegistry.new()
	var first := MockAiVfxProvider.new("mock_ai_vfx")
	var second := MockAiVfxProvider.new("mock_ai_vfx_alt")
	_expect(registry.register_provider(first).is_empty(), "first provider should register", failures)
	_expect(registry.register_provider(second).is_empty(), "second provider should register without runtime changes", failures)
	_expect(registry.active_provider_id() == "mock_ai_vfx", "first provider should become active by default", failures)
	var request := _valid_request("req_swap_001")
	var first_result: Variant = registry.generate(request)
	_expect(first_result != null and str(first_result.get("provider_id")) == "mock_ai_vfx", "registry should delegate to active provider", failures)
	_expect(registry.set_active_provider("mock_ai_vfx_alt").is_empty(), "registered provider should be swappable", failures)
	var second_result: Variant = registry.generate(request)
	_expect(second_result != null and str(second_result.get("provider_id")) == "mock_ai_vfx_alt", "provider swap should change only adapter selection", failures)
	_expect(_contains(registry.set_active_provider("missing_provider"), "provider_id is not registered"), "unknown provider selection must fail closed", failures)

func _test_malformed_result_fails_closed(failures: PackedStringArray) -> void:
	var request := _valid_request("req_result_guard_001")
	var provider := MockAiVfxProvider.new()
	var result: Variant = provider.generate(request)
	result.set("image_width", int(result.get("image_width")) + 1)
	var errors: PackedStringArray = result.validate_against_request(request)
	_expect(_contains(errors, "PNG dimensions do not match metadata") or _contains(errors, "sprite-strip width does not match request"), "tampered provider metadata must be rejected", failures)

	var error_result := AiVfxResult.new()
	var configure_errors: PackedStringArray = error_result.configure_error("mock_ai_vfx", request.request_id, "generation unavailable")
	_expect(configure_errors.is_empty(), "well-formed provider error result should itself validate", failures)
	_expect(not error_result.is_usable_against_request(request), "provider error result must never be usable as VFX", failures)

func _valid_request(id: String) -> Variant:
	var request := AiVfxRequest.new()
	request.request_id = id
	request.prompt = "A compact electric projectile burst with a bright core"
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
