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
enum State { MOVING, SELECTING_MANEUVER, SELECTING_TARGET, TURN_OVER }
var _state: State = State.MOVING
var _pending_maneuver: Maneuver.Type = Maneuver.Type.DO_NOTHING
var _pending_all_out: bool = false

func _ready() -> void:
	hex_grid.hex_clicked.connect(_on_hex_clicked)
	ui.end_turn_pressed.connect(_on_end_turn)
	ui.maneuver_selected.connect(_on_maneuver_selected)

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
		var state: CombatantState = combat_states[token] as CombatantState
		if token.data.dead or state.unconscious:
			current_turn_index = (current_turn_index + 1) % turn_order.size()
			attempts += 1
			continue
		break

	if attempts >= turn_order.size():
		combat_log.log_message("All characters are down. Combat over.")
		return

	var token: CharacterToken = turn_order[current_turn_index]
	var state: CombatantState = combat_states[token] as CombatantState
	state.reset_for_new_turn()
	token.movement_used = 0

	_select_character(token)
	combat_log.log_turn(token.data.char_name, current_turn_index + 1, turn_order.size())
	ui.set_turn_info(token.data.char_name, current_turn_index + 1, turn_order.size())

	# Handle stunned
	if state.stunned:
		combat_log.log_message("%s is stunned! Must Do Nothing. Rolling HT to recover..." % token.data.char_name)
		var roll: int = Dice.roll_3d()
		if roll <= token.data.ht:
			state.stunned = false
			combat_log.log_message("  Rolled %d vs HT %d — recovered from stun!" % [roll, token.data.ht])
		else:
			combat_log.log_message("  Rolled %d vs HT %d — still stunned." % [roll, token.data.ht])
		_state = State.TURN_OVER
		ui.set_maneuvers([])
		ui.show_message("Stunned — turn over")
		hex_grid.clear_highlights()
		return

	_state = State.MOVING
	_update_available_maneuvers()
	_show_movement_zones()

func _select_character(token: CharacterToken) -> void:
	if selected_character:
		selected_character.set_selected(false)
	selected_character = token
	token.set_selected(true)

func _show_movement_zones() -> void:
	if not selected_character:
		return
	var basic_move: int = selected_character.data.effective_move()
	var current_hex: Vector2i = selected_character.hex_pos
	var moved: int = selected_character.movement_used
	var remaining_full: int = basic_move - moved
	var remaining_half: int = int(ceil(basic_move / 2.0)) - moved
	var remaining_step: int = 1 - moved

	var highlights: Dictionary = {}
	var reachable: Dictionary = _bfs_reachable(current_hex, remaining_full)

	for hex: Vector2i in reachable:
		var dist: int = reachable[hex] as int
		if dist == 0:
			continue
		if dist <= max(remaining_step, 0):
			highlights[hex] = COLOR_STEP
		elif dist <= max(remaining_half, 0):
			highlights[hex] = COLOR_HALF
		elif dist <= max(remaining_full, 0):
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

func _on_hex_clicked(hex: Vector2i) -> void:
	if not selected_character:
		return

	match _state:
		State.MOVING:
			_handle_movement_click(hex)
		State.SELECTING_TARGET:
			_handle_target_click(hex)

func _handle_movement_click(hex: Vector2i) -> void:
	if hex == selected_character.hex_pos:
		return
	if occupied_hexes.has(hex) and occupied_hexes[hex] != selected_character:
		return

	var basic_move: int = selected_character.data.effective_move()
	var max_remaining: int = basic_move - selected_character.movement_used
	var reachable: Dictionary = _bfs_reachable(selected_character.hex_pos, max_remaining)

	if reachable.has(hex):
		var dist: int = reachable[hex] as int
		_move_character(selected_character, hex, dist)

