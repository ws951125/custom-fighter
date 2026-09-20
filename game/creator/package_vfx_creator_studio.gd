extends "res://game/creator/package_creator_studio.gd"

const SelfContainedPackageDefinition = preload("res://game/core/package/self_contained_character_package_definition.gd")

func _build_export_package() -> Dictionary:
	var base_result: Dictionary = super()
	var errors: PackedStringArray = base_result.get("errors", PackedStringArray())
	if not errors.is_empty():
		return base_result

	var package_input: Dictionary = base_result.get("data", {}).duplicate(true)
	package_input["schema_version"] = SelfContainedPackageDefinition.CURRENT_SCHEMA_VERSION
	package_input["animation_map"] = animation_draft.to_dictionary()
	package_input["audio_bindings"] = audio_draft.to_dictionary()
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session != null and session.has_method("has_stored_audio_asset") and bool(session.call("has_stored_audio_asset")):
		var audio_asset_data: Dictionary = session.call("stored_audio_asset_data")
		var wav_bytes: PackedByteArray = session.call("stored_audio_asset_bytes")
		package_input["audio_asset"] = {
			"metadata": audio_asset_data.duplicate(true),
			"wav_base64": Marshalls.raw_to_base64(wav_bytes)
		}
	if session != null and session.has_method("has_stored_vfx") and bool(session.call("has_stored_vfx")):
		var character_data: Dictionary = package_input.get("character", {})
		var slots: Dictionary = character_data.get("skill_slots", {})
		var vfx_data: Dictionary = session.call("stored_vfx_data")
		var png_bytes: PackedByteArray = session.call("stored_vfx_png_bytes")
		package_input["vfx_asset"] = {
			"skill_slot": "skill_1",
			"skill_id": str(slots.get("skill_1", "")),
			"mime_type": "image/png",
			"metadata": vfx_data.duplicate(true),
			"png_base64": Marshalls.raw_to_base64(png_bytes)
		}

	var package := SelfContainedPackageDefinition.new()
	var package_errors: PackedStringArray = package.load_from_dictionary(package_input)
	for error in package_errors:
		errors.append("package: %s" % error)
	return {"errors": errors, "data": package.to_dictionary() if errors.is_empty() else {}}

