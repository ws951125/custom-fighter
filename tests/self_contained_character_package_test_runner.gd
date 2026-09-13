extends SceneTree

const PackageDefinition = preload("res://game/core/package/self_contained_character_package_definition.gd")

func _init() -> void:
	var failures := PackedStringArray()
	_test_accepts_legacy_v1(failures)
	_test_valid_v2_vfx_round_trip(failures)
	_test_rejects_malformed_base64(failures)
	_test_rejects_non_png_bytes(failures)
	_test_rejects_oversized_png(failures)
	_test_rejects_dimension_mismatch(failures)
	_test_rejects_unknown_asset_field(failures)
	if failures.is_empty():
		print("SELF_CONTAINED_CHARACTER_PACKAGE_TESTS_PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_accepts_legacy_v1(failures: PackedStringArray) -> void:
	var package := PackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(_legacy_package())
	_expect(errors.is_empty(), "schema-v1 package should remain import compatible", failures)
	_expect(package.schema_version == 1, "legacy package should preserve schema version 1", failures)
	_expect(not package.has_vfx_asset(), "legacy package should not invent a VFX asset", failures)

func _test_valid_v2_vfx_round_trip(failures: PackedStringArray) -> void:
	var package := PackageDefinition.new()
	var input: Dictionary = _v2_package_with_vfx()
	var errors: PackedStringArray = package.load_from_dictionary(input)
	_expect(errors.is_empty(), "valid schema-v2 package with VFX should load", failures)
	_expect(package.has_vfx_asset(), "valid schema-v2 package should expose VFX bytes", failures)
	_expect(int(package.vfx_data.get("frame_count", 0)) == 4, "VFX metadata should retain frame count", failures)

	var serialized: Dictionary = package.to_dictionary()
	_expect(int(serialized.get("schema_version", 0)) == 2, "VFX package should serialize as schema 2", failures)
	var reloaded := PackageDefinition.new()
	var reload_errors: PackedStringArray = reloaded.load_from_dictionary(serialized)
	_expect(reload_errors.is_empty(), "serialized schema-v2 package should reload", failures)
	_expect(reloaded.vfx_png_bytes == package.vfx_png_bytes, "VFX PNG bytes should round trip deterministically", failures)
	_expect(JSON.stringify(serialized) == JSON.stringify(reloaded.to_dictionary()), "schema-v2 package round trip should be deterministic", failures)

func _test_rejects_malformed_base64(failures: PackedStringArray) -> void:
	var data: Dictionary = _v2_package_with_vfx()
	var asset: Dictionary = data.get("vfx_asset", {})
	asset["png_base64"] = "%%%not-base64%%%"
	var package := PackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "png_base64 is malformed"), "malformed base64 must fail closed", failures)

func _test_rejects_non_png_bytes(failures: PackedStringArray) -> void:
	var data: Dictionary = _v2_package_with_vfx()
	var asset: Dictionary = data.get("vfx_asset", {})
	asset["png_base64"] = Marshalls.raw_to_base64("not a png".to_utf8_buffer())
	var package := PackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "PNG bytes failed runtime decode"), "non-PNG bytes must fail runtime decode", failures)

func _test_rejects_oversized_png(failures: PackedStringArray) -> void:
	var data: Dictionary = _v2_package_with_vfx()
	var bytes := PackedByteArray()
	bytes.resize(PackageDefinition.MAX_VFX_PNG_BYTES + 1)
	var asset: Dictionary = data.get("vfx_asset", {})
	asset["png_base64"] = Marshalls.raw_to_base64(bytes)
	var package := PackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "PNG exceeds 5 MB limit"), "decoded PNG byte ceiling must be enforced", failures)

func _test_rejects_dimension_mismatch(failures: PackedStringArray) -> void:
	var data: Dictionary = _v2_package_with_vfx()
	var asset: Dictionary = data.get("vfx_asset", {})
	var metadata: Dictionary = asset.get("metadata", {})
	metadata["image_width"] = 20
	var crop: Dictionary = metadata.get("crop", {})
	crop["width"] = 20
	var package := PackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "decoded PNG dimensions do not match metadata"), "metadata/PNG dimension mismatch must fail closed", failures)

