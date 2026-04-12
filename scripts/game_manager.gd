class_name GameManager
extends Node2D

## Manages game state: turn order, character selection, movement, combat.

@onready var hex_grid: HexGrid = $HexGrid
@onready var ui: GameUI = $CanvasLayer/GameUI
@onready var combat_log: CombatLog = $CanvasLayer/CombatLog

var characters: Array[CharacterToken] = []
var turn_order: Array[CharacterToken] = []
var current_turn_index: int = 0
var selected_character: CharacterToken = null
var occupied_hexes: Dictionary = {}  # Vector2i -> CharacterToken
var character_enabled: Dictionary = {}  # CharacterToken -> bool
var combat_started: bool = false

var combat_states: Dictionary = {}  # CharacterToken -> CombatantState

const COLOR_STEP:   Color = Color(0.2, 0.6, 1.0, 0.25)
const COLOR_HALF:   Color = Color(0.2, 0.8, 0.3, 0.25)
const COLOR_FULL:   Color = Color(1.0, 0.8, 0.2, 0.25)
const COLOR_TARGET: Color = Color(1.0, 0.2, 0.2, 0.3)

enum State {
	PLAYER_TURN,             # move + choose maneuver
	SELECTING_WEAPON,        # attack maneuver chosen; picking weapon + shots
	SELECTING_ATTACK_TARGET, # weapon chosen; picking enemy to resolve
	SELECTING_ALL_OUT_DEFENSE_OPTION,
	STEP_AVAILABLE,          # attacked with no prior movement; 1-hex step allowed
	TURN_OVER,               # done, waiting for End Turn
}
var _state: State = State.PLAYER_TURN

# Turn-local attack tracking
var _committed_maneuver: Maneuver.Type = Maneuver.Type.DO_NOTHING
var _pending_target: CharacterToken = null   # target chosen in SELECTING_ATTACK_TARGET
var _pending_weapon = null                   # weapon chosen before target
var _pending_attack_mode: String = ""        # "ranged" or melee mode string
var _pending_shots: int = 1                  # shot count for ranged RoF > 1

func _ready() -> void:
	hex_grid.hex_clicked.connect(_on_hex_clicked)
	ui.end_turn_pressed.connect(_on_end_turn)
	ui.attack_mode_selected.connect(_on_attack_mode_selected)
	ui.shots_selected.connect(_on_shots_selected)
	ui.maneuver_button_pressed.connect(_on_maneuver_button_pressed)
	ui.inventory_opened.connect(_on_inventory_opened)
	ui.combat_log_toggled.connect(_on_combat_log_toggled)
	ui.combat_popup_confirmed.connect(_on_combat_popup_confirmed)
	ui.equip_weapon_requested.connect(_on_equip_weapon_requested)
	ui.cancel_attack.connect(_on_cancel_attack)
	ui.all_out_defense_option_selected.connect(_on_all_out_defense_option_selected)
	ui.character_toggle_requested.connect(_on_character_toggle_requested)

func add_character(token: CharacterToken, hex: Vector2i) -> void:
	characters.append(token)
	hex_grid.add_child(token)
	token.place_on_hex(hex)
	occupied_hexes[hex] = token
	combat_states[token] = CombatantState.new()
	character_enabled[token] = true
	_sync_character_toggle_menu()

func start_combat() -> void:
	_rebuild_turn_order()
	combat_started = true
	if turn_order.is_empty():
		hex_grid.clear_highlights()
		ui.show_action_buttons([])
		ui.show_message("No enabled characters. Enable one from Characters menu.")
		return
	current_turn_index = 0
	_start_turn()

# ─── Turn Management ──────────────────────────────────────────────────────────

