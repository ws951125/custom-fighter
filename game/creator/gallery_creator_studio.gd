extends "res://game/creator/timeline_creator_studio.gd"

# WU5 read-side Gallery: only same-origin-approved Render API. No publisher credentials
# are collected or persisted while the dedicated Free provider remains unprovisioned.
const GALLERY_API := "https://custom-fighter-ai-vfx-6899.onrender.com/v1/sharing/publications"
const MAX_GALLERY_PACKAGE_BYTES := 16 * 1024 * 1024
const MAX_GALLERY_QUERY := 80
const MAX_GALLERY_RECORDS := 50

var gallery_open_button: Button
var gallery_overlay: ColorRect
var gallery_query: LineEdit
var gallery_items: ItemList
var gallery_info: Label
var gallery_status: Label
var gallery_revision: OptionButton
var gallery_import_button: Button
var gallery_next_button: Button
var gallery_request: HTTPRequest
var gallery_confirm: ConfirmationDialog

var _gallery_records: Array = []
var _gallery_cursor := ""
var _gallery_publication_id := ""
var _gallery_manifest: Dictionary = {}
var _gallery_pending := ""
var _gallery_requested_revision := 0
var _gallery_last_status := "idle"
var _gallery_import_status := "idle"
var _gallery_web_open_callback
var _gallery_web_select_callback
var _gallery_web_confirm_import_callback

func _ready() -> void:
	super()
	_install_gallery_ui()
	_set_gallery_web_state()

func _install_gallery_ui() -> void:
	gallery_open_button = Button.new()
	gallery_open_button.text = "Creator Gallery"
	gallery_open_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gallery_open_button.offset_left = -188.0
	gallery_open_button.offset_right = -24.0
	gallery_open_button.offset_top = 74.0
	gallery_open_button.offset_bottom = 112.0
	gallery_open_button.disabled = not OS.has_feature("web")
	gallery_open_button.pressed.connect(_gallery_open)
	add_child(gallery_open_button)

	gallery_overlay = ColorRect.new()
	gallery_overlay.color = Color(0.035, 0.05, 0.10, 0.96)
	gallery_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gallery_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	gallery_overlay.visible = false
	add_child(gallery_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 26.0
	panel.offset_right = -26.0
	panel.offset_top = 18.0
	panel.offset_bottom = -18.0
	gallery_overlay.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	panel.add_child(body)

	var header := HBoxContainer.new()
	body.add_child(header)
	var title := Label.new()
	title.text = "Creator Gallery · Safe package catalog"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_gallery_close)
	header.add_child(close_button)

	var search_row := HBoxContainer.new()
	body.add_child(search_row)
	gallery_query = LineEdit.new()
	gallery_query.placeholder_text = "Search title / package / tags (80 characters max)"
	gallery_query.max_length = MAX_GALLERY_QUERY
	gallery_query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery_query.text_submitted.connect(_gallery_search_submitted)
	search_row.add_child(gallery_query)
	var search_button := Button.new()
	search_button.text = "Search"
	search_button.pressed.connect(_gallery_search)
	search_row.add_child(search_button)
	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_gallery_search)
	search_row.add_child(refresh_button)

	gallery_status = Label.new()
	gallery_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(gallery_status)
	gallery_items = ItemList.new()
	gallery_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gallery_items.custom_minimum_size = Vector2(0, 130)
	gallery_items.item_selected.connect(_gallery_select)
	body.add_child(gallery_items)
	gallery_next_button = Button.new()
	gallery_next_button.text = "Next 20"
	gallery_next_button.disabled = true
	gallery_next_button.pressed.connect(_gallery_next)
	body.add_child(gallery_next_button)

	gallery_info = Label.new()
	gallery_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gallery_info.text = "Select a publication to view its immutable revisions."
	body.add_child(gallery_info)
	var revision_row := HBoxContainer.new()
	body.add_child(revision_row)
	var revision_label := Label.new()
	revision_label.text = "Revision"
	revision_row.add_child(revision_label)
	gallery_revision = OptionButton.new()
	gallery_revision.disabled = true
	revision_row.add_child(gallery_revision)
	gallery_import_button = Button.new()
	gallery_import_button.text = "Download & Import Selected Revision"
	gallery_import_button.disabled = true
	gallery_import_button.pressed.connect(_gallery_confirm_import)
	revision_row.add_child(gallery_import_button)

	var publish_note := Label.new()
	publish_note.text = "Publish requires verified sign-in and a dedicated Free storage project; not enabled yet."
	publish_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	publish_note.modulate = Color("a9b8d8")
	body.add_child(publish_note)
	var publish_button := Button.new()
	publish_button.text = "Publish (not configured)"
	publish_button.disabled = true
	publish_button.tooltip_text = "Production publisher Auth and dedicated persistence must be separately authorized."
	body.add_child(publish_button)

	gallery_confirm = ConfirmationDialog.new()
	gallery_confirm.title = "Import Gallery package?"
	gallery_confirm.dialog_text = "The downloaded revision will be verified, then replace the current Creator draft. Continue?"
	gallery_confirm.confirmed.connect(_gallery_download_import)
	gallery_confirm.visibility_changed.connect(_set_gallery_web_state)
	add_child(gallery_confirm)

	gallery_request = HTTPRequest.new()
	gallery_request.body_size_limit = MAX_GALLERY_PACKAGE_BYTES
	gallery_request.timeout = 20.0
	gallery_request.request_completed.connect(_gallery_request_completed)
	add_child(gallery_request)

	if OS.has_feature("web"):
		_gallery_web_open_callback = JavaScriptBridge.create_callback(_gallery_web_open)
		var window: Variant = JavaScriptBridge.get_interface("window")
		window.customFighterCreatorOpenGallery = _gallery_web_open_callback
		_gallery_web_select_callback = JavaScriptBridge.create_callback(_gallery_web_select)
		_gallery_web_confirm_import_callback = JavaScriptBridge.create_callback(_gallery_web_confirm_import)
		window.customFighterCreatorGallerySelect = _gallery_web_select_callback
		window.customFighterCreatorGalleryConfirmImport = _gallery_web_confirm_import_callback
	_gallery_status_update("idle", "Open Gallery to browse published metadata. No stored package is trusted automatically.")

