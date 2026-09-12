class_name VfxDraft
extends RefCounted

const CURRENT_SCHEMA_VERSION := 1
const SUPPORTED_MIME_TYPE := "image/png"
const MAX_DIMENSION := 4096
const MAX_FRAME_COUNT := 64

var schema_version := CURRENT_SCHEMA_VERSION
var file_name := ""
var mime_type := ""
var image_width := 0
var image_height := 0
var frame_count := 1
var crop_x := 0
var crop_y := 0
var crop_width := 0
var crop_height := 0
var scale := 1.0
var offset_x := 0.0
var offset_y := 0.0
var fps := 12.0

func reset() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	file_name = ""
	mime_type = ""
	image_width = 0
	image_height = 0
	frame_count = 1
	crop_x = 0
	crop_y = 0
	crop_width = 0
	crop_height = 0
	scale = 1.0
	offset_x = 0.0
	offset_y = 0.0
	fps = 12.0

func configure_import(name: String, mime: String, width: int, height: int) -> PackedStringArray:
	file_name = name.strip_edges()
	mime_type = mime.strip_edges().to_lower()
	image_width = width
	image_height = height
	frame_count = 1
	crop_x = 0
	crop_y = 0
	crop_width = max(width, 0)
	crop_height = max(height, 0)
	return validate()

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	reset()
	var shape_errors := PackedStringArray()

	schema_version = int(data.get("schema_version", 0))
	file_name = str(data.get("file_name", "")).strip_edges()
	mime_type = str(data.get("mime_type", "")).strip_edges().to_lower()
	image_width = int(data.get("image_width", 0))
	image_height = int(data.get("image_height", 0))
	frame_count = int(data.get("frame_count", 1))
	scale = float(data.get("scale", 1.0))
	fps = float(data.get("fps", 12.0))

	var crop_value: Variant = data.get("crop", {})
	if crop_value is Dictionary:
		var crop: Dictionary = crop_value
		crop_x = int(crop.get("x", 0))
		crop_y = int(crop.get("y", 0))
		crop_width = int(crop.get("width", 0))
		crop_height = int(crop.get("height", 0))
	else:
		shape_errors.append("crop must be an object")

	var offset_value: Variant = data.get("offset", {})
	if offset_value is Dictionary:
		var offset: Dictionary = offset_value
		offset_x = float(offset.get("x", 0.0))
		offset_y = float(offset.get("y", 0.0))
	else:
		shape_errors.append("offset must be an object")

	var validation_errors := validate()
	shape_errors.append_array(validation_errors)
	return shape_errors

func frame_width() -> int:
	if frame_count < 1 or crop_width < 1:
		return 0
	if crop_width % frame_count != 0:
		return 0
	return int(crop_width / frame_count)

func frame_height() -> int:
	return crop_height if crop_height > 0 else 0

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"file_name": file_name,
		"mime_type": mime_type,
		"image_width": image_width,
		"image_height": image_height,
		"frame_count": frame_count,
		"crop": {
			"x": crop_x,
			"y": crop_y,
			"width": crop_width,
			"height": crop_height
		},
		"scale": scale,
		"offset": {
			"x": offset_x,
			"y": offset_y
		},
		"fps": fps
	}

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported schema_version: %d" % schema_version)
	if file_name.is_empty():
		errors.append("file_name must not be empty")
	if mime_type != SUPPORTED_MIME_TYPE:
		errors.append("only image/png is supported")
	if image_width < 1 or image_width > MAX_DIMENSION:
		errors.append("image_width must be between 1 and %d" % MAX_DIMENSION)
	if image_height < 1 or image_height > MAX_DIMENSION:
		errors.append("image_height must be between 1 and %d" % MAX_DIMENSION)
	if frame_count < 1 or frame_count > MAX_FRAME_COUNT:
		errors.append("frame_count must be between 1 and %d" % MAX_FRAME_COUNT)
	if crop_x < 0 or crop_y < 0:
		errors.append("crop origin must be non-negative")
	if crop_width < 1 or crop_height < 1:
		errors.append("crop size must be positive")
	if crop_x + crop_width > image_width or crop_y + crop_height > image_height:
		errors.append("crop must stay inside image bounds")
	if frame_count >= 1 and frame_count <= MAX_FRAME_COUNT and crop_width > 0 and crop_width % frame_count != 0:
		errors.append("crop width must divide evenly across frame_count")
	if scale < 0.1 or scale > 8.0:
		errors.append("scale must be between 0.1 and 8.0")
	if absf(offset_x) > 4096.0 or absf(offset_y) > 4096.0:
		errors.append("offset must stay within +/-4096")
	if fps < 1.0 or fps > 60.0:
		errors.append("fps must be between 1 and 60")
	return errors

func is_valid() -> bool:
	return validate().is_empty()
