extends "res://game/creator/creator_preview_studio.gd"

const CharacterPackageDefinitionScript = preload("res://game/core/package/character_package_definition.gd")
const SkillRegistryScript = preload("res://game/core/skills/skill_registry.gd")
const SkillDefinitionScript = preload("res://game/core/skills/skill_definition.gd")
const CharacterDraftScript = preload("res://game/creator/character_editor/character_draft.gd")
const SkillDraftScript = preload("res://game/creator/skill_editor/skill_draft.gd")

const MAX_PACKAGE_JSON_BYTES := 8 * 1024 * 1024
const APPROVED_PREVIEW_VISUAL := "prototype_fireball"
const APPROVED_PREVIEW_IMPACT_VISUAL := "prototype_impact"

var package_status_label: Label
var package_export_button: Button
var package_import_button: Button
var _package_export_count := 0
var _package_import_count := 0
var _package_import_status := "idle"
var _package_import_error := ""
var _last_export_json := ""
var _web_export_package_callback
var _web_import_package_json_callback
var _web_open_package_file_callback
var _web_package_file_error_callback

func _ready() -> void:
	super()
	_install_package_ui()
	_install_package_web_bridge()
	_set_package_web_state()

func _install_package_ui() -> void:
	package_export_button = Button.new()
	package_export_button.text = "Export Package"
	package_export_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	package_export_button.offset_left = 202.0
	package_export_button.offset_top = -72.0
	package_export_button.offset_right = 342.0
	package_export_button.offset_bottom = -28.0
	package_export_button.pressed.connect(_on_export_package_pressed)
	add_child(package_export_button)

	package_import_button = Button.new()
	package_import_button.text = "Import Package"
	package_import_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	package_import_button.offset_left = 352.0
	package_import_button.offset_top = -72.0
	package_import_button.offset_right = 492.0
	package_import_button.offset_bottom = -28.0
	package_import_button.pressed.connect(_on_import_package_pressed)
	add_child(package_import_button)

	package_status_label = Label.new()
	package_status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	package_status_label.offset_left = 502.0
	package_status_label.offset_top = -70.0
	package_status_label.offset_right = 624.0
	package_status_label.offset_bottom = -30.0
	package_status_label.text = "JSON package"
	package_status_label.modulate = Color("8fa1c6")
	package_status_label.clip_text = true
	add_child(package_status_label)

func _install_package_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_export_package_callback = JavaScriptBridge.create_callback(_web_export_package)
	_web_import_package_json_callback = JavaScriptBridge.create_callback(_web_import_package_json)
	_web_open_package_file_callback = JavaScriptBridge.create_callback(_web_open_package_file)
	_web_package_file_error_callback = JavaScriptBridge.create_callback(_web_package_file_error)
	var window: Variant = JavaScriptBridge.get_interface("window")
	window.customFighterCreatorExportPackage = _web_export_package_callback
	window.customFighterCreatorImportPackageJson = _web_import_package_json_callback
	window.customFighterCreatorOpenPackageFile = _web_open_package_file_callback
	window.customFighterCreatorPackageFileError = _web_package_file_error_callback

func _on_export_package_pressed() -> void:
	var build_result: Dictionary = _build_export_package()
	var errors: PackedStringArray = build_result.get("errors", PackedStringArray())
	if not errors.is_empty():
		_set_package_error("EXPORT BLOCKED · %s" % " | ".join(errors))
		return

	var package_data: Dictionary = build_result.get("data", {})
	var json_text: String = JSON.stringify(package_data, "  ", true)
	var byte_count: int = json_text.to_utf8_buffer().size()
	if byte_count <= 0 or byte_count > MAX_PACKAGE_JSON_BYTES:
		_set_package_error("EXPORT BLOCKED · JSON exceeds package size limit")
		return

	_last_export_json = json_text
	_package_export_count += 1
	_package_import_error = ""
	if package_status_label != null:
		package_status_label.text = "Exported #%d" % _package_export_count
		package_status_label.modulate = Color("7ff0b1")

	if OS.has_feature("web"):
		var package_id: String = str(package_data.get("package_id", "character"))
		var filename: String = "%s.custom-fighter.json" % package_id
		var script: String = (
			"(()=>{const text=%s;const name=%s;window.customFighterLastPackageJson=text;" +
			"const blob=new Blob([text],{type:'application/json;charset=utf-8'});" +
			"const url=URL.createObjectURL(blob);const a=document.createElement('a');" +
			"a.href=url;a.download=name;document.body.appendChild(a);a.click();a.remove();" +
			"setTimeout(()=>URL.revokeObjectURL(url),0);})();"
		) % [JSON.stringify(json_text), JSON.stringify(filename)]
		JavaScriptBridge.eval(script)
	_set_package_web_state()

