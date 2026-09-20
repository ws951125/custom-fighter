class_name CharacterAudioAssetDraft
extends RefCounted

const CharacterAudioBindings = preload("res://game/core/character/character_audio_bindings.gd")

const CURRENT_SCHEMA_VERSION := 1
const SUPPORTED_MIME_TYPE := "audio/wav"
const MAX_FILE_BYTES := 512 * 1024
const MAX_DURATION_MS := 3000
const MIN_SAMPLE_RATE := 8000
const MAX_SAMPLE_RATE := 48000
const ALLOWED_BITS_PER_SAMPLE := [8, 16]

var schema_version := CURRENT_SCHEMA_VERSION
var binding := ""
var cue_id := ""
var file_name := ""
var mime_type := ""
var byte_size := 0
var sample_rate := 0
var channels := 0
var bits_per_sample := 0
var duration_ms := 0

func reset() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	binding = ""
	cue_id = ""
	file_name = ""
	mime_type = ""
	byte_size = 0
	sample_rate = 0
	channels = 0
	bits_per_sample = 0
	duration_ms = 0

func configure_import(name: String, mime: String, binding_name: String, cue: String, wav_bytes: PackedByteArray) -> PackedStringArray:
	reset()
	file_name = name.strip_edges()
	mime_type = _normalize_mime(mime)
	binding = binding_name.strip_edges().to_lower()
	cue_id = cue.strip_edges().to_lower()
	byte_size = wav_bytes.size()

	var errors := PackedStringArray()
	if not _is_safe_wav_name(file_name):
		errors.append("file_name must be a safe .wav filename")
	if mime_type != SUPPORTED_MIME_TYPE:
		errors.append("only audio/wav is supported")
	if not CharacterAudioBindings.REQUIRED_BINDINGS.has(binding):
		errors.append("binding must use the fixed character audio binding vocabulary")
	if not _is_safe_token(cue_id):
		errors.append("cue_id must be a safe lowercase token")
	if wav_bytes.is_empty():
		errors.append("WAV bytes must not be empty")
	elif wav_bytes.size() > MAX_FILE_BYTES:
		errors.append("WAV exceeds 512 KB limit")
	if not errors.is_empty():
		return errors

	var inspect_errors: PackedStringArray = _inspect_pcm_wav(wav_bytes)
	errors.append_array(inspect_errors)
	if not errors.is_empty():
		reset()
	return errors

func load_from_dictionary(data: Dictionary) -> PackedStringArray:
	reset()
	var allowed := ["schema_version", "binding", "cue_id", "file_name", "mime_type", "byte_size", "sample_rate", "channels", "bits_per_sample", "duration_ms"]
	var errors := PackedStringArray()
	for raw_key in data.keys():
		var key := str(raw_key)
		if not allowed.has(key):
			errors.append("unsupported audio asset field: %s" % key)
	for key in allowed:
		if not data.has(key):
			errors.append("missing required audio asset field: %s" % key)
	if not errors.is_empty():
		return errors

	schema_version = int(data.get("schema_version", 0))
	binding = str(data.get("binding", "")).strip_edges().to_lower()
	cue_id = str(data.get("cue_id", "")).strip_edges().to_lower()
	file_name = str(data.get("file_name", "")).strip_edges()
	mime_type = _normalize_mime(str(data.get("mime_type", "")))
	byte_size = int(data.get("byte_size", 0))
	sample_rate = int(data.get("sample_rate", 0))
	channels = int(data.get("channels", 0))
	bits_per_sample = int(data.get("bits_per_sample", 0))
	duration_ms = int(data.get("duration_ms", 0))
	errors.append_array(validate_metadata())
	return errors

func validate_metadata() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append("unsupported audio asset schema_version: %d" % schema_version)
	if not CharacterAudioBindings.REQUIRED_BINDINGS.has(binding):
		errors.append("binding must use the fixed character audio binding vocabulary")
	if not _is_safe_token(cue_id):
		errors.append("cue_id must be a safe lowercase token")
	if not _is_safe_wav_name(file_name):
		errors.append("file_name must be a safe .wav filename")
	if mime_type != SUPPORTED_MIME_TYPE:
		errors.append("only audio/wav is supported")
	if byte_size < 1 or byte_size > MAX_FILE_BYTES:
		errors.append("byte_size must be between 1 and %d" % MAX_FILE_BYTES)
	if sample_rate < MIN_SAMPLE_RATE or sample_rate > MAX_SAMPLE_RATE:
		errors.append("sample_rate must be between %d and %d" % [MIN_SAMPLE_RATE, MAX_SAMPLE_RATE])
	if channels < 1 or channels > 2:
		errors.append("channels must be 1 or 2")
	if not ALLOWED_BITS_PER_SAMPLE.has(bits_per_sample):
		errors.append("bits_per_sample must be 8 or 16")
	if duration_ms < 1 or duration_ms > MAX_DURATION_MS:
		errors.append("duration_ms must be between 1 and %d" % MAX_DURATION_MS)
	return errors