func _handle_target_click(hex: Vector2i) -> void:
	if not occupied_hexes.has(hex):
		return
	var target_token: CharacterToken = occupied_hexes[hex] as CharacterToken
	if target_token == selected_character:
		return
	if target_token.data.dead:
		return

	var state: CombatantState = combat_states[selected_character] as CombatantState

	# Handle Aim maneuver
	if _pending_maneuver == Maneuver.Type.AIM:
		if selected_character.data.ranged_weapons.size() == 0:
			combat_log.log_message("No ranged weapon to aim with!")
			return
		var weapon: RangedWeaponData = selected_character.data.ranged_weapons[0]
		if state.aim_target == target_token.data and state.aim_weapon_name == weapon.weapon_name:
			state.aim_turns += 1
		else:
			state.aim_target = target_token.data
			state.aim_weapon_name = weapon.weapon_name
			state.aim_turns = 1
		var aim_bonus: int = weapon.accuracy + min(state.aim_turns - 1, 2)
		combat_log.log_message("%s aims %s at %s (turn %d, +%d)" % [
			selected_character.data.char_name, weapon.weapon_name,
			target_token.data.char_name, state.aim_turns, aim_bonus])
		_state = State.TURN_OVER
		hex_grid.clear_highlights()
		ui.show_message("Aiming — click End Turn")
		ui.set_maneuvers([])
		return

	# Calculate range
	var range_hexes: int = HexUtils.hex_distance(selected_character.hex_pos, target_token.hex_pos)

	# Determine if we have a valid weapon for this range
	var is_adjacent: bool = range_hexes <= 1
	var attack_result: AttackResult = null

	var all_out: bool = _pending_all_out
	var extra_mods: Array = []

	# Apply shock from last turn
	if state.shock != 0:
		extra_mods.append(["shock", state.shock])

	if _pending_maneuver == Maneuver.Type.MOVE_AND_ATTACK:
		# Move and Attack penalties
		if is_adjacent and selected_character.data.melee_weapons.size() > 0:
			extra_mods.append(["move & attack", -4])
			var weapon: MeleeWeaponData = selected_character.data.melee_weapons[0]
			attack_result = CombatResolver.resolve_melee_attack(
				selected_character.data, weapon, target_token.data,
				"", false, extra_mods, 0, 9)
		elif selected_character.data.ranged_weapons.size() > 0:
			var weapon: RangedWeaponData = selected_character.data.ranged_weapons[0]
			var bulk_penalty: int = min(-2, weapon.bulk)
			extra_mods.append(["move & attack", bulk_penalty])
			attack_result = CombatResolver.resolve_ranged_attack(
				selected_character.data, weapon, target_token.data,
				range_hexes, 1, "", 0, false, false, extra_mods)
	elif is_adjacent and selected_character.data.melee_weapons.size() > 0:
		# Melee attack
		var weapon: MeleeWeaponData = selected_character.data.melee_weapons[0]
		var dmg_bonus: int = 2 if all_out else 0  # simplified All-Out Strong
		attack_result = CombatResolver.resolve_melee_attack(
			selected_character.data, weapon, target_token.data,
			"", all_out, extra_mods, dmg_bonus)
	elif selected_character.data.ranged_weapons.size() > 0:
		# Ranged attack
		var weapon: RangedWeaponData = selected_character.data.ranged_weapons[0]
		var aim_turns: int = state.aim_turns if state.aim_target == target_token.data else 0
		attack_result = CombatResolver.resolve_ranged_attack(
			selected_character.data, weapon, target_token.data,
			range_hexes, 1, "", aim_turns, false, all_out, extra_mods)
		# Break aim after firing
		state.break_aim()
	else:
		combat_log.log_message("No weapon available for this range!")
		return

	if attack_result:
		combat_log.log_attack(attack_result)

		# Apply shock to target for next turn
		if attack_result.total_injury > 0:
			var target_state: CombatantState = combat_states[target_token] as CombatantState
			target_state.shock = target_token.data.shock_from_injury(attack_result.total_injury)

			# Check if target was stunned/killed
			for dr: DamageResult in attack_result.damage_results:
				if dr.knockdown_required and not dr.knockdown_succeeded:
					target_state.stunned = true
				if dr.dead:
					target_token.set_dead()

			# Visual feedback
			target_token.flash_damage()
			target_token.update_hp_display()

	# Attack resolves the turn
	_state = State.TURN_OVER
	hex_grid.clear_highlights()
	ui.show_message("Turn over — click End Turn")
	ui.set_maneuvers([])