func _start_turn() -> void:
	var attempts: int = 0
	while attempts < turn_order.size():
		var tok: CharacterToken = turn_order[current_turn_index]
		var cst: CombatantState = combat_states[tok] as CombatantState
		if not _is_character_enabled(tok) or tok.data.dead or cst.unconscious:
			current_turn_index = (current_turn_index + 1) % turn_order.size()
			attempts += 1
			continue
		break

	if attempts >= turn_order.size():
		combat_log.log_message("No enabled conscious characters available. Combat paused.")
		hex_grid.clear_highlights()
		ui.show_action_buttons([])
		ui.show_message("Enable a character from Characters menu")
		return

	var token: CharacterToken = turn_order[current_turn_index]
	var cstate: CombatantState = combat_states[token] as CombatantState
	cstate.reset_for_new_turn()
	token.movement_used = 0

	_committed_maneuver = Maneuver.Type.DO_NOTHING
	_pending_target = null
	_pending_weapon = null
	_pending_attack_mode = ""
	_pending_shots = 1

	_select_character(token)
	combat_log.log_turn(token.data.char_name, current_turn_index + 1, turn_order.size())

	# Show aim crosshair if this character is aiming at someone
	_refresh_aim_crosshairs(token, cstate)

	if cstate.stunned:
		combat_log.log_message("%s is stunned! Must Do Nothing. Rolling HT to recover..." % token.data.char_name)
		var roll: int = Dice.roll_3d()
		if roll <= token.data.ht:
			cstate.stunned = false
			combat_log.log_message("  Rolled %d vs HT %d — recovered from stun!" % [roll, token.data.ht])
		else:
			combat_log.log_message("  Rolled %d vs HT %d — still stunned." % [roll, token.data.ht])
		_state = State.TURN_OVER
		hex_grid.clear_highlights()
		ui.show_action_buttons([])
		ui.set_character_info(token.data.char_name, token.data.hp, token.data.hp_max,
			token.data.fp, token.data.fp_max, "STUNNED — turn over")
	
		return

	_state = State.PLAYER_TURN
	_refresh_ui()

func _refresh_aim_crosshairs(aimer: CharacterToken, cstate: CombatantState) -> void:
	# Clear all crosshairs first
	for tok: CharacterToken in characters:
		if not _is_character_enabled(tok):
			continue
		if tok.is_aim_target:
			tok.is_aim_target = false
			tok.queue_redraw()
	# Set on aim target if aiming
	if cstate.aim_target != null:
		for tok: CharacterToken in characters:
			if not _is_character_enabled(tok):
				continue
			if tok.data == cstate.aim_target:
				tok.is_aim_target = true
				tok.queue_redraw()
				break

func _select_character(token: CharacterToken) -> void:
	if selected_character:
		selected_character.set_selected(false)
	selected_character = token
	token.set_selected(true)

func _refresh_ui() -> void:
	if not selected_character:
		return
	var token := selected_character
	ui.set_character_info(token.data.char_name, token.data.hp, token.data.hp_max,
		token.data.fp, token.data.fp_max, "")

	_update_action_buttons()
	_show_movement_zones()

# ─── Movement ─────────────────────────────────────────────────────────────────

func _show_movement_zones() -> void:
	if not selected_character:
		return
	var basic_move: int = selected_character.data.effective_move()
	var current_hex: Vector2i = selected_character.hex_pos
	var moved: int = selected_character.movement_used

	var max_remaining: int = max(_current_turn_max_movement(basic_move) - moved, 0)

	var remaining_half: int = max(int(ceil(basic_move / 2.0)) - moved, 0)
	var remaining_step: int = max(1 - moved, 0)

	var highlights: Dictionary = {}
	var reachable: Dictionary = _bfs_reachable(current_hex, max_remaining)

	for hex: Vector2i in reachable:
		var dist: int = reachable[hex] as int
		if dist == 0:
			continue
		if dist <= remaining_step:
			highlights[hex] = COLOR_STEP
		elif dist <= remaining_half:
			highlights[hex] = COLOR_HALF
		elif dist <= max_remaining:
			highlights[hex] = COLOR_FULL

	hex_grid.set_highlights(highlights)

