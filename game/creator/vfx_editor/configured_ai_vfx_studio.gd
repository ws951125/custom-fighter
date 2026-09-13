extends "res://game/creator/vfx_editor/ai_vfx_studio.gd"

const AiVfxProviderConfigScript = preload("res://game/ai/provider/ai_vfx_provider_config.gd")
const RemoteAiVfxProviderScript = preload("res://game/ai/remote/remote_ai_vfx_provider.gd")

var active_ai_provider: Variant
var active_ai_provider_id := "mock_ai_vfx"

func _initialize_provider() -> void:
	var config := AiVfxProviderConfigScript.new()
	config.load_from_environment()
	_apply_web_query_config(config)
	var config_errors: PackedStringArray = config.validate()
	if not config_errors.is_empty():
		ai_error = "AI provider config failed: %s" % " | ".join(config_errors)
		ai_last_status = "error"
		active_ai_provider = MockAiVfxProviderScript.new()
		_register_and_select(active_ai_provider)
		return

	if config.provider_id == AiVfxProviderConfigScript.REMOTE_PROVIDER_ID:
		active_ai_provider = RemoteAiVfxProviderScript.new(config.remote_endpoint)
	else:
		active_ai_provider = MockAiVfxProviderScript.new()
	_register_and_select(active_ai_provider)

func _register_and_select(provider: Variant) -> void:
	var register_errors: PackedStringArray = provider_registry.call("register_provider", provider)
	if not register_errors.is_empty():
		ai_error = "AI provider setup failed: %s" % " | ".join(register_errors)
		ai_last_status = "error"
		return
	active_ai_provider_id = str(provider.call("provider_id"))
	var select_errors: PackedStringArray = provider_registry.call("set_active_provider", active_ai_provider_id)
	if not select_errors.is_empty():
		ai_error = "AI provider selection failed: %s" % " | ".join(select_errors)
		ai_last_status = "error"

func _apply_web_query_config(config: Variant) -> void:
	if not OS.has_feature("web"):
		return
	var provider_value: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('ai_vfx_provider') || ''")
	var endpoint_value: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('ai_vfx_endpoint') || ''")
	var provider_text := str(provider_value).strip_edges().to_lower()
	var endpoint_text := str(endpoint_value).strip_edges()
	if not provider_text.is_empty():
		config.provider_id = provider_text
	if not endpoint_text.is_empty():
		config.remote_endpoint = endpoint_text

func _on_generate_pressed() -> void:
	if active_ai_provider_id != AiVfxProviderConfigScript.REMOTE_PROVIDER_ID:
		super._on_generate_pressed()
		return
	var next_request_id := "creator_ai_vfx_%d" % (ai_generation_count + 1)
	var request: Variant = AiVfxRequestScript.new()
	request.set("request_id", next_request_id)
	request.set("prompt", prompt_input.text.strip_edges())
	request.set("frame_count", roundi(ai_frame_count_spin.value))
	request.set("frame_width", roundi(ai_frame_width_spin.value))
	request.set("frame_height", roundi(ai_frame_height_spin.value))
	request.set("fps", ai_fps_spin.value)
	if not reference_png_bytes.is_empty():
		var reference_errors: PackedStringArray = request.call("set_reference_png", reference_file_name, reference_mime_type, reference_png_bytes)
		if not reference_errors.is_empty():
			_set_ai_error("Reference rejected: %s" % " | ".join(reference_errors))
			return
	var request_errors: PackedStringArray = request.call("validate")
	if not request_errors.is_empty():
		_set_ai_error("Request rejected: %s" % " | ".join(request_errors))
		return

	generate_button.disabled = true
	ai_last_status = "generating"
	ai_error = ""
	ai_revision += 1
	_refresh_ai_ui()
	_set_ai_web_state()
	var result: Variant = await active_ai_provider.call("generate_async", request, self)
	generate_button.disabled = false
	_apply_remote_result(result, request, next_request_id)

func _apply_remote_result(result: Variant, request: Variant, next_request_id: String) -> void:
	if result == null or not result.has_method("validate_against_request") or not result.has_method("to_vfx_draft_dictionary"):
		_set_ai_error("Active remote provider returned no usable AI VFX result")
		return
	var result_errors: PackedStringArray = result.call("validate_against_request", request)
	if not result_errors.is_empty():
		_set_ai_error("Generated result rejected: %s" % " | ".join(result_errors))
		return
	var bytes_value: Variant = result.get("png_bytes")
	if not (bytes_value is PackedByteArray):
		_set_ai_error("Generated result did not contain PNG bytes")
		return
	var generated_bytes: PackedByteArray = bytes_value
	var draft_value: Variant = result.call("to_vfx_draft_dictionary")
	if not (draft_value is Dictionary):
		_set_ai_error("Generated result did not contain VFX draft metadata")
		return
	var draft_errors: PackedStringArray = draft.load_from_dictionary(draft_value)
	if not draft_errors.is_empty():
		_set_ai_error("Generated VFX draft rejected: %s" % " | ".join(draft_errors))
		return
	var image := Image.new()
	var decode_error: Error = image.load_png_from_buffer(generated_bytes)
	if decode_error != OK or image.get_width() != draft.image_width or image.get_height() != draft.image_height:
		_set_ai_error("Generated PNG failed final runtime decode")
		return
	var proposal_value: Variant = result.get("skill_proposal")
	if proposal_value is Dictionary and not proposal_value.is_empty():
		var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
		if session == null or not session.has_method("store_ai_skill_proposal"):
			_set_ai_error("Creator session cannot preserve AI skill proposal")
			return
		var proposal_store_errors: PackedStringArray = session.call("store_ai_skill_proposal", proposal_value)
		if not proposal_store_errors.is_empty():
			_set_ai_error("AI skill proposal rejected by Creator session")
			return
	imported_png_bytes = generated_bytes.duplicate()
	imported_texture = ImageTexture.create_from_image(image)
	imported = true
	import_error = ""
	_reset_animation_preview()
	draft_revision += 1
	_sync_controls_from_draft()
	_refresh_validation(false)
	ai_generation_count += 1
	ai_last_request_id = next_request_id
	ai_last_status = "success"
	ai_error = ""
	ai_revision += 1
	_refresh_ai_ui()
	_set_ai_web_state()

func _refresh_ai_ui() -> void:
	super._refresh_ai_ui()
	if ai_status_label == null:
		return
	if ai_last_status == "generating":
		ai_status_label.text = "GENERATING · waiting for trusted AI backend"
		ai_status_label.modulate = Color("9fb0d2")
	elif ai_last_status == "ready" and active_ai_provider_id == AiVfxProviderConfigScript.REMOTE_PROVIDER_ID:
		ai_status_label.text = "READY · production remote AI provider"
