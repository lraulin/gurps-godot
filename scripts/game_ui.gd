class_name GameUI
extends Control

## XCOM-style bottom bar HUD.
## All UI built programmatically.
## Attack flow: pick maneuver → pick weapon → (pick shots) → click target → popup.

signal attack_mode_selected(weapon, mode: String)
signal shots_selected(count: int)
signal maneuver_button_pressed(type: Maneuver.Type)
signal inventory_opened()
signal end_turn_pressed()
signal combat_log_toggled()
signal combat_popup_confirmed()
signal equip_weapon_requested(weapon)
signal cancel_attack()

const BAR_HEIGHT := 120

# Bottom bar refs
var _action_row: HBoxContainer
var _name_label: Label
var _hp_label: Label
var _fp_label: Label
var _status_label: Label

# Attack popup
var _attack_popup: AcceptDialog

# Inventory panel
var _inv_panel: PanelContainer
var _inv_list: VBoxContainer

# State
var _current_available: Array[Maneuver.Type] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bottom_bar()
	_build_attack_popup()
	_build_inventory_panel()


# ─── Bottom Bar ────────────────────────────────────────────────────────────────

func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	bar.add_child(hbox)

	# ── Center ──
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 2)
	hbox.add_child(center)

	_action_row = HBoxContainer.new()
	_action_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_row.add_theme_constant_override("separation", 4)
	center.add_child(_action_row)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 14)
	center.add_child(info_row)

	_name_label = Label.new()
	_name_label.text = "—"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(_name_label)

	_hp_label = Label.new()
	_hp_label.text = "HP: —"
	info_row.add_child(_hp_label)

	_fp_label = Label.new()
	_fp_label.text = "FP: —"
	info_row.add_child(_fp_label)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.modulate = Color.YELLOW
	info_row.add_child(_status_label)

	_build_action_buttons([])


# ─── Action Row ────────────────────────────────────────────────────────────────

func _build_action_buttons(available: Array[Maneuver.Type]) -> void:
	_clear_action_row()
	_current_available = available

	# All maneuver buttons (attack types now included explicitly)
	var shown_maneuvers: Array[Maneuver.Type] = [
		Maneuver.Type.ATTACK,
		Maneuver.Type.ALL_OUT_ATTACK,
		Maneuver.Type.MOVE_AND_ATTACK,
		Maneuver.Type.ALL_OUT_DEFENSE,
		Maneuver.Type.AIM,
		Maneuver.Type.READY,
		Maneuver.Type.WAIT,
	]
	for mtype in shown_maneuvers:
		var btn := Button.new()
		btn.text = Maneuver.get_maneuver_name(mtype)
		# Empty available = all disabled; populated = only listed types enabled
		var enabled: bool = mtype in available
		btn.disabled = not enabled
		var t := mtype  # capture for closure
		btn.pressed.connect(func(): maneuver_button_pressed.emit(t))
		_action_row.add_child(btn)

	_action_row.add_child(_make_spacer())

	var log_btn := Button.new()
	log_btn.text = "Log"
	log_btn.pressed.connect(func(): combat_log_toggled.emit())
	_action_row.add_child(log_btn)

	var inv_btn := Button.new()
	inv_btn.text = "Inventory"
	inv_btn.pressed.connect(func(): inventory_opened.emit())
	_action_row.add_child(inv_btn)

	var end_btn := Button.new()
	end_btn.text = "End Turn"
	end_btn.pressed.connect(func(): end_turn_pressed.emit())
	_action_row.add_child(end_btn)


func _clear_action_row() -> void:
	for child in _action_row.get_children():
		child.queue_free()


func _make_spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


# ─── Public API ────────────────────────────────────────────────────────────────

func show_action_buttons(available: Array[Maneuver.Type]) -> void:
	_build_action_buttons(available)


