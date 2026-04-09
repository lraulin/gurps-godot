class_name HexGrid
extends Node2D

## Visual hex grid that renders hexes and handles mouse interaction.

signal hex_clicked(hex: Vector2i)
signal hex_hovered(hex: Vector2i)

@export var grid_radius: int = 8

# Visual state
var _highlighted_hexes: Dictionary = {} # Vector2i -> Color
var _hovered_hex: Vector2i = Vector2i(99999, 99999)
var _valid_hexes: Dictionary = {} # Set of hexes that exist on the grid

# Panning state
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Build the set of valid hexes
	for hex: Vector2i in HexUtils.hexes_in_range(Vector2i.ZERO, grid_radius):
		_valid_hexes[hex] = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			if event.pressed:
				_drag_start = event.position
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos: Vector2 = get_local_mouse_position()
			var hex: Vector2i = HexUtils.pixel_to_axial(local_pos)
			if _valid_hexes.has(hex):
				hex_clicked.emit(hex)
	elif event is InputEventMouseMotion:
		if _dragging:
			var delta: Vector2 = event.position - _drag_start
			_drag_start = event.position
			var camera: Camera2D = get_viewport().get_camera_2d()
			if camera:
				camera.position -= delta / camera.zoom.x
			get_viewport().set_input_as_handled()
			return
		var local_pos: Vector2 = get_local_mouse_position()
		var hex: Vector2i = HexUtils.pixel_to_axial(local_pos)
		if hex != _hovered_hex and _valid_hexes.has(hex):
			_hovered_hex = hex
			hex_hovered.emit(hex)
			queue_redraw()

func _draw() -> void:
	# Draw all grid hexes
	for hex: Vector2i in _valid_hexes:
		var center: Vector2 = HexUtils.axial_to_pixel(hex)
		var corners: PackedVector2Array = HexUtils.hex_corners(center)

		# Fill highlighted hexes
		if _highlighted_hexes.has(hex):
			var color: Color = _highlighted_hexes[hex] as Color
			_draw_hex_filled(corners, color)

		# Hover highlight
		if hex == _hovered_hex:
			_draw_hex_filled(corners, Color(1, 1, 1, 0.15))

		# Draw hex outline
		_draw_hex_outline(corners, Color(0.5, 0.55, 0.6, 0.8))

func _draw_hex_filled(corners: PackedVector2Array, color: Color) -> void:
	var polygon: PackedVector2Array = PackedVector2Array(corners)
	draw_colored_polygon(polygon, color)

func _draw_hex_outline(corners: PackedVector2Array, color: Color) -> void:
	for i: int in range(6):
		draw_line(corners[i], corners[(i + 1) % 6], color, 1.0, true)

## Set hexes to highlight with specific colors.
func set_highlights(hexes: Dictionary) -> void:
	_highlighted_hexes = hexes
	queue_redraw()

## Clear all highlights.
func clear_highlights() -> void:
	_highlighted_hexes.clear()
	queue_redraw()

## Check if a hex is valid (on the grid).
func is_valid_hex(hex: Vector2i) -> bool:
	return _valid_hexes.has(hex)
