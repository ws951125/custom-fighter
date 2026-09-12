class_name BuffState
extends RefCounted

var active := false
var remaining := 0.0
var duration := 0.0
var move_speed_multiplier := 1.0
var basic_attack_damage_multiplier := 1.0
var activation_count := 0

func start(buff_duration: float, move_multiplier: float, attack_multiplier: float) -> bool:
	if buff_duration <= 0.0:
		return false
	if move_multiplier < 1.0 or attack_multiplier < 1.0:
		return false

	duration = buff_duration
	remaining = buff_duration
	move_speed_multiplier = move_multiplier
	basic_attack_damage_multiplier = attack_multiplier
	active = true
	activation_count += 1
	return true

func tick(delta: float) -> void:
	if not active:
		return
	remaining = maxf(0.0, remaining - maxf(0.0, delta))
	if remaining <= 0.0:
		deactivate()

func deactivate() -> void:
	active = false
	remaining = 0.0
	move_speed_multiplier = 1.0
	basic_attack_damage_multiplier = 1.0

func movement_multiplier() -> float:
	return move_speed_multiplier if active else 1.0

func attack_multiplier() -> float:
	return basic_attack_damage_multiplier if active else 1.0
