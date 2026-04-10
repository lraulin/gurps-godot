extends Node2D

## Sets up the test scene with sample characters and weapons.

func _ready() -> void:
	var manager: GameManager = $GameManager
	print("=== GURPS Tactical Setup ===")

	# --- Chris Redfield ---
	var chris: CharacterData = _make_character("Chris Redfield", 13, 13, 11, 12, 13, 6.25, 6, 4)
	chris.will = 11
	chris.per = 11
	chris.fp = 14
	chris.fp_max = 14
	chris.advantages = ["Appearance (Attractive)", "Combat Reflexes", "Fearlessness 2", "Fit",
			"High Pain Threshold", "Legal Enforcement Powers 1", "Luck", "Resistant (Disease +3)"]
	chris.disadvantages = ["Code of Honor (Soldier's)", "Duty (STARS)", "Overconfidence"]
	chris.skills = {
		"Brawling": 15, "Climbing": 12, "First Aid": 11, "Forced Entry": 15,
		"Guns (Grenade Launcher)": 13, "Guns (Pistol)": 15, "Guns (Rifle)": 14,
		"Guns (Shotgun)": 16, "Guns (Submachine Gun)": 14, "Knife": 13,
		"Observation": 10, "Parachuting": 13, "Piloting (Helicopter)": 14,
		"Piloting (Light Airplane)": 13, "Running": 11, "Savoir-Faire (Military)": 11,
		"Soldier": 10, "Swimming": 12, "Tactics": 11, "Throwing": 12
	}
	chris.ranged_weapons.append(_make_pistol("Auto Pistol 9mm", "2d+2 pi", 2, 150, 1850, 3, "15+1(3)", 15, 9, -2, 2))
	chris.melee_weapons.append(_make_melee("Large Knife", "Swing", "2d-3 cut", "C,1", 13, "0"))
	chris.melee_weapons.append(_make_melee("Large Knife", "Thrust", "1d imp", "C,1", 13, "0"))
	chris.melee_weapons.append(_make_melee("Brawling", "Punch", "1d cr", "C", 15, "0"))
	chris.melee_weapons.append(_make_melee("Brawling", "Kick", "1d+1 cr", "C,1", 13, "No"))
	var chris_token: CharacterToken = _make_token(chris, Color.CORNFLOWER_BLUE, "res://assets/chris-token.webp")
	manager.add_character(chris_token, Vector2i(0, 0))

	# --- Jill Valentine ---
	var jill: CharacterData = _make_character("Jill Valentine", 8, 13, 12, 11, 8, 6.0, 6, 0)
	jill.will = 12
	jill.per = 12
	jill.fp = 11
	jill.fp_max = 11
	jill.advantages = ["Appearance (Attractive)", "Combat Reflexes", "Fearlessness 2", "Fit",
			"High Pain Threshold", "Luck"]
	jill.disadvantages = ["Code of Honor (Soldier's)", "Duty (STARS)", "Overconfidence"]
	jill.skills = {
		"Brawling": 13, "Climbing": 12, "Computer Operation": 12, "Driving (Automobile)": 12,
		"Electronics Repair (Security)": 13, "Explosives (Demolition)": 13, "Explosives (EOD)": 13,
		"First Aid": 12, "Forced Entry": 13, "Guns (Grenade Launcher)": 13, "Guns (Pistol)": 13,
		"Guns (Rifle)": 13, "Guns (Shotgun)": 13, "Guns (Submachine Gun)": 13,
		"Knife": 13, "Lockpicking": 14, "Running": 10, "Savoir-Faire (Military)": 12,
		"Soldier": 11, "Swimming": 11, "Throwing": 12
	}
	jill.ranged_weapons.append(_make_pistol("Beretta 92", "2d+2 pi", 2, 150, 1850, 3, "15+1(3)", 13, 9, -2, 2))
	jill.melee_weapons.append(_make_melee("Large Knife", "Swing", "2d-3 cut", "C,1", 13, "0"))
	jill.melee_weapons.append(_make_melee("Large Knife", "Thrust", "1d imp", "C,1", 13, "0"))
	jill.melee_weapons.append(_make_melee("Brawling", "Punch", "1d-3 cr", "C", 13, "0"))
	jill.melee_weapons.append(_make_melee("Brawling", "Kick", "1d-2 cr", "C,1", 11, "No"))
	var jill_token: CharacterToken = _make_token(jill, Color.MEDIUM_SEA_GREEN, "res://assets/jill-token.webp")
	manager.add_character(jill_token, Vector2i(-1, 2))

	# --- Leon Kennedy (RE4) ---
	var leon: CharacterData = _make_character("Leon Kennedy", 13, 15, 12, 14, 13, 7.25, 7, 4)
	leon.will = 14
	leon.per = 13
	leon.fp = 14
	leon.fp_max = 14
	leon.advantages = ["Appearance (Handsome)", "Combat Reflexes", "Danger Sense", "Fearlessness 3",
			"Fit (Very Fit)", "Gunslinger", "Hard to Kill 3", "High Pain Threshold", "Luck",
			"Patron (US Govt/DSO)", "Security Clearance"]
	leon.disadvantages = ["Code of Honor (Hero's)", "Duty (US Govt/DSO)", "Overconfidence",
			"Secret Identity", "Sense of Duty (Innocents)"]
	leon.skills = {
		"Acrobatics": 16, "Brawling": 15, "Climbing": 14, "Driving (Automobile)": 16,
		"Fast-Draw (Pistol)": 16, "Forced Entry": 16, "Guns (Grenade Launcher)": 16,
		"Guns (Light Machine Gun)": 17, "Guns (Pistol)": 19, "Guns (Rifle)": 19,
		"Guns (Shotgun)": 18, "Guns (Submachine Gun)": 17, "Judo": 16, "Jumping": 16,
		"Karate": 16, "Knife": 18, "Stealth": 16, "Tactics": 13,
		"Throwing": 16, "Wrestling": 17
	}
	var leon_pistol: RangedWeaponData = _make_pistol("Auto Pistol 9mm", "2d+2 pi", 2, 150, 1850, 3, "15+1(3)", 19, 9, -2, 2)
	leon.ranged_weapons.append(leon_pistol)
	var leon_shotgun: RangedWeaponData = _make_pistol("Auto Shotgun 12G (Slug)", "5d pi++", 3, 125, 188, 3, "6+1(3)", 18, 10, -5, 4)
	leon.ranged_weapons.append(leon_shotgun)
	var leon_rifle: RangedWeaponData = _make_pistol("Bolt Rifle 7.62mm", "7d pi", 7, 1000, 4200, 1, "5+1(3)", 19, 10, -5, 4)
	leon.ranged_weapons.append(leon_rifle)
	leon.melee_weapons.append(_make_melee("Large Knife", "Swing", "2d-3 cut", "C,1", 18, "0"))
	leon.melee_weapons.append(_make_melee("Large Knife", "Thrust", "1d imp", "C,1", 18, "0"))
	leon.melee_weapons.append(_make_melee("Karate", "Punch", "1d+1 cr", "C", 16, "0"))
	leon.melee_weapons.append(_make_melee("Karate", "Kick", "1d+2 cr", "C,1", 14, "No"))
	var leon_token: CharacterToken = _make_token(leon, Color.DARK_ORANGE, "res://assets/leon-token-hex.webp")
	manager.add_character(leon_token, Vector2i(2, -1))

	# --- T-Virus Zombies ---
	var zombie_spawns: Array[Vector2i] = [Vector2i(4, -2), Vector2i(3, 2), Vector2i(5, 1)]
	for i: int in range(zombie_spawns.size()):
		var zname: String = "Zombie %s" % char(65 + i)  # Zombie A, B, C...
		var zombie: CharacterData = _make_zombie(zname)
		var zombie_token: CharacterToken = _make_token(zombie, Color.DARK_OLIVE_GREEN, "res://assets/zombie-token.webp")
		manager.add_character(zombie_token, zombie_spawns[i])

	print("Total characters: %d" % manager.characters.size())
	manager.start_combat()
	print("Combat started.")