func _gallery_web_open(_args: Array) -> void:
	_gallery_open()

func _gallery_web_select(args: Array) -> void:
	# JS numeric callback arguments can cross the Godot Web bridge as int or float.
	# This is diagnostic parity with the real ItemList item_selected signal.
	if args.is_empty() or not (args[0] is int or args[0] is float):
		return
	var index: int = int(args[0])
	if index >= 0 and float(index) == float(args[0]):
		_gallery_select(index)

func _gallery_web_confirm_import(_args: Array) -> void:
	# The test bridge invokes the same visible/cancellable action as the real button.
	# It must not bypass explicit confirmation and directly start a download.
	_gallery_confirm_import()

func _gallery_open() -> void:
	if not OS.has_feature("web"):
		return
	gallery_overlay.visible = true
	if _gallery_records.is_empty() and _gallery_pending.is_empty():
		_gallery_search()
	_set_gallery_web_state()

func _gallery_close() -> void:
	gallery_overlay.visible = false
	_set_gallery_web_state()

func _gallery_safe_publication_id(value: String) -> bool:
	if value.length() != 36 or not value.begins_with("pub_"):
		return false
	for character in value.substr(4):
		if "0123456789abcdef".find(character) < 0:
			return false
	return true

func _gallery_positive_integer(raw: Variant, maximum: int) -> int:
	# JSON.parse_string can represent integer-looking JSON numbers as floats.
	# Reject fractions, strings, negative values, and out-of-range values.
	if not (raw is int or raw is float):
		return -1
	var value: int = int(raw)
	if value < 1 or value > maximum or float(value) != float(raw):
		return -1
	return value