func _test_rejects_unknown_asset_field(failures: PackedStringArray) -> void:
	var data: Dictionary = _v2_package_with_vfx()
	var asset: Dictionary = data.get("vfx_asset", {})
	asset["script_path"] = "res://payload.gd"
	var package := PackageDefinition.new()
	var errors: PackedStringArray = package.load_from_dictionary(data)
	_expect(_contains(errors, "unsupported vfx_asset field: script_path"), "unknown VFX asset fields must fail closed", failures)

func _v2_package_with_vfx() -> Dictionary:
	var data: Dictionary = _legacy_package()
	data["schema_version"] = 2
	var png_bytes: PackedByteArray = _png_strip_bytes()
	data["vfx_asset"] = {
		"skill_slot": "skill_1",
		"skill_id": "pkg_projectile",
		"mime_type": "image/png",
		"metadata": {
			"schema_version": 1,
			"file_name": "package-strip.png",
			"mime_type": "image/png",
			"image_width": 16,
			"image_height": 4,
			"frame_count": 4,
			"crop": {"x": 0, "y": 0, "width": 16, "height": 4},
			"scale": 2.0,
			"offset": {"x": 12.0, "y": -8.0},
			"fps": 20.0
		},
		"png_base64": Marshalls.raw_to_base64(png_bytes)
	}
	return data

func _png_strip_bytes() -> PackedByteArray:
	var image := Image.create(16, 4, false, Image.FORMAT_RGBA8)
	for x in range(16):
		var frame_index: int = int(x / 4)
		var color := Color(1.0, 0.2 * frame_index, 1.0 - 0.2 * frame_index, 1.0)
		for y in range(4):
			image.set_pixel(x, y, color)
	return image.save_png_to_buffer()

func _legacy_package() -> Dictionary:
	return {
		"schema_version": 1,
		"package_id": "package_hero",
		"package_version": 1,
		"character": {
			"schema_version": 1,
			"id": "package_hero",
			"name": "Package Hero",
			"archetype": "balanced",
			"stats": {
				"max_hp": 140,
				"max_mp": 120,
				"move_speed": 380.0,
				"depth_speed": 0.72,
				"run_multiplier": 1.6,
				"guard_move_multiplier": 0.35
			},
			"skill_slots": {
				"skill_1": "pkg_projectile",
				"skill_2": "pkg_dash",
				"skill_3": "pkg_area",
				"skill_4": "pkg_formation",
				"skill_5": "pkg_buff",
				"skill_6": "pkg_melee"
			},
			"visual_profile": "training_blue",
			"animation_map": "ember_vanguard"
		},
		"skills": [
			_skill("pkg_projectile", "projectile"),
			_skill("pkg_melee", "melee"),
			_skill("pkg_buff", "buff"),
			_skill("pkg_dash", "dash"),
			_skill("pkg_formation", "formation"),
			_skill("pkg_area", "area")
		]
	}

func _skill(skill_id: String, skill_type: String) -> Dictionary:
	return {
		"schema_version": 1,
		"id": skill_id,
		"name": skill_id,
		"type": skill_type,
		"damage": 12,
		"mp_cost": 8,
		"cooldown": 0.8,
		"startup": 0.1,
		"active": 0.5,
		"recovery": 0.15,
		"speed": 500.0,
		"range": 360.0,
		"hitstun": 0.15,
		"knockback": 120.0,
		"hitbox_half_width": 24.0,
		"hitbox_half_depth": 0.08,
		"formation_count": 3,
		"formation_spacing": 48.0,
		"formation_interval": 0.1,
		"formation_offset": 24.0,
		"buff_duration": 2.0,
		"move_speed_multiplier": 1.1,
		"basic_attack_damage_multiplier": 1.1,
		"visual": "package_visual",
		"impact_visual": "package_impact"
	}

func _contains(errors: PackedStringArray, text: String) -> bool:
	for error in errors:
		if str(error).contains(text):
			return true
	return false

func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