func _bfs_reachable(start: Vector2i, max_dist: int) -> Dictionary:
	var result: Dictionary = {start: 0}
	var frontier: Array[Vector2i] = [start]
	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front() as Vector2i
		var current_dist: int = result[current] as int
		if current_dist >= max_dist:
			continue
		for neighbor: Vector2i in HexUtils.get_neighbors(current):
			if result.has(neighbor):
				continue
			if not hex_grid.is_valid_hex(neighbor):
				continue
			if occupied_hexes.has(neighbor) and neighbor != start:
				continue
			result[neighbor] = current_dist + 1
			frontier.append(neighbor)
	return result

func _move_character(token: CharacterToken, to_hex: Vector2i, distance: int) -> void:
	occupied_hexes.erase(token.hex_pos)
	occupied_hexes[to_hex] = token
	token.hex_pos = to_hex
	token.position = HexUtils.axial_to_pixel(to_hex)
	token.movement_used += distance

	if distance > 0:
		var cstate: CombatantState = combat_states[token] as CombatantState
		cstate.break_aim()
		cstate.break_evaluate()
		# Clear aim crosshair since aim was broken
		for tok: CharacterToken in characters:
			if tok.is_aim_target:
				tok.is_aim_target = false
				tok.queue_redraw()

	_update_action_buttons()
	_show_movement_zones()

func _update_action_buttons() -> void:
	if not selected_character:
		return
	var available: Array[Maneuver.Type] = Maneuver.available_maneuvers(
		selected_character.movement_used,
		selected_character.data.effective_move()
	)
	if _committed_maneuver == Maneuver.Type.ALL_OUT_DEFENSE:
		ui.show_action_buttons([])
	else:
		ui.show_action_buttons(available)

# ─── Hex Clicks ───────────────────────────────────────────────────────────────

func _on_hex_clicked(hex: Vector2i) -> void:
	if not selected_character:
		return
	match _state:
		State.PLAYER_TURN:
			_handle_movement_click(hex)
		State.SELECTING_ALL_OUT_DEFENSE_OPTION:
			pass
		State.SELECTING_WEAPON:
			pass  # no hex interaction during weapon/shots selection
		State.STEP_AVAILABLE:
			_handle_step_click(hex)
		State.SELECTING_ATTACK_TARGET:
			_handle_target_click(hex)

func _handle_movement_click(hex: Vector2i) -> void:
	if hex == selected_character.hex_pos:
		return
	if occupied_hexes.has(hex) and occupied_hexes[hex] != selected_character:
		return

	var basic_move: int = selected_character.data.effective_move()
	var max_remaining: int = _current_turn_max_movement(basic_move) - selected_character.movement_used
	max_remaining = max(max_remaining, 0)

	var reachable: Dictionary = _bfs_reachable(selected_character.hex_pos, max_remaining)
	if reachable.has(hex):
		_move_character(selected_character, hex, reachable[hex] as int)

func _handle_step_click(hex: Vector2i) -> void:
	if hex == selected_character.hex_pos:
		return
	if occupied_hexes.has(hex) and occupied_hexes[hex] != selected_character:
		return
	var reachable: Dictionary = _bfs_reachable(selected_character.hex_pos, 1)
	if reachable.has(hex):
		_move_character(selected_character, hex, reachable[hex] as int)
		_state = State.TURN_OVER
		hex_grid.clear_highlights()
		ui.show_action_buttons([])
		ui.show_message("Turn over — click End Turn")

