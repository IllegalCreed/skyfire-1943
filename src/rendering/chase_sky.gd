extends RefCounted
## Persistent cloud rows, with the same horizontal/vertical view as air targets.

const CLOUD_BASE_Y := 519.0
const ROW_SPACING := 380.0
const COLUMN_COUNT := 15

static func clouds(flight) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# These are fixed rows in the sky, not clouds wrapped inside the viewport.
	# As a lower row leaves the bottom, an upper row enters beyond the top edge.
	# The altitude range needs only these four rows; none moves autonomously.
	for row in range(-2, 2):
		for column in range(COLUMN_COUNT):
			var base_y := CLOUD_BASE_Y + row * ROW_SPACING - (column % 4) * 34
			var pos: Vector2 = flight.sky_screen(float(column) * TAU / COLUMN_COUNT, base_y)
			var width := 105 + column % 3 * 16
			if pos.x + width - 46 < -8 or pos.x - 46 > 968: continue
			if pos.y + 5 < 66 or pos.y - 6 > 506: continue
			result.append({"id": Vector2i(column, row), "pos": pos, "width": width})
	return result

static func draw_clouds(c: Node2D, flight) -> void:
	for cloud in clouds(flight):
		var pos: Vector2 = cloud.pos
		c.draw_rect(Rect2(pos + Vector2(-46, 0), Vector2(cloud.width, 5)), Color("cc8d7c"))
		c.draw_rect(Rect2(pos + Vector2(-20, -6), Vector2(45, 6)), Color("bb827c"))
