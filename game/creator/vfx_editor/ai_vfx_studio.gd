extends "res://game/creator/vfx_editor/vfx_studio.gd"

const AiVfxRequestScript = preload("res://game/ai/provider/ai_vfx_request.gd")
const AiVfxProviderRegistryScript = preload("res://game/ai/provider/ai_vfx_provider_registry.gd")
const MockAiVfxProviderScript = preload("res://game/ai/mock/mock_ai_vfx_provider.gd")

const AI_REFERENCE_MAX_BYTES := 5 * 1024 * 1024
const AI_REFERENCE_MAX_DATA_URL_CHARS := 8 * 1024 * 1024
const AI_REFERENCE_MAX_DIMENSION := 4096

var provider_registry: Variant = AiVfxProviderRegistryScript.new()
var ai_panel: PanelContainer
var prompt_input: LineEdit
var ai_frame_count_spin: SpinBox
var ai_frame_width_spin: SpinBox
var ai_frame_height_spin: SpinBox
var ai_fps_spin: SpinBox
var reference_label: Label
var ai_status_label: Label
var generate_button: Button

var reference_file_name := ""
var reference_mime_type := ""
var reference_width := 0
var reference_height := 0
var reference_png_bytes := PackedByteArray()
var ai_error := ""
var ai_last_status := "ready"
var ai_last_request_id := ""
var ai_generation_count := 0
var ai_revision := 0

var _web_ai_set_prompt_callback
var _web_ai_set_output_callback
var _web_ai_import_reference_callback
var _web_ai_reference_error_callback
var _web_ai_clear_reference_callback
var _web_ai_generate_callback

func _ready() -> void:
	super()
	_initialize_provider()
	_install_ai_ui()
	_install_ai_web_bridge()
	_refresh_ai_ui()
	_set_ai_web_state()

func _initialize_provider() -> void:
	var provider: Variant = MockAiVfxProviderScript.new()
	var register_errors: PackedStringArray = provider_registry.call("register_provider", provider)
	if not register_errors.is_empty():
		ai_error = "AI provider setup failed: %s" % " | ".join(register_errors)
		ai_last_status = "error"

