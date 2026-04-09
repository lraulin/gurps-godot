extends Node2D

## Sets up the test scene with sample characters and weapons.

func _ready() -> void:
	var manager: GameManager = $GameManager
	print("=== GURPS Tactical Setup ===")

	# --- Leon ---
	var leon: CharacterData = _make_character("Leon", 11, 12, 10, 11, 11, 6.0, 5, 2)
	leon.skills = {"Guns (Pistol)": 13, "Knife": 11}
	leon.ranged_weapons.append(_make_pistol("M1911A1", "2d pi", 2, 150, 1850, 3, "7+1(3)", 13, 10, -2, 4))
	leon.melee_weapons.append(_make_melee("Combat Knife", "Thrust", "1d imp", "C,1", 11, "0"))
	var leon_token: CharacterToken = _make_token(leon, Color.CORNFLOWER_BLUE)
	manager.add_character(leon_token, Vector2i(0, 0))

	# --- Claire ---
	var claire: CharacterData = _make_character("Claire", 10, 11, 10, 10, 10, 5.5, 5, 1)
	claire.skills = {"Guns (Pistol)": 12}
	claire.ranged_weapons.append(_make_pistol("Browning HP", "2d+2 pi+", 2, 175, 1900, 3, "13+1(3)", 12, 10, -2, 3))
	var claire_token: CharacterToken = _make_token(claire, Color.INDIAN_RED)
	manager.add_character(claire_token, Vector2i(2, -1))

	# --- Jill ---
	var jill: CharacterData = _make_character("Jill", 10, 13, 11, 11, 10, 6.0, 6, 1)
	jill.skills = {"Guns (Pistol)": 14, "Knife": 12}
	jill.ranged_weapons.append(_make_pistol("Beretta 92", "2d+2 pi", 2, 150, 1850, 3, "15+1(3)", 14, 10, -2, 4))
	jill.melee_weapons.append(_make_melee("Combat Knife", "Thrust", "1d imp", "C,1", 12, "0"))
	var jill_token: CharacterToken = _make_token(jill, Color.MEDIUM_SEA_GREEN)
	manager.add_character(jill_token, Vector2i(-1, 2))

	# --- Zombie A ---
	var zombie_a: CharacterData = _make_character("Zombie A", 13, 8, 2, 10, 15, 4.5, 4, 2)
	zombie_a.advantages = ["Injury Tolerance (No Brain)", "Injury Tolerance (No Vitals)", "High Pain Threshold"]
	zombie_a.melee_weapons.append(_make_melee("Bite", "Thrust", "1d-1 cr", "C", 10, "No"))
	zombie_a.melee_weapons.append(_make_melee("Claws", "Swing", "1d cut", "C", 9, "No"))
	var za_token: CharacterToken = _make_token(zombie_a, Color.DARK_OLIVE_GREEN)
	manager.add_character(za_token, Vector2i(4, -2))

	# --- Zombie B ---
	var zombie_b: CharacterData = _make_character("Zombie B", 12, 8, 2, 10, 14, 4.5, 3, 2)
	zombie_b.advantages = ["Injury Tolerance (No Brain)", "Injury Tolerance (No Vitals)", "High Pain Threshold"]
	zombie_b.melee_weapons.append(_make_melee("Bite", "Thrust", "1d-1 cr", "C", 10, "No"))
	zombie_b.melee_weapons.append(_make_melee("Claws", "Swing", "1d-1 cut", "C", 9, "No"))
	var zb_token: CharacterToken = _make_token(zombie_b, Color.DARK_OLIVE_GREEN)
	manager.add_character(zb_token, Vector2i(3, 2))

	print("Total characters: %d" % manager.characters.size())
	manager.start_combat()
	print("Combat started.")


func _make_character(cname: String, st_val: int, dx_val: int, iq_val: int,
		ht_val: int, hp_val: int, speed: float, move: int, dr_val: int) -> CharacterData:
	var c: CharacterData = CharacterData.new()
	c.char_name = cname
	c.st = st_val
	c.dx_stat = dx_val
	c.iq = iq_val
	c.ht = ht_val
	c.hp = hp_val
	c.hp_max = hp_val
	c.speed_stat = speed
	c.move_stat = move
	c.dr = dr_val
	return c


func _make_pistol(wname: String, dmg: String, acc: int, rh: int, rm: int,
		rate: int, ammo: String, skill: int, st_req: int, blk: int, rcl: int) -> RangedWeaponData:
	var w: RangedWeaponData = RangedWeaponData.new()
	w.weapon_name = wname
	w.damage = dmg
	w.accuracy = acc
	w.range_half = rh
	w.range_max = rm
	w.rof = rate
	w.shots = ammo
	w.skill_level = skill
	w.st_required = st_req
	w.bulk = blk
	w.recoil = rcl
	w.initialize_ammo(3)
	return w


func _make_melee(wname: String, wmode: String, dmg: String, wreach: String,
		skill: int, parry: String) -> MeleeWeaponData:
	var w: MeleeWeaponData = MeleeWeaponData.new()
	w.weapon_name = wname
	w.mode = wmode
	w.damage = dmg
	w.reach = wreach
	w.skill_level = skill
	w.parry_modifier = parry
	return w


func _make_token(char_data: CharacterData, color: Color) -> CharacterToken:
	var token: CharacterToken = CharacterToken.new()
	token.data = char_data
	token.token_color = color
	return token
