extends Control

const VfxDraft = preload("res://game/creator/vfx_editor/vfx_draft.gd")
const MAX_FILE_BYTES := 5 * 1024 * 1024
const MAX_DATA_URL_CHARS := 8 * 1024 * 1024

var draft := VfxDraft.new()
var draft_revision := 0
var imported_texture: ImageTexture
var import_error := ""
var imported := false

var preview_texture: TextureRect
var metadata_label: Label
var validation_label: Label
var crop_x_spin: SpinBox
var crop_y_spin: SpinBox
var crop_width_spin: SpinBox
var crop_height_spin: SpinBox
var scale_spin: SpinBox
var offset_x_spin: SpinBox
var offset_y_spin: SpinBox
var fps_spin: SpinBox

var _web_import_callback
var _web_import_error_callback
var _web_reset_callback
var _web_set_crop_callback
var _web_set_scale_callback

func _ready() -> void:
	_build_ui()
	_sync_controls_from_draft()
	_refresh_validation(false)
	_install_web_bridge()
	_set_web_state()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0b1020")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)

	var title := Label.new()
	title.text = "CUSTOM FIGHTER · VFX CREATOR"
	title.add_theme_font_size_override("font_size", 30)
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "M5 · Safe in-memory PNG import, validation and preview"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.modulate = Color("a9b8d8")
	page.add_child(subtitle)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	page.add_child(nav)

	var choose_button := Button.new()
	choose_button.text = "Choose PNG"
	choose_button.pressed.connect(_on_choose_png_pressed)
	nav.add_child(choose_button)

	var reset_button := Button.new()
	reset_button.text = "Reset VFX Draft"
	reset_button.pressed.connect(_on_reset_pressed)
	nav.add_child(reset_button)

	var creator_button := Button.new()
	creator_button.text = "Back to Creator Studio"
	creator_button.pressed.connect(_on_creator_pressed)
	nav.add_child(creator_button)

	var note := Label.new()
	note.text = "PNG only · ≤ 5 MB · ≤ 4096 px · memory only"
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.modulate = Color("8292b3")
	nav.add_child(note)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	page.add_child(body)

	var settings_panel := PanelContainer.new()
	settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(settings_panel)
	var settings_margin := MarginContainer.new()
	settings_margin.add_theme_constant_override("margin_left", 18)
	settings_margin.add_theme_constant_override("margin_right", 18)
	settings_margin.add_theme_constant_override("margin_top", 14)
	settings_margin.add_theme_constant_override("margin_bottom", 14)
	settings_panel.add_child(settings_margin)
	var settings := VBoxContainer.new()
	settings.add_theme_constant_override("separation", 7)
	settings_margin.add_child(settings)

	_add_heading(settings, "Transform")
	var crop_row := HBoxContainer.new()
	crop_row.add_theme_constant_override("separation", 8)
	settings.add_child(crop_row)
	crop_x_spin = _add_number_field(crop_row, "Crop X", 0.0, 4096.0, 1.0)
	crop_y_spin = _add_number_field(crop_row, "Crop Y", 0.0, 4096.0, 1.0)
	crop_width_spin = _add_number_field(crop_row, "Crop W", 0.0, 4096.0, 1.0)
	crop_height_spin = _add_number_field(crop_row, "Crop H", 0.0, 4096.0, 1.0)

	var transform_row := HBoxContainer.new()
	transform_row.add_theme_constant_override("separation", 8)
	settings.add_child(transform_row)
	scale_spin = _add_number_field(transform_row, "Scale", 0.0, 8.0, 0.1)
	offset_x_spin = _add_number_field(transform_row, "Offset X", -4096.0, 4096.0, 1.0)
	offset_y_spin = _add_number_field(transform_row, "Offset Y", -4096.0, 4096.0, 1.0)
	fps_spin = _add_number_field(transform_row, "FPS", 0.0, 60.0, 1.0)

	crop_x_spin.value_changed.connect(_on_transform_changed)
	crop_y_spin.value_changed.connect(_on_transform_changed)
	crop_width_spin.value_changed.connect(_on_transform_changed)
	crop_height_spin.value_changed.connect(_on_transform_changed)
	scale_spin.value_changed.connect(_on_transform_changed)
	offset_x_spin.value_changed.connect(_on_transform_changed)
	offset_y_spin.value_changed.connect(_on_transform_changed)
	fps_spin.value_changed.connect(_on_transform_changed)

	settings.add_child(HSeparator.new())
	metadata_label = Label.new()
	metadata_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metadata_label.modulate = Color("b8c7e6")
	settings.add_child(metadata_label)

	validation_label = Label.new()
	validation_label.custom_minimum_size = Vector2(0, 68)
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings.add_child(validation_label)

	var security_note := Label.new()
	security_note.text = "Security boundary: the browser passes PNG bytes only. The draft stores metadata only; no file path, script or executable content is persisted."
	security_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	security_note.modulate = Color("8fa1c6")
	settings.add_child(security_note)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(460, 0)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(preview_panel)
	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 18)
	preview_margin.add_theme_constant_override("margin_right", 18)
	preview_margin.add_theme_constant_override("margin_top", 14)
	preview_margin.add_theme_constant_override("margin_bottom", 14)
	preview_panel.add_child(preview_margin)
	var preview_column := VBoxContainer.new()
	preview_column.add_theme_constant_override("separation", 10)
	preview_margin.add_child(preview_column)

	_add_heading(preview_column, "Preview")
	var canvas := ColorRect.new()
	canvas.color = Color("121a2e")
	canvas.custom_minimum_size = Vector2(420, 420)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	preview_column.add_child(canvas)

	preview_texture = TextureRect.new()
	preview_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(preview_texture)

	var preview_note := Label.new()
	preview_note.text = "Crop is applied to the preview. Scale / offset / FPS are validated authoring metadata in this slice."
	preview_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_note.modulate = Color("8292b3")
	preview_column.add_child(preview_note)