func _on_import_package_pressed() -> void:
	if not OS.has_feature("web"):
		_set_package_error("IMPORT BLOCKED · Web JSON file picker is unavailable")
		return
	JavaScriptBridge.eval(
		"(()=>{const input=document.createElement('input');input.type='file';" +
		"input.accept='.json,application/json';input.style.display='none';" +
		"input.onchange=()=>{const file=input.files&&input.files[0];if(!file){input.remove();return;}" +
		"if(file.size>%d){window.customFighterCreatorPackageFileError('Package exceeds 8 MB limit');input.remove();return;}" % MAX_PACKAGE_JSON_BYTES +
		"const reader=new FileReader();reader.onload=()=>{window.customFighterCreatorImportPackageJson(String(reader.result||''));input.remove();};" +
		"reader.onerror=()=>{window.customFighterCreatorPackageFileError('Package file could not be read');input.remove();};" +
		"reader.readAsText(file,'utf-8');};document.body.appendChild(input);input.click();})();"
	)

func _build_export_package() -> Dictionary:
	var errors := PackedStringArray()
	var character_errors: PackedStringArray = _validate_character_authoring()
	var skill_errors: PackedStringArray = skill_draft.validate()
	for error in character_errors:
		errors.append("character: %s" % error)
	for error in skill_errors:
		errors.append("skill_1: %s" % error)
	if not errors.is_empty():
		return {"errors": errors, "data": {}}

	var character_data: Dictionary = character_draft.to_dictionary()
	var slots: Dictionary = character_data.get("skill_slots", {}).duplicate(true)
	slots["skill_1"] = str(skill_draft.skill_id).strip_edges().to_lower()
	character_data["skill_slots"] = slots

	var registry := SkillRegistryScript.new()
	var registry_errors: PackedStringArray = registry.load_default()
	for error in registry_errors:
		errors.append("skill registry: %s" % error)
	if not errors.is_empty():
		return {"errors": errors, "data": {}}

	var skills: Array = [skill_draft.to_dictionary()]
	for slot_index in range(2, 7):
		var slot_name: String = "skill_%d" % slot_index
		var skill_id: String = str(slots.get(slot_name, ""))
		var expected_type: String = registry.registered_type_for_id(skill_id)
		if expected_type.is_empty():
			errors.append("%s references an unknown production skill: %s" % [slot_name, skill_id])
			continue
		var definition := SkillDefinitionScript.new()
		var load_errors: PackedStringArray = registry.load_skill(skill_id, expected_type, definition)
		for error in load_errors:
			errors.append("%s: %s" % [slot_name, error])
		if load_errors.is_empty():
			skills.append(_skill_definition_to_dictionary(definition))

	if not errors.is_empty():
		return {"errors": errors, "data": {}}

	var package_input: Dictionary = {
		"schema_version": CharacterPackageDefinitionScript.CURRENT_SCHEMA_VERSION,
		"package_id": str(character_data.get("id", "")),
		"package_version": 1,
		"character": character_data,
		"skills": skills
	}
	var package := CharacterPackageDefinitionScript.new()
	var package_errors: PackedStringArray = package.load_from_dictionary(package_input)
	for error in package_errors:
		errors.append("package: %s" % error)
	return {
		"errors": errors,
		"data": package.to_dictionary() if errors.is_empty() else {}
	}

