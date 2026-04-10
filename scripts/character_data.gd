class_name CharacterData
extends Resource

## Full GURPS character stats for tactical combat.

# Identity
@export var char_name: String = "Unknown"

# Primary Attributes
@export var st: int = 10
@export var dx_stat: int = 10
@export var iq: int = 10
@export var ht: int = 10

# Secondary Attributes
@export var hp: int = 10
@export var hp_max: int = 10
@export var will: int = 10
@export var per: int = 10
@export var fp: int = 10
@export var fp_max: int = 10
@export var basic_lift: int = 20
@export var damage_thr: String = "1d-2"
@export var damage_sw: String = "1d"
@export var speed_stat: float = 5.0     # Basic Speed
@export var move_stat: int = 5          # Basic Move
@export var sm: int = 0                 # Size Modifier

# Armor
@export var dr: int = 0                 # Base DR (torso)
var dr_by_location: Dictionary = {}     # String -> int

# Skills, Advantages, Disadvantages
var skills: Dictionary = {}             # String -> int (skill level)
var advantages: Array[String] = []
var disadvantages: Array[String] = []

# Weapons
var ranged_weapons: Array[RangedWeaponData] = []
var melee_weapons: Array[MeleeWeaponData] = []

# Currently held in right hand (null = use first available weapon as default)
var right_hand_weapon: Resource = null  # RangedWeaponData or MeleeWeaponData

## Returns the weapon currently in the right hand, falling back to first available.
func get_right_hand() -> Resource:
	if right_hand_weapon != null:
		return right_hand_weapon
	if ranged_weapons.size() > 0:
		return ranged_weapons[0]
	for w: MeleeWeaponData in melee_weapons:
		if w.mode.to_lower() not in ["kick", "bite"]:
			return w
	return null

# Injury tracking
var wounds: Dictionary = {}             # String -> int (location -> accumulated injury)
var crippled_locations: Array[String] = []
var dead: bool = false
var death_checks_passed: int = 0        # highest -N×HP multiple already checked

# --- Computed Properties ---

func is_alive() -> bool:
	return not dead and hp > -5 * hp_max

func is_conscious() -> bool:
	return hp > 0 or (hp > -hp_max)

func is_reeling() -> bool:
	return hp <= hp_max / 3

func effective_move() -> int:
	var m: int = move_stat
	# Reeling halves move
	if is_reeling():
		m = m / 2
	# Crippled legs
	var crippled_leg_count: int = 0
	for loc: String in crippled_locations:
		if loc.ends_with("leg") or loc.ends_with("foot"):
			crippled_leg_count += 1
	if crippled_leg_count >= 2:
		m = 0
	elif crippled_leg_count == 1:
		m = int(m * 0.6)
	return m

func dodge_score() -> int:
	var base: int = int(floor(speed_stat)) + 3
	if is_reeling():
		base = base / 2
	return base

func best_parry() -> int:
	var best: int = 0
	for weapon: MeleeWeaponData in melee_weapons:
		var score: int = weapon.parry_score()
		if score > best:
			best = score
	return best

func has_advantage(adv_name: String) -> bool:
	var lower: String = adv_name.to_lower()
	for a: String in advantages:
		if lower in a.to_lower():
			return true
	return false

func has_disadvantage(dis_name: String) -> bool:
	var lower: String = dis_name.to_lower()
	for d: String in disadvantages:
		if lower in d.to_lower():
			return true
	return false

func get_dr_for_location(location: String) -> int:
	var base_dr: int = int(dr_by_location.get(location, dr))
	var extra: int = CombatTables.location_extra_dr(location)
	return base_dr + extra

## Get a character's shock penalty (capped at -4).
func shock_from_injury(injury: int) -> int:
	if has_advantage("High Pain Threshold"):
		return 0
	return -min(injury, 4)