func _handle_target_click(hex: Vector2i) -> void:
	if not occupied_hexes.has(hex):
		return
	var target_token: CharacterToken = occupied_hexes[hex] as CharacterToken
	if not _is_character_enabled(target_token) or target_token == selected_character or target_token.data.dead:
		return

	var cstate: CombatantState = combat_states[selected_character] as CombatantState

	# ── Aim ──
	if _committed_maneuver == Maneuver.Type.AIM:
		if selected_character.data.ranged_weapons.size() == 0:
			return
		var weapon: RangedWeaponData = selected_character.data.ranged_weapons[0]
		if cstate.aim_target == target_token.data and cstate.aim_weapon_name == weapon.weapon_name:
			cstate.aim_turns += 1
		else:
			cstate.aim_target = target_token.data
			cstate.aim_weapon_name = weapon.weapon_name
			cstate.aim_turns = 1
		var aim_bonus: int = weapon.accuracy + min(cstate.aim_turns - 1, 2)
		combat_log.log_message("%s aims %s at %s (turn %d, +%d acc)" % [
			selected_character.data.char_name, weapon.weapon_name,
			target_token.data.char_name, cstate.aim_turns, aim_bonus])
		# Show crosshair on the aim target
		for tok: CharacterToken in characters:
			if not _is_character_enabled(tok):
				continue
			tok.is_aim_target = (tok == target_token)
			tok.queue_redraw()
		_state = State.TURN_OVER
		hex_grid.clear_highlights()
		ui.show_action_buttons([])
		ui.show_message("Aiming at %s — click End Turn" % target_token.data.char_name)
		return

	# ── Store target and resolve ──
	_pending_target = target_token

	if _pending_weapon == null:
		return  # shouldn't happen — weapon selected before target in new flow

	# Validate range for melee
	if _pending_attack_mode != "ranged":
		var range_hexes: int = HexUtils.hex_distance(selected_character.hex_pos, target_token.hex_pos)
		if range_hexes > 1:
			ui.show_message("Target is not adjacent — melee out of range!")
			_pending_target = null
			return

	_resolve_attack(_pending_target, _pending_weapon, _pending_attack_mode, _pending_shots)

# ─── UI Signal Handlers ───────────────────────────────────────────────────────

func _on_maneuver_button_pressed(type: Maneuver.Type) -> void:
	if not selected_character:
		return
	var cstate: CombatantState = combat_states[selected_character] as CombatantState
	cstate.last_maneuver = type

	match type:
		Maneuver.Type.ATTACK, Maneuver.Type.ALL_OUT_ATTACK, Maneuver.Type.MOVE_AND_ATTACK:
			_committed_maneuver = type
			if type == Maneuver.Type.ALL_OUT_ATTACK:
				cstate.all_out_attack = true
				combat_log.log_message("%s goes All-Out Attack!" % selected_character.data.char_name)
			elif type == Maneuver.Type.MOVE_AND_ATTACK:
				combat_log.log_message("%s uses Move and Attack." % selected_character.data.char_name)
			_state = State.SELECTING_WEAPON
			hex_grid.clear_highlights()
			ui.show_weapon_options(selected_character.data, _has_adjacent_enemy())
			ui.show_message("Choose your weapon")

		Maneuver.Type.ALL_OUT_DEFENSE:
			_state = State.SELECTING_ALL_OUT_DEFENSE_OPTION
			hex_grid.clear_highlights()
			ui.show_all_out_defense_options(selected_character.movement_used <= 1)
			ui.show_message("Choose All-Out Defense option")

		Maneuver.Type.AIM:
			if selected_character.data.ranged_weapons.size() == 0:
				ui.show_message("No ranged weapon to aim!")
				return
			_committed_maneuver = type
			_state = State.SELECTING_ATTACK_TARGET
			hex_grid.clear_highlights()
			_highlight_valid_targets()
			ui.show_select_target_prompt()
			ui.show_message("Click a target to aim at")

		Maneuver.Type.READY:
			_committed_maneuver = type
			combat_log.log_message("%s takes a Ready action." % selected_character.data.char_name)
			_state = State.TURN_OVER
			hex_grid.clear_highlights()
			ui.show_action_buttons([])
			ui.show_message("Ready — click End Turn (or use Inventory to equip)")

		Maneuver.Type.WAIT:
			_committed_maneuver = type
			cstate.waiting = true
			combat_log.log_message("%s waits." % selected_character.data.char_name)
			_state = State.TURN_OVER
			hex_grid.clear_highlights()
			ui.show_action_buttons([])
			ui.show_message("Waiting — click End Turn")


