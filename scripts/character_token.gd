class_name CharacterToken
extends Node2D

## A character on the hex grid.

@export var data: CharacterData

var hex_pos: Vector2i = Vector2i.ZERO
var is_selected: bool = false
var movement_used: int = 0
var token_color: Color = Color.CORNFLOWER_BLUE
var _flash_timer: float = 0.0
var _is_dead_visual: bool = false
var is_aim_target: bool = false  # shows crosshair when someone is aiming at this token

func _ready() -> void:
	if not data:
		data = CharacterData.new()

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			queue_redraw()

func _draw() -> void:
	var radius: float = HexUtils.HEX_SIZE * 0.6

	# Dead visual
	if _is_dead_visual:
		draw_circle(Vector2.ZERO, radius, Color(0.3, 0.3, 0.3, 0.5))
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(-4, 5), "X", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.RED)
		return

	# Damage flash
	var draw_color: Color = token_color
	if _flash_timer > 0.0:
		draw_color = Color.RED.lerp(token_color, 1.0 - _flash_timer * 4.0)

	var outline_color: Color = Color.WHITE if is_selected else Color(0.8, 0.8, 0.8, 0.6)
	var outline_width: float = 3.0 if is_selected else 1.5

	draw_circle(Vector2.ZERO, radius, draw_color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, outline_color, outline_width, true)

	# Name label
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11
	var text: String = data.char_name if data else "?"
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, Vector2(-text_size.x / 2, font_size / 2.0 - 1), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

	# HP bar below token
	if data:
		var bar_width: float = radius * 1.6
		var bar_height: float = 4.0
		var bar_y: float = radius + 4.0
		var bar_x: float = -bar_width / 2.0
		var hp_ratio: float = clampf(float(data.hp) / float(data.hp_max), 0.0, 1.0)

		# Background
		draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))
		# HP fill
		var hp_color: Color = Color.GREEN
		if hp_ratio < 0.34:
			hp_color = Color.RED
		elif hp_ratio < 0.67:
			hp_color = Color.YELLOW
		draw_rect(Rect2(bar_x, bar_y, bar_width * hp_ratio, bar_height), hp_color)

		# HP text
		var hp_text: String = "%d/%d" % [data.hp, data.hp_max]
		var hp_font_size: int = 9
		var hp_text_size: Vector2 = font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, hp_font_size)
		draw_string(font, Vector2(-hp_text_size.x / 2, bar_y + bar_height + hp_font_size + 1),
			hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, hp_font_size, Color.WHITE)

	# Aim crosshair (drawn on top, independent of data)
	if is_aim_target:
		var cr: float = radius * 1.1
		var cross_color := Color(1.0, 0.3, 0.0, 0.9)
		var cross_w := 2.0
		draw_line(Vector2(-cr, -cr), Vector2(cr, cr), cross_color, cross_w, true)
		draw_line(Vector2(cr, -cr), Vector2(-cr, cr), cross_color, cross_w, true)
		draw_arc(Vector2.ZERO, cr, 0, TAU, 32, cross_color, cross_w, true)

func place_on_hex(hex: Vector2i) -> void:
	hex_pos = hex
	position = HexUtils.axial_to_pixel(hex)

func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()

func reset_turn() -> void:
	movement_used = 0

func flash_damage() -> void:
	_flash_timer = 0.25
	queue_redraw()

func update_hp_display() -> void:
	queue_redraw()

func set_dead() -> void:
	_is_dead_visual = true
	queue_redraw()
