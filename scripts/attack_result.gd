class_name AttackResult
extends RefCounted

## Structured result from resolving an attack.

var attacker_name: String = ""
var target_name: String = ""
var weapon_name: String = ""
var is_ranged: bool = true

# Skill calculation
var base_skill: int = 0
var effective_skill: int = 0
var modifier_breakdown: Array[Array] = []  # [[label, value], ...]

# Attack roll
var roll: int = 0
var is_hit: bool = false
var is_critical_hit: bool = false
var is_critical_miss: bool = false
var margin: int = 0
var hits_count: int = 0

# Defense (auto-resolved)
var defense_type: String = ""           # "dodge", "parry", "block", or ""
var defense_score: int = 0
var defense_roll: int = 0
var defense_succeeded: bool = false

# Damage results per hit
var damage_results: Array[DamageResult] = []
var total_injury: int = 0

# Ammo tracking
var ammo_after: String = ""

# Special cases
var hit_torso_instead: bool = false     # Missed targeted location by 1
var weapon_empty: bool = false

# Status
var messages: Array[String] = []
