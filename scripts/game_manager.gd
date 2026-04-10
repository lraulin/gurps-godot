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

# Per-combatant state
var combat_states: Dictionary = {}  # CharacterToken -> CombatantState

# Movement zone colors
const COLOR_STEP: Color = Color(0.2, 0.6, 1.0, 0.25)
const COLOR_HALF: Color = Color(0.2, 0.8, 0.3, 0.25)
const COLOR_FULL: Color = Color(1.0, 0.8, 0.2, 0.25)
const COLOR_TARGET: Color = Color(1.0, 0.2, 0.2, 0.3)

# Game state
enum State {
	PLAYER_TURN,            # Default: can click hexes to move, see action buttons
	SELECTING_ATTACK_TARGET, # Chose an attack, picking an enemy hex
	STEP_AVAILABLE,         # Attacked with no prior movement; 1-hex step still allowed
	TURN_OVER,              # Main action done, waiting for End Turn
}
var _state: State = State.PLAYER_TURN

# Turn-local attack tracking
var _committed_maneuver: Maneuver.Type = Maneuver.Type.DO_NOTHING
var _pending_weapon = null        # MeleeWeaponData or RangedWeaponData
var _pending_attack_mode: String = ""  # "ranged", or melee mode string like "Punch"

func _ready() -> void:
	hex_grid.hex_clicked.connect(_on_hex_clicked)
	ui.end_turn_pressed.connect(_on_end_turn)
	ui.hand_slot_clicked.connect(_on_hand_clicked)
	ui.attack_mode_selected.connect(_on_attack_mode_selected)
	ui.kick_requested.connect(_on_kick_requested)
	ui.maneuver_button_pressed.connect(_on_maneuver_button_pressed)
	ui.inventory_opened.connect(_on_inventory_opened)
	ui.combat_log_toggled.connect(_on_combat_log_toggled)
	ui.combat_popup_confirmed.connect(_on_combat_popup_confirmed)

func add_character(token: CharacterToken, hex: Vector2i) -> void:
	characters.append(token)
	hex_grid.add_child(token)
	token.place_on_hex(hex)
	occupied_hexes[hex] = token
	combat_states[token] = CombatantState.new()

func start_combat() -> void:
	turn_order = characters.duplicate()
	turn_order.sort_custom(func(a: CharacterToken, b: CharacterToken) -> bool:
		if a.data.speed_stat != b.data.speed_stat:
			return a.data.speed_stat > b.data.speed_stat
		return a.data.dx_stat > b.data.dx_stat
	)
	current_turn_index = 0
	_start_turn()

func _start_turn() -> void:
	# Skip dead/unconscious characters
	var attempts: int = 0
	while attempts < turn_order.size():
		var token: CharacterToken = turn_order[current_turn_index]
		var cstate: CombatantState = combat_states[token] as CombatantState
		if token.data.dead or cstate.unconscious:
			current_turn_index = (current_turn_index + 1) % turn_order.size()
			attempts += 1
			continue
		break

	if attempts >= turn_order.size():
		combat_log.log_message("All characters are down. Combat over.")
		return

	var token: CharacterToken = turn_order[current_turn_index]
	var cstate: CombatantState = combat_states[token] as CombatantState
	cstate.reset_for_new_turn()
	token.movement_used = 0

	_committed_maneuver = Maneuver.Type.DO_NOTHING
	_pending_weapon = null
	_pending_attack_mode = ""

	_select_character(token)
	combat_log.log_turn(token.data.char_name, current_turn_index + 1, turn_order.size())

	# Handle stunned
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
		ui.update_hand_displays(token.data)
		return

	_state = State.PLAYER_TURN
	_refresh_ui()

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
	ui.update_hand_displays(token.data)
	_update_action_buttons()
	_show_movement_zones()

# ─── Movement ─────────────────────────────────────────────────────────────────

func _show_movement_zones() -> void:
	if not selected_character:
		return
	var basic_move: int = selected_character.data.effective_move()
	var current_hex: Vector2i = selected_character.hex_pos
	var moved: int = selected_character.movement_used

	# Determine max remaining based on committed maneuver
	var max_remaining: int
	match _committed_maneuver:
		Maneuver.Type.ALL_OUT_ATTACK:
			max_remaining = int(ceil(basic_move / 2.0)) - moved
		Maneuver.Type.DO_NOTHING, Maneuver.Type.ATTACK:
			# Allow full move by default; maneuver is inferred later
			max_remaining = basic_move - moved
		_:
			max_remaining = basic_move - moved

	# For STEP_AVAILABLE state: only allow 1-hex step
	if _state == State.STEP_AVAILABLE:
		max_remaining = 1

	max_remaining = max(max_remaining, 0)

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

	_update_action_buttons()
	_show_movement_zones()

func _update_action_buttons() -> void:
	if not selected_character:
		return
	var available: Array[Maneuver.Type] = Maneuver.available_maneuvers(
		selected_character.movement_used,
		selected_character.data.effective_move()
	)
	ui.show_action_buttons(available)

