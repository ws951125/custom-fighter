class_name AiVfxRequest
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1
const SUPPORTED_GENERATION_KIND := "projectile_vfx"
const SUPPORTED_REFERENCE_MIME := "image/png"
const MAX_PROMPT_CHARS := 800
const MAX_REFERENCE_BYTES := 5 * 1024 * 1024
const MAX_REFERENCE_DIMENSION := 4096
const MAX_FRAME_COUNT := 64
const MIN_FRAME_DIMENSION := 8
const MAX_FRAME_DIMENSION := 512
const MAX_OUTPUT_DIMENSION := 4096

var schema_version := CURRENT_SCHEMA_VERSION
var request_id := ""
var prompt := ""
var generation_kind := SUPPORTED_GENERATION_KIND
var frame_count := 4
var frame_width := 64
var frame_height := 64
var fps := 12.0
var reference_file_name := ""
var reference_mime_type := ""
var reference_width := 0
var reference_height := 0
var reference_png_bytes := PackedByteArray()

func reset() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	request_id = ""
	prompt = ""
	generation_kind = SUPPORTED_GENERATION_KIND
	frame_count = 4
	frame_width = 64
	frame_height = 64
	fps = 12.0
	clear_reference()

func set_reference_png(file_name: String, mime_type: String, png_bytes: PackedByteArray) -> PackedStringArray:
	clear_reference()
	if png_bytes.is_empty():
		return PackedStringArray(["reference PNG bytes must not be empty"])
	if png_bytes.size() > MAX_REFERENCE_BYTES:
		return PackedStringArray(["reference PNG exceeds 5 MB limit"])
	var image := Image.new()
	var decode_error: Error = image.load_png_from_buffer(png_bytes)
	if decode_error != OK:
		return PackedStringArray(["reference PNG bytes failed runtime decode"])
	reference_file_name = file_name.strip_edges()
	reference_mime_type = mime_type.strip_edges().to_lower()
	reference_width = image.get_width()
	reference_height = image.get_height()
	reference_png_bytes = png_bytes.duplicate()
	return validate()

func clear_reference() -> void:
	reference_file_name = ""
	reference_mime_type = ""
	reference_width = 0
	reference_height = 0
	reference_png_bytes.clear()

func has_reference() -> bool:
	return not reference_png_bytes.is_empty()

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"request_id": request_id,
		"prompt": prompt,
		"generation_kind": generation_kind,
		"output": {
			"frame_count": frame_count,
			"frame_width": frame_width,
			"frame_height": frame_height,
			"fps": fps
		},
		"reference": {
			"present": has_reference(),
			"file_name": reference_file_name,
			"mime_type": reference_mime_type,
			"width": reference_width,
			"height": reference_height,
			"byte_count": reference_png_bytes.size()
		}
	}

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported schema_version: %d" % schema_version)
	if not _is_safe_token(request_id):
		errors.append("request_id must be a safe lowercase reference token")
	var normalized_prompt := prompt.strip_edges()
	if normalized_prompt.is_empty():
		errors.append("prompt must not be empty")
	elif normalized_prompt.length() > MAX_PROMPT_CHARS:
		errors.append("prompt must be at most %d characters" % MAX_PROMPT_CHARS)
	if generation_kind != SUPPORTED_GENERATION_KIND:
		errors.append("unsupported generation_kind: %s" % generation_kind)
	if frame_count < 1 or frame_count > MAX_FRAME_COUNT:
		errors.append("frame_count must be between 1 and %d" % MAX_FRAME_COUNT)
	if frame_width < MIN_FRAME_DIMENSION or frame_width > MAX_FRAME_DIMENSION:
		errors.append("frame_width must be between %d and %d" % [MIN_FRAME_DIMENSION, MAX_FRAME_DIMENSION])
	if frame_height < MIN_FRAME_DIMENSION or frame_height > MAX_FRAME_DIMENSION:
		errors.append("frame_height must be between %d and %d" % [MIN_FRAME_DIMENSION, MAX_FRAME_DIMENSION])
	if frame_count > 0 and frame_width > 0 and frame_count * frame_width > MAX_OUTPUT_DIMENSION:
		errors.append("combined sprite-strip width must not exceed %d" % MAX_OUTPUT_DIMENSION)
	if fps < 1.0 or fps > 60.0:
		errors.append("fps must be between 1 and 60")
	_validate_reference(errors)
	return errors

func is_valid() -> bool:
	return validate().is_empty()

func _validate_reference(errors: PackedStringArray) -> void:
	if reference_png_bytes.is_empty():
		if not reference_file_name.is_empty() or not reference_mime_type.is_empty() or reference_width != 0 or reference_height != 0:
			errors.append("reference metadata must be empty when no reference PNG is present")
		return
	if reference_file_name.strip_edges().is_empty():
		errors.append("reference file_name must not be empty")
	if reference_mime_type != SUPPORTED_REFERENCE_MIME:
		errors.append("reference image must use image/png")
	if reference_png_bytes.size() > MAX_REFERENCE_BYTES:
		errors.append("reference PNG exceeds 5 MB limit")
		return
	var image := Image.new()
	var decode_error: Error = image.load_png_from_buffer(reference_png_bytes)
	if decode_error != OK:
		errors.append("reference PNG bytes failed runtime decode")
		return
	if image.get_width() != reference_width or image.get_height() != reference_height:
		errors.append("reference PNG dimensions do not match decoded content")
	if reference_width < 1 or reference_width > MAX_REFERENCE_DIMENSION or reference_height < 1 or reference_height > MAX_REFERENCE_DIMENSION:
		errors.append("reference PNG dimensions must stay within %d px" % MAX_REFERENCE_DIMENSION)

func _is_safe_token(value: String) -> bool:
	if value.is_empty() or value.length() > 80:
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null