func _on_attack_mode_selected(weapon, mode: String) -> void:
	_pending_weapon = weapon
	_pending_attack_mode = mode

	# For ranged weapons with RoF > 1, ask how many shots before target selection
	if mode == "ranged":
		var rw := weapon as RangedWeaponData
		if rw.rof > 1 and rw.loaded_rounds() > 1:
			ui.show_shots_selector(rw)
			ui.show_message("How many shots? (RoF %d)" % rw.rof)
			return

	# Single-shot ranged or melee — proceed to target selection
	_pending_shots = 1
	_enter_target_selection()


func _on_all_out_defense_option_selected(option: int) -> void:
	if not selected_character:
		return

	var cstate: CombatantState = combat_states[selected_character] as CombatantState
	var selected_option: Maneuver.AllOutDefenseOption = option as Maneuver.AllOutDefenseOption

	if selected_option != Maneuver.AllOutDefenseOption.INCREASED_DODGE and selected_character.movement_used > 1:
		ui.show_message("That All-Out Defense option is step-only")
		return

	_committed_maneuver = Maneuver.Type.ALL_OUT_DEFENSE
	cstate.last_maneuver = Maneuver.Type.ALL_OUT_DEFENSE
	cstate.all_out_defense = true
	cstate.all_out_defense_option = selected_option

	var option_name: String = Maneuver.get_all_out_defense_option_name(selected_option)
	combat_log.log_message("%s takes All-Out Defense (%s)." % [selected_character.data.char_name, option_name])

	_state = State.PLAYER_TURN
	ui.show_action_buttons([])
	_show_movement_zones()
	ui.show_message("All-Out Defense (%s) — move, then End Turn" % option_name)


func _on_shots_selected(count: int) -> void:
	if _pending_weapon == null:
		return
	_pending_shots = count
	_enter_target_selection()


func _enter_target_selection() -> void:
	_state = State.SELECTING_ATTACK_TARGET
	_highlight_valid_targets()
	ui.show_select_target_prompt()
	ui.show_message("Click an enemy to attack")


func _on_cancel_attack() -> void:
	if _state == State.SELECTING_ALL_OUT_DEFENSE_OPTION:
		_committed_maneuver = Maneuver.Type.DO_NOTHING
		_state = State.PLAYER_TURN
		_refresh_ui()
		return

	# From target selection or shots selector — go back to weapon options
	if _state == State.SELECTING_ATTACK_TARGET or _pending_weapon != null:
		_pending_target = null
		_pending_weapon = null
		_pending_attack_mode = ""
		_pending_shots = 1
		_state = State.SELECTING_WEAPON
		hex_grid.clear_highlights()
		ui.show_weapon_options(selected_character.data, _has_adjacent_enemy())
		ui.show_message("Choose your weapon")
		return

	# From weapon selection — return to PLAYER_TURN
	_committed_maneuver = Maneuver.Type.DO_NOTHING
	_state = State.PLAYER_TURN
	_refresh_ui()


func _on_inventory_opened() -> void:
	if selected_character:
		ui.show_inventory(selected_character.data)


func _on_equip_weapon_requested(weapon) -> void:
	if not selected_character:
		return
	# Equipping costs a Ready maneuver — only allowed at start of turn before any action
	if _state != State.PLAYER_TURN:
		ui.show_message("Equipping costs a Ready maneuver — can't do it now")
		return
	if _committed_maneuver != Maneuver.Type.DO_NOTHING:
		ui.show_message("Already committed to a maneuver this turn")
		return

	selected_character.data.right_hand_weapon = weapon
	var wname: String = weapon.weapon_name if weapon else "Fist"
	combat_log.log_message("%s readies %s." % [selected_character.data.char_name, wname])

	_committed_maneuver = Maneuver.Type.READY
	var cstate := combat_states[selected_character] as CombatantState
	cstate.last_maneuver = Maneuver.Type.READY
	_state = State.TURN_OVER
	hex_grid.clear_highlights()
	ui.show_action_buttons([])
	ui.close_inventory()
	ui.show_message("Readied %s — click End Turn" % wname)


