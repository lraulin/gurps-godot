class_name Dice

## Dice rolling utilities for GURPS (3d6 system).

## Roll dice from notation like "2d+2", "1d-1", "3d", "2d6+1".
static func roll_dice(notation: String) -> int:
	var regex: RegEx = RegEx.new()
	regex.compile("^(\\d+)d(?:6)?\\s*([+-]\\s*\\d+)?$")
	var result: RegExMatch = regex.search(notation.strip_edges())
	if not result:
		push_warning("Dice: could not parse '%s'" % notation)
		return 0

	var num_dice: int = int(result.get_string(1))
	var modifier: int = 0
	var mod_str: String = result.get_string(2).strip_edges()
	if mod_str != "":
		modifier = int(mod_str.replace(" ", ""))

	var total: int = 0
	for i: int in range(num_dice):
		total += randi_range(1, 6)
	return total + modifier

## Maximum possible result for a dice notation.
static func max_dice(notation: String) -> int:
	var regex: RegEx = RegEx.new()
	regex.compile("^(\\d+)d(?:6)?\\s*([+-]\\s*\\d+)?$")
	var result: RegExMatch = regex.search(notation.strip_edges())
	if not result:
		return 0

	var num_dice: int = int(result.get_string(1))
	var modifier: int = 0
	var mod_str: String = result.get_string(2).strip_edges()
	if mod_str != "":
		modifier = int(mod_str.replace(" ", ""))
	return num_dice * 6 + modifier

## Roll 3d6.
static func roll_3d() -> int:
	return randi_range(1, 6) + randi_range(1, 6) + randi_range(1, 6)

## Parse "2d+2 pi" into [dice_notation, damage_type].
## Returns ["2d+2", "pi"]. If no type specified, defaults to "cr".
static func parse_damage(damage_str: String) -> Array[String]:
	var parts: PackedStringArray = damage_str.strip_edges().rsplit(" ", true, 1)
	if parts.size() == 2:
		return [parts[0], parts[1]]
	return [parts[0], "cr"]
