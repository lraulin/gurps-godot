class_name GameUI
extends Control

## XCOM-style bottom bar HUD.
## Builds all UI nodes programmatically — no .tscn sub-nodes needed.

signal hand_slot_clicked(hand: String)
signal attack_mode_selected(weapon, mode: String)
signal kick_requested()
signal maneuver_button_pressed(type: Maneuver.Type)
signal inventory_opened()
signal end_turn_pressed()
signal combat_log_toggled()
signal combat_popup_confirmed()

const BAR_HEIGHT := 120

# Bottom bar refs
var _left_hand_btn: Button
var _right_hand_btn: Button
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
var _current_char_data: CharacterData = null

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

	# ── Left hand ──
	_left_hand_btn = Button.new()
	_left_hand_btn.custom_minimum_size = Vector2(110, 0)
	_left_hand_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_hand_btn.text = "LEFT HAND\n\n[Fist]"
	_left_hand_btn.pressed.connect(func(): hand_slot_clicked.emit("left"))
	hbox.add_child(_left_hand_btn)

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

	# ── Right hand ──
	_right_hand_btn = Button.new()
	_right_hand_btn.custom_minimum_size = Vector2(110, 0)
	_right_hand_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_hand_btn.text = "RIGHT HAND\n\n[Fist]"
	_right_hand_btn.pressed.connect(func(): hand_slot_clicked.emit("right"))
	hbox.add_child(_right_hand_btn)

	_build_action_buttons([])


# ─── Action Row ────────────────────────────────────────────────────────────────

func _build_action_buttons(available: Array[Maneuver.Type]) -> void:
	_clear_action_row()
	_current_available = available

	# Maneuver buttons
	var shown_maneuvers: Array[Maneuver.Type] = [
		Maneuver.Type.ALL_OUT_ATTACK,
		Maneuver.Type.ALL_OUT_DEFENSE,
		Maneuver.Type.READY,
		Maneuver.Type.AIM,
		Maneuver.Type.WAIT,
	]
	for mtype in shown_maneuvers:
		var btn := Button.new()
		btn.text = Maneuver.get_maneuver_name(mtype)
		# Empty available = all disabled (turn over); populated = only listed types enabled
		var enabled: bool = mtype in available
		btn.disabled = not enabled
		var t := mtype  # capture for closure
		btn.pressed.connect(func(): maneuver_button_pressed.emit(t))
		_action_row.add_child(btn)

	_action_row.add_child(_make_spacer())

	# Kick (always enabled)
	var kick_btn := Button.new()
	kick_btn.text = "KICK"
	kick_btn.pressed.connect(func(): kick_requested.emit())
	_action_row.add_child(kick_btn)

	_action_row.add_child(_make_spacer())

	# Utility buttons
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


func show_attack_options(char_data: CharacterData) -> void:
	## Replace the action row with weapon/attack mode buttons + Cancel.
	_clear_action_row()

	for weapon in char_data.ranged_weapons:
		var btn := Button.new()
		btn.text = "%s (Skill %d)" % [weapon.weapon_name, weapon.skill_level]
		var w = weapon
		btn.pressed.connect(func(): attack_mode_selected.emit(w, "ranged"))
		_action_row.add_child(btn)

	for weapon in char_data.melee_weapons:
		var btn := Button.new()
		btn.text = "%s: %s (%d)" % [weapon.weapon_name, weapon.mode, weapon.skill_level]
		var w = weapon
		var m: String = weapon.mode
		btn.pressed.connect(func(): attack_mode_selected.emit(w, m))
		_action_row.add_child(btn)

	_action_row.add_child(_make_spacer())

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): _build_action_buttons(_current_available))
	_action_row.add_child(cancel)


func update_hand_displays(char_data: CharacterData) -> void:
	_current_char_data = char_data
	if not char_data:
		_left_hand_btn.text = "LEFT HAND\n\n[Fist]"
		_right_hand_btn.text = "RIGHT HAND\n\n[Fist]"
		return

	# Right hand: primary weapon
	var right_text := "[Fist]"
	if char_data.ranged_weapons.size() > 0:
		right_text = char_data.ranged_weapons[0].weapon_name
	elif char_data.melee_weapons.size() > 0:
		for w in char_data.melee_weapons:
			if w.weapon_name != "Brawling" and w.mode.to_lower() not in ["kick", "bite"]:
				right_text = "%s (%s)" % [w.weapon_name, w.mode]
				break
	_right_hand_btn.text = "RIGHT HAND\n\n%s" % right_text
	_left_hand_btn.text = "LEFT HAND\n\n[Fist]"


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


# ─── Attack Popup ──────────────────────────────────────────────────────────────

func _build_attack_popup() -> void:
	_attack_popup = AcceptDialog.new()
	_attack_popup.title = "Attack Resolution"
	_attack_popup.min_size = Vector2(440, 220)
	_attack_popup.exclusive = true   # blocks input to background while open
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

	# Skill line
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
		lines.append("* Missed targeted location by 1 — hits TORSO instead!")

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
	_inv_panel.custom_minimum_size = Vector2(380, 350)
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
	scroll.custom_minimum_size = Vector2(0, 220)
	vbox.add_child(scroll)

	_inv_list = VBoxContainer.new()
	_inv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inv_list)

	vbox.add_child(HSeparator.new())

	var note := Label.new()
	note.text = "Dropping from hand: free action.  Equipping from inventory: Ready maneuver."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(note)


func show_inventory(char_data: CharacterData) -> void:
	for child in _inv_list.get_children():
		child.queue_free()

	if not char_data:
		_inv_panel.visible = true
		return

	var _add_row := func(text: String) -> void:
		var lbl := Label.new()
		lbl.text = text
		_inv_list.add_child(lbl)

	# Hands section
	_add_row.call("── Equipped ─────────────────────")

	var rh_text := "[Fist]"
	if char_data.ranged_weapons.size() > 0:
		rh_text = "%s  (Skill %d,  Ammo: %s)" % [
			char_data.ranged_weapons[0].weapon_name,
			char_data.ranged_weapons[0].skill_level,
			char_data.ranged_weapons[0].ammo_summary() if char_data.ranged_weapons[0].uses_magazines() else "—"]
	_add_row.call("Right Hand:  %s" % rh_text)
	_add_row.call("Left Hand:   [Fist]")

	_inv_list.add_child(HSeparator.new())
	_add_row.call("── Weapons Carried ──────────────")

	for weapon: RangedWeaponData in char_data.ranged_weapons:
		_add_row.call("  %s  [Ranged]  Skill %d  Dmg %s" % [
			weapon.weapon_name, weapon.skill_level, weapon.damage])

	for weapon: MeleeWeaponData in char_data.melee_weapons:
		_add_row.call("  %s: %s  Skill %d  Dmg %s" % [
			weapon.weapon_name, weapon.mode, weapon.skill_level, weapon.damage])

	_inv_panel.visible = true