func _make_zombie(zname: String) -> CharacterData:
	var z: CharacterData = _make_character(zname, 13, 8, 3, 8, 18, 4.0, 3, 0)
	z.will = 3
	z.per = 3
	z.fp = 8
	z.fp_max = 8
	z.advantages = ["Fearlessness 5", "Hard to Kill 1", "Hard to Subdue 2",
			"High Pain Threshold", "Resistant (Disease Immunity)", "Unfazeable"]
	z.disadvantages = ["Appearance (Monstrous)", "Bad Smell", "Bestial", "Cannot Learn",
			"Cannot Speak", "Compulsive Behavior (Eat Flesh)", "Infectious Attack",
			"Odious Personal Habit (Constant moaning)", "Short Attention Span"]
	z.skills = {"Brawling": 13}
	z.melee_weapons.append(_make_melee("Brawling", "Punch", "1d cr", "C", 13, "0"))
	z.melee_weapons.append(_make_melee("Brawling", "Bite", "1d cr", "C", 13, "No"))
	z.melee_weapons.append(_make_melee("Brawling", "Kick", "1d+1 cr", "C,1", 11, "No"))
	return z


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


func _make_token(char_data: CharacterData, color: Color, texture_path: String = "") -> CharacterToken:
	var token: CharacterToken = CharacterToken.new()
	token.data = char_data
	token.token_color = color
	if texture_path != "":
		token.token_texture = load(texture_path)
	return token