func _add_heading(parent: Control, text_value: String) -> void:
	var heading := Label.new()
	heading.text = text_value
	heading.add_theme_font_size_override("font_size", 19)
	parent.add_child(heading)

func _add_number_field(parent: Control, label_text: String, minimum: float, maximum: float, step_value: float) -> SpinBox:
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 2)
	parent.add_child(field)
	var label := Label.new()
	label.text = label_text
	field.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step_value
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.custom_minimum_size = Vector2(92, 32)
	field.add_child(spin)
	return spin

func _sync_controls_from_draft() -> void:
	crop_x_spin.set_value_no_signal(draft.crop_x)
	crop_y_spin.set_value_no_signal(draft.crop_y)
	crop_width_spin.set_value_no_signal(draft.crop_width)
	crop_height_spin.set_value_no_signal(draft.crop_height)
	scale_spin.set_value_no_signal(draft.scale)
	offset_x_spin.set_value_no_signal(draft.offset_x)
	offset_y_spin.set_value_no_signal(draft.offset_y)
	fps_spin.set_value_no_signal(draft.fps)

func _on_transform_changed(_value: float) -> void:
	draft.crop_x = roundi(crop_x_spin.value)
	draft.crop_y = roundi(crop_y_spin.value)
	draft.crop_width = roundi(crop_width_spin.value)
	draft.crop_height = roundi(crop_height_spin.value)
	draft.scale = scale_spin.value
	draft.offset_x = offset_x_spin.value
	draft.offset_y = offset_y_spin.value
	draft.fps = fps_spin.value
	draft_revision += 1
	_refresh_validation(false)

