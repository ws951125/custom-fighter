class_name AiVfxProviderConfig
extends RefCounted

const DEFAULT_PROVIDER_ID := "mock_ai_vfx"
const REMOTE_PROVIDER_ID := "remote_ai_vfx"

var provider_id := DEFAULT_PROVIDER_ID
var remote_endpoint := ""

func load_from_environment() -> PackedStringArray:
	provider_id = OS.get_environment("CUSTOM_FIGHTER_AI_VFX_PROVIDER").strip_edges().to_lower()
	if provider_id.is_empty():
		provider_id = DEFAULT_PROVIDER_ID
	remote_endpoint = OS.get_environment("CUSTOM_FIGHTER_AI_VFX_ENDPOINT").strip_edges()
	return validate()

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if provider_id != DEFAULT_PROVIDER_ID and provider_id != REMOTE_PROVIDER_ID:
		errors.append("provider_id must be mock_ai_vfx or remote_ai_vfx")
	if provider_id == REMOTE_PROVIDER_ID:
		if remote_endpoint.is_empty():
			errors.append("remote AI VFX provider requires CUSTOM_FIGHTER_AI_VFX_ENDPOINT")
		elif not _is_safe_https_endpoint(remote_endpoint):
			errors.append("remote AI VFX endpoint must be an https URL without embedded credentials")
	return errors

func _is_safe_https_endpoint(value: String) -> bool:
	if not value.begins_with("https://"):
		return false
	if value.length() > 2048:
		return false
	var remainder := value.substr("https://".length())
	var slash_index := remainder.find("/")
	var authority := remainder if slash_index < 0 else remainder.substr(0, slash_index)
	if authority.is_empty() or authority.contains("@"):
		return false
	return true
