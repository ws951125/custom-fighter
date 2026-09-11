class_name CombatBox
extends RefCounted

var center: Vector2
var half_extents: Vector2

func _init(initial_center: Vector2 = Vector2.ZERO, initial_half_extents: Vector2 = Vector2.ZERO) -> void:
	center = initial_center
	half_extents = Vector2(maxf(0.0, initial_half_extents.x), maxf(0.0, initial_half_extents.y))

func overlaps(other: CombatBox) -> bool:
	return (
		absf(center.x - other.center.x) <= half_extents.x + other.half_extents.x
		and absf(center.y - other.center.y) <= half_extents.y + other.half_extents.y
	)

func left() -> float:
	return center.x - half_extents.x

func right() -> float:
	return center.x + half_extents.x

func top() -> float:
	return center.y - half_extents.y

func bottom() -> float:
	return center.y + half_extents.y
