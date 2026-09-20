extends SceneTree

const CharacterAnimationAssetDraft = preload("res://game/creator/character_editor/character_animation_asset_draft.gd")

func _init() -> void:
	var failures := PackedStringArray()
	_test_valid_strip(failures)
	_test_rejects_path_name(failures)
	_test_rejects_unknown_semantic(failures)
	_test_rejects_unsafe_animation_id(failures)
	_test_rejects_frame_shape(failures)
	_test_rejects_oversized_bytes(failures)
	_test_metadata_round_trip(failures)
	if failures.is_empty():
		print("CHARACTER_ANIMATION_ASSET_DRAFT_TESTS_PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_valid_strip(failures: PackedStringArray) -> void:
	var image := Image.create(16, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color("55aaff"))
	var png := image.save_png_to_buffer()
	var draft := CharacterAnimationAssetDraft.new()
	var errors: PackedStringArray = draft.configure_import(
		"attack_1",
		"custom_attack_one",
		"attack-strip.png",
		"image/png",
		16,
		4,
		4,
		12.0
	)
	_expect(errors.is_empty(), "valid bounded animation strip metadata should pass", failures)
	_expect(draft.frame_width() == 4, "frame width should be derived from horizontal strip", failures)
	_expect(draft.validate_bytes(png).is_empty(), "valid PNG bytes should match metadata", failures)

func _test_rejects_path_name(failures: PackedStringArray) -> void:
	var draft := CharacterAnimationAssetDraft.new()
	var errors := draft.configure_import("ready", "custom_ready", "../evil.png", "image/png", 4, 4)
	_expect(_contains(errors, "safe .png filename"), "path-like PNG name must fail closed", failures)

func _test_rejects_unknown_semantic(failures: PackedStringArray) -> void:
	var draft := CharacterAnimationAssetDraft.new()
	var errors := draft.configure_import("script", "custom_ready", "ready.png", "image/png", 4, 4)
	_expect(_contains(errors, "required character animation semantic"), "unknown semantic must fail closed", failures)

func _test_rejects_unsafe_animation_id(failures: PackedStringArray) -> void:
	var draft := CharacterAnimationAssetDraft.new()
	var errors := draft.configure_import("ready", "../evil.gd", "ready.png", "image/png", 4, 4)
	_expect(_contains(errors, "safe lowercase token"), "path-like animation id must fail closed", failures)

func _test_rejects_frame_shape(failures: PackedStringArray) -> void:
	var draft := CharacterAnimationAssetDraft.new()
	var errors := draft.configure_import("ready", "custom_ready", "ready.png", "image/png", 10, 4, 4, 12.0)
	_expect(_contains(errors, "divide evenly"), "horizontal strip width must divide across frame_count", failures)

func _test_rejects_oversized_bytes(failures: PackedStringArray) -> void:
	var draft := CharacterAnimationAssetDraft.new()
	var errors := draft.configure_import("ready", "custom_ready", "ready.png", "image/png", 4, 4)
	_expect(errors.is_empty(), "valid metadata should pass before byte-size test", failures)
	var huge := PackedByteArray()
	huge.resize(CharacterAnimationAssetDraft.MAX_FILE_BYTES + 1)
	var byte_errors := draft.validate_bytes(huge)
	_expect(_contains(byte_errors, "exceeds 5 MB"), "oversized animation PNG must fail closed before decode", failures)

func _test_metadata_round_trip(failures: PackedStringArray) -> void:
	var draft := CharacterAnimationAssetDraft.new()
	var errors := draft.configure_import("jump", "custom_jump", "jump-strip.png", "image/png", 24, 6, 4, 18.0)
	_expect(errors.is_empty(), "valid animation asset metadata should import", failures)
	var clone := CharacterAnimationAssetDraft.new()
	var reload_errors := clone.load_from_dictionary(draft.to_dictionary())
	_expect(reload_errors.is_empty(), "animation asset metadata should round-trip", failures)
	_expect(JSON.stringify(clone.to_dictionary()) == JSON.stringify(draft.to_dictionary()), "animation asset metadata round trip should be deterministic", failures)

func _contains(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if str(error).contains(fragment):
			return true
	return false

func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
