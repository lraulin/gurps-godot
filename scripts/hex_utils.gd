class_name HexUtils

## Hex grid utilities using axial coordinates (q, r).
## Flat-top hexagons, matching GURPS tactical combat hex grids.

# Hex size (distance from center to vertex)
const HEX_SIZE: float = 32.0

# The six axial direction vectors for flat-top hexes
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

## Convert axial coordinates to pixel position (flat-top hex).
static func axial_to_pixel(hex: Vector2i) -> Vector2:
	var x: float = HEX_SIZE * (3.0 / 2.0 * hex.x)
	var y: float = HEX_SIZE * (sqrt(3.0) / 2.0 * hex.x + sqrt(3.0) * hex.y)
	return Vector2(x, y)

## Convert pixel position to axial coordinates (flat-top hex).
static func pixel_to_axial(pixel: Vector2) -> Vector2i:
	var q: float = (2.0 / 3.0 * pixel.x) / HEX_SIZE
	var r: float = (-1.0 / 3.0 * pixel.x + sqrt(3.0) / 3.0 * pixel.y) / HEX_SIZE
	return axial_round(Vector2(q, r))

## Round fractional axial coords to nearest hex.
static func axial_round(frac: Vector2) -> Vector2i:
	var s: float = -frac.x - frac.y
	var q: float = round(frac.x)
	var r: float = round(frac.y)
	var s_round: float = round(s)

	var q_diff: float = abs(q - frac.x)
	var r_diff: float = abs(r - frac.y)
	var s_diff: float = abs(s_round - s)

	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s_round
	elif r_diff > s_diff:
		r = -q - s_round

	return Vector2i(int(q), int(r))

## Get all 6 neighbors of a hex.
static func get_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir: Vector2i in DIRECTIONS:
		neighbors.append(hex + dir)
	return neighbors

## Hex distance (number of hex steps between two hexes).
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var diff: Vector2i = a - b
	return (abs(diff.x) + abs(diff.x + diff.y) + abs(diff.y)) / 2

## Get all hexes within a given radius.
static func hexes_in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	for q: int in range(-radius, radius + 1):
		for r: int in range(max(-radius, -q - radius), min(radius, -q + radius) + 1):
			results.append(center + Vector2i(q, r))
	return results

## Get the corner points of a hex for drawing (flat-top).
static func hex_corners(center_pixel: Vector2) -> PackedVector2Array:
	var corners: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		var angle_deg: float = 60.0 * i
		var angle_rad: float = deg_to_rad(angle_deg)
		corners.append(center_pixel + Vector2(HEX_SIZE * cos(angle_rad), HEX_SIZE * sin(angle_rad)))
	return corners