func _import_package_json(json_text: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var byte_count: int = json_text.to_utf8_buffer().size()
	if byte_count <= 0:
		errors.append("package JSON must not be empty")
		return errors
	if byte_count > MAX_PACKAGE_JSON_BYTES:
		errors.append("package JSON exceeds 8 MB limit")
		return errors

	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		errors.append("package JSON must contain one object")
		return errors

	var package := CharacterPackageDefinitionScript.new()
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

	var character_data: Dictionary = package.character_data.duplicate(true)
	var slots: Dictionary = character_data.get("skill_slots", {})
	var skill_1_id: String = str(slots.get("skill_1", ""))
	var skill_1_data: Dictionary = package.skill_data_by_id.get(skill_1_id, {}).duplicate(true)

	var candidate_character := CharacterDraftScript.new()
	var candidate_character_errors: PackedStringArray = candidate_character.load_from_dictionary(character_data)
	var candidate_skill := SkillDraftScript.new()
	var candidate_skill_errors: PackedStringArray = candidate_skill.load_from_dictionary(skill_1_data)
	for error in candidate_character_errors:
		errors.append("character draft: %s" % error)
	for error in candidate_skill_errors:
		errors.append("skill_1 draft: %s" % error)
	if not errors.is_empty():
		return errors

	var session: Variant = get_node_or_null("/root/CreatorPreviewSession")
	if session == null or not session.has_method("store_drafts"):
		errors.append("Creator preview session is unavailable")
		return errors

	var store_errors: PackedStringArray = session.call("store_drafts", character_data, skill_1_data)
	for error in store_errors:
		errors.append("preview session: %s" % error)
	if not errors.is_empty():
		return errors

	if session.has_method("clear_vfx_draft"):
		session.call("clear_vfx_draft")
	_clear_audio_asset("")

	var apply_character_errors: PackedStringArray = character_draft.load_from_dictionary(character_data)
	var apply_skill_errors: PackedStringArray = skill_draft.load_from_dictionary(skill_1_data)
	var apply_animation_errors: PackedStringArray = animation_draft.load_from_id(character_draft.animation_map) if apply_character_errors.is_empty() else PackedStringArray()
	if not apply_character_errors.is_empty() or not apply_skill_errors.is_empty() or not apply_animation_errors.is_empty():
		errors.append("validated package failed to apply to Creator drafts")
		return errors
	if session.has_method("store_animation_map_draft"):
		var animation_store_errors: PackedStringArray = session.call("store_animation_map_draft", animation_draft.to_dictionary())
		for error in animation_store_errors:
			errors.append("animation draft: %s" % error)
	if not errors.is_empty():
		return errors

	_sync_character_controls_from_draft()
	_sync_skill_controls_from_draft()
	_refresh_character_validation(false)
	_refresh_skill_validation(false)
	_refresh_preview_binding_status()
	_package_import_count += 1
	_package_import_status = "valid"
	_package_import_error = ""
	if package_status_label != null:
		package_status_label.text = "Imported #%d" % _package_import_count
		package_status_label.modulate = Color("7ff0b1")
	_set_web_state()
	return PackedStringArray()

func _validate_creator_import_compatibility(package: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	var character_data: Dictionary = package.character_data
	var slots: Dictionary = character_data.get("skill_slots", {})
	var skill_1_id: String = str(slots.get("skill_1", ""))
	var skill_1_data: Dictionary = package.skill_data_by_id.get(skill_1_id, {})
	var candidate_skill := SkillDraftScript.new()
	var candidate_skill_errors: PackedStringArray = candidate_skill.load_from_dictionary(skill_1_data)
	for error in candidate_skill_errors:
		errors.append("skill_1 is not Creator-compatible: %s" % error)
	if candidate_skill_errors.is_empty():
		if candidate_skill.visual != APPROVED_PREVIEW_VISUAL:
			errors.append("skill_1 visual is not approved for Creator preview")
		if candidate_skill.impact_visual != APPROVED_PREVIEW_IMPACT_VISUAL:
			errors.append("skill_1 impact visual is not approved for Creator preview")

	var registry := SkillRegistryScript.new()
	var registry_errors: PackedStringArray = registry.load_default()
	for error in registry_errors:
		errors.append("skill registry: %s" % error)
	if not registry_errors.is_empty():
		return errors

	for slot_index in range(2, 7):
		var slot_name: String = "skill_%d" % slot_index
		var skill_id: String = str(slots.get(slot_name, ""))
		var expected_type: String = registry.registered_type_for_id(skill_id)
		if expected_type.is_empty():
			errors.append("%s must reference an approved production skill" % slot_name)
			continue
		var canonical_skill := SkillDefinitionScript.new()
		var load_errors: PackedStringArray = registry.load_skill(skill_id, expected_type, canonical_skill)
		for error in load_errors:
			errors.append("%s: %s" % [slot_name, error])
		if not load_errors.is_empty():
			continue
		var imported_skill: Dictionary = package.skill_data_by_id.get(skill_id, {})
		var canonical_data: Dictionary = _skill_definition_to_dictionary(canonical_skill)
		if JSON.stringify(imported_skill, "", true) != JSON.stringify(canonical_data, "", true):
			errors.append("%s packaged skill must match the approved production definition" % slot_name)
	return errors

func _skill_definition_to_dictionary(skill: Variant) -> Dictionary:
	var data := {
		"schema_version": skill.schema_version,
		"id": skill.skill_id,
		"name": skill.skill_name,
		"type": skill.skill_type,
		"damage": skill.damage,
		"mp_cost": skill.mp_cost,
		"cooldown": skill.cooldown,
		"startup": skill.startup,
		"active": skill.active,
		"recovery": skill.recovery,
		"speed": skill.speed,
		"range": skill.range,
		"hitstun": skill.hitstun,
		"knockback": skill.knockback,
		"hitbox_half_width": skill.hitbox_half_width,
		"hitbox_half_depth": skill.hitbox_half_depth,
		"formation_count": skill.formation_count,
		"formation_spacing": skill.formation_spacing,
		"formation_interval": skill.formation_interval,
		"formation_offset": skill.formation_offset,
		"buff_duration": skill.buff_duration,
		"move_speed_multiplier": skill.move_speed_multiplier,
		"basic_attack_damage_multiplier": skill.basic_attack_damage_multiplier,
		"visual": skill.visual,
		"impact_visual": skill.impact_visual
	}
	if skill.skill_type == "trap":
		data["trap_duration"] = skill.trap_duration
	if skill.skill_type == "aura":
		data["aura_duration"] = skill.aura_duration
	if skill.has_timeline():
		var timeline_events: Array = []
		for event in skill.timeline_events:
			timeline_events.append(event.duplicate(true))
		data["timeline"] = {
			"schema_version": skill.timeline_schema_version,
			"events": timeline_events
		}
	return data

func _web_export_package(_args: Array) -> void:
	_on_export_package_pressed()

func _web_open_package_file(_args: Array) -> void:
	_on_import_package_pressed()

func _web_import_package_json(args: Array) -> void:
	if args.is_empty():
		_set_package_error("IMPORT BLOCKED · package JSON argument is missing")
		return
	var errors: PackedStringArray = _import_package_json(str(args[0]))
	if not errors.is_empty():
		_set_package_error("IMPORT BLOCKED · %s" % " | ".join(errors))

func _web_package_file_error(args: Array) -> void:
	var message: String = "Package file could not be read" if args.is_empty() else str(args[0])
	_set_package_error("IMPORT BLOCKED · %s" % message)

func _set_package_error(message: String) -> void:
	_package_import_status = "invalid"
	_package_import_error = message
	if package_status_label != null:
		package_status_label.text = "Package blocked"
		package_status_label.modulate = Color("ff7b86")
	_set_package_web_state()

func _set_web_state(character_errors: PackedStringArray = PackedStringArray(), skill_errors: PackedStringArray = PackedStringArray()) -> void:
	super(character_errors, skill_errors)
	_set_package_web_state()

func _set_package_web_state() -> void:
	if not OS.has_feature("web"):
		return
	var can_export: bool = _validate_character_authoring().is_empty() and skill_draft.is_valid()
	JavaScriptBridge.eval(
		"document.documentElement.dataset.creatorPackageReady='true';" +
		"document.documentElement.dataset.creatorPackageCanExport='%s';" % ("true" if can_export else "false") +
		"document.documentElement.dataset.creatorPackageExportCount='%d';" % _package_export_count +
		"document.documentElement.dataset.creatorPackageImportCount='%d';" % _package_import_count +
		"document.documentElement.dataset.creatorPackageImportStatus=%s;" % JSON.stringify(_package_import_status) +
		"document.documentElement.dataset.creatorPackageImportError=%s;" % JSON.stringify(_package_import_error) +
		"document.documentElement.dataset.creatorPackageLastExportBytes='%d';" % _last_export_json.to_utf8_buffer().size()
	)
