class_name SelfContainedCharacterPackageDefinition
extends RefCounted

const CharacterPackageDefinition = preload("res://game/core/package/character_package_definition.gd")
const CharacterAnimationMap = preload("res://game/core/character/character_animation_map.gd")
const CharacterAudioBindings = preload("res://game/core/character/character_audio_bindings.gd")
const CharacterAudioAssetDraft = preload("res://game/creator/character_editor/character_audio_asset_draft.gd")
const VfxDraft = preload("res://game/creator/vfx_editor/vfx_draft.gd")

const CURRENT_SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1
const MAX_VFX_PNG_BYTES := 5 * 1024 * 1024
const MAX_VFX_BASE64_CHARS := 7 * 1024 * 1024
const MAX_AUDIO_BASE64_CHARS := 700 * 1024
const ALLOWED_V2_TOP_LEVEL_FIELDS := [
	"schema_version", "package_id", "package_version", "character", "skills", "animation_map", "audio_bindings", "audio_asset", "vfx_asset"
]
const ALLOWED_AUDIO_ASSET_FIELDS := ["metadata", "wav_base64"]
const ALLOWED_VFX_ASSET_FIELDS := [
	"skill_slot", "skill_id", "mime_type", "metadata", "png_base64"
]

var schema_version := CURRENT_SCHEMA_VERSION
var package_id := ""
var package_version := 1
var character_data: Dictionary = {}
var skill_data_by_id: Dictionary = {}
var animation_map_data: Dictionary = {}
var audio_bindings_data: Dictionary = {}
var audio_asset_data: Dictionary = {}
var audio_wav_bytes := PackedByteArray()
var vfx_data: Dictionary = {}
var vfx_png_bytes := PackedByteArray()
var loaded := false

func reset() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	package_id = ""
	package_version = 1
	character_data.clear()
	skill_data_by_id.clear()
	animation_map_data.clear()
	audio_bindings_data.clear()
	audio_asset_data.clear()
	audio_wav_bytes.clear()
	vfx_data.clear()
	vfx_png_bytes.clear()
	loaded = false

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	reset()
	var requested_schema: int = int(data.get("schema_version", 0))
	if requested_schema == LEGACY_SCHEMA_VERSION:
		return _load_legacy(data)
	if requested_schema != CURRENT_SCHEMA_VERSION:
		return PackedStringArray(["unsupported package schema_version: %d" % requested_schema])
	return _load_v2(data)

func _load_legacy(data: Dictionary) -> PackedStringArray:
	var legacy := CharacterPackageDefinition.new()
	var errors: PackedStringArray = legacy.load_from_dictionary(data)
	if not errors.is_empty():
		return errors
	_copy_legacy_state(legacy)
	schema_version = LEGACY_SCHEMA_VERSION
	loaded = true
	return PackedStringArray()

