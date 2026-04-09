class_name DefenseResolver

## Resolves active defenses (Dodge, Parry, Block).

## Compute Dodge score: floor(Basic Speed) + 3, halved if reeling.
static func compute_dodge(character: CharacterData) -> int:
	return character.dodge_score()

## Compute Parry score for a specific melee weapon.
static func compute_parry(character: CharacterData, weapon: MeleeWeaponData) -> int:
	if not weapon.can_parry():
		return 0
	return weapon.parry_score()

## Compute best Parry among all melee weapons.
static func compute_best_parry(character: CharacterData) -> int:
	return character.best_parry()

## Auto-pick the best available defense.
## Returns {type: String, score: int} or {type: "", score: 0} if no defense available.
## is_ranged: if true, only Dodge is available (no Parry/Block vs bullets).
## all_out_attack: if true, no defenses available.
static func auto_best_defense(defender: CharacterData, is_ranged: bool,
		all_out_attack: bool = false) -> Dictionary:
	if all_out_attack:
		return {"type": "", "score": 0}

	var best_type: String = ""
	var best_score: int = 0

	# Dodge is always available
	var dodge: int = compute_dodge(defender)
	if dodge > best_score:
		best_score = dodge
		best_type = "dodge"

	# Parry/Block only vs melee/thrown
	if not is_ranged:
		var parry: int = compute_best_parry(defender)
		if parry > best_score:
			best_score = parry
			best_type = "parry"

	return {"type": best_type, "score": best_score}

## Roll a defense. Returns true if defense succeeds.
static func resolve_defense(defense_score: int) -> bool:
	var roll: int = Dice.roll_3d()
	return roll <= CombatTables.success_target(defense_score)

## Roll a defense and return details.
static func resolve_defense_detailed(defense_score: int) -> Dictionary:
	var roll: int = Dice.roll_3d()
	var target: int = CombatTables.success_target(defense_score)
	var succeeded: bool = roll <= target
	var crit_success: bool = CombatTables.is_critical_success(roll, defense_score)
	var crit_fail: bool = CombatTables.is_critical_failure(roll, defense_score)
	return {
		"roll": roll,
		"target": target,
		"succeeded": succeeded,
		"critical_success": crit_success,
		"critical_failure": crit_fail,
	}
