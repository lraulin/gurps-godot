class_name CombatResolver

## Resolves ranged and melee attacks with full GURPS mechanics.

## Resolve a ranged attack.
## target_location: specific location string, or "" for random.
## extra_mods: Array of [label: String, value: int] pairs.
static func resolve_ranged_attack(
		attacker: CharacterData, weapon: RangedWeaponData,
		target: CharacterData, range_yards: int,
		shots: int = 1, target_location: String = "",
		aim_turns: int = 0, braced: bool = false,
		all_out: bool = false,
		extra_mods: Array = [],
		max_effective: int = -1) -> AttackResult:

	var result: AttackResult = AttackResult.new()
	result.attacker_name = attacker.char_name
	result.target_name = target.char_name
	result.weapon_name = weapon.weapon_name
	result.is_ranged = true

	# Check ammo
	if weapon.uses_magazines() and weapon.loaded_rounds() <= 0:
		result.weapon_empty = true
		result.messages.append("Click. The weapon is empty.")
		result.ammo_after = weapon.ammo_summary()
		return result

	# Clamp shots to RoF and available ammo
	var available: int = weapon.loaded_rounds() if weapon.uses_magazines() else shots
	var actual_shots: int = min(shots, weapon.rof, available)

	# Shotgun handling
	var is_shotgun: bool = weapon.rof_pellets > 1
	var close_range_shotgun: bool = is_shotgun and range_yards <= weapon.range_half / 10
	var effective_rof: int = actual_shots
	var effective_recoil: int = weapon.recoil

	if is_shotgun:
		if close_range_shotgun:
			effective_recoil = weapon.slug_recoil
			result.messages.append("Shotgun close range: pellets hit as mass")
		else:
			effective_rof = actual_shots * weapon.rof_pellets
			result.messages.append("Shotgun: %d shots × %d pellets = RoF %d" % [
				actual_shots, weapon.rof_pellets, effective_rof])

	# Build effective skill
	var targeted: bool = target_location != ""
	var loc: String = target_location.to_lower() if targeted else ""
	result.base_skill = weapon.skill_level
	var mods: Array[Array] = []
	var total_mod: int = 0

	# Range modifier
	var rng_mod: int = CombatTables.range_modifier(range_yards)
	if rng_mod != 0:
		mods.append(["range %dyd" % range_yards, rng_mod])
		total_mod += rng_mod

	# Target size modifier
	if target.sm != 0:
		mods.append(["SM", target.sm])
		total_mod += target.sm

	# Hit location penalty
	if targeted:
		var loc_pen: int = CombatTables.location_penalty(loc)
		if loc_pen != 0:
			mods.append([loc, loc_pen])
			total_mod += loc_pen

	# Aim bonus
	if aim_turns > 0:
		var aim_bonus: int = weapon.accuracy + min(aim_turns - 1, 2)
		mods.append(["aim (%dt)" % aim_turns, aim_bonus])
		total_mod += aim_bonus

	# Braced
	if braced and aim_turns > 0:
		mods.append(["braced", 1])
		total_mod += 1

	# All-Out Attack (ranged: +1)
	if all_out:
		mods.append(["all-out", 1])
		total_mod += 1

	# Extra modifiers (shock, posture, etc.)
	for mod_pair: Array in extra_mods:
		var label: String = String(mod_pair[0])
		var value: int = int(mod_pair[1])
		if value != 0:
			mods.append([label, value])
			total_mod += value

	# Rapid fire bonus
	var rf_bonus: int = CombatTables.rapid_fire_bonus(effective_rof)
	if rf_bonus > 0:
		mods.append(["rapid fire (%d)" % effective_rof, rf_bonus])
		total_mod += rf_bonus

	var effective: int = result.base_skill + total_mod
	if max_effective > 0:
		effective = min(effective, max_effective)
	result.effective_skill = effective
	result.modifier_breakdown = mods

	# Fire rounds (consume ammo)
	for i: int in range(actual_shots):
		weapon.fire_one_round()

	# Roll to hit
	result.roll = Dice.roll_3d()
	result.is_critical_hit = CombatTables.is_critical_success(result.roll, effective)
	result.is_critical_miss = CombatTables.is_critical_failure(result.roll, effective)

	if result.is_critical_miss:
		result.is_hit = false
		result.messages.append("CRITICAL MISS!")
		result.ammo_after = weapon.ammo_summary()
		return result

	if result.is_critical_hit:
		result.is_hit = true
		result.hits_count = effective_rof
		result.messages.append("CRITICAL HIT!")
	elif result.roll <= CombatTables.success_target(effective):
		result.is_hit = true
		result.margin = effective - result.roll
		if effective_rof > 1:
			result.hits_count = min(1 + result.margin / effective_recoil, effective_rof)
		else:
			result.hits_count = 1
	else:
		# Miss by 1 on targeted location -> hits torso
		if targeted and result.roll == effective + 1 and loc != "torso":
			var loc_pen: int = CombatTables.location_penalty(loc)
			if loc_pen != 0:
				result.is_hit = true
				result.hits_count = 1
				result.hit_torso_instead = true
				loc = "torso"
				targeted = true
				result.messages.append("Missed %s by 1, hits TORSO instead!" % target_location)
			else:
				result.is_hit = false
		else:
			result.is_hit = false

	if not result.is_hit:
		result.messages.append("MISS (needed %d or less)" % CombatTables.success_target(effective))
		result.ammo_after = weapon.ammo_summary()
		return result

	# Active defense (auto-resolve best)
	if not result.is_critical_hit:
		var defense: Dictionary = DefenseResolver.auto_best_defense(target, true, false)
		result.defense_type = String(defense["type"])
		result.defense_score = int(defense["score"])
		if result.defense_type != "":
			var def_detail: Dictionary = DefenseResolver.resolve_defense_detailed(result.defense_score)
			result.defense_roll = int(def_detail["roll"])
			result.defense_succeeded = bool(def_detail["succeeded"])
			if result.defense_succeeded:
				result.messages.append("%s %ss! (rolled %d vs %d)" % [
					target.char_name, result.defense_type, result.defense_roll, result.defense_score])
				result.ammo_after = weapon.ammo_summary()
				return result

	# Resolve damage for each hit
	var dice_str: String = weapon.dice_notation()
	var dmg_type: String = weapon.dmg_type()

	# Close-range shotgun: pellets as mass
	var pellet_multiplier: int = 0
	if close_range_shotgun:
		pellet_multiplier = weapon.rof_pellets / 2
		dmg_type = "pi++"

	for i: int in range(result.hits_count):
		var hit_loc: String = loc if targeted else CombatTables.random_hit_location()
		var hit_dr: int = target.get_dr_for_location(hit_loc)
		var raw: int = 0

		if close_range_shotgun:
			raw = Dice.roll_dice(dice_str) * pellet_multiplier
			hit_dr = hit_dr * pellet_multiplier
		else:
			raw = Dice.roll_dice(dice_str)

		var dmg_result: DamageResult = DamageResolver.apply_damage(target, raw, hit_dr, dmg_type, hit_loc)
		result.damage_results.append(dmg_result)
		result.total_injury += dmg_result.injury

	result.ammo_after = weapon.ammo_summary()
	return result


