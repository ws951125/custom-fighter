extends SceneTree

const CharacterAnimationAssetDraft = preload("res://game/creator/character_editor/character_animation_asset_draft.gd")

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var image := Image.create(16, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color("7cc7ff"))
	var png_bytes: PackedByteArray = image.save_png_to_buffer()

	var draft := CharacterAnimationAssetDraft.new()
	var errors: PackedStringArray = draft.configure_import(
		"attack-strip.png", "image/png", "attack_1", "custom_attack_one", 16, 4, 4, 20.0
	)
	_check(errors.is_empty(), "valid animation PNG metadata configures")
	_check(draft.validate_bytes(png_bytes).is_empty(), "valid animation PNG bytes decode")
	_check(draft.frame_width() == 4, "horizontal sprite strip frame width is deterministic")

	var round_trip := CharacterAnimationAssetDraft.new()
	var round_errors: PackedStringArray = round_trip.load_from_dictionary(draft.to_dictionary())
	_check(round_errors.is_empty(), "animation asset metadata round-trips")
	_check(round_trip.semantic == "attack_1" and round_trip.animation_id == "custom_attack_one", "binding metadata round-trips")

	var unsafe_semantic: Dictionary = draft.to_dictionary()
	unsafe_semantic["semantic"] = "script_callback"
	var unsafe_semantic_draft := CharacterAnimationAssetDraft.new()
	_check(_contains(unsafe_semantic_draft.load_from_dictionary(unsafe_semantic), "required character animation semantic"), "unknown semantic fails closed")

	var unsafe_id: Dictionary = draft.to_dictionary()
	unsafe_id["animation_id"] = "../evil.gd"
	var unsafe_id_draft := CharacterAnimationAssetDraft.new()
	_check(_contains(unsafe_id_draft.load_from_dictionary(unsafe_id), "safe lowercase token"), "unsafe animation id fails closed")

	var unsafe_name: Dictionary = draft.to_dictionary()
	unsafe_name["file_name"] = "../attack.png"
	var unsafe_name_draft := CharacterAnimationAssetDraft.new()
	_check(_contains(unsafe_name_draft.load_from_dictionary(unsafe_name), "safe .png filename"), "unsafe PNG filename fails closed")

	var wrong_mime: Dictionary = draft.to_dictionary()
	wrong_mime["mime_type"] = "image/svg+xml"
	var wrong_mime_draft := CharacterAnimationAssetDraft.new()
	_check(_contains(wrong_mime_draft.load_from_dictionary(wrong_mime), "image/png"), "non-PNG MIME fails closed")

	var bad_frames: Dictionary = draft.to_dictionary()
	bad_frames["frame_count"] = 3
	var bad_frames_draft := CharacterAnimationAssetDraft.new()
	_check(_contains(bad_frames_draft.load_from_dictionary(bad_frames), "divide evenly"), "non-divisible frame strip fails closed")

	var bad_fps: Dictionary = draft.to_dictionary()
	bad_fps["fps"] = 120.0
	var bad_fps_draft := CharacterAnimationAssetDraft.new()
	_check(_contains(bad_fps_draft.load_from_dictionary(bad_fps), "fps must be between"), "out-of-range fps fails closed")

	var bad_dimensions: Dictionary = draft.to_dictionary()
	bad_dimensions["image_width"] = 32
	var bad_dimensions_draft := CharacterAnimationAssetDraft.new()
	var bad_dimension_meta_errors: PackedStringArray = bad_dimensions_draft.load_from_dictionary(bad_dimensions)
	_check(bad_dimension_meta_errors.is_empty(), "dimension metadata remains syntactically valid before byte validation")
	_check(_contains(bad_dimensions_draft.validate_bytes(png_bytes), "decoded PNG dimensions do not match metadata"), "decoded dimension mismatch fails closed")

	var garbage := PackedByteArray([1, 2, 3, 4])
	_check(_contains(draft.validate_bytes(garbage), "failed runtime decode"), "non-PNG bytes fail closed")

	var oversized := PackedByteArray()
	oversized.resize(CharacterAnimationAssetDraft.MAX_FILE_BYTES + 1)
	_check(_contains(draft.validate_bytes(oversized), "exceeds 5 MB"), "oversized PNG fails closed before decode")

	if failures == 0:
		print("CHARACTER_ANIMATION_ASSET_DRAFT_TESTS_PASSED")
		quit(0)
		return
	printerr("CHARACTER_ANIMATION_ASSET_DRAFT_TEST_FAILURES=%d" % failures)
	quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)

func _contains(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if fragment in error:
			return true
	return false