func _gallery_search_submitted(_value: String) -> void:
	_gallery_search()

func _gallery_search() -> void:
	if not _gallery_pending.is_empty():
		return
	_gallery_cursor = ""
	_gallery_records.clear()
	_gallery_publication_id = ""
	_gallery_manifest.clear()
	gallery_items.clear()
	gallery_revision.clear()
	gallery_revision.disabled = true
	gallery_import_button.disabled = true
	gallery_info.text = "Select a publication to view its immutable revisions."
	_gallery_browse("")

func _gallery_next() -> void:
	if _gallery_cursor.is_empty() or not _gallery_pending.is_empty():
		return
	_gallery_browse(_gallery_cursor)

func _gallery_browse(cursor: String) -> void:
	var query := gallery_query.text.strip_edges()
	if query.length() > MAX_GALLERY_QUERY:
		_gallery_status_update("blocked", "Search is limited to 80 characters.")
		return
	var url := GALLERY_API + "?limit=20&q=" + query.uri_encode()
	if not cursor.is_empty():
		url += "&cursor=" + cursor.uri_encode()
	_gallery_send("browse", url)

func _gallery_select(index: int) -> void:
	if not _gallery_pending.is_empty() or index < 0 or index >= _gallery_records.size():
		return
	var record: Variant = _gallery_records[index]
	if not record is Dictionary:
		return
	var publication_id := str(record.get("publication_id", ""))
	if not _gallery_safe_publication_id(publication_id):
		_gallery_status_update("blocked", "Catalog returned an invalid publication ID.")
		return
	_gallery_publication_id = publication_id
	_gallery_manifest.clear()
	gallery_revision.clear()
	gallery_revision.disabled = true
	gallery_import_button.disabled = true
	_gallery_send("detail", GALLERY_API + "/" + publication_id)

func _gallery_confirm_import() -> void:
	if gallery_overlay.visible and gallery_import_button != null and not gallery_import_button.disabled and _gallery_pending.is_empty() and _gallery_safe_publication_id(_gallery_publication_id) and gallery_revision.get_selected_id() > 0:
		gallery_confirm.popup_centered()
		_set_gallery_web_state()

func _gallery_download_import() -> void:
	if not _gallery_pending.is_empty() or not _gallery_safe_publication_id(_gallery_publication_id):
		return
	var revision := gallery_revision.get_selected_id()
	if revision <= 0:
		return
	_gallery_requested_revision = revision
	_gallery_import_status = "loading"
	_gallery_send("manifest", GALLERY_API + "/" + _gallery_publication_id + "/revisions/" + str(revision))

func _gallery_send(kind: String, url: String) -> void:
	if not _gallery_pending.is_empty():
		return
	_gallery_pending = kind
	gallery_import_button.disabled = true
	gallery_next_button.disabled = true
	_gallery_status_update("loading", "Gallery request in progress…")
	var err := gallery_request.request(url, PackedStringArray(["Accept: application/json"]), HTTPClient.METHOD_GET)
	if err != OK:
		_gallery_pending = ""
		_gallery_status_update("unavailable", "Gallery network request could not start.")
		_gallery_refresh_buttons()