# ─── Hex Clicks ───────────────────────────────────────────────────────────────

func _on_hex_clicked(hex: Vector2i) -> void:
	if not selected_character:
		return

	match _state:
		State.PLAYER_TURN:
			_handle_movement_click(hex)
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
	var max_remaining: int = basic_move - selected_character.movement_used

	# AOA limits movement to half
	if _committed_maneuver == Maneuver.Type.ALL_OUT_ATTACK:
		max_remaining = int(ceil(basic_move / 2.0)) - selected_character.movement_used

	max_remaining = max(max_remaining, 0)
	var reachable: Dictionary = _bfs_reachable(selected_character.hex_pos, max_remaining)

	if reachable.has(hex):
		var dist: int = reachable[hex] as int
		_move_character(selected_character, hex, dist)

func _handle_step_click(hex: Vector2i) -> void:
	if hex == selected_character.hex_pos:
		return
	if occupied_hexes.has(hex) and occupied_hexes[hex] != selected_character:
		return

	var reachable: Dictionary = _bfs_reachable(selected_character.hex_pos, 1)
	if reachable.has(hex):
		var dist: int = reachable[hex] as int
		_move_character(selected_character, hex, dist)
		_state = State.TURN_OVER
		hex_grid.clear_highlights()
		ui.show_action_buttons([])
		ui.show_message("Turn over — click End Turn")

# ─── UI Signal Handlers ───────────────────────────────────────────────────────

func _on_hand_clicked(hand: String) -> void:
	if _state != State.PLAYER_TURN and _state != State.STEP_AVAILABLE:
		return
	if not selected_character:
		return
	ui.show_attack_options(selected_character.data)

func _on_attack_mode_selected(weapon, mode: String) -> void:
	if not selected_character:
		return
	_pending_weapon = weapon
	_pending_attack_mode = mode
	_state = State.SELECTING_ATTACK_TARGET
	hex_grid.clear_highlights()
	_highlight_valid_targets()
	var weapon_name: String = weapon.weapon_name if weapon else "?"
	ui.show_message("Attacking with %s — click a target" % weapon_name)

func _on_kick_requested() -> void:
	if _state != State.PLAYER_TURN and _state != State.STEP_AVAILABLE:
		return
	if not selected_character:
		return

	# Find kick weapon in character's melee list
	var kick_weapon: MeleeWeaponData = null
	for w: MeleeWeaponData in selected_character.data.melee_weapons:
		if w.mode.to_lower() == "kick":
			kick_weapon = w
			break

	# Fall back to DX-2 improvised kick
	if not kick_weapon:
		kick_weapon = MeleeWeaponData.new()
		kick_weapon.weapon_name = "Brawling"
		kick_weapon.mode = "Kick"
		kick_weapon.damage = "1d cr"
		kick_weapon.skill_level = selected_character.data.dx_stat - 2
		kick_weapon.reach = "C,1"
		kick_weapon.parry_modifier = "No"

	_pending_weapon = kick_weapon
	_pending_attack_mode = "Kick"
	_state = State.SELECTING_ATTACK_TARGET
	hex_grid.clear_highlights()
	_highlight_valid_targets()
	ui.show_message("Kick attack — click a target")

func _on_maneuver_button_pressed(type: Maneuver.Type) -> void:
	if not selected_character:
		return
	var cstate: CombatantState = combat_states[selected_character] as CombatantState
	cstate.last_maneuver = type

	match type:
		Maneuver.Type.ALL_OUT_ATTACK:
			_committed_maneuver = Maneuver.Type.ALL_OUT_ATTACK
			cstate.all_out_attack = true
			combat_log.log_message("%s goes All-Out Attack!" % selected_character.data.char_name)
			ui.show_message("All-Out Attack (+4) — choose weapon or KICK")
			# Recalculate movement zones (now limited to half)
			_show_movement_zones()
			_update_action_buttons()

		Maneuver.Type.ALL_OUT_DEFENSE:
			_committed_maneuver = Maneuver.Type.ALL_OUT_DEFENSE
			cstate.all_out_defense = true
			combat_log.log_message("%s takes All-Out Defense (+2 to all defenses)" % selected_character.data.char_name)
			_state = State.TURN_OVER
			hex_grid.clear_highlights()
			ui.show_action_buttons([])
			ui.show_message("All-Out Defense — click End Turn")

		Maneuver.Type.AIM:
			if selected_character.data.ranged_weapons.size() == 0:
				ui.show_message("No ranged weapon to aim!")
				return
			_committed_maneuver = Maneuver.Type.AIM
			_state = State.SELECTING_ATTACK_TARGET
			hex_grid.clear_highlights()
			_highlight_valid_targets()
			ui.show_action_buttons([])
			ui.show_message("Aim — click a target")

		Maneuver.Type.READY:
			_committed_maneuver = Maneuver.Type.READY
			combat_log.log_message("%s takes a Ready action." % selected_character.data.char_name)
			_state = State.TURN_OVER
			hex_grid.clear_highlights()
			ui.show_action_buttons([])
			ui.show_message("Ready — click End Turn")

		Maneuver.Type.WAIT:
			_committed_maneuver = Maneuver.Type.WAIT
			cstate.waiting = true
			combat_log.log_message("%s waits." % selected_character.data.char_name)
			_state = State.TURN_OVER
			hex_grid.clear_highlights()
			ui.show_action_buttons([])
			ui.show_message("Waiting — click End Turn")

