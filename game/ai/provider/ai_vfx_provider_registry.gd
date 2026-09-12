class_name AiVfxProviderRegistry
extends RefCounted

var providers: Dictionary = {}
var active_id := ""

func register_provider(provider: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if provider == null:
		errors.append("provider must not be null")
		return errors
	if not provider.has_method("provider_id") or not provider.has_method("capabilities") or not provider.has_method("generate"):
		errors.append("provider does not satisfy the AI VFX provider contract")
		return errors
	var id := str(provider.call("provider_id")).strip_edges().to_lower()
	if not _safe_token(id):
		errors.append("provider_id must be a safe lowercase reference token")
		return errors
	if providers.has(id):
		errors.append("provider_id is already registered")
		return errors
	var caps: Variant = provider.call("capabilities")
	if not (caps is Dictionary):
		errors.append("provider capabilities must be a dictionary")
		return errors
	providers[id] = provider
	if active_id.is_empty():
		active_id = id
	return errors

func set_active_provider(provider_id: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var id := provider_id.strip_edges().to_lower()
	if not providers.has(id):
		errors.append("provider_id is not registered")
		return errors
	active_id = id
	return errors

func active_provider_id() -> String:
	return active_id

func registered_provider_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in providers.keys():
		ids.append(str(key))
	ids.sort()
	return ids

func active_capabilities() -> Dictionary:
	var provider: Variant = providers.get(active_id)
	if provider == null:
		return {}
	var caps: Variant = provider.call("capabilities")
	return caps.duplicate(true) if caps is Dictionary else {}

func generate(request: Variant) -> Variant:
	var provider: Variant = providers.get(active_id)
	if provider == null:
		return null
	return provider.call("generate", request)

func _safe_token(value: String) -> bool:
	if value.is_empty() or value.length() > 80:
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	return regex.search(value) != null
