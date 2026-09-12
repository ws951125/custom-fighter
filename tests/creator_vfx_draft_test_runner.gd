extends SceneTree

const VfxDraft = preload("res://game/creator/vfx_editor/vfx_draft.gd")

func _init() -> void:
	var failures := PackedStringArray()
	_test_valid_png(failures)
	_test_rejects_wrong_mime(failures)
	_test_rejects_unsafe_crop(failures)
	_test_rejects_bad_scale_and_fps(failures)
	_test_rejects_oversized_image(failures)
	if failures.is_empty():
		print("CREATOR_VFX_DRAFT_TESTS_PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_valid_png(failures: PackedStringArray) -> void:
	var draft := VfxDraft.new()
	var errors := draft.configure_import("spark.png", "image/png", 64, 32)
	_expect(errors.is_empty(), "valid PNG metadata should pass", failures)
	_expect(draft.is_valid(), "configured PNG draft should be valid", failures)
	_expect(draft.crop_width == 64 and draft.crop_height == 32, "initial crop should match image bounds", failures)

func _test_rejects_wrong_mime(failures: PackedStringArray) -> void:
	var draft := VfxDraft.new()
	var errors := draft.configure_import("payload.js", "application/javascript", 64, 64)
	_expect(_contains(errors, "only image/png is supported"), "non-PNG mime must be rejected", failures)

func _test_rejects_unsafe_crop(failures: PackedStringArray) -> void:
	var draft := VfxDraft.new()
	draft.configure_import("spark.png", "image/png", 64, 64)
	draft.crop_x = 40
	draft.crop_width = 40
	_expect(_contains(draft.validate(), "crop must stay inside image bounds"), "out-of-bounds crop must be rejected", failures)

func _test_rejects_bad_scale_and_fps(failures: PackedStringArray) -> void:
	var draft := VfxDraft.new()
	draft.configure_import("spark.png", "image/png", 64, 64)
	draft.scale = 0.01
	draft.fps = 120.0
	var errors := draft.validate()
	_expect(_contains(errors, "scale must be between 0.1 and 8.0"), "invalid scale must be rejected", failures)
	_expect(_contains(errors, "fps must be between 1 and 60"), "invalid fps must be rejected", failures)

func _test_rejects_oversized_image(failures: PackedStringArray) -> void:
	var draft := VfxDraft.new()
	var errors := draft.configure_import("huge.png", "image/png", 8192, 64)
	_expect(_contains(errors, "image_width must be between 1 and 4096"), "oversized PNG width must be rejected", failures)

func _contains(errors: PackedStringArray, text: String) -> bool:
	for error in errors:
		if str(error).contains(text):
			return true
	return false

func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
