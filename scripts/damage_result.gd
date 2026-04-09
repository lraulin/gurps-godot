class_name DamageResult
extends RefCounted

## Structured result from applying damage to a character.

var injury: int = 0
var location: String = "torso"
var raw_damage: int = 0
var dr_applied: int = 0
var penetrating: int = 0
var wounding_multiplier: float = 1.0
var hp_after: int = 0
var crippled: bool = false
var major_wound: bool = false
var knockdown_required: bool = false
var knockdown_penalty: int = 0
var knockdown_succeeded: bool = false
var knockdown_roll: int = 0
var reeling: bool = false
var dead: bool = false
var death_check_results: Array[Dictionary] = [] # [{threshold, roll, target, passed}]
var shock: int = 0
var status_messages: Array[String] = []
