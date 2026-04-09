class_name CombatTables

## GURPS combat reference tables and lookup functions.

# ---------------------------------------------------------------------------
# Hit Locations
# ---------------------------------------------------------------------------

# Each location: {penalty, wound_mod: {type: multiplier}, cripple, extra_dr}
# cripple: "limb" (HP/2), "extremity" (HP/3), or "" (none)
const HIT_LOCATIONS: Dictionary = {
	"torso":     {"penalty": 0,  "wound_mod": {"pi": 1.0, "pi-": 0.5, "pi+": 1.5, "pi++": 2.0, "imp": 2.0, "cr": 1.0, "cut": 1.5, "burn": 1.0}, "cripple": "", "extra_dr": 0},
	"skull":     {"penalty": -7, "wound_mod": {"pi": 4.0, "pi-": 4.0, "pi+": 4.0, "pi++": 4.0, "imp": 4.0, "cr": 4.0, "cut": 4.0, "burn": 4.0}, "cripple": "", "extra_dr": 2},
	"face":      {"penalty": -5, "wound_mod": {"pi": 1.0, "pi-": 0.5, "pi+": 1.5, "pi++": 2.0, "imp": 2.0, "cr": 1.0, "cut": 1.5, "burn": 1.0}, "cripple": "", "extra_dr": 0},
	"eye":       {"penalty": -9, "wound_mod": {"pi": 4.0, "pi-": 4.0, "pi+": 4.0, "pi++": 4.0, "imp": 4.0, "cr": 4.0, "cut": 4.0, "burn": 4.0}, "cripple": "", "extra_dr": 0},
	"neck":      {"penalty": -5, "wound_mod": {"pi": 1.0, "pi-": 0.5, "pi+": 1.5, "pi++": 2.0, "imp": 2.0, "cr": 1.5, "cut": 2.0, "burn": 1.0}, "cripple": "", "extra_dr": 0},
	"vitals":    {"penalty": -3, "wound_mod": {"pi": 3.0, "pi-": 3.0, "pi+": 3.0, "pi++": 3.0, "imp": 3.0, "cr": 1.0, "cut": 1.0, "burn": 2.0}, "cripple": "", "extra_dr": 0},
	"groin":     {"penalty": -3, "wound_mod": {"pi": 1.0, "pi-": 0.5, "pi+": 1.5, "pi++": 2.0, "imp": 2.0, "cr": 1.0, "cut": 1.5, "burn": 1.0}, "cripple": "", "extra_dr": 0},
	"right leg": {"penalty": -2, "wound_mod": {"pi": 1.0, "pi-": 0.5, "pi+": 1.0, "pi++": 1.0, "imp": 1.0, "cr": 1.0, "cut": 1.0, "burn": 1.0}, "cripple": "limb", "extra_dr": 0},
	"left leg":  {"penalty": -2, "wound_mod": {"pi": 1.0, "pi-": 0.5, "pi+": 1.0, "pi++": 1.0, "imp": 1.0, "cr": 1.0, "cut": 1.0, "burn": 1.0}, "cripple": "limb", "extra_dr": 0},
	"right arm": {"penalty": -2, "wound_mod": {"pi": 1.0, "pi-": 0.5, "pi+": 1.0, "pi++": 1.0, "imp": 1.0, "cr": 1.0, "cut": 1.0, "burn": 1.0}, "cripple": "limb", "extra_dr": 0},
	"left arm":  {"penalty": -2, "wound_mod": {"pi": 1.0, "pi-": 0.5, "pi+": 1.0, "pi++": 1.0, "imp": 1.0, "cr": 1.0, "cut": 1.0, "burn": 1.0}, "cripple": "limb", "extra_dr": 0},
	"hand":      {"penalty": -4, "wound_mod": {"pi": 1.0, "pi-": 0.5, "pi+": 1.0, "pi++": 1.0, "imp": 1.0, "cr": 1.0, "cut": 1.0, "burn": 1.0}, "cripple": "extremity", "extra_dr": 0},
	"foot":      {"penalty": -4, "wound_mod": {"pi": 1.0, "pi-": 0.5, "pi+": 1.0, "pi++": 1.0, "imp": 1.0, "cr": 1.0, "cut": 1.0, "burn": 1.0}, "cripple": "extremity", "extra_dr": 0},
}

