class_name CombatLog
extends PanelContainer

## Scrollable combat log with colored text output.

@onready var rich_text: RichTextLabel = $RichText

func _ready() -> void:
	rich_text.bbcode_enabled = true
	rich_text.scroll_following = true

func log_attack(result: AttackResult) -> void:
	var text: String = ""

	# Header
	var weapon_type: String = "fires" if result.is_ranged else "attacks with"
	text += "[b]%s[/b] %s [b]%s[/b] at [b]%s[/b]\n" % [
		result.attacker_name, weapon_type, result.weapon_name, result.target_name]

	# Weapon empty
	if result.weapon_empty:
		text += "[color=gray]Click. The weapon is empty.[/color]\n"
		_append(text)
		return

	# Skill breakdown
	text += "  Skill: %d" % result.base_skill
	for mod: Array in result.modifier_breakdown:
		var label: String = String(mod[0])
		var value: int = int(mod[1])
		text += "  %s %s%d" % [label, "+" if value >= 0 else "", value]
	text += "  = [b]%d[/b] (need %d-)\n" % [
		result.effective_skill, CombatTables.success_target(result.effective_skill)]

	# Roll result
	if result.is_critical_hit:
		text += "  Roll: %d — [color=yellow][b]CRITICAL HIT![/b][/color]\n" % result.roll
	elif result.is_critical_miss:
		text += "  Roll: %d — [color=red][b]CRITICAL MISS![/b][/color]\n" % result.roll
		_append(text)
		return
	elif result.is_hit:
		text += "  Roll: %d — [color=green]HIT[/color] (margin %d, %d hit%s)\n" % [
			result.roll, result.margin, result.hits_count, "s" if result.hits_count != 1 else ""]
	else:
		text += "  Roll: %d — [color=red]MISS[/color]\n" % result.roll
		_append(text)
		return

	# Hit torso instead
	if result.hit_torso_instead:
		text += "  [color=orange]Missed targeted location by 1 — hits TORSO instead![/color]\n"

	# Defense
	if result.defense_type != "":
		if result.defense_succeeded:
			text += "  [color=cyan]%s %ss! (rolled %d vs %d)[/color]\n" % [
				result.target_name, result.defense_type, result.defense_roll, result.defense_score]
			_append(text)
			return
		else:
			text += "  %s fails to %s (rolled %d vs %d)\n" % [
				result.target_name, result.defense_type, result.defense_roll, result.defense_score]

	# Damage per hit
	for i: int in range(result.damage_results.size()):
		var dr: DamageResult = result.damage_results[i]
		text += "  Hit %d → %s: %d raw - %d DR = %d pen ×%.1f = [b]%d injury[/b]\n" % [
			i + 1, dr.location, dr.raw_damage, dr.dr_applied, dr.penetrating,
			dr.wounding_multiplier, dr.injury]
		for msg: String in dr.status_messages:
			text += "    [color=orange]%s[/color]\n" % msg

	# Total
	if result.total_injury > 0:
		text += "  [b]Total injury: %d[/b]\n" % result.total_injury
	elif result.is_hit and not result.defense_succeeded:
		text += "  [color=gray]No damage penetrates.[/color]\n"

	# Ammo
	if result.ammo_after != "":
		text += "  [color=gray]Ammo: %s[/color]\n" % result.ammo_after

	_append(text)

func log_message(text: String) -> void:
	_append("[color=white]%s[/color]\n" % text)

func log_turn(char_name: String, turn_num: int, total: int) -> void:
	_append("\n[color=yellow]━━━ Turn %d/%d: %s ━━━[/color]\n" % [turn_num, total, char_name])

func _append(bbcode: String) -> void:
	rich_text.append_text(bbcode)
