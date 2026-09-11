class_name CombatMath
extends RefCounted

static func calculate_damage(base_damage: float, attack_multiplier: float = 1.0, defense_multiplier: float = 1.0) -> int:
	var safe_base := maxf(base_damage, 0.0)
	var safe_attack := maxf(attack_multiplier, 0.0)
	var safe_defense := maxf(defense_multiplier, 0.01)
	return maxi(0, int(round((safe_base * safe_attack) / safe_defense)))

static func can_cast(current_mp: float, mp_cost: float, cooldown_remaining: float) -> bool:
	return current_mp >= maxf(mp_cost, 0.0) and cooldown_remaining <= 0.0

static func remaining_mp(current_mp: float, mp_cost: float) -> float:
	return maxf(0.0, current_mp - maxf(mp_cost, 0.0))

static func knockback_direction(attacker_x: float, target_x: float) -> float:
	return 1.0 if target_x >= attacker_x else -1.0
