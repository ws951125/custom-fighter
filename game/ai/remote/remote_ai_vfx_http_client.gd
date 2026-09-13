class_name RemoteAiVfxHttpClient
extends RefCounted

const DEFAULT_TIMEOUT_SECONDS := 90.0
const MAX_RESPONSE_BYTES := 8 * 1024 * 1024

func post_json(host: Node, endpoint: String, payload: Dictionary) -> Dictionary:
	if host == null or not host.is_inside_tree():
		return {"ok": false, "error": "remote AI VFX HTTP host must be inside the scene tree"}
	if endpoint.is_empty() or not endpoint.begins_with("https://"):
		return {"ok": false, "error": "remote AI VFX endpoint must use https"}
	var request := HTTPRequest.new()
	request.timeout = DEFAULT_TIMEOUT_SECONDS
	host.add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var body := JSON.stringify(payload)
	var start_error: Error = request.request(endpoint, headers, HTTPClient.METHOD_POST, body)
	if start_error != OK:
		request.queue_free()
		return {"ok": false, "error": "remote AI VFX request could not start: %s" % error_string(start_error)}
	var completed: Array = await request.request_completed
	request.queue_free()
	if completed.size() < 4:
		return {"ok": false, "error": "remote AI VFX request returned an incomplete transport result"}
	var transport_result := int(completed[0])
	var response_code := int(completed[1])
	var response_body: PackedByteArray = completed[3]
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "remote AI VFX transport failed with result %d" % transport_result}
	if response_code < 200 or response_code >= 300:
		return {"ok": false, "error": "remote AI VFX backend returned HTTP %d" % response_code}
	if response_body.is_empty():
		return {"ok": false, "error": "remote AI VFX backend returned an empty response"}
	if response_body.size() > MAX_RESPONSE_BYTES:
		return {"ok": false, "error": "remote AI VFX backend response exceeds safe size limit"}
	var response_text := response_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)
	if not (parsed is Dictionary):
		return {"ok": false, "error": "remote AI VFX backend response must be a JSON object"}
	return (parsed as Dictionary).duplicate(true)