func _on_choose_png_pressed() -> void:
	if not OS.has_feature("web"):
		import_error = "PNG file picker is currently enabled for the Web build"
		_refresh_validation(false)
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
      window.customFighterCreatorVfxImportError('PNG exceeds 5 MB limit');
      input.remove();
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      window.customFighterCreatorVfxImportPng(file.name, file.type || 'image/png', String(reader.result || ''));
      input.remove();
    };
    reader.onerror = () => {
      window.customFighterCreatorVfxImportError('Browser could not read PNG');
      input.remove();
    };
    reader.readAsDataURL(file);
  };
  input.click();
})();
""" % MAX_FILE_BYTES
	JavaScriptBridge.eval(script)

func _on_reset_pressed() -> void:
	draft.reset()
	imported_texture = null
	imported = false
	import_error = ""
	draft_revision += 1
	_sync_controls_from_draft()
	_refresh_validation(false)

func _on_creator_pressed() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = window.location.pathname + '?mode=creator';")
		return
	var router := get_parent()
	if router != null and router.has_method("switch_mode"):
		router.switch_mode("creator")

func _import_png_data(file_name: String, mime_type: String, data_url: String) -> void:
	import_error = ""
	imported = false
	imported_texture = null
	if data_url.length() > MAX_DATA_URL_CHARS:
		_import_failed("PNG data URL exceeds safe transfer limit")
		return
	var marker := "base64,"
	var marker_index := data_url.find(marker)
	if marker_index < 0 or not data_url.begins_with("data:image/png"):
		_import_failed("PNG import requires a base64 image/png data URL")
		return
	var payload := data_url.substr(marker_index + marker.length())
	var bytes: PackedByteArray = Marshalls.base64_to_raw(payload)
	if bytes.is_empty():
		_import_failed("PNG payload could not be decoded")
		return
	if bytes.size() > MAX_FILE_BYTES:
		_import_failed("PNG exceeds 5 MB limit")
		return
	var image := Image.new()
	var load_error := image.load_png_from_buffer(bytes)
	if load_error != OK:
		_import_failed("PNG bytes failed Godot image decoding")
		return
	var errors := draft.configure_import(file_name, mime_type, image.get_width(), image.get_height())
	if not errors.is_empty():
		_import_failed(" | ".join(errors))
		return
	imported_texture = ImageTexture.create_from_image(image)
	imported = true
	draft_revision += 1
	_sync_controls_from_draft()
	_refresh_validation(false)

func _import_failed(message: String) -> void:
	import_error = message
	imported = false
	imported_texture = null
	draft_revision += 1
	_refresh_validation(false)

func _refresh_validation(increment_revision: bool = true) -> void:
	if increment_revision:
		draft_revision += 1
	var errors := draft.validate()
	var valid := imported and import_error.is_empty() and errors.is_empty()
	var error_text := import_error
	if error_text.is_empty() and not errors.is_empty():
		error_text = " | ".join(errors)
	validation_label.text = "VALID · PNG VFX draft passes Slice 1 safety rules" if valid else "INVALID · %s" % error_text
	validation_label.modulate = Color("7ff0b1") if valid else Color("ff7b86")
	metadata_label.text = "File: %s · %dx%d · Crop %d,%d %dx%d · Scale %.2f · Offset %.0f,%.0f · FPS %.0f" % [
		draft.file_name if not draft.file_name.is_empty() else "none",
		draft.image_width,
		draft.image_height,
		draft.crop_x,
		draft.crop_y,
		draft.crop_width,
		draft.crop_height,
		draft.scale,
		draft.offset_x,
		draft.offset_y,
		draft.fps
	]
	_refresh_preview(valid)
	_set_web_state(errors)

func _refresh_preview(_valid: bool) -> void:
	if not imported or imported_texture == null:
		preview_texture.texture = null
		return
	if draft.crop_width < 1 or draft.crop_height < 1:
		preview_texture.texture = imported_texture
		return
	if draft.crop_x < 0 or draft.crop_y < 0:
		preview_texture.texture = imported_texture
		return
	if draft.crop_x + draft.crop_width > draft.image_width or draft.crop_y + draft.crop_height > draft.image_height:
		preview_texture.texture = imported_texture
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = imported_texture
	atlas.region = Rect2(draft.crop_x, draft.crop_y, draft.crop_width, draft.crop_height)
	preview_texture.texture = atlas

func _install_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_import_callback = JavaScriptBridge.create_callback(_web_import_png)
	_web_import_error_callback = JavaScriptBridge.create_callback(_web_import_error)
	_web_reset_callback = JavaScriptBridge.create_callback(_web_reset)
	_web_set_crop_callback = JavaScriptBridge.create_callback(_web_set_crop)
	_web_set_scale_callback = JavaScriptBridge.create_callback(_web_set_scale)
	var window = JavaScriptBridge.get_interface("window")
	window.customFighterCreatorVfxImportPng = _web_import_callback
	window.customFighterCreatorVfxImportError = _web_import_error_callback
	window.customFighterCreatorVfxReset = _web_reset_callback
	window.customFighterCreatorVfxSetCrop = _web_set_crop_callback
	window.customFighterCreatorVfxSetScale = _web_set_scale_callback

func _web_import_png(args: Array) -> void:
	if args.size() < 3:
		_import_failed("PNG bridge requires name, MIME type and data URL")
		return
	_import_png_data(str(args[0]), str(args[1]).strip_edges().to_lower(), str(args[2]))

func _web_import_error(args: Array) -> void:
	_import_failed(str(args[0]) if not args.is_empty() else "Browser PNG import failed")

func _web_reset(_args: Array) -> void:
	_on_reset_pressed()

func _web_set_crop(args: Array) -> void:
	if args.size() < 4:
		return
	draft.crop_x = int(args[0])
	draft.crop_y = int(args[1])
	draft.crop_width = int(args[2])
	draft.crop_height = int(args[3])
	_sync_controls_from_draft()
	draft_revision += 1
	_refresh_validation(false)

func _web_set_scale(args: Array) -> void:
	if args.is_empty():
		return
	draft.scale = float(args[0])
	_sync_controls_from_draft()
	draft_revision += 1
	_refresh_validation(false)

func _set_web_state(errors: PackedStringArray = PackedStringArray()) -> void:
	if not OS.has_feature("web"):
		return
	var current_errors := errors
	if current_errors.is_empty() and not draft.is_valid():
		current_errors = draft.validate()
	var error_text := import_error
	if error_text.is_empty() and not current_errors.is_empty():
		error_text = " | ".join(current_errors)
	var valid := imported and error_text.is_empty()
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorVfxReady='true';" +
		"document.documentElement.dataset.creatorVfxRevision='%d';" % draft_revision +
		"document.documentElement.dataset.creatorVfxImported='%s';" % ("true" if imported else "false") +
		"document.documentElement.dataset.creatorVfxValid='%s';" % ("true" if valid else "false") +
		"document.documentElement.dataset.creatorVfxFileName=%s;" % JSON.stringify(draft.file_name) +
		"document.documentElement.dataset.creatorVfxMime=%s;" % JSON.stringify(draft.mime_type) +
		"document.documentElement.dataset.creatorVfxWidth='%d';" % draft.image_width +
		"document.documentElement.dataset.creatorVfxHeight='%d';" % draft.image_height +
		"document.documentElement.dataset.creatorVfxCropX='%d';" % draft.crop_x +
		"document.documentElement.dataset.creatorVfxCropY='%d';" % draft.crop_y +
		"document.documentElement.dataset.creatorVfxCropWidth='%d';" % draft.crop_width +
		"document.documentElement.dataset.creatorVfxCropHeight='%d';" % draft.crop_height +
		"document.documentElement.dataset.creatorVfxScale='%.3f';" % draft.scale +
		"document.documentElement.dataset.creatorVfxOffsetX='%.3f';" % draft.offset_x +
		"document.documentElement.dataset.creatorVfxOffsetY='%.3f';" % draft.offset_y +
		"document.documentElement.dataset.creatorVfxFps='%.3f';" % draft.fps +
		"document.documentElement.dataset.creatorVfxError=%s;" % JSON.stringify(error_text)
	)