func show_weapon_options(char_data: CharacterData, has_adjacent_target: bool) -> void:
	## Shows equipped weapon + natural attacks. Call after maneuver is chosen.
	## Melee options only shown when has_adjacent_target is true.
	_clear_action_row()

	var equipped = char_data.get_right_hand()
	var natural_modes := ["punch", "kick", "bite"]
	var any_shown := false

	# Show equipped weapon (if it's not a natural attack)
	if equipped != null:
		var is_natural := false
		if equipped is MeleeWeaponData:
			if (equipped as MeleeWeaponData).mode.to_lower() in natural_modes:
				is_natural = true
		if not is_natural:
			if equipped is RangedWeaponData:
				var btn := Button.new()
				var rw := equipped as RangedWeaponData
				var ammo_str := " [%s]" % rw.ammo_summary() if rw.uses_magazines() else ""
				btn.text = "%s (Skill %d)%s" % [rw.weapon_name, rw.skill_level, ammo_str]
				var w := rw
				btn.pressed.connect(func(): attack_mode_selected.emit(w, "ranged"))
				_action_row.add_child(btn)
				any_shown = true
			elif equipped is MeleeWeaponData and has_adjacent_target:
				var btn := Button.new()
				var mw := equipped as MeleeWeaponData
				btn.text = "%s: %s (%d)" % [mw.weapon_name, mw.mode, mw.skill_level]
				var w := mw
				var m: String = mw.mode
				btn.pressed.connect(func(): attack_mode_selected.emit(w, m))
				_action_row.add_child(btn)
				any_shown = true

	# Natural attacks — only if an adjacent target exists
	if has_adjacent_target:
		var found_punch := false
		var found_kick := false
		for weapon: MeleeWeaponData in char_data.melee_weapons:
			var mode_lower := weapon.mode.to_lower()
			if mode_lower == "punch":
				found_punch = true
			elif mode_lower == "kick":
				found_kick = true
			elif mode_lower == "bite":
				pass  # show bite if present
			else:
				continue  # skip non-natural melee (shown as equipped if applicable)
			var btn := Button.new()
			btn.text = "%s (%d)" % [weapon.mode, weapon.skill_level]
			var w := weapon
			var m: String = weapon.mode
			btn.pressed.connect(func(): attack_mode_selected.emit(w, m))
			_action_row.add_child(btn)
			any_shown = true

		# Default punch if not in melee_weapons
		if not found_punch:
			var punch := MeleeWeaponData.new()
			punch.weapon_name = "Brawling"
			punch.mode = "Punch"
			punch.damage = "1d-2 cr"
			punch.skill_level = char_data.dx_stat
			punch.reach = "C"
			punch.parry_modifier = "0"
			var btn := Button.new()
			btn.text = "Punch (%d)" % punch.skill_level
			var w := punch
			btn.pressed.connect(func(): attack_mode_selected.emit(w, "Punch"))
			_action_row.add_child(btn)
			any_shown = true

		# Default kick if not in melee_weapons
		if not found_kick:
			var kick := MeleeWeaponData.new()
			kick.weapon_name = "Brawling"
			kick.mode = "Kick"
			kick.damage = "1d cr"
			kick.skill_level = char_data.dx_stat - 2
			kick.reach = "C,1"
			kick.parry_modifier = "No"
			var btn := Button.new()
			btn.text = "Kick (%d)" % kick.skill_level
			var w := kick
			btn.pressed.connect(func(): attack_mode_selected.emit(w, "Kick"))
			_action_row.add_child(btn)
			any_shown = true

	if not any_shown:
		var lbl := Label.new()
		lbl.text = "No attacks available (no targets in range)"
		_action_row.add_child(lbl)

	_action_row.add_child(_make_spacer())

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): cancel_attack.emit())
	_action_row.add_child(cancel)


func show_shots_selector(weapon: RangedWeaponData) -> void:
	## Shows shot count buttons for ranged weapons with RoF > 1.
	_clear_action_row()

	var lbl := Label.new()
	lbl.text = "Shots:"
	_action_row.add_child(lbl)

	var max_shots: int = min(weapon.rof, weapon.loaded_rounds())
	for i: int in range(1, max_shots + 1):
		var btn := Button.new()
		btn.text = str(i)
		var count := i
		btn.pressed.connect(func(): shots_selected.emit(count))
		_action_row.add_child(btn)

	_action_row.add_child(_make_spacer())

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): cancel_attack.emit())
	_action_row.add_child(cancel)


