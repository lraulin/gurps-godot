class_name DamageResolver

## Resolves damage application with full GURPS injury mechanics.

## Apply damage to a target at a specific location.
## raw_damage: total rolled damage before DR
## dr: effective DR at the location (including extra_dr)
## dmg_type: damage type string ("pi", "cut", "cr", etc.)
## location: hit location string
static func apply_damage(target: CharacterData, raw_damage: int, dr: int,
		dmg_type: String, location: String) -> DamageResult:
	var result: DamageResult = DamageResult.new()
	result.location = location
	result.raw_damage = raw_damage
	result.dr_applied = dr

	# Penetrating damage
	result.penetrating = max(0, raw_damage - dr)

	# Wounding multiplier
	result.wounding_multiplier = CombatTables.wounding_multiplier(dmg_type, location)
	var uncapped_injury: int = max(0, int(result.penetrating * result.wounding_multiplier))

	# Cap crippling injury
	var capped: Array = _cap_crippling(target.hp_max, location, uncapped_injury)
	result.injury = int(capped[0])
	var excess: int = int(capped[1])

	if result.injury <= 0:
		result.hp_after = target.hp
		return result

	# Check for crippling
	var threshold: int = CombatTables.crippling_threshold(target.hp_max, location)
	if threshold > 0:
		# Check accumulated wounds at this location
		var prev_wounds: int = int(target.wounds.get(location, 0))
		if prev_wounds + result.injury > threshold and location not in target.crippled_locations:
			result.crippled = true
			result.status_messages.append("%s crippled!" % location.capitalize())

	# Major wound check (injury > HP/2)
	result.major_wound = result.injury > target.hp_max / 2

	# Apply to HP
	target.hp -= result.injury
	result.hp_after = target.hp

	# Track wounds by location
	var current_loc_wounds: int = int(target.wounds.get(location, 0))
	target.wounds[location] = current_loc_wounds + result.injury

	# Mark crippled
	if result.crippled and location not in target.crippled_locations:
		target.crippled_locations.append(location)

	# Shock
	result.shock = target.shock_from_injury(result.injury)
	if result.shock != 0:
		result.status_messages.append("Shock %d" % result.shock)

	# Reeling check
	result.reeling = target.is_reeling()
	if result.reeling:
		result.status_messages.append("Reeling (HP <= 1/3)")

	# Knockdown/stun check
	var kd: Dictionary = _resolve_knockdown(target, location, result.injury, result.major_wound)
	if kd.get("required", false):
		result.knockdown_required = true
		result.knockdown_penalty = int(kd.get("penalty", 0))
		result.knockdown_roll = int(kd.get("roll", 0))
		result.knockdown_succeeded = bool(kd.get("passed", false))
		if not result.knockdown_succeeded:
			result.status_messages.append("Knocked down and stunned!")
		else:
			result.status_messages.append("Resisted knockdown (rolled %d)" % result.knockdown_roll)

	# Death checks
	result.death_check_results = _check_death(target)
	for check: Dictionary in result.death_check_results:
		if not bool(check["passed"]):
			target.dead = true
			result.dead = true
			result.status_messages.append("DEAD!")
			break

	if target.hp <= -5 * target.hp_max:
		target.dead = true
		result.dead = true
		result.status_messages.append("DEAD! (HP <= -5×Max HP)")

	if excess > 0:
		result.status_messages.append("%d excess injury lost (crippling cap)" % excess)

	return result


## Cap injury to crippling threshold. Returns [capped_injury, excess].
static func _cap_crippling(max_hp: int, location: String, injury: int) -> Array:
	var threshold: int = CombatTables.crippling_threshold(max_hp, location)
	if threshold <= 0:
		return [injury, 0]  # No crippling cap for this location
	# Cap at threshold (but only if not already crippled — simplified: always cap)
	if injury > threshold:
		return [threshold, injury - threshold]
	return [injury, 0]


## Resolve knockdown/stun check. Returns {required, penalty, roll, target_score, passed, reason}.
static func _resolve_knockdown(target: CharacterData, location: String,
		injury: int, major_wound: bool) -> Dictionary:
	if injury <= 0:
		return {"required": false}

	var loc: String = location.to_lower()
	var head_locs: Array[String] = ["skull", "face", "eye"]
	var no_brain: bool = _has_injury_tolerance(target, "No Brain")
	var no_vitals: bool = _has_injury_tolerance(target, "No Vitals")

	# Determine if knockdown check is needed
	var shock_trigger: bool = false
	if not target.has_advantage("High Pain Threshold"):
		if loc in head_locs and not no_brain:
			shock_trigger = true
		elif loc == "vitals" and not no_vitals:
			shock_trigger = true

	if not major_wound and not shock_trigger:
		return {"required": false}

	# Calculate penalty
	var penalty: int = 0
	if loc in ["skull", "eye"]:
		if not (major_wound and no_brain):
			penalty = -10
	elif loc == "face":
		if not (major_wound and no_brain):
			penalty = -5
	elif loc in ["vitals", "groin"]:
		if not (major_wound and no_vitals):
			penalty = -5

	# Advantage/disadvantage modifiers
	if target.has_advantage("High Pain Threshold"):
		penalty += 3
	if target.has_disadvantage("Low Pain Threshold"):
		penalty -= 4

	var target_score: int = target.ht + penalty
	var roll: int = Dice.roll_3d()
	var passed: bool = roll <= target_score

	return {
		"required": true,
		"penalty": penalty,
		"roll": roll,
		"target_score": target_score,
		"passed": passed,
		"reason": "major wound" if major_wound else "%s hit" % loc,
	}


## Check death at HP thresholds (-HP, -2×HP, -3×HP, -4×HP).
static func _check_death(target: CharacterData) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if target.hp >= 0:
		return results

	# Check each threshold from -1×HP to -4×HP
	for multiple: int in range(1, 5):
		var threshold: int = -multiple * target.hp_max
		if target.hp <= threshold and target.death_checks_passed < multiple:
			var bonus: int = 0
			if target.has_advantage("Hard to Kill"):
				bonus = 2  # simplified; actual level varies
			var target_score: int = target.ht + bonus
			var roll: int = Dice.roll_3d()
			var passed: bool = roll <= target_score

			results.append({
				"threshold": threshold,
				"multiple": multiple,
				"roll": roll,
				"target_score": target_score,
				"passed": passed,
			})

			if passed:
				target.death_checks_passed = multiple
			else:
				break  # Dead, no more checks

	return results


static func _has_injury_tolerance(character: CharacterData, qualifier: String) -> bool:
	var q_lower: String = qualifier.to_lower()
	for adv: String in character.advantages:
		var lower: String = adv.to_lower()
		if "injury tolerance" in lower and q_lower in lower:
			return true
	if q_lower in ["no brain", "no vitals"]:
		if character.has_advantage("Homogenous") or character.has_advantage("Homogeneous"):
			return true
		if character.has_advantage("Diffuse"):
			return true
	return false