## Resolve a melee attack.
static func resolve_melee_attack(
		attacker: CharacterData, weapon: MeleeWeaponData,
		target: CharacterData, target_location: String = "",
		all_out: bool = false,
		extra_mods: Array = [],
		damage_bonus: int = 0,
		max_effective: int = -1) -> AttackResult:

	var result: AttackResult = AttackResult.new()
	result.attacker_name = attacker.char_name
	result.target_name = target.char_name
	result.weapon_name = weapon.weapon_name
	result.is_ranged = false

	var targeted: bool = target_location != ""
	var loc: String = target_location.to_lower() if targeted else ""
	result.base_skill = weapon.skill_level
	var mods: Array[Array] = []
	var total_mod: int = 0

	# Hit location penalty
	if targeted:
		var loc_pen: int = CombatTables.location_penalty(loc)
		if loc_pen != 0:
			mods.append([loc, loc_pen])
			total_mod += loc_pen

	# Target size modifier
	if target.sm != 0:
		mods.append(["SM", target.sm])
		total_mod += target.sm

	# All-Out Attack (Determined: +4 melee)
	if all_out:
		mods.append(["all-out determined", 4])
		total_mod += 4

	# Extra modifiers
	for mod_pair: Array in extra_mods:
		var label: String = String(mod_pair[0])
		var value: int = int(mod_pair[1])
		if value != 0:
			mods.append([label, value])
			total_mod += value

	var effective: int = result.base_skill + total_mod
	if max_effective > 0:
		effective = min(effective, max_effective)
	result.effective_skill = effective
	result.modifier_breakdown = mods

	# Roll to hit
	result.roll = Dice.roll_3d()
	result.is_critical_hit = CombatTables.is_critical_success(result.roll, effective)
	result.is_critical_miss = CombatTables.is_critical_failure(result.roll, effective)

	if result.is_critical_miss:
		result.is_hit = false
		result.messages.append("CRITICAL MISS!")
		return result

	if result.is_critical_hit:
		result.is_hit = true
		result.hits_count = 1
		result.messages.append("CRITICAL HIT!")
	elif result.roll <= CombatTables.success_target(effective):
		result.is_hit = true
		result.hits_count = 1
		result.margin = effective - result.roll
	else:
		# Miss by 1 on targeted location -> hits torso
		if targeted and result.roll == effective + 1 and loc != "torso":
			var loc_pen: int = CombatTables.location_penalty(loc)
			if loc_pen != 0:
				result.is_hit = true
				result.hits_count = 1
				result.hit_torso_instead = true
				loc = "torso"
				targeted = true
				result.messages.append("Missed %s by 1, hits TORSO instead!" % target_location)
			else:
				result.is_hit = false
		else:
			result.is_hit = false

	if not result.is_hit:
		result.messages.append("MISS (needed %d or less)" % CombatTables.success_target(effective))
		return result

	# Active defense (auto-resolve best)
	if not result.is_critical_hit:
		var defense: Dictionary = DefenseResolver.auto_best_defense(target, false, false)
		result.defense_type = String(defense["type"])
		result.defense_score = int(defense["score"])
		if result.defense_type != "":
			var def_detail: Dictionary = DefenseResolver.resolve_defense_detailed(result.defense_score)
			result.defense_roll = int(def_detail["roll"])
			result.defense_succeeded = bool(def_detail["succeeded"])
			if result.defense_succeeded:
				result.messages.append("%s %ss! (rolled %d vs %d)" % [
					target.char_name, result.defense_type, result.defense_roll, result.defense_score])
				return result

	# Resolve damage
	var dice_str: String = weapon.dice_notation()
	var dmg_type: String = weapon.dmg_type()
	var hit_loc: String = loc if targeted else CombatTables.random_hit_location()
	var hit_dr: int = target.get_dr_for_location(hit_loc)
	var raw: int = Dice.roll_dice(dice_str) + damage_bonus

	var dmg_result: DamageResult = DamageResolver.apply_damage(target, raw, hit_dr, dmg_type, hit_loc)
	result.damage_results.append(dmg_result)
	result.total_injury = dmg_result.injury

	return result
