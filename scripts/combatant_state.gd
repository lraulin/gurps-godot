class_name CombatantState
extends RefCounted

## Per-combatant combat state tracked across turns.

# Aim tracking
var aim_target: CharacterData = null
var aim_weapon_name: String = ""
var aim_turns: int = 0

# Status effects
var shock: int = 0              # -1 to -4 penalty to DX/IQ next turn only
var stunned: bool = false
var unconscious: bool = false

# Posture
var posture: String = "standing"

# Evaluate tracking
var evaluate_target: CharacterData = null
var evaluate_bonus: int = 0     # +1 to +3, cumulative

# Feint
var feint_target: CharacterData = null
var feint_margin: int = 0       # applied as defense penalty

# Turn tracking
var last_maneuver: int = -1     # Maneuver.Type enum value
var movement_used: int = 0

# Defense state
var all_out_defense: bool = false
var all_out_defense_option: Maneuver.AllOutDefenseOption = Maneuver.AllOutDefenseOption.NONE
var all_out_attack: bool = false
var dodges_this_turn: int = 0

# Reload tracking
var reload_weapon_name: String = ""
var reload_turns_remaining: int = 0

# Waiting
var waiting: bool = false

# Turn commitment tracking
var committed_maneuver: Maneuver.Type = Maneuver.Type.DO_NOTHING
var attacked_this_turn: bool = false

func break_aim() -> void:
	aim_target = null
	aim_weapon_name = ""
	aim_turns = 0

func break_evaluate() -> void:
	evaluate_target = null
	evaluate_bonus = 0

func reset_for_new_turn() -> void:
	# Shock only lasts one turn
	shock = 0
	all_out_defense = false
	all_out_defense_option = Maneuver.AllOutDefenseOption.NONE
	all_out_attack = false
	dodges_this_turn = 0
	movement_used = 0
	waiting = false
	committed_maneuver = Maneuver.Type.DO_NOTHING
	attacked_this_turn = false
