class_name CombatantState
extends RefCounted

var max_hp: int
var hp: int
var max_mp: int
var mp: int
var hitstun_remaining := 0.0

func _init(initial_max_hp: int = 100, initial_max_mp: int = 100) -> void:
	max_hp = maxi(1, initial_max_hp)
	max_mp = maxi(0, initial_max_mp)
	hp = max_hp
	mp = max_mp

func apply_damage(amount: int, guarding: bool = false) -> int:
	var final_damage := maxi(0, amount)
	if guarding:
		final_damage = ceili(float(final_damage) * 0.35)

	var dealt := mini(hp, final_damage)
	hp -= dealt
	return dealt

func restore_hp(amount: int) -> int:
	var before := hp
	hp = mini(max_hp, hp + maxi(0, amount))
	return hp - before

func spend_mp(cost: int) -> bool:
	var safe_cost := maxi(0, cost)
	if mp < safe_cost:
		return false
	mp -= safe_cost
	return true

func restore_mp(amount: int) -> int:
	var before := mp
	mp = mini(max_mp, mp + maxi(0, amount))
	return mp - before

func apply_hitstun(seconds: float) -> void:
	hitstun_remaining = maxf(hitstun_remaining, maxf(0.0, seconds))

func tick(delta: float) -> void:
	hitstun_remaining = maxf(0.0, hitstun_remaining - maxf(0.0, delta))

func is_defeated() -> bool:
	return hp <= 0