func _gallery_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind := _gallery_pending
	_gallery_pending = ""
	if result != HTTPRequest.RESULT_SUCCESS:
		if kind == "manifest" or kind == "package":
			_gallery_import_status = "blocked"
		_gallery_status_update("unavailable", "Gallery request unavailable. Existing Creator drafts are unchanged.")
		_gallery_refresh_buttons()
		return
	if response_code != 200:
		if kind == "manifest" or kind == "package":
			_gallery_import_status = "blocked"
		_gallery_status_update("unavailable" if response_code == 503 else "error", "Gallery HTTP " + str(response_code) + ". No Creator data was changed.")
		_gallery_refresh_buttons()
		return
	if kind == "package":
		_gallery_accept_package(body)
		_gallery_refresh_buttons()
		return
	if body.size() > 262144:
		if kind == "manifest":
			_gallery_import_status = "blocked"
		_gallery_status_update("blocked", "Catalog metadata response exceeded the safety limit.")
		_gallery_refresh_buttons()
		return
	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not payload is Dictionary or payload.get("ok", false) != true:
		if kind == "manifest":
			_gallery_import_status = "blocked"
		_gallery_status_update("blocked", "Catalog returned an invalid response.")
		_gallery_refresh_buttons()
		return
	match kind:
		"browse":
			_gallery_accept_browse(payload)
		"detail":
			_gallery_accept_detail(payload)
		"manifest":
			_gallery_accept_manifest(payload)
		_:
			_gallery_status_update("blocked", "Unexpected Gallery response.")
	_gallery_refresh_buttons()

func _gallery_accept_browse(payload: Dictionary) -> void:
	var items: Variant = payload.get("items")
	if not items is Array or items.size() > MAX_GALLERY_RECORDS:
		_gallery_status_update("blocked", "Catalog page was invalid.")
		return
	for item in items:
		if not item is Dictionary or not _gallery_safe_publication_id(str(item.get("publication_id", ""))):
			_gallery_status_update("blocked", "Catalog metadata contains an invalid publication.")
			return
	for item in items:
		_gallery_records.append(item)
		gallery_items.add_item(str(item.get("title", "Untitled")).substr(0, 80) + " · " + str(item.get("package_id", "")).substr(0, 100) + " · r" + str(item.get("revision", "?")))
	var next_cursor: Variant = payload.get("next_cursor")
	_gallery_cursor = ""
	if next_cursor is String:
		var safe_cursor: bool = str(next_cursor).length() <= 32
		for character in str(next_cursor):
			if not ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-".contains(character)):
				safe_cursor = false
				break
		if safe_cursor:
			_gallery_cursor = next_cursor
	_gallery_status_update("ready", "Loaded " + str(_gallery_records.size()) + " publication(s)." if not _gallery_records.is_empty() else "No publications found. The current Creator draft is unchanged.")

func _gallery_accept_detail(payload: Dictionary) -> void:
	var manifest: Variant = payload.get("manifest")
	var revisions: Variant = payload.get("revisions")
	if not manifest is Dictionary or not revisions is Array or str(manifest.get("publication_id", "")) != _gallery_publication_id or revisions.size() > 500:
		_gallery_status_update("blocked", "Publication details were invalid.")
		return
	_gallery_manifest = manifest.duplicate(true)
	gallery_revision.clear()
	for raw_revision in revisions:
		var revision_number: int = _gallery_positive_integer(raw_revision, 1000000)
		if revision_number < 1:
			gallery_revision.clear()
			_gallery_status_update("blocked", "Publication revision list was invalid.")
			return
		gallery_revision.add_item(str(revision_number), revision_number)
	if gallery_revision.item_count == 0:
		_gallery_status_update("blocked", "No accepted revisions were returned.")
		return
	gallery_revision.select(gallery_revision.item_count - 1)
	gallery_revision.disabled = false
	gallery_info.text = str(manifest.get("title", "Untitled")).substr(0, 80) + " · " + str(manifest.get("description", "")).substr(0, 500) + "\nPublisher: " + str(manifest.get("publisher_id", "")).substr(0, 96) + " · Latest: r" + str(manifest.get("revision", "?"))
	_gallery_status_update("ready", "Select an immutable revision, then explicitly confirm import.")