# Random hit location table (3d6)
const RANDOM_HIT_LOCATION: Dictionary = {
	3: "skull", 4: "skull", 5: "face",
	6: "right leg", 7: "right leg", 8: "right arm",
	9: "torso", 10: "torso", 11: "groin",
	12: "left arm", 13: "left leg", 14: "left leg",
	15: "hand", 16: "foot", 17: "neck", 18: "neck",
}

# ---------------------------------------------------------------------------
# Postures: [attack_mod, defense_mod, target_mod (ranged penalty to hit)]
# ---------------------------------------------------------------------------

const POSTURES: Dictionary = {
	"standing":  [0, 0, 0],
	"crouching": [-2, 0, -2],
	"kneeling":  [-2, -2, -2],
	"sitting":   [-2, -2, -2],
	"crawling":  [-4, -3, -2],
	"prone":     [-4, -3, -2],
	"face_up":   [-4, -3, -2],
}

# ---------------------------------------------------------------------------
# Range Table (Speed/Range)
# ---------------------------------------------------------------------------

# [max_yards, modifier]
const RANGE_TABLE: Array = [
	[2, 0], [3, -1], [5, -2], [7, -3],
	[10, -4], [15, -5], [20, -6], [30, -7],
	[50, -8], [70, -9], [100, -10], [150, -11],
	[200, -12], [300, -13], [500, -14], [700, -15],
	[1000, -16], [1500, -17], [2000, -18],
]

# ---------------------------------------------------------------------------
# Rapid Fire Bonus
# ---------------------------------------------------------------------------

# [max_shots, bonus]
const RAPID_FIRE_TABLE: Array = [
	[1, 0], [4, 0], [8, 1], [12, 2], [16, 3],
	[24, 4], [49, 5], [99, 6], [199, 7],
]

# ---------------------------------------------------------------------------
# Static lookup functions
# ---------------------------------------------------------------------------

static func range_modifier(yards: float) -> int:
	if yards <= 2.0:
		return 0
	for band: Array in RANGE_TABLE:
		if yards <= float(band[0]):
			return int(band[1])
	return -18

static func rapid_fire_bonus(shots: int) -> int:
	if shots <= 1:
		return 0
	for band: Array in RAPID_FIRE_TABLE:
		if shots <= int(band[0]):
			return int(band[1])
	return 7

static func wounding_multiplier(dmg_type: String, location: String) -> float:
	var loc: Dictionary = HIT_LOCATIONS.get(location, HIT_LOCATIONS["torso"]) as Dictionary
	var wound_mod: Dictionary = loc["wound_mod"] as Dictionary
	return float(wound_mod.get(dmg_type, 1.0))

## Returns crippling threshold for a location, or -1 if location can't be crippled.
static func crippling_threshold(max_hp: int, location: String) -> int:
	var loc: Dictionary = HIT_LOCATIONS.get(location.to_lower(), HIT_LOCATIONS["torso"]) as Dictionary
	var cripple_type: String = String(loc.get("cripple", ""))
	if cripple_type == "limb":
		return max_hp / 2
	if cripple_type == "extremity":
		return max_hp / 3
	return -1

## Get the extra DR for a location (e.g. skull +2).
static func location_extra_dr(location: String) -> int:
	var loc: Dictionary = HIT_LOCATIONS.get(location.to_lower(), HIT_LOCATIONS["torso"]) as Dictionary
	return int(loc.get("extra_dr", 0))

## Get the hit penalty for targeting a specific location.
static func location_penalty(location: String) -> int:
	var loc: Dictionary = HIT_LOCATIONS.get(location.to_lower(), HIT_LOCATIONS["torso"]) as Dictionary
	return int(loc["penalty"])

## Roll random hit location on 3d6 table.
static func random_hit_location() -> String:
	var roll: int = Dice.roll_3d()
	return String(RANDOM_HIT_LOCATION.get(roll, "torso"))

## GURPS critical success check.
static func is_critical_success(roll: int, effective_skill: int) -> bool:
	if roll <= 4:
		return true
	if roll == 5 and effective_skill >= 15:
		return true
	if roll == 6 and effective_skill >= 16:
		return true
	return false

## GURPS critical failure check.
static func is_critical_failure(roll: int, effective_skill: int) -> bool:
	if roll == 18:
		return true
	if roll == 17 and effective_skill <= 15:
		return true
	if roll >= effective_skill + 10:
		return true
	return false

## Maximum roll that succeeds (capped at 16).
static func success_target(effective_skill: int) -> int:
	return min(effective_skill, 16)