func _on_combat_log_toggled() -> void:
	combat_log.visible = not combat_log.visible


func _on_combat_popup_confirmed() -> void:
	if _state == State.SELECTING_ATTACK_TARGET:
		var moved: int = selected_character.movement_used
		if moved == 0 and _committed_maneuver == Maneuver.Type.ATTACK:
			_state = State.STEP_AVAILABLE
			_show_movement_zones()
			ui.show_action_buttons([])
			ui.show_message("Attack done — take a step or End Turn")
		else:
			_state = State.TURN_OVER
			hex_grid.clear_highlights()
			ui.show_action_buttons([])
			ui.show_message("Turn over — click End Turn")


func _on_end_turn() -> void:
	# Clear all aim crosshairs before moving to next turn
	for tok: CharacterToken in characters:
		if tok.is_aim_target:
			tok.is_aim_target = false
			tok.queue_redraw()
	if turn_order.is_empty():
		hex_grid.clear_highlights()
		ui.show_action_buttons([])
		ui.show_message("No enabled characters. Enable one from Characters menu.")
		return
	hex_grid.clear_highlights()
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	_start_turn()

# ─── Combat Resolution ────────────────────────────────────────────────────────

func _resolve_attack(target: CharacterToken, weapon, mode: String, shots: int) -> void:
	var cstate: CombatantState = combat_states[selected_character] as CombatantState
	var range_hexes: int = HexUtils.hex_distance(selected_character.hex_pos, target.hex_pos)
	var is_adjacent: bool = range_hexes <= 1
	var extra_mods: Array = []

	if cstate.shock != 0:
		extra_mods.append(["shock", cstate.shock])

	# Infer maneuver if not explicitly committed
	var maneuver: Maneuver.Type = _committed_maneuver
	if maneuver == Maneuver.Type.DO_NOTHING:
		maneuver = _get_inferred_maneuver()

	if maneuver == Maneuver.Type.MOVE_AND_ATTACK:
		if mode == "ranged":
			var rw := weapon as RangedWeaponData
			extra_mods.append(["move & attack", min(-2, rw.bulk)])
		else:
			extra_mods.append(["move & attack", -4])

	var is_all_out: bool = (maneuver == Maneuver.Type.ALL_OUT_ATTACK)
	var attack_result: AttackResult = null

	if mode == "ranged":
		var rw := weapon as RangedWeaponData
		var aim_turns: int = cstate.aim_turns if cstate.aim_target == target.data else 0
		attack_result = CombatResolver.resolve_ranged_attack(
			selected_character.data, rw, target.data,
			range_hexes, shots, "", aim_turns, false, is_all_out, extra_mods)
		cstate.break_aim()
		# Clear crosshair on fired-at target
		target.is_aim_target = false
		target.queue_redraw()
	else:
		var mw := weapon as MeleeWeaponData
		var dmg_bonus: int = 2 if is_all_out else 0
		var max_eff: int = 9 if maneuver == Maneuver.Type.MOVE_AND_ATTACK else -1
		attack_result = CombatResolver.resolve_melee_attack(
			selected_character.data, mw, target.data,
			"", is_all_out, extra_mods, dmg_bonus, max_eff)

	if attack_result:
		combat_log.log_attack(attack_result)

		if attack_result.total_injury > 0:
			var target_state: CombatantState = combat_states[target] as CombatantState
			target_state.shock = target.data.shock_from_injury(attack_result.total_injury)
			for dr: DamageResult in attack_result.damage_results:
				if dr.knockdown_required and not dr.knockdown_succeeded:
					target_state.stunned = true
				if dr.dead:
					target.set_dead()
			target.flash_damage()
			target.update_hp_display()

		_committed_maneuver = maneuver
		cstate.all_out_attack = is_all_out
		cstate.attacked_this_turn = true

		ui.show_combat_popup(attack_result)
		# State advances in _on_combat_popup_confirmed