func show_select_target_prompt() -> void:
	## Replaces action row with a "click target" message and a Cancel.
	_clear_action_row()

	var lbl := Label.new()
	lbl.text = "← Click an enemy to attack"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_row.add_child(lbl)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): cancel_attack.emit())
	_action_row.add_child(cancel)


func set_character_info(char_name: String, hp: int, hp_max: int, fp: int, fp_max: int, status: String) -> void:
	_name_label.text = char_name
	_hp_label.text = "HP: %d/%d" % [hp, hp_max]
	_fp_label.text = "FP: %d/%d" % [fp, fp_max]

	var hp_ratio: float = float(hp) / float(hp_max) if hp_max > 0 else 1.0
	if hp_ratio < 0.34:
		_hp_label.modulate = Color.RED
	elif hp_ratio < 0.67:
		_hp_label.modulate = Color.YELLOW
	else:
		_hp_label.modulate = Color.LIME_GREEN

	_status_label.text = status


func show_message(text: String) -> void:
	if _status_label:
		_status_label.text = text


func close_inventory() -> void:
	if _inv_panel:
		_inv_panel.visible = false


# ─── Attack Popup ──────────────────────────────────────────────────────────────

func _build_attack_popup() -> void:
	_attack_popup = AcceptDialog.new()
	_attack_popup.title = "Attack Resolution"
	_attack_popup.min_size = Vector2(480, 240)
	_attack_popup.exclusive = true
	_attack_popup.confirmed.connect(func(): combat_popup_confirmed.emit())
	_attack_popup.canceled.connect(func(): combat_popup_confirmed.emit())
	add_child(_attack_popup)


func show_combat_popup(result: AttackResult) -> void:
	var lines: PackedStringArray = []

	var verb := "fires" if result.is_ranged else "attacks with"
	lines.append("%s %s %s  →  %s" % [
		result.attacker_name, verb, result.weapon_name, result.target_name])
	lines.append("")

	if result.weapon_empty:
		lines.append("Click. The weapon is empty.")
		_attack_popup.dialog_text = "\n".join(lines)
		_attack_popup.popup_centered()
		return

	var skill_line := "Skill: %d" % result.base_skill
	for mod: Array in result.modifier_breakdown:
		var val := int(mod[1])
		skill_line += "   %s %s%d" % [str(mod[0]), "+" if val >= 0 else "", val]
	skill_line += "   =  %d  (need %d-)" % [
		result.effective_skill, CombatTables.success_target(result.effective_skill)]
	lines.append(skill_line)

	if result.is_critical_hit:
		lines.append("Roll: %d  —  CRITICAL HIT!" % result.roll)
	elif result.is_critical_miss:
		lines.append("Roll: %d  —  CRITICAL MISS!" % result.roll)
		_attack_popup.dialog_text = "\n".join(lines)
		_attack_popup.popup_centered()
		return
	elif result.is_hit:
		lines.append("Roll: %d  —  HIT  (margin %d, %d hit%s)" % [
			result.roll, result.margin, result.hits_count,
			"s" if result.hits_count != 1 else ""])
	else:
		lines.append("Roll: %d  —  MISS" % result.roll)
		_attack_popup.dialog_text = "\n".join(lines)
		_attack_popup.popup_centered()
		return

	if result.hit_torso_instead:
		lines.append("* Missed targeted location — hits TORSO instead!")

	if result.defense_type != "":
		if result.defense_succeeded:
			lines.append("%s %ss!  (rolled %d vs %d)" % [
				result.target_name, result.defense_type,
				result.defense_roll, result.defense_score])
			_attack_popup.dialog_text = "\n".join(lines)
			_attack_popup.popup_centered()
			return
		else:
			lines.append("%s fails to %s  (rolled %d vs %d)" % [
				result.target_name, result.defense_type,
				result.defense_roll, result.defense_score])

	lines.append("")
	for i: int in range(result.damage_results.size()):
		var dr := result.damage_results[i] as DamageResult
		lines.append("Hit %d → %s:  %d raw  −  %d DR  =  %d pen  ×%.1f  =  %d injury" % [
			i + 1, dr.location, dr.raw_damage, dr.dr_applied,
			dr.penetrating, dr.wounding_multiplier, dr.injury])
		for msg: String in dr.status_messages:
			lines.append("    * %s" % msg)

	if result.total_injury > 0:
		lines.append("")
		lines.append("Total injury: %d" % result.total_injury)
	elif result.is_hit:
		lines.append("No damage penetrates.")

	if result.ammo_after != "":
		lines.append("Ammo remaining: %s" % result.ammo_after)

	_attack_popup.dialog_text = "\n".join(lines)
	_attack_popup.popup_centered()