func _import_package_json(json_text: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var byte_count: int = json_text.to_utf8_buffer().size()
	if byte_count <= 0:
		errors.append("package JSON must not be empty")
		return errors
	if byte_count > MAX_PACKAGE_JSON_BYTES:
		errors.append("package JSON exceeds 256 KB limit")
		return errors

	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		errors.append("package JSON must contain one object")
		return errors

	var package := SelfContainedPackageDefinition.new()
	var package_errors: PackedStringArray = package.load_from_dictionary(parsed)
	for error in package_errors:
		errors.append(error)
	if not errors.is_empty():
		return errors

	var compatibility_errors: PackedStringArray = _validate_creator_import_compatibility(package)
	for error in compatibility_errors:
		errors.append(error)
	if not errors.is_empty():
		return errors

	var legacy_json: String = JSON.stringify(package.to_legacy_dictionary(), "", true)
	var base_errors: PackedStringArray = super._import_package_json(legacy_json)
	for error in base_errors:
		errors.append(error)
	if not errors.is_empty():
		return errors

	if package.has_audio_bindings():
		var audio_errors: PackedStringArray = audio_draft.load_from_dictionary(package.audio_bindings_data)
		for error in audio_errors:
			errors.append("packaged audio bindings: %s" % error)
		if not errors.is_empty():
			return errors
	else:
		audio_draft.reset()
	var audio_session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if audio_session == null or not audio_session.has_method("store_audio_bindings_draft"):
		errors.append("Creator preview session cannot restore packaged audio bindings")
		return errors
	var audio_store_errors: PackedStringArray = audio_session.call("store_audio_bindings_draft", audio_draft.to_dictionary())
	for error in audio_store_errors:
		errors.append("packaged audio bindings: %s" % error)
	if not errors.is_empty():
		return errors
	_sync_audio_controls_from_draft()
	_refresh_character_validation(false)
	_set_web_state()

	if package.has_audio_asset():
		if audio_session == null or not audio_session.has_method("store_audio_asset_draft"):
			errors.append("Creator preview session cannot restore packaged WAV")
			return errors
		var audio_asset_store_errors: PackedStringArray = audio_session.call(
			"store_audio_asset_draft",
			package.audio_asset_data,
			package.audio_wav_bytes
		)
		for error in audio_asset_store_errors:
			errors.append("packaged WAV: %s" % error)
		if not errors.is_empty():
			return errors
		_restore_audio_asset_from_session()
		_refresh_audio_asset_status()

	if package.has_animation_map():
		var animation_errors: PackedStringArray = animation_draft.load_from_dictionary(package.animation_map_data)
		for error in animation_errors:
			errors.append("packaged animation map: %s" % error)
		if not errors.is_empty():
			return errors
		var animation_session: Variant = get_node_or_null("/root/CreatorPreviewSession")
		if animation_session == null or not animation_session.has_method("store_animation_map_draft"):
			errors.append("Creator preview session cannot restore packaged animation map")
			return errors
		var animation_store_errors: PackedStringArray = animation_session.call("store_animation_map_draft", animation_draft.to_dictionary())
		for error in animation_store_errors:
			errors.append("packaged animation map: %s" % error)
		if not errors.is_empty():
			return errors
		_sync_character_controls_from_draft()
		_refresh_character_validation(false)
		_set_web_state()

	if package.has_vfx_asset():
		var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
		if session == null or not session.has_method("store_vfx_draft"):
			errors.append("Creator preview session cannot restore packaged VFX")
			return errors
		var store_errors: PackedStringArray = session.call("store_vfx_draft", package.vfx_data, package.vfx_png_bytes)
		for error in store_errors:
			errors.append("packaged VFX: %s" % error)
		if not errors.is_empty():
			return errors
		_refresh_preview_binding_status()
		_set_web_state()
	return PackedStringArray()

func _set_package_web_state() -> void:
	super._set_package_web_state()
	if not OS.has_feature("web"):
		return
	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	var vfx_bound := false
	var vfx_bytes := 0
	var audio_bound := false
	var audio_asset_bound := false
	var audio_asset_bytes := 0
	if session != null and session.has_method("has_stored_vfx"):
		vfx_bound = bool(session.call("has_stored_vfx"))
	if session != null and session.has_method("has_stored_audio_bindings"):
		audio_bound = bool(session.call("has_stored_audio_bindings"))
	if session != null and session.has_method("has_stored_audio_asset"):
		audio_asset_bound = bool(session.call("has_stored_audio_asset"))
	if audio_asset_bound and session.has_method("stored_audio_asset_bytes"):
		var wav_bytes: PackedByteArray = session.call("stored_audio_asset_bytes")
		audio_asset_bytes = wav_bytes.size()
	if vfx_bound and session.has_method("stored_vfx_png_bytes"):
		var bytes: PackedByteArray = session.call("stored_vfx_png_bytes")
		vfx_bytes = bytes.size()
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorPackageFormatVersion='%d';" % SelfContainedPackageDefinition.CURRENT_SCHEMA_VERSION +
		"document.documentElement.dataset.creatorPackageAudioBindings='%s';" % ("true" if audio_bound else "false") +
		"document.documentElement.dataset.creatorPackageAudioAssetBound='%s';" % ("true" if audio_asset_bound else "false") +
		"document.documentElement.dataset.creatorPackageAudioAssetBytes='%d';" % audio_asset_bytes +
		"document.documentElement.dataset.creatorPackageVfxBound='%s';" % ("true" if vfx_bound else "false") +
		"document.documentElement.dataset.creatorPackageVfxBytes='%d';" % vfx_bytes
	)
