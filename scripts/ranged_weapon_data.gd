class_name RangedWeaponData
extends Resource

## GURPS ranged weapon stats and magazine management.

@export var weapon_name: String = ""
@export var damage: String = ""         # e.g. "2d+2 pi"
@export var accuracy: int = 0
@export var range_half: int = 0         # half-damage range (yards)
@export var range_max: int = 0          # max range (yards)
@export var rof: int = 1                # trigger pulls per turn
@export var shots: String = ""          # e.g. "15+1(3)"
@export var skill_level: int = 10
@export var st_required: int = 0
@export var bulk: int = 0
@export var recoil: int = 2
@export var rof_pellets: int = 1        # pellets per shot (9 for shotgun "3x9")
@export var slug_recoil: int = 5        # recoil for slug/close-range shotgun

# Magazine state (initialized from shots string)
var magazine_capacity: int = 0
var chamber_capacity: int = 0
var reload_ready_actions: int = 0
var current_magazine_rounds: int = 0
var chambered_rounds: int = 0
var spare_magazine_count: int = 0

# Starting state for reset
var _starting_magazine_rounds: int = 0
var _starting_chambered_rounds: int = 0
var _starting_spare_count: int = 0

func dice_notation() -> String:
	return Dice.parse_damage(damage)[0]

func dmg_type() -> String:
	return Dice.parse_damage(damage)[1]

func uses_magazines() -> bool:
	return magazine_capacity > 0

func loaded_rounds() -> int:
	return chambered_rounds + current_magazine_rounds

func max_loaded_rounds() -> int:
	return magazine_capacity + chamber_capacity

func ammo_summary() -> String:
	if not uses_magazines():
		return shots if shots != "" else "n/a"
	return "%d loaded (%d mag, %d chambered), %d spare" % [
		loaded_rounds(), current_magazine_rounds, chambered_rounds, spare_magazine_count
	]

## Initialize magazine state from the shots string (e.g. "15+1(3)").
func initialize_ammo(spare_mags: int = 3) -> void:
	var regex: RegEx = RegEx.new()
	regex.compile("^(\\d+)(?:\\+(\\d+))?(?:\\((\\d+)\\))?$")
	var result: RegExMatch = regex.search(shots.strip_edges())
	if not result:
		return
	magazine_capacity = int(result.get_string(1))
	chamber_capacity = int(result.get_string(2)) if result.get_string(2) != "" else 0
	reload_ready_actions = int(result.get_string(3)) if result.get_string(3) != "" else 0

	current_magazine_rounds = magazine_capacity
	chambered_rounds = chamber_capacity
	spare_magazine_count = spare_mags
	_record_starting_loadout()

func _record_starting_loadout() -> void:
	_starting_magazine_rounds = current_magazine_rounds
	_starting_chambered_rounds = chambered_rounds
	_starting_spare_count = spare_magazine_count

func reset_ammo() -> void:
	current_magazine_rounds = _starting_magazine_rounds
	chambered_rounds = _starting_chambered_rounds
	spare_magazine_count = _starting_spare_count

## Fire one round. Returns false if empty.
func fire_one_round() -> bool:
	if not uses_magazines():
		return true  # unlimited for non-magazine weapons
	if chambered_rounds <= 0:
		return false
	chambered_rounds -= 1
	# Auto-chamber next round from magazine
	if chamber_capacity > 0 and current_magazine_rounds > 0:
		current_magazine_rounds -= 1
		chambered_rounds += 1
	return true

## Reload from spare magazine. retain_mag keeps partial magazine as spare.
func perform_reload(retain_mag: bool = true) -> void:
	if not uses_magazines() or spare_magazine_count <= 0:
		return
	# Save old mag if it has rounds
	if retain_mag and current_magazine_rounds > 0:
		spare_magazine_count += 1  # simplified: just track count
	spare_magazine_count -= 1
	current_magazine_rounds = magazine_capacity
	# Chamber a round if empty
	if chambered_rounds == 0 and chamber_capacity > 0 and current_magazine_rounds > 0:
		current_magazine_rounds -= 1
		chambered_rounds = 1

## Ready actions needed to reload.
func reload_actions_needed() -> int:
	if not uses_magazines():
		return 0
	var base: int = reload_ready_actions if reload_ready_actions > 0 else 1
	if chambered_rounds > 0:
		return max(1, base - 1)
	return base
