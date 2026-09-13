class_name AiVfxResult
extends RefCounted

const VfxDraft = preload("res://game/creator/vfx_editor/vfx_draft.gd")

const CURRENT_SCHEMA_VERSION := 1
const STATUS_SUCCESS := "success"
const STATUS_ERROR := "error"
const SUPPORTED_MIME_TYPE := "image/png"
const MAX_PNG_BYTES := 5 * 1024 * 1024

var schema_version := CURRENT_SCHEMA_VERSION
var provider_id := ""
var request_id := ""
var status := STATUS_ERROR
var message := ""
var file_name := ""
var mime_type := ""
var image_width := 0
var image_height := 0
var frame_count := 1
var fps := 12.0
var png_bytes := PackedByteArray()
var skill_proposal: Dictionary = {}

func configure_success(source_provider_id: String, source_request_id: String, generated_png: PackedByteArray, generated_frame_count: int, generated_fps: float) -> PackedStringArray:
	reset()
	provider_id = source_provider_id.strip_edges().to_lower()
	request_id = source_request_id.strip_edges().to_lower()
	status = STATUS_SUCCESS
	file_name = "ai_%s.png" % request_id
	mime_type = SUPPORTED_MIME_TYPE
	frame_count = generated_frame_count
	fps = generated_fps
	png_bytes = generated_png.duplicate()
	if not png_bytes.is_empty() and png_bytes.size() <= MAX_PNG_BYTES:
		var image := Image.new()
		if image.load_png_from_buffer(png_bytes) == OK:
			image_width = image.get_width()
			image_height = image.get_height()
	return validate()

func configure_error(source_provider_id: String, source_request_id: String, error_message: String) -> PackedStringArray:
	reset()
	provider_id = source_provider_id.strip_edges().to_lower()
	request_id = source_request_id.strip_edges().to_lower()
	status = STATUS_ERROR
	message = error_message.strip_edges()
	return validate()

func reset() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	provider_id = ""
	request_id = ""
	status = STATUS_ERROR
	message = ""
	file_name = ""
	mime_type = ""
	image_width = 0
	image_height = 0
	frame_count = 1
	fps = 12.0
	png_bytes.clear()
	skill_proposal.clear()

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"provider_id": provider_id,
		"request_id": request_id,
		"status": status,
		"message": message,
		"file_name": file_name,
		"mime_type": mime_type,
		"image_width": image_width,
		"image_height": image_height,
		"frame_count": frame_count,
		"fps": fps,
		"byte_count": png_bytes.size(),
		"skill_proposal": skill_proposal.duplicate(true)
	}

func to_vfx_draft_dictionary() -> Dictionary:
	if status != STATUS_SUCCESS:
		return {}
	return {
		"schema_version": VfxDraft.CURRENT_SCHEMA_VERSION,
		"file_name": file_name,
		"mime_type": mime_type,
		"image_width": image_width,
		"image_height": image_height,
		"frame_count": frame_count,
		"crop": {
			"x": 0,
			"y": 0,
			"width": image_width,
			"height": image_height
		},
		"scale": 1.0,
		"offset": {
			"x": 0.0,
			"y": 0.0
		},
		"fps": fps
	}

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported schema_version: %d" % schema_version)
	if not _is_safe_token(provider_id):
		errors.append("provider_id must be a safe lowercase reference token")
	if not _is_safe_token(request_id):
		errors.append("request_id must be a safe lowercase reference token")
	if status != STATUS_SUCCESS and status != STATUS_ERROR:
		errors.append("status must be success or error")
		return errors
	if status == STATUS_ERROR:
		if message.is_empty():
			errors.append("error result must include a message")
		if not png_bytes.is_empty():
			errors.append("error result must not include PNG bytes")
		return errors
	_validate_success_payload(errors)
	return errors

func validate_against_request(request: Variant) -> PackedStringArray:
	var errors := validate()
	if request == null or not request.has_method("validate"):
		errors.append("request must implement the AI VFX request contract")
		return errors
	var request_errors: PackedStringArray = request.call("validate")
	for error in request_errors:
		errors.append("request: %s" % error)
	if not request_errors.is_empty():
		return errors
	if request_id != str(request.get("request_id")):
		errors.append("result request_id does not match request")
	if status != STATUS_SUCCESS:
		return errors
	if frame_count != int(request.get("frame_count")):
		errors.append("result frame_count does not match request")
	if image_width != int(request.get("frame_count")) * int(request.get("frame_width")):
		errors.append("result sprite-strip width does not match request")
	if image_height != int(request.get("frame_height")):
		errors.append("result image height does not match request")
	if absf(fps - float(request.get("fps"))) > 0.001:
		errors.append("result fps does not match request")
	return errors

func is_usable_against_request(request: Variant) -> bool:
	return status == STATUS_SUCCESS and validate_against_request(request).is_empty()

func _validate_success_payload(errors: PackedStringArray) -> void:
	if file_name.is_empty():
		errors.append("success result file_name must not be empty")
	if mime_type != SUPPORTED_MIME_TYPE:
		errors.append("success result must use image/png")
	if png_bytes.is_empty():
		errors.append("success result PNG bytes must not be empty")
		return
	if png_bytes.size() > MAX_PNG_BYTES:
		errors.append("success result PNG exceeds 5 MB limit")
		return
	var image := Image.new()
	var decode_error: Error = image.load_png_from_buffer(png_bytes)
	if decode_error != OK:
		errors.append("success result PNG bytes failed runtime decode")
		return
	if image.get_width() != image_width or image.get_height() != image_height:
		errors.append("success result PNG dimensions do not match metadata")
	var draft := VfxDraft.new()
	var draft_errors: PackedStringArray = draft.load_from_dictionary(to_vfx_draft_dictionary())
	for error in draft_errors:
		errors.append("vfx: %s" % error)

func _is_safe_token(value: String) -> bool:
	if value.is_empty() or value.length() > 80:
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null