# ─── Inventory Panel ───────────────────────────────────────────────────────────

func _build_inventory_panel() -> void:
	_inv_panel = PanelContainer.new()
	_inv_panel.visible = false
	_inv_panel.custom_minimum_size = Vector2(420, 380)
	_inv_panel.set_anchors_preset(Control.PRESET_CENTER)
	_inv_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_inv_panel)

	var vbox := VBoxContainer.new()
	_inv_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "INVENTORY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): _inv_panel.visible = false)
	header.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 250)
	vbox.add_child(scroll)

	_inv_list = VBoxContainer.new()
	_inv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inv_list)

	vbox.add_child(HSeparator.new())

	var note := Label.new()
	note.text = "Drop (free) | Equip = Ready maneuver"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(note)


func show_inventory(char_data: CharacterData) -> void:
	for child in _inv_list.get_children():
		child.queue_free()

	if not char_data:
		_inv_panel.visible = true
		return

	# ── Currently equipped ──
	_inv_list.add_child(_make_section_label("── Equipped ─────────────────"))

	var rh := char_data.get_right_hand()
	var rh_name := "[Unarmed]"
	if rh is RangedWeaponData:
		var rw := rh as RangedWeaponData
		rh_name = "%s (Skill %d)  %s" % [rw.weapon_name, rw.skill_level, rw.ammo_summary() if rw.uses_magazines() else ""]
	elif rh is MeleeWeaponData:
		var mw := rh as MeleeWeaponData
		if mw.mode.to_lower() not in ["punch", "kick", "bite"]:
			rh_name = "%s: %s (Skill %d)" % [mw.weapon_name, mw.mode, mw.skill_level]

	_inv_list.add_child(_make_item_row(rh_name, null))

	_inv_list.add_child(HSeparator.new())
	_inv_list.add_child(_make_section_label("── Ranged Weapons ───────────"))

	for weapon: RangedWeaponData in char_data.ranged_weapons:
		var label := "%s  Skill %d  Dmg %s  Ammo: %s" % [
			weapon.weapon_name, weapon.skill_level, weapon.damage,
			weapon.ammo_summary() if weapon.uses_magazines() else weapon.shots]
		var w := weapon
		var row := _make_item_row(label, func(): equip_weapon_requested.emit(w))
		_inv_list.add_child(row)

	_inv_list.add_child(HSeparator.new())
	_inv_list.add_child(_make_section_label("── Melee Weapons ────────────"))

	for weapon: MeleeWeaponData in char_data.melee_weapons:
		var label := "%s: %s  Skill %d  Dmg %s" % [
			weapon.weapon_name, weapon.mode, weapon.skill_level, weapon.damage]
		var w := weapon
		var row := _make_item_row(label, func(): equip_weapon_requested.emit(w))
		_inv_list.add_child(row)

	_inv_panel.visible = true


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl


func _make_item_row(item_text: String, equip_callback = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = item_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(lbl)
	if equip_callback != null and equip_callback is Callable and equip_callback.is_valid():
		var btn := Button.new()
		btn.text = "Equip"
		btn.pressed.connect(equip_callback)
		row.add_child(btn)
	return row