func _on_inventory_opened() -> void:
	if selected_character:
		ui.show_inventory(selected_character.data)

func _on_combat_log_toggled() -> void:
	combat_log.visible = not combat_log.visible

func _on_combat_popup_confirmed() -> void:
	# Popup dismissed — advance to post-attack state
	if _state == State.SELECTING_ATTACK_TARGET:
		var moved: int = selected_character.movement_used
		if moved == 0 and _committed_maneuver in [
				Maneuver.Type.ATTACK, Maneuver.Type.DO_NOTHING]:
			# Step still available
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
	hex_grid.clear_highlights()
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	_start_turn()

# ─── Combat ───────────────────────────────────────────────────────────────────

func _handle_target_click(hex: Vector2i) -> void:
	if not occupied_hexes.has(hex):
		return
	var target_token: CharacterToken = occupied_hexes[hex] as CharacterToken
	if target_token == selected_character or target_token.data.dead:
		return

	var cstate: CombatantState = combat_states[selected_character] as CombatantState

	# ── Aim maneuver ──
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
		_state = State.TURN_OVER
		hex_grid.clear_highlights()
		ui.show_action_buttons([])
		ui.show_message("Aiming — click End Turn")
		return

	# ── Attack ──
	if _pending_weapon == null:
		combat_log.log_message("No weapon selected!")
		return

	var range_hexes: int = HexUtils.hex_distance(selected_character.hex_pos, target_token.hex_pos)
	var is_adjacent: bool = range_hexes <= 1
	var extra_mods: Array = []

	if cstate.shock != 0:
		extra_mods.append(["shock", cstate.shock])

	# Determine effective maneuver
	var maneuver: Maneuver.Type = _committed_maneuver
	if maneuver == Maneuver.Type.DO_NOTHING:
		maneuver = _get_inferred_maneuver()

	# Move and Attack penalty
	if maneuver == Maneuver.Type.MOVE_AND_ATTACK:
		if _pending_attack_mode == "ranged":
			var rw := _pending_weapon as RangedWeaponData
			var bulk_penalty: int = min(-2, rw.bulk)
			extra_mods.append(["move & attack", bulk_penalty])
		else:
			extra_mods.append(["move & attack", -4])

	var is_all_out: bool = (maneuver == Maneuver.Type.ALL_OUT_ATTACK)
	var attack_result: AttackResult = null

	if _pending_attack_mode == "ranged":
		var weapon := _pending_weapon as RangedWeaponData
		var aim_turns: int = cstate.aim_turns if cstate.aim_target == target_token.data else 0
		attack_result = CombatResolver.resolve_ranged_attack(
			selected_character.data, weapon, target_token.data,
			range_hexes, 1, "", aim_turns, false, is_all_out, extra_mods)
		cstate.break_aim()
	else:
		if not is_adjacent:
			ui.show_message("Target out of melee range!")
			return
		var weapon := _pending_weapon as MeleeWeaponData
		var dmg_bonus: int = 2 if is_all_out else 0
		# Move and Attack caps melee skill at 9
		var max_eff: int = 9 if maneuver == Maneuver.Type.MOVE_AND_ATTACK else -1
		attack_result = CombatResolver.resolve_melee_attack(
			selected_character.data, weapon, target_token.data,
			"", is_all_out, extra_mods, dmg_bonus, max_eff)

	if attack_result:
		combat_log.log_attack(attack_result)

		if attack_result.total_injury > 0:
			var target_state: CombatantState = combat_states[target_token] as CombatantState
			target_state.shock = target_token.data.shock_from_injury(attack_result.total_injury)
			for dr: DamageResult in attack_result.damage_results:
				if dr.knockdown_required and not dr.knockdown_succeeded:
					target_state.stunned = true
				if dr.dead:
					target_token.set_dead()
			target_token.flash_damage()
			target_token.update_hp_display()

		# Record committed maneuver
		_committed_maneuver = maneuver
		cstate.all_out_attack = is_all_out
		cstate.attacked_this_turn = true

		# Show popup — state advances in _on_combat_popup_confirmed
		ui.show_combat_popup(attack_result)

func _get_inferred_maneuver() -> Maneuver.Type:
	if not selected_character:
		return Maneuver.Type.ATTACK
	var moved: int = selected_character.movement_used
	if moved <= 1:
		return Maneuver.Type.ATTACK
	return Maneuver.Type.MOVE_AND_ATTACK

func _highlight_valid_targets() -> void:
	var highlights: Dictionary = {}
	for token: CharacterToken in characters:
		if token == selected_character or token.data.dead:
			continue
		highlights[token.hex_pos] = COLOR_TARGET
	hex_grid.set_highlights(highlights)