func _move_character(token: CharacterToken, to_hex: Vector2i, distance: int) -> void:
	occupied_hexes.erase(token.hex_pos)
	occupied_hexes[to_hex] = token
	token.hex_pos = to_hex
	token.position = HexUtils.axial_to_pixel(to_hex)
	token.movement_used += distance

	# Movement breaks aim and evaluate
	if distance > 0:
		var state: CombatantState = combat_states[token] as CombatantState
		state.break_aim()
		state.break_evaluate()

	_update_available_maneuvers()
	_show_movement_zones()

func _update_available_maneuvers() -> void:
	if not selected_character:
		return
	var available: Array[Maneuver.Type] = Maneuver.available_maneuvers(
		selected_character.movement_used,
		selected_character.data.effective_move()
	)
	ui.set_maneuvers(available)

func _on_maneuver_selected(type: Maneuver.Type) -> void:
	_pending_maneuver = type
	_pending_all_out = (type == Maneuver.Type.ALL_OUT_ATTACK)

	var state: CombatantState = combat_states[selected_character] as CombatantState
	state.last_maneuver = type

	match type:
		Maneuver.Type.ATTACK, Maneuver.Type.ALL_OUT_ATTACK, Maneuver.Type.MOVE_AND_ATTACK:
			# Enter target selection mode
			_state = State.SELECTING_TARGET
			hex_grid.clear_highlights()
			_highlight_valid_targets()
			ui.show_message("Click a target to attack")
			if type == Maneuver.Type.ALL_OUT_ATTACK:
				state.all_out_attack = true
				combat_log.log_message("%s goes All-Out!" % selected_character.data.char_name)

		Maneuver.Type.AIM:
			_state = State.SELECTING_TARGET
			hex_grid.clear_highlights()
			_highlight_valid_targets()
			ui.show_message("Click a target to aim at")

		Maneuver.Type.MOVE:
			# Already handled by movement system — just end the maneuver selection
			_state = State.TURN_OVER
			hex_grid.clear_highlights()
			ui.show_message("Move complete — click End Turn")
			ui.set_maneuvers([])

		Maneuver.Type.DO_NOTHING, Maneuver.Type.CHANGE_POSTURE, \
		Maneuver.Type.CONCENTRATE, Maneuver.Type.READY:
			combat_log.log_message("%s: %s" % [
				selected_character.data.char_name, Maneuver.get_maneuver_name(type)])
			_state = State.TURN_OVER
			hex_grid.clear_highlights()
			ui.show_message("Turn over — click End Turn")
			ui.set_maneuvers([])

		Maneuver.Type.ALL_OUT_DEFENSE:
			state.all_out_defense = true
			combat_log.log_message("%s takes All-Out Defense (+2 to all defenses)" % selected_character.data.char_name)
			_state = State.TURN_OVER
			hex_grid.clear_highlights()
			ui.show_message("All-Out Defense — click End Turn")
			ui.set_maneuvers([])

		Maneuver.Type.WAIT:
			combat_log.log_message("%s waits." % selected_character.data.char_name)
			_state = State.TURN_OVER
			hex_grid.clear_highlights()
			ui.set_maneuvers([])

func _highlight_valid_targets() -> void:
	var highlights: Dictionary = {}
	for token: CharacterToken in characters:
		if token == selected_character:
			continue
		if token.data.dead:
			continue
		highlights[token.hex_pos] = COLOR_TARGET
	hex_grid.set_highlights(highlights)

func _on_end_turn() -> void:
	# Handle aim maneuver - store aim if we were aiming at a target
	# (aim target selection handled in _handle_target_click for aim)
	hex_grid.clear_highlights()
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	_start_turn()
