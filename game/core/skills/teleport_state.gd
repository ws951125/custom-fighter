class_name TeleportState
extends RefCounted

var activation_count := 0
var last_start_x := 0.0
var last_destination_x := 0.0
var last_distance := 0.0
var last_direction := 1.0

func resolve(start_x: float, facing: float, requested_distance: float, min_x: float, max_x: float) -> bool:
	if requested_distance <= 0.0 or min_x >= max_x:
		return false
	var safe_start := clampf(start_x, min_x, max_x)
	var direction := 1.0 if facing >= 0.0 else -1.0
	var destination := clampf(safe_start + direction * requested_distance, min_x, max_x)
	last_start_x = safe_start
	last_destination_x = destination
	last_distance = absf(destination - safe_start)
	last_direction = direction
	activation_count += 1
	return true