func validate_bytes(wav_bytes: PackedByteArray) -> PackedStringArray:
	var errors := PackedStringArray()
	if wav_bytes.size() != byte_size:
		errors.append("WAV byte size does not match metadata")
		return errors
	var snapshot := to_dictionary()
	var inspect_errors := _inspect_pcm_wav(wav_bytes)
	if not inspect_errors.is_empty():
		return inspect_errors
	if sample_rate != int(snapshot.get("sample_rate", 0)) or channels != int(snapshot.get("channels", 0)) or bits_per_sample != int(snapshot.get("bits_per_sample", 0)) or duration_ms != int(snapshot.get("duration_ms", 0)):
		errors.append("WAV decoded properties do not match metadata")
	return errors

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"binding": binding,
		"cue_id": cue_id,
		"file_name": file_name,
		"mime_type": mime_type,
		"byte_size": byte_size,
		"sample_rate": sample_rate,
		"channels": channels,
		"bits_per_sample": bits_per_sample,
		"duration_ms": duration_ms
	}

func _inspect_pcm_wav(bytes: PackedByteArray) -> PackedStringArray:
	var errors := PackedStringArray()
	if bytes.size() < 44:
		errors.append("WAV is too small to contain a valid PCM header")
		return errors
	if _ascii(bytes, 0, 4) != "RIFF" or _ascii(bytes, 8, 4) != "WAVE":
		errors.append("WAV must use RIFF/WAVE framing")
		return errors
	var riff_size := _u32_le(bytes, 4)
	if riff_size + 8 != bytes.size():
		errors.append("WAV RIFF size does not match payload length")
		return errors

	var found_fmt := false
	var found_data := false
	var byte_rate := 0
	var block_align := 0
	var data_size := 0
	var offset := 12
	while offset + 8 <= bytes.size():
		var chunk_id := _ascii(bytes, offset, 4)
		var chunk_size := _u32_le(bytes, offset + 4)
		var chunk_data := offset + 8
		if chunk_size < 0 or chunk_data + chunk_size > bytes.size():
			errors.append("WAV chunk exceeds payload bounds")
			return errors
		if chunk_id == "fmt ":
			if found_fmt:
				errors.append("WAV contains duplicate fmt chunk")
				return errors
			if chunk_size < 16:
				errors.append("WAV fmt chunk is too small")
				return errors
			found_fmt = true
			var audio_format := _u16_le(bytes, chunk_data)
			channels = _u16_le(bytes, chunk_data + 2)
			sample_rate = _u32_le(bytes, chunk_data + 4)
			byte_rate = _u32_le(bytes, chunk_data + 8)
			block_align = _u16_le(bytes, chunk_data + 12)
			bits_per_sample = _u16_le(bytes, chunk_data + 14)
			if audio_format != 1:
				errors.append("WAV must use uncompressed PCM format")
			if channels < 1 or channels > 2:
				errors.append("WAV channels must be 1 or 2")
			if sample_rate < MIN_SAMPLE_RATE or sample_rate > MAX_SAMPLE_RATE:
				errors.append("WAV sample_rate must be between %d and %d" % [MIN_SAMPLE_RATE, MAX_SAMPLE_RATE])
			if not ALLOWED_BITS_PER_SAMPLE.has(bits_per_sample):
				errors.append("WAV bits_per_sample must be 8 or 16")
			var expected_align := channels * bits_per_sample / 8
			if block_align != expected_align:
				errors.append("WAV block_align is inconsistent")
			if byte_rate != sample_rate * block_align:
				errors.append("WAV byte_rate is inconsistent")
		elif chunk_id == "data":
			if found_data:
				errors.append("WAV contains duplicate data chunk")
				return errors
			found_data = true
			data_size = chunk_size
		offset = chunk_data + chunk_size + (chunk_size % 2)

	if not found_fmt:
		errors.append("WAV is missing fmt chunk")
	if not found_data:
		errors.append("WAV is missing data chunk")
	if not errors.is_empty():
		return errors
	if data_size < 1 or block_align < 1 or byte_rate < 1:
		errors.append("WAV data chunk must contain PCM samples")
		return errors
	if data_size % block_align != 0:
		errors.append("WAV data size must align to complete PCM frames")
		return errors
	duration_ms = int(round(float(data_size) * 1000.0 / float(byte_rate)))
	if duration_ms < 1 or duration_ms > MAX_DURATION_MS:
		errors.append("WAV duration must be between 1 and %d ms" % MAX_DURATION_MS)
	return errors

func _u16_le(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 2 > bytes.size():
		return -1
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)

func _u32_le(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 4 > bytes.size():
		return -1
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)

func _ascii(bytes: PackedByteArray, offset: int, length: int) -> String:
	if offset < 0 or length < 0 or offset + length > bytes.size():
		return ""
	var value := ""
	for index in range(offset, offset + length):
		value += String.chr(int(bytes[index]))
	return value

func _normalize_mime(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["audio/x-wav", "audio/wave", "audio/vnd.wave"]:
		return SUPPORTED_MIME_TYPE
	return normalized

func _is_safe_token(value: String) -> bool:
	if value.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null

func _is_safe_wav_name(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	if normalized.is_empty() or normalized.length() > 96:
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9._-]*\\.wav$")
	return regex.search(normalized) != null