func _load_v2(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_allowed_fields(data, ALLOWED_V2_TOP_LEVEL_FIELDS, "package", errors)
	for required_field in ["schema_version", "package_id", "package_version", "character", "skills"]:
		if not data.has(required_field):
			errors.append("missing required package field: %s" % required_field)
	if not errors.is_empty():
		return errors

	var legacy_input: Dictionary = {
		"schema_version": LEGACY_SCHEMA_VERSION,
		"package_id": data.get("package_id", ""),
		"package_version": data.get("package_version", 0),
		"character": data.get("character", {}),
		"skills": data.get("skills", [])
	}
	var legacy := CharacterPackageDefinition.new()
	var legacy_errors: PackedStringArray = legacy.load_from_dictionary(legacy_input)
	for error in legacy_errors:
		errors.append(error)
	if not errors.is_empty():
		return errors

	_copy_legacy_state(legacy)
	schema_version = CURRENT_SCHEMA_VERSION

	if data.has("animation_map"):
		_validate_animation_map_payload(data.get("animation_map"), errors)
		if not errors.is_empty():
			return errors

	if data.has("audio_bindings"):
		_validate_audio_bindings_payload(data.get("audio_bindings"), errors)
		if not errors.is_empty():
			return errors

	if data.has("audio_asset"):
		var audio_asset_value: Variant = data.get("audio_asset")
		if not audio_asset_value is Dictionary:
			errors.append("audio_asset must be an object")
			return errors
		_validate_audio_asset(audio_asset_value, errors)
		if not errors.is_empty():
			return errors

	if data.has("vfx_asset"):
		var asset_value: Variant = data.get("vfx_asset")
		if not asset_value is Dictionary:
			errors.append("vfx_asset must be an object")
			return errors
		var asset: Dictionary = asset_value
		_validate_vfx_asset(asset, errors)

	loaded = errors.is_empty()
	if not loaded:
		animation_map_data.clear()
		audio_bindings_data.clear()
		audio_asset_data.clear()
		audio_wav_bytes.clear()
		vfx_data.clear()
		vfx_png_bytes.clear()
	return errors

func _validate_animation_map_payload(value: Variant, errors: PackedStringArray) -> void:
	if not value is Dictionary:
		errors.append("animation_map must be an object")
		return
	var animation_map := CharacterAnimationMap.new()
	var map_errors: PackedStringArray = animation_map.load_from_dictionary(value)
	for error in map_errors:
		errors.append("animation_map: %s" % error)
	if not map_errors.is_empty():
		return
	var expected_id: String = str(character_data.get("animation_map", "")).strip_edges().to_lower()
	if animation_map.map_id != expected_id:
		errors.append("animation_map id must match character animation_map")
		return
	var canonical_animations: Dictionary = {}
	for semantic in CharacterAnimationMap.REQUIRED_SEMANTICS:
		canonical_animations[semantic] = str(animation_map.animations.get(semantic, ""))
	animation_map_data = {
		"schema_version": animation_map.schema_version,
		"id": animation_map.map_id,
		"animations": canonical_animations
	}

func _validate_audio_bindings_payload(value: Variant, errors: PackedStringArray) -> void:
	if not value is Dictionary:
		errors.append("audio_bindings must be an object")
		return
	var bindings := CharacterAudioBindings.new()
	var binding_errors: PackedStringArray = bindings.load_from_dictionary(value)
	for error in binding_errors:
		errors.append("audio_bindings: %s" % error)
	if not binding_errors.is_empty():
		return
	audio_bindings_data = bindings.to_dictionary()

func _validate_audio_asset(asset: Dictionary, errors: PackedStringArray) -> void:
	_validate_allowed_fields(asset, ALLOWED_AUDIO_ASSET_FIELDS, "audio_asset", errors)
	for required_field in ALLOWED_AUDIO_ASSET_FIELDS:
		if not asset.has(required_field):
			errors.append("missing required audio_asset field: %s" % required_field)
	if not errors.is_empty():
		return

	var metadata_value: Variant = asset.get("metadata")
	if not metadata_value is Dictionary:
		errors.append("audio_asset metadata must be an object")
		return
	var draft := CharacterAudioAssetDraft.new()
	var metadata_errors: PackedStringArray = draft.load_from_dictionary(metadata_value)
	for error in metadata_errors:
		errors.append("audio_asset metadata: %s" % error)
	if not errors.is_empty():
		return

	if audio_bindings_data.is_empty():
		errors.append("audio_asset requires packaged audio_bindings")
		return
	var cues: Dictionary = audio_bindings_data.get("cues", {})
	var expected_cue: String = str(cues.get(draft.binding, "")).strip_edges().to_lower()
	if expected_cue != draft.cue_id:
		errors.append("audio_asset cue_id must match packaged audio_bindings")
		return

	var encoded: String = str(asset.get("wav_base64", "")).strip_edges()
	if not _is_valid_base64_shape(encoded, MAX_AUDIO_BASE64_CHARS):
		errors.append("audio_asset wav_base64 is malformed or exceeds the encoded size limit")
		return
	var wav_bytes: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if wav_bytes.is_empty():
		errors.append("audio_asset WAV bytes must not be empty")
		return
	if wav_bytes.size() > CharacterAudioAssetDraft.MAX_FILE_BYTES:
		errors.append("audio_asset WAV exceeds 512 KB limit")
		return
	var byte_errors: PackedStringArray = draft.validate_bytes(wav_bytes)
	for error in byte_errors:
		errors.append("audio_asset WAV: %s" % error)
	if not errors.is_empty():
		return

	audio_asset_data = draft.to_dictionary()
	audio_wav_bytes = wav_bytes.duplicate()

func _validate_vfx_asset(asset: Dictionary, errors: PackedStringArray) -> void:
	_validate_allowed_fields(asset, ALLOWED_VFX_ASSET_FIELDS, "vfx_asset", errors)
	for required_field in ALLOWED_VFX_ASSET_FIELDS:
		if not asset.has(required_field):
			errors.append("missing required vfx_asset field: %s" % required_field)
	if not errors.is_empty():
		return

	var skill_slot: String = str(asset.get("skill_slot", ""))
	var skill_id: String = str(asset.get("skill_id", "")).strip_edges().to_lower()
	var mime_type: String = str(asset.get("mime_type", "")).strip_edges().to_lower()
	if skill_slot != "skill_1":
		errors.append("vfx_asset skill_slot must be skill_1")
	var slots: Dictionary = character_data.get("skill_slots", {})
	if skill_id != str(slots.get("skill_1", "")):
		errors.append("vfx_asset skill_id must match character skill_1")
	if mime_type != "image/png":
		errors.append("vfx_asset mime_type must be image/png")

	var metadata_value: Variant = asset.get("metadata")
	if not metadata_value is Dictionary:
		errors.append("vfx_asset metadata must be an object")
		return
	var draft := VfxDraft.new()
	var draft_errors: PackedStringArray = draft.load_from_dictionary(metadata_value)
	for error in draft_errors:
		errors.append("vfx_asset metadata: %s" % error)
	if not _is_safe_png_name(draft.file_name):
		errors.append("vfx_asset metadata file_name must be a safe .png filename")
	if not errors.is_empty():
		return

	var encoded: String = str(asset.get("png_base64", "")).strip_edges()
	if not _is_valid_base64_shape(encoded, MAX_VFX_BASE64_CHARS):
		errors.append("vfx_asset png_base64 is malformed or exceeds the encoded size limit")
		return
	var png_bytes: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if png_bytes.is_empty():
		errors.append("vfx_asset PNG bytes must not be empty")
		return
	if png_bytes.size() > MAX_VFX_PNG_BYTES:
		errors.append("vfx_asset PNG exceeds 5 MB limit")
		return

	var image := Image.new()
	var decode_error: Error = image.load_png_from_buffer(png_bytes)
	if decode_error != OK:
		errors.append("vfx_asset PNG bytes failed runtime decode")
		return
	if image.get_width() != draft.image_width or image.get_height() != draft.image_height:
		errors.append("vfx_asset decoded PNG dimensions do not match metadata")
		return

	vfx_data = draft.to_dictionary()
	vfx_png_bytes = png_bytes.duplicate()

func has_animation_map() -> bool:
	return loaded and not animation_map_data.is_empty()

func has_audio_bindings() -> bool:
	return loaded and not audio_bindings_data.is_empty()

func has_audio_asset() -> bool:
	return loaded and not audio_asset_data.is_empty() and not audio_wav_bytes.is_empty()

func has_vfx_asset() -> bool:
	return loaded and not vfx_data.is_empty() and not vfx_png_bytes.is_empty()

func to_dictionary() -> Dictionary:
	if not loaded:
		return {}
	if schema_version == LEGACY_SCHEMA_VERSION:
		return to_legacy_dictionary()

	var result: Dictionary = to_legacy_dictionary()
	result["schema_version"] = CURRENT_SCHEMA_VERSION
	if has_animation_map():
		result["animation_map"] = animation_map_data.duplicate(true)
	if has_audio_bindings():
		result["audio_bindings"] = audio_bindings_data.duplicate(true)
	if has_audio_asset():
		result["audio_asset"] = {
			"metadata": audio_asset_data.duplicate(true),
			"wav_base64": Marshalls.raw_to_base64(audio_wav_bytes)
		}
	if has_vfx_asset():
		var slots: Dictionary = character_data.get("skill_slots", {})
		result["vfx_asset"] = {
			"skill_slot": "skill_1",
			"skill_id": str(slots.get("skill_1", "")),
			"mime_type": "image/png",
			"metadata": vfx_data.duplicate(true),
			"png_base64": Marshalls.raw_to_base64(vfx_png_bytes)
		}
	return result

func to_legacy_dictionary() -> Dictionary:
	if package_id.is_empty() or character_data.is_empty() or skill_data_by_id.is_empty():
		return {}
	var ordered_skills: Array = []
	var skill_ids: Array = skill_data_by_id.keys()
	skill_ids.sort()
	for raw_id in skill_ids:
		var skill_id: String = str(raw_id)
		ordered_skills.append(skill_data_by_id[skill_id].duplicate(true))
	return {
		"schema_version": LEGACY_SCHEMA_VERSION,
		"package_id": package_id,
		"package_version": package_version,
		"character": character_data.duplicate(true),
		"skills": ordered_skills
	}

func is_valid() -> bool:
	return loaded

func _copy_legacy_state(legacy: Variant) -> void:
	package_id = str(legacy.package_id)
	package_version = int(legacy.package_version)
	character_data = legacy.character_data.duplicate(true)
	skill_data_by_id = legacy.skill_data_by_id.duplicate(true)

func _validate_allowed_fields(data: Dictionary, allowed_fields: Array, scope: String, errors: PackedStringArray) -> void:
	for raw_key in data.keys():
		var key: String = str(raw_key)
		if not allowed_fields.has(key):
			errors.append("unsupported %s field: %s" % [scope, key])

func _is_valid_base64_shape(value: String, max_chars: int) -> bool:
	if value.is_empty() or value.length() > max_chars or value.length() % 4 != 0:
		return false
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9+/]*={0,2}$")
	return regex.search(value) != null

func _is_safe_png_name(value: String) -> bool:
	if value.is_empty() or value.contains("/") or value.contains("\\") or value.contains(".."):
		return false
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9][A-Za-z0-9_.-]*\\.png$")
	return regex.search(value) != null
