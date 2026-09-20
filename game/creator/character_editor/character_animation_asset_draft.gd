class_name CharacterAnimationAssetDraft
extends RefCounted

const CharacterAnimationMap = preload("res://game/core/character/character_animation_map.gd")

const CURRENT_SCHEMA_VERSION := 1
const SUPPORTED_MIME_TYPE := "image/png"
const MAX_FILE_BYTES := 5 * 1024 * 1024
const MAX_DIMENSION := 4096
const MAX_FRAME_COUNT := 64

var schema_version := CURRENT_SCHEMA_VERSION
var semantic := ""
var animation_id := ""
var file_name := ""
var mime_type := ""
var image_width := 0
var image_height := 0
var frame_count := 1
var fps := 12.0

func reset() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	semantic = ""
	animation_id = ""
	file_name = ""
	mime_type = ""
	image_width = 0
	image_height = 0
	frame_count = 1
	fps = 12.0

func configure_import(
	name: String,
	mime: String,
	semantic_name: String,
	animation_token: String,
	width: int,
	height: int,
	frames: int,
	fps_value: float
) -> PackedStringArray:
	schema_version = CURRENT_SCHEMA_VERSION
	file_name = name.strip_edges()
	mime_type = mime.strip_edges().to_lower()
	semantic = semantic_name.strip_edges().to_lower()
	animation_id = animation_token.strip_edges().to_lower()
	image_width = width
	image_height = height
	frame_count = frames
	fps = fps_value
	return validate()

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	reset()
	var allowed := ["schema_version", "semantic", "animation_id", "file_name", "mime_type", "image_width", "image_height", "frame_count", "fps"]
	var errors := PackedStringArray()
	for raw_key in data.keys():
		var key := str(raw_key)
		if not allowed.has(key):
			errors.append("unsupported animation asset field: %s" % key)
	for field in allowed:
		if not data.has(field):
			errors.append("missing required animation asset field: %s" % field)
	if not errors.is_empty():
		return errors

	schema_version = int(data.get("schema_version", 0))
	semantic = str(data.get("semantic", "")).strip_edges().to_lower()
	animation_id = str(data.get("animation_id", "")).strip_edges().to_lower()
	file_name = str(data.get("file_name", "")).strip_edges()
	mime_type = str(data.get("mime_type", "")).strip_edges().to_lower()
	image_width = int(data.get("image_width", 0))
	image_height = int(data.get("image_height", 0))
	frame_count = int(data.get("frame_count", 0))
	fps = float(data.get("fps", 0.0))
	errors.append_array(validate())
	return errors

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"semantic": semantic,
		"animation_id": animation_id,
		"file_name": file_name,
		"mime_type": mime_type,
		"image_width": image_width,
		"image_height": image_height,
		"frame_count": frame_count,
		"fps": fps
	}

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported animation asset schema_version: %d" % schema_version)
	if not CharacterAnimationMap.REQUIRED_SEMANTICS.has(semantic):
		errors.append("animation asset semantic must be a required character animation semantic")
	if not _is_safe_token(animation_id):
		errors.append("animation asset animation_id must be a safe lowercase token")
	if not _is_safe_png_name(file_name):
		errors.append("animation asset file_name must be a safe .png filename")
	if mime_type != SUPPORTED_MIME_TYPE:
		errors.append("animation asset only supports image/png")
	if image_width < 1 or image_width > MAX_DIMENSION:
		errors.append("animation asset image_width must be between 1 and %d" % MAX_DIMENSION)
	if image_height < 1 or image_height > MAX_DIMENSION:
		errors.append("animation asset image_height must be between 1 and %d" % MAX_DIMENSION)
	if frame_count < 1 or frame_count > MAX_FRAME_COUNT:
		errors.append("animation asset frame_count must be between 1 and %d" % MAX_FRAME_COUNT)
	elif image_width > 0 and image_width % frame_count != 0:
		errors.append("animation asset image_width must divide evenly across frame_count")
	if fps < 1.0 or fps > 60.0:
		errors.append("animation asset fps must be between 1 and 60")
	return errors

func validate_bytes(png_bytes: PackedByteArray) -> PackedStringArray:
	var errors := validate()
	if not errors.is_empty():
		return errors
	if png_bytes.is_empty():
		errors.append("animation asset PNG bytes must not be empty")
		return errors
	if png_bytes.size() > MAX_FILE_BYTES:
		errors.append("animation asset PNG exceeds 5 MB limit")
		return errors
	var image := Image.new()
	var decode_error: Error = image.load_png_from_buffer(png_bytes)
	if decode_error != OK:
		errors.append("animation asset PNG bytes failed runtime decode")
		return errors
	if image.get_width() != image_width or image.get_height() != image_height:
		errors.append("animation asset decoded PNG dimensions do not match metadata")
	return errors

func frame_width() -> int:
	if frame_count < 1 or image_width < 1 or image_width % frame_count != 0:
		return 0
	return int(image_width / frame_count)

func is_valid() -> bool:
	return validate().is_empty()

func _is_safe_token(value: String) -> bool:
	if value.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null

func _is_safe_png_name(value: String) -> bool:
	if value.is_empty() or value.length() > 96 or value.contains("/") or value.contains("\\") or value.contains(".."):
		return false
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9][A-Za-z0-9_.-]*\\.png$")
	return regex.search(value) != null