func _install_ai_ui() -> void:
	ai_panel = PanelContainer.new()
	ai_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ai_panel.offset_left = -470.0
	ai_panel.offset_top = 92.0
	ai_panel.offset_right = -24.0
	ai_panel.offset_bottom = 475.0
	add_child(ai_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	ai_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "AI VFX · Mock Provider"
	heading.add_theme_font_size_override("font_size", 19)
	column.add_child(heading)

	var hint := Label.new()
	hint.text = "Describe the projectile effect, optionally add a PNG reference, then Generate / Regenerate."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color("9fb0d2")
	column.add_child(hint)

	prompt_input = LineEdit.new()
	prompt_input.placeholder_text = "Example: electric blue comet with a bright white core"
	prompt_input.max_length = AiVfxRequestScript.MAX_PROMPT_CHARS
	prompt_input.text_changed.connect(_on_prompt_changed)
	column.add_child(prompt_input)

	var reference_row := HBoxContainer.new()
	reference_row.add_theme_constant_override("separation", 8)
	column.add_child(reference_row)

	var choose_reference_button := Button.new()
	choose_reference_button.text = "Choose Reference PNG"
	choose_reference_button.pressed.connect(_on_choose_reference_pressed)
	reference_row.add_child(choose_reference_button)

	var clear_reference_button := Button.new()
	clear_reference_button.text = "Clear Reference"
	clear_reference_button.pressed.connect(_clear_reference)
	reference_row.add_child(clear_reference_button)

	reference_label = Label.new()
	reference_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reference_label.modulate = Color("9fb0d2")
	column.add_child(reference_label)

	var output_row := HBoxContainer.new()
	output_row.add_theme_constant_override("separation", 6)
	column.add_child(output_row)
	ai_frame_count_spin = _add_number_field(output_row, "Frames", 1.0, 8.0, 1.0)
	ai_frame_width_spin = _add_number_field(output_row, "Frame W", 8.0, 128.0, 1.0)
	ai_frame_height_spin = _add_number_field(output_row, "Frame H", 8.0, 128.0, 1.0)
	ai_fps_spin = _add_number_field(output_row, "FPS", 1.0, 60.0, 1.0)
	ai_frame_count_spin.set_value_no_signal(4)
	ai_frame_width_spin.set_value_no_signal(64)
	ai_frame_height_spin.set_value_no_signal(64)
	ai_fps_spin.set_value_no_signal(12)
	ai_frame_count_spin.value_changed.connect(_on_ai_output_changed)
	ai_frame_width_spin.value_changed.connect(_on_ai_output_changed)
	ai_frame_height_spin.value_changed.connect(_on_ai_output_changed)
	ai_fps_spin.value_changed.connect(_on_ai_output_changed)

	generate_button = Button.new()
	generate_button.text = "Generate AI VFX"
	generate_button.pressed.connect(_on_generate_pressed)
	column.add_child(generate_button)

	ai_status_label = Label.new()
	ai_status_label.custom_minimum_size = Vector2(0, 54)
	ai_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(ai_status_label)

	var boundary_note := Label.new()
	boundary_note.text = "M6 safety boundary: generation uses the provider adapter. The mock provider is deterministic and requires no external service."
	boundary_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boundary_note.modulate = Color("8292b3")
	column.add_child(boundary_note)

func _on_prompt_changed(_value: String) -> void:
	ai_error = ""
	ai_last_status = "ready"
	ai_revision += 1
	_refresh_ai_ui()
	_set_ai_web_state()

func _on_ai_output_changed(_value: float) -> void:
	ai_error = ""
	ai_last_status = "ready"
	ai_revision += 1
	_refresh_ai_ui()
	_set_ai_web_state()

func _on_choose_reference_pressed() -> void:
	if not OS.has_feature("web"):
		_set_ai_error("Reference PNG picker is currently enabled for the Web build")
		return
	var script := """
(() => {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/png,.png';
  input.style.display = 'none';
  document.body.appendChild(input);
  input.onchange = () => {
    const file = input.files && input.files[0];
    if (!file) { input.remove(); return; }
    if (file.size > %d) {
      window.customFighterCreatorAiVfxReferenceError('Reference PNG exceeds 5 MB limit');
      input.remove();
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      window.customFighterCreatorAiVfxImportReference(file.name, file.type || 'image/png', String(reader.result || ''));
      input.remove();
    };
    reader.onerror = () => {
      window.customFighterCreatorAiVfxReferenceError('Browser could not read reference PNG');
      input.remove();
    };
    reader.readAsDataURL(file);
  };
  input.click();
})();
""" % AI_REFERENCE_MAX_BYTES
	JavaScriptBridge.eval(script)

func _import_reference_data(file_name: String, mime_type: String, data_url: String) -> void:
	if data_url.length() > AI_REFERENCE_MAX_DATA_URL_CHARS:
		_set_ai_error("Reference PNG data URL exceeds safe transfer limit")
		return
	if mime_type.strip_edges().to_lower() != "image/png" or not data_url.begins_with("data:image/png"):
		_set_ai_error("Reference image must be image/png")
		return
	var marker := "base64,"
	var marker_index := data_url.find(marker)
	if marker_index < 0:
		_set_ai_error("Reference PNG must use base64 data URL encoding")
		return
	var bytes: PackedByteArray = Marshalls.base64_to_raw(data_url.substr(marker_index + marker.length()))
	if bytes.is_empty():
		_set_ai_error("Reference PNG payload could not be decoded")
		return
	if bytes.size() > AI_REFERENCE_MAX_BYTES:
		_set_ai_error("Reference PNG exceeds 5 MB limit")
		return
	var image := Image.new()
	var load_error: Error = image.load_png_from_buffer(bytes)
	if load_error != OK:
		_set_ai_error("Reference PNG bytes failed Godot image decoding")
		return
	if image.get_width() < 1 or image.get_height() < 1 or image.get_width() > AI_REFERENCE_MAX_DIMENSION or image.get_height() > AI_REFERENCE_MAX_DIMENSION:
		_set_ai_error("Reference PNG dimensions must stay within 4096 px")
		return
	reference_file_name = file_name.strip_edges()
	reference_mime_type = "image/png"
	reference_width = image.get_width()
	reference_height = image.get_height()
	reference_png_bytes = bytes.duplicate()
	ai_error = ""
	ai_last_status = "ready"
	ai_revision += 1
	_refresh_ai_ui()
	_set_ai_web_state()

func _clear_reference() -> void:
	reference_file_name = ""
	reference_mime_type = ""
	reference_width = 0
	reference_height = 0
	reference_png_bytes.clear()
	ai_error = ""
	ai_last_status = "ready"
	ai_revision += 1
	_refresh_ai_ui()
	_set_ai_web_state()

func _on_generate_pressed() -> void:
	var next_request_id := "creator_ai_vfx_%d" % (ai_generation_count + 1)
	var request: Variant = AiVfxRequestScript.new()
	request.set("request_id", next_request_id)
	request.set("prompt", prompt_input.text.strip_edges())
	request.set("frame_count", roundi(ai_frame_count_spin.value))
	request.set("frame_width", roundi(ai_frame_width_spin.value))
	request.set("frame_height", roundi(ai_frame_height_spin.value))
	request.set("fps", ai_fps_spin.value)

	if not reference_png_bytes.is_empty():
		var reference_errors: PackedStringArray = request.call(
			"set_reference_png",
			reference_file_name,
			reference_mime_type,
			reference_png_bytes
		)
		if not reference_errors.is_empty():
			_set_ai_error("Reference rejected: %s" % " | ".join(reference_errors))
			return

	var request_errors: PackedStringArray = request.call("validate")
	if not request_errors.is_empty():
		_set_ai_error("Request rejected: %s" % " | ".join(request_errors))
		return

	var result: Variant = provider_registry.call("generate", request)
	if result == null or not result.has_method("validate_against_request") or not result.has_method("to_vfx_draft_dictionary"):
		_set_ai_error("Active provider returned no usable AI VFX result")
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
	var generated_draft_data: Dictionary = draft_value
	var draft_errors: PackedStringArray = draft.load_from_dictionary(generated_draft_data)
	if not draft_errors.is_empty():
		_set_ai_error("Generated VFX draft rejected: %s" % " | ".join(draft_errors))
		return

	var image := Image.new()
	var decode_error: Error = image.load_png_from_buffer(generated_bytes)
	if decode_error != OK or image.get_width() != draft.image_width or image.get_height() != draft.image_height:
		_set_ai_error("Generated PNG failed final runtime decode")
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

func _set_ai_error(message: String) -> void:
	ai_error = message
	ai_last_status = "error"
	ai_revision += 1
	_refresh_ai_ui()
	_set_ai_web_state()

func _refresh_ai_ui() -> void:
	if reference_label != null:
		reference_label.text = "Reference: none (optional)" if reference_png_bytes.is_empty() else "Reference: %s · %dx%d · %d bytes" % [reference_file_name, reference_width, reference_height, reference_png_bytes.size()]
	if generate_button != null:
		generate_button.text = "Generate AI VFX" if ai_generation_count == 0 else "Regenerate AI VFX"
	if ai_status_label != null:
		if ai_last_status == "error":
			ai_status_label.text = "AI VFX BLOCKED · %s" % ai_error
			ai_status_label.modulate = Color("ff7b86")
		elif ai_last_status == "success":
			ai_status_label.text = "GENERATED · %s · valid VFX is bound to Creator Skill 1" % ai_last_request_id
			ai_status_label.modulate = Color("7ff0b1")
		else:
			ai_status_label.text = "READY · Prompt is processed through the active provider adapter"
			ai_status_label.modulate = Color("9fb0d2")

func _install_ai_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_ai_set_prompt_callback = JavaScriptBridge.create_callback(_web_ai_set_prompt)
	_web_ai_set_output_callback = JavaScriptBridge.create_callback(_web_ai_set_output)
	_web_ai_import_reference_callback = JavaScriptBridge.create_callback(_web_ai_import_reference)
	_web_ai_reference_error_callback = JavaScriptBridge.create_callback(_web_ai_reference_error)
	_web_ai_clear_reference_callback = JavaScriptBridge.create_callback(_web_ai_clear_reference)
	_web_ai_generate_callback = JavaScriptBridge.create_callback(_web_ai_generate)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterCreatorAiVfxSetPrompt = _web_ai_set_prompt_callback
	window.customFighterCreatorAiVfxSetOutput = _web_ai_set_output_callback
	window.customFighterCreatorAiVfxImportReference = _web_ai_import_reference_callback
	window.customFighterCreatorAiVfxReferenceError = _web_ai_reference_error_callback
	window.customFighterCreatorAiVfxClearReference = _web_ai_clear_reference_callback
	window.customFighterCreatorAiVfxGenerate = _web_ai_generate_callback

func _web_ai_set_prompt(args: Array) -> void:
	if args.is_empty():
		return
	prompt_input.text = str(args[0]).substr(0, AiVfxRequestScript.MAX_PROMPT_CHARS)
	ai_error = ""
	ai_last_status = "ready"
	ai_revision += 1
	_refresh_ai_ui()
	_set_ai_web_state()

func _web_ai_set_output(args: Array) -> void:
	if args.size() < 4:
		return
	ai_frame_count_spin.set_value_no_signal(float(args[0]))
	ai_frame_width_spin.set_value_no_signal(float(args[1]))
	ai_frame_height_spin.set_value_no_signal(float(args[2]))
	ai_fps_spin.set_value_no_signal(float(args[3]))
	ai_error = ""
	ai_last_status = "ready"
	ai_revision += 1
	_refresh_ai_ui()
	_set_ai_web_state()

func _web_ai_import_reference(args: Array) -> void:
	if args.size() < 3:
		_set_ai_error("Reference bridge requires name, MIME type and data URL")
		return
	_import_reference_data(str(args[0]), str(args[1]), str(args[2]))

func _web_ai_reference_error(args: Array) -> void:
	_set_ai_error(str(args[0]) if not args.is_empty() else "Reference PNG import failed")

func _web_ai_clear_reference(_args: Array) -> void:
	_clear_reference()

func _web_ai_generate(_args: Array) -> void:
	_on_generate_pressed()

func _set_ai_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var provider_id := ""
	if provider_registry != null and provider_registry.has_method("active_provider_id"):
		provider_id = str(provider_registry.call("active_provider_id"))
	var generated_valid := ai_generation_count > 0 and imported and import_error.is_empty() and draft.is_valid()
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorAiVfxReady='true';" +
		"document.documentElement.dataset.creatorAiVfxRevision='%d';" % ai_revision +
		"document.documentElement.dataset.creatorAiVfxProvider=%s;" % JSON.stringify(provider_id) +
		"document.documentElement.dataset.creatorAiVfxPrompt=%s;" % JSON.stringify(prompt_input.text if prompt_input != null else "") +
		"document.documentElement.dataset.creatorAiVfxReferencePresent='%s';" % ("true" if not reference_png_bytes.is_empty() else "false") +
		"document.documentElement.dataset.creatorAiVfxReferenceFileName=%s;" % JSON.stringify(reference_file_name) +
		"document.documentElement.dataset.creatorAiVfxReferenceWidth='%d';" % reference_width +
		"document.documentElement.dataset.creatorAiVfxReferenceHeight='%d';" % reference_height +
		"document.documentElement.dataset.creatorAiVfxOutputFrameCount='%d';" % (roundi(ai_frame_count_spin.value) if ai_frame_count_spin != null else 0) +
		"document.documentElement.dataset.creatorAiVfxOutputFrameWidth='%d';" % (roundi(ai_frame_width_spin.value) if ai_frame_width_spin != null else 0) +
		"document.documentElement.dataset.creatorAiVfxOutputFrameHeight='%d';" % (roundi(ai_frame_height_spin.value) if ai_frame_height_spin != null else 0) +
		"document.documentElement.dataset.creatorAiVfxOutputFps='%.3f';" % (ai_fps_spin.value if ai_fps_spin != null else 0.0) +
		"document.documentElement.dataset.creatorAiVfxGenerationCount='%d';" % ai_generation_count +
		"document.documentElement.dataset.creatorAiVfxLastRequestId=%s;" % JSON.stringify(ai_last_request_id) +
		"document.documentElement.dataset.creatorAiVfxLastStatus=%s;" % JSON.stringify(ai_last_status) +
		"document.documentElement.dataset.creatorAiVfxGeneratedValid='%s';" % ("true" if generated_valid else "false") +
		"document.documentElement.dataset.creatorAiVfxError=%s;" % JSON.stringify(ai_error)
	)