func _current_turn_max_movement(basic_move: int) -> int:
	if _state == State.STEP_AVAILABLE:
		return 1

	if _committed_maneuver == Maneuver.Type.ALL_OUT_ATTACK:
		return int(ceil(basic_move / 2.0))

	if _committed_maneuver == Maneuver.Type.ALL_OUT_DEFENSE and selected_character:
		var cstate: CombatantState = combat_states[selected_character] as CombatantState
		return Maneuver.all_out_defense_max_movement(cstate.all_out_defense_option, basic_move)

	return basic_move


func _get_inferred_maneuver() -> Maneuver.Type:
	if not selected_character:
		return Maneuver.Type.ATTACK
	return Maneuver.Type.ATTACK if selected_character.movement_used <= 1 else Maneuver.Type.MOVE_AND_ATTACK


func _has_adjacent_enemy() -> bool:
	for token: CharacterToken in characters:
		if not _is_character_enabled(token) or token == selected_character or token.data.dead:
			continue
		if HexUtils.hex_distance(selected_character.hex_pos, token.hex_pos) <= 1:
			return true
	return false


func _highlight_valid_targets() -> void:
	var highlights: Dictionary = {}
	for token: CharacterToken in characters:
		if not _is_character_enabled(token) or token == selected_character or token.data.dead:
			continue
		var dist := HexUtils.hex_distance(selected_character.hex_pos, token.hex_pos)
		# Filter by weapon range
		if _pending_weapon is MeleeWeaponData:
			if dist > 1:
				continue
		elif _pending_weapon is RangedWeaponData:
			var rw := _pending_weapon as RangedWeaponData
			if dist > rw.range_max:
				continue
		highlights[token.hex_pos] = COLOR_TARGET
	hex_grid.set_highlights(highlights)


func _is_character_enabled(token: CharacterToken) -> bool:
	return bool(character_enabled.get(token, true))


func _rebuild_turn_order() -> void:
	var previous_current: CharacterToken = null
	if current_turn_index >= 0 and current_turn_index < turn_order.size():
		previous_current = turn_order[current_turn_index]

	turn_order.clear()
	for token: CharacterToken in characters:
		if _is_character_enabled(token):
			turn_order.append(token)

	turn_order.sort_custom(func(a: CharacterToken, b: CharacterToken) -> bool:
		if a.data.speed_stat != b.data.speed_stat:
			return a.data.speed_stat > b.data.speed_stat
		return a.data.dx_stat > b.data.dx_stat
	)

	if turn_order.is_empty():
		current_turn_index = 0
		return

	if previous_current != null and turn_order.has(previous_current):
		current_turn_index = turn_order.find(previous_current)
	else:
		current_turn_index = clamp(current_turn_index, 0, turn_order.size() - 1)


func _sync_character_toggle_menu() -> void:
	var names: Array[String] = []
	var enabled: Array[bool] = []
	for token: CharacterToken in characters:
		names.append(token.data.char_name)
		enabled.append(_is_character_enabled(token))
	ui.set_character_toggle_options(names, enabled)


func _on_character_toggle_requested(index: int, enabled: bool) -> void:
	if index < 0 or index >= characters.size():
		return

	var token: CharacterToken = characters[index]
	character_enabled[token] = enabled
	token.modulate = Color.WHITE if enabled else Color(1.0, 1.0, 1.0, 0.35)

	if not enabled:
		token.set_selected(false)
		token.is_aim_target = false
		token.queue_redraw()
		if _pending_target == token:
			_pending_target = null
		if selected_character == token:
			selected_character = null

	_sync_character_toggle_menu()

	if not combat_started:
		return

	_rebuild_turn_order()

	if turn_order.is_empty():
		hex_grid.clear_highlights()
		ui.show_action_buttons([])
		ui.show_message("No enabled characters. Enable one from Characters menu.")
		return

	if selected_character == null or not _is_character_enabled(selected_character):
		_start_turn()
		return

	if _state == State.SELECTING_ATTACK_TARGET:
		_highlight_valid_targets()

	_refresh_ui()
