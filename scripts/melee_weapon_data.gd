class_name MeleeWeaponData
extends Resource

## GURPS melee weapon stats.

@export var weapon_name: String = ""
@export var mode: String = ""           # "Punch", "Kick", "Swing", "Thrust", etc.
@export var damage: String = ""         # e.g. "1d-3 cr"
@export var reach: String = ""          # e.g. "1", "1,2", "C,1"
@export var skill_level: int = 10
@export var parry_modifier: String = "" # e.g. "0", "-1", "No"
@export var st_required: int = 0

func dice_notation() -> String:
	return Dice.parse_damage(damage)[0]

func dmg_type() -> String:
	return Dice.parse_damage(damage)[1]

## Maximum reach in hexes.
func max_reach() -> int:
	var best: int = 1
	var parts: PackedStringArray = reach.split(",")
	for part: String in parts:
		var trimmed: String = part.strip_edges()
		if trimmed == "C":
			continue  # close combat, reach 0
		var val: int = int(trimmed)
		if val > best:
			best = val
	return best

## Whether this weapon can parry.
func can_parry() -> bool:
	return parry_modifier.strip_edges() != "No" and parry_modifier.strip_edges() != ""

## Parry score: 3 + floor(skill / 2) + modifier.
func parry_score() -> int:
	if not can_parry():
		return 0
	var base: int = 3 + skill_level / 2
	var mod: int = int(parry_modifier) if parry_modifier.is_valid_int() else 0
	return base + mod
