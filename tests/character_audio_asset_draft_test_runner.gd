extends SceneTree

const CharacterAudioAssetDraft = preload("res://game/creator/character_editor/character_audio_asset_draft.gd")

func _init() -> void:
	var failures := PackedStringArray()
	_test_valid_pcm_wav(failures)
	_test_rejects_path_name(failures)
	_test_rejects_compressed_format(failures)
	_test_rejects_duration_limit(failures)
	_test_metadata_round_trip(failures)
	if failures.is_empty():
		print("CHARACTER_AUDIO_ASSET_DRAFT_TESTS_PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_valid_pcm_wav(failures: PackedStringArray) -> void:
	var bytes := _pcm_wav(8000, 1, 8, 800)
	var draft := CharacterAudioAssetDraft.new()
	var errors: PackedStringArray = draft.configure_import("skill_cast.wav", "audio/wav", "skill_cast", "nova_cast", bytes)
	_expect(errors.is_empty(), "valid bounded PCM WAV should import", failures)
	_expect(draft.sample_rate == 8000, "sample rate should be parsed", failures)
	_expect(draft.channels == 1, "channel count should be parsed", failures)
	_expect(draft.bits_per_sample == 8, "bit depth should be parsed", failures)
	_expect(draft.duration_ms == 100, "duration should be derived from PCM data", failures)
	_expect(draft.validate_bytes(bytes).is_empty(), "imported WAV bytes should validate against metadata", failures)

func _test_rejects_path_name(failures: PackedStringArray) -> void:
	var draft := CharacterAudioAssetDraft.new()
	var errors := draft.configure_import("../evil.wav", "audio/wav", "skill_cast", "nova_cast", _pcm_wav(8000, 1, 8, 80))
	_expect(_contains(errors, "safe .wav filename"), "path-like WAV name must fail closed", failures)

func _test_rejects_compressed_format(failures: PackedStringArray) -> void:
	var bytes := _pcm_wav(8000, 1, 8, 80, 3)
	var draft := CharacterAudioAssetDraft.new()
	var errors := draft.configure_import("compressed.wav", "audio/wav", "skill_cast", "nova_cast", bytes)
	_expect(_contains(errors, "uncompressed PCM"), "compressed/non-PCM WAV must fail closed", failures)

func _test_rejects_duration_limit(failures: PackedStringArray) -> void:
	var bytes := _pcm_wav(8000, 1, 8, 24008)
	var draft := CharacterAudioAssetDraft.new()
	var errors := draft.configure_import("too_long.wav", "audio/wav", "skill_cast", "nova_cast", bytes)
	_expect(_contains(errors, "duration must be between"), "WAV longer than three seconds must fail closed", failures)

func _test_metadata_round_trip(failures: PackedStringArray) -> void:
	var bytes := _pcm_wav(16000, 2, 16, 6400)
	var draft := CharacterAudioAssetDraft.new()
	var errors := draft.configure_import("impact.wav", "audio/x-wav", "skill_impact", "nova_impact", bytes)
	_expect(errors.is_empty(), "alternate WAV MIME alias should canonicalize", failures)
	var clone := CharacterAudioAssetDraft.new()
	var reload_errors := clone.load_from_dictionary(draft.to_dictionary())
	_expect(reload_errors.is_empty(), "audio asset metadata should round-trip", failures)
	_expect(JSON.stringify(clone.to_dictionary()) == JSON.stringify(draft.to_dictionary()), "audio asset metadata round trip should be deterministic", failures)

func _pcm_wav(sample_rate: int, channels: int, bits: int, data_size: int, format_code: int = 1) -> PackedByteArray:
	var bytes := PackedByteArray()
	_append_ascii(bytes, "RIFF")
	_append_u32(bytes, 36 + data_size)
	_append_ascii(bytes, "WAVE")
	_append_ascii(bytes, "fmt ")
	_append_u32(bytes, 16)
	_append_u16(bytes, format_code)
	_append_u16(bytes, channels)
	_append_u32(bytes, sample_rate)
	var block_align := channels * bits / 8
	_append_u32(bytes, sample_rate * block_align)
	_append_u16(bytes, block_align)
	_append_u16(bytes, bits)
	_append_ascii(bytes, "data")
	_append_u32(bytes, data_size)
	for index in range(data_size):
		bytes.append(128 if bits == 8 else 0)
	return bytes

func _append_ascii(bytes: PackedByteArray, value: String) -> void:
	for index in range(value.length()):
		bytes.append(value.unicode_at(index))

func _append_u16(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xff)
	bytes.append((value >> 8) & 0xff)

func _append_u32(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xff)
	bytes.append((value >> 8) & 0xff)
	bytes.append((value >> 16) & 0xff)
	bytes.append((value >> 24) & 0xff)

func _contains(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if str(error).contains(fragment):
			return true
	return false

func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
