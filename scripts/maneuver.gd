class_name Maneuver

## GURPS maneuver definitions and movement constraints.

enum Type {
	DO_NOTHING,
	MOVE,
	CHANGE_POSTURE,
	AIM,
	ATTACK,
	ALL_OUT_ATTACK,
	MOVE_AND_ATTACK,
	ALL_OUT_DEFENSE,
	CONCENTRATE,
	READY,
	WAIT,
}

enum AllOutDefenseOption {
	NONE,
	INCREASED_DODGE,
	INCREASED_PARRY,
	INCREASED_BLOCK,
	DOUBLE_DEFENSE,
}

## Movement allowance for each maneuver.
## -1 = no movement, 0 = step only (1 hex), 0.5 = half move, 1.0 = full move
const MOVEMENT_ALLOWANCE: Dictionary = {
	Type.DO_NOTHING: 0, # step
	Type.MOVE: 1.0,
	Type.CHANGE_POSTURE: 0, # step
	Type.AIM: 0, # step
	Type.ATTACK: 0, # step
	Type.ALL_OUT_ATTACK: 0.5,
	Type.MOVE_AND_ATTACK: 1.0,
	Type.ALL_OUT_DEFENSE: 0.5,
	Type.CONCENTRATE: 0, # step
	Type.READY: 0, # step
	Type.WAIT: -1, # varies
}

const NAMES: Dictionary = {
	Type.DO_NOTHING: "Do Nothing",
	Type.MOVE: "Move",
	Type.CHANGE_POSTURE: "Change Posture",
	Type.AIM: "Aim",
	Type.ATTACK: "Attack",
	Type.ALL_OUT_ATTACK: "All-Out Attack",
	Type.MOVE_AND_ATTACK: "Move and Attack",
	Type.ALL_OUT_DEFENSE: "All-Out Defense",
	Type.CONCENTRATE: "Concentrate",
	Type.READY: "Ready",
	Type.WAIT: "Wait",
}

const ALL_OUT_DEFENSE_OPTION_NAMES: Dictionary = {
	AllOutDefenseOption.NONE: "None",
	AllOutDefenseOption.INCREASED_DODGE: "Increased Dodge",
	AllOutDefenseOption.INCREASED_PARRY: "Increased Parry",
	AllOutDefenseOption.INCREASED_BLOCK: "Increased Block",
	AllOutDefenseOption.DOUBLE_DEFENSE: "Double Defense",
}

## Get the maximum hexes a character can move for a given maneuver.
## step_distance is always 1.
static func max_movement(maneuver_type: Type, basic_move: int) -> int:
	var allowance: float = float(MOVEMENT_ALLOWANCE[maneuver_type])
	if allowance < 0:
		return 0
	if allowance == 0:
		return 1 # step
	if allowance == 0.5:
		return int(ceil(basic_move / 2.0))
	return basic_move

## Get movement for a specific All-Out Defense option.
## Increased Dodge = half move, other options = step.
static func all_out_defense_max_movement(option: AllOutDefenseOption, basic_move: int) -> int:
	if option == AllOutDefenseOption.INCREASED_DODGE:
		return int(ceil(basic_move / 2.0))
	return 1

static func get_all_out_defense_option_name(option: AllOutDefenseOption) -> String:
	return String(ALL_OUT_DEFENSE_OPTION_NAMES.get(option, "Unknown"))

## Get available maneuvers given how many hexes have been moved.
static func available_maneuvers(hexes_moved: int, basic_move: int) -> Array[Type]:
	var result: Array[Type] = []
	for type_key: int in MOVEMENT_ALLOWANCE:
		var type: Type = type_key as Type
		if max_movement(type, basic_move) >= hexes_moved:
			result.append(type)
	return result

## Get the name of a maneuver.
static func get_maneuver_name(type: Type) -> String:
	return String(NAMES.get(type, "Unknown"))