func _gallery_accept_manifest(payload: Dictionary) -> void:
	var manifest: Variant = payload.get("manifest")
	if not manifest is Dictionary or str(manifest.get("publication_id", "")) != _gallery_publication_id or _gallery_positive_integer(manifest.get("revision"), 1000000) != _gallery_requested_revision:
		_gallery_import_status = "blocked"
		_gallery_status_update("blocked", "Revision identity mismatch. No Creator data was changed.")
		return
	var digest := str(manifest.get("content_sha256", ""))
	var byte_size: int = _gallery_positive_integer(manifest.get("byte_size"), MAX_GALLERY_PACKAGE_BYTES)
	if digest.length() != 64 or byte_size < 1:
		_gallery_import_status = "blocked"
		_gallery_status_update("blocked", "Revision integrity metadata was invalid.")
		return
	for character in digest:
		if "0123456789abcdef".find(character) < 0:
			_gallery_import_status = "blocked"
			_gallery_status_update("blocked", "Revision SHA-256 was invalid.")
			return
	_gallery_manifest = manifest.duplicate(true)
	_gallery_send("package", GALLERY_API + "/" + _gallery_publication_id + "/revisions/" + str(_gallery_requested_revision) + "/package")

func _gallery_accept_package(body: PackedByteArray) -> void:
	if body.is_empty() or body.size() > MAX_GALLERY_PACKAGE_BYTES or body.size() != int(_gallery_manifest.get("byte_size", 0)):
		_gallery_import_status = "blocked"
		_gallery_status_update("blocked", "Downloaded package size mismatch. No Creator data was changed.")
		return
	var sha := HashingContext.new()
	if sha.start(HashingContext.HASH_SHA256) != OK or sha.update(body) != OK:
		_gallery_import_status = "blocked"
		_gallery_status_update("blocked", "Package digest verification unavailable.")
		return
	if sha.finish().hex_encode() != str(_gallery_manifest.get("content_sha256", "")):
		_gallery_import_status = "blocked"
		_gallery_status_update("blocked", "Package SHA-256 mismatch. Current draft was not changed.")
		return
	var json_text := body.get_string_from_utf8()
	if json_text.to_utf8_buffer() != body:
		_gallery_import_status = "blocked"
		_gallery_status_update("blocked", "Downloaded package is not valid UTF-8.")
		return
	# Use the existing Self-contained Package schema + Creator compatibility gate.
	# A Gallery manifest never becomes a PvP trusted package.
	var errors: PackedStringArray = _import_package_json(json_text)
	if not errors.is_empty():
		_gallery_import_status = "blocked"
		_gallery_status_update("blocked", "Package import rejected: " + " | ".join(errors).substr(0, 220))
		return
	_gallery_import_status = "valid"
	_gallery_status_update("imported", "Gallery revision r" + str(_gallery_requested_revision) + " imported through the existing Creator package validation path.")

func _gallery_refresh_buttons() -> void:
	gallery_next_button.disabled = not _gallery_pending.is_empty() or _gallery_cursor.is_empty()
	gallery_import_button.disabled = not _gallery_pending.is_empty() or not _gallery_safe_publication_id(_gallery_publication_id) or gallery_revision.item_count == 0
	_set_gallery_web_state()

func _gallery_status_update(state: String, detail: String) -> void:
	_gallery_last_status = state
	if gallery_status != null:
		gallery_status.text = detail
		gallery_status.modulate = Color("ff9a98") if state in ["unavailable", "blocked", "error"] else Color("a9b8d8")
	_set_gallery_web_state()

func _set_gallery_web_state() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorGalleryReady='true';" +
		"document.documentElement.dataset.creatorGalleryOpen='%s';" % ("true" if gallery_overlay != null and gallery_overlay.visible else "false") +
		"document.documentElement.dataset.creatorGalleryStatus=%s;" % JSON.stringify(_gallery_last_status) +
		"document.documentElement.dataset.creatorGalleryItems='%d';" % _gallery_records.size() +
		"document.documentElement.dataset.creatorGallerySelectedPublication=%s;" % JSON.stringify(_gallery_publication_id) +
		"document.documentElement.dataset.creatorGalleryImportStatus=%s;" % JSON.stringify(_gallery_import_status) +
		"document.documentElement.dataset.creatorGalleryConfirmationVisible='%s';" % ("true" if gallery_confirm != null and gallery_confirm.visible else "false")
	)
