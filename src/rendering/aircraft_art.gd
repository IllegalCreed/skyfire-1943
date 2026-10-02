extends RefCounted
## Code-native original aircraft. Detail is suppressed at distant scales.

const INK := Color("172735")
const SILVER := Color("d6ded7")
const SHADOW := Color("889da1")
const GLASS := Color("284b62")
const LIGHT := Color("edf7eb")

static func draw_plane(c: Node2D, pos: Vector2, scale: float, accent: Color,
	perspective: int, friendly: bool, roll: float, kind: String, time: float) -> void:
	var spec := dimensions(kind, friendly)
	# Rotation of a top-down model is not a side view: each view has its own hull.
	var angle := roll if perspective == 2 else 0.0
	if perspective == 1 and not friendly: angle = PI
	# Mirror a side hull horizontally; a 180-degree rotation would put its
	# cockpit and vertical tail underneath the aircraft.
	var stretch := Vector2(-scale, scale) if perspective == 0 and not friendly else Vector2.ONE * scale
	c.draw_set_transform(pos, angle, stretch)
	var body := SILVER if friendly else Color("bdc7bd")
	var detailed := scale >= 0.4
	if perspective == 2: _draw_front(c, spec, body, accent, friendly, detailed, time)
	elif perspective == 0: _draw_side(c, spec, body, accent, friendly, detailed, time)
	else: _draw_top(c, spec, body, accent, friendly, detailed, time)
	c.draw_set_transform(Vector2.ZERO)

static func dimensions(kind: String, friendly: bool) -> Dictionary:
	if friendly: return {"span": 36.0, "top_span": 27.0, "length": 29.0, "twin": true, "round": false}
	match kind:
		"bomber": return {"span": 58.0, "length": 38.0, "twin": true, "round": false}
		"raider": return {"span": 33.0, "length": 28.0, "twin": false, "round": true}
	return {"span": 28.0, "length": 29.0, "twin": false, "round": false}

static func _draw_front(c: Node2D, spec: Dictionary, body: Color, accent: Color,
	friendly: bool, detailed: bool, time: float) -> void:
	var w: float = spec.span
	var tip: float = 6.0 if spec.round else 2.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(-w, tip), Vector2(-12, -1),
		Vector2(-5, -8), Vector2(5, -8), Vector2(12, -1), Vector2(w, tip),
		Vector2(w - 3, 8), Vector2(8, 5), Vector2(0, 12), Vector2(-8, 5), Vector2(-w + 3, 8)]), body)
	c.draw_line(Vector2(-w + 3, 7), Vector2(w - 3, 7), SHADOW, 2)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-3, 3), Vector2(-3, -20),
		Vector2(1, -23), Vector2(5, -5), Vector2(5, 4)]), accent)
	var motors: Array = [-18.5, 18.5] if friendly else [-27.0, 27.0] if spec.twin else [0.0]
	for x in motors:
		c.draw_rect(Rect2(x - 4, -3, 8, 14), SHADOW)
		c.draw_rect(Rect2(x - 3, -3, 6, 12), body)
		if detailed:
			c.draw_circle(Vector2(x, 4), 4, INK)
			c.draw_circle(Vector2(x, 4), 2, SHADOW)
			var blade := Vector2.from_angle(time * 32 + x) * 10
			c.draw_line(Vector2(x, 4) - blade, Vector2(x, 4) + blade, Color(LIGHT, 0.26), 1)
		if friendly:
			# Preserve the twin-gun attachment positions used by flight/aim math.
			c.draw_circle(Vector2(x, 11), 2.6, Color("ffba68"))
	if detailed:
		c.draw_rect(Rect2(-5, -7, 10, 7), GLASS)
		c.draw_line(Vector2(-4, -7), Vector2(3, -7), LIGHT, 1)
		c.draw_line(Vector2(0, -7), Vector2(0, -1), SHADOW, 1)
		for sign in [-1, 1]:
			c.draw_line(Vector2(sign * 10, 2), Vector2(sign * (w - 7), 4), SHADOW, 1)
			c.draw_line(Vector2(sign * (w - 12), 3), Vector2(sign * (w - 12), 7), SHADOW, 1)
			c.draw_rect(Rect2(sign * (w - 13) - 3, 2, 6, 5), accent)
		c.draw_line(Vector2(-10, 9), Vector2(10, 9), accent, 2)

static func _draw_top(c: Node2D, spec: Dictionary, body: Color, accent: Color,
	friendly: bool, detailed: bool, time: float) -> void:
	var w: float = spec.get("top_span", spec.span)
	var length: float = spec.length
	var wing_front := -5.0 if spec.round else 1.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, -length), Vector2(5, -14),
		Vector2(6, -6), Vector2(w - 3, wing_front), Vector2(w, 8), Vector2(7, 7),
		Vector2(4, length - 8), Vector2(-4, length - 8), Vector2(-7, 7),
		Vector2(-w, 8), Vector2(-w + 3, wing_front), Vector2(-6, -6), Vector2(-5, -14)]), body)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-16, length - 11), Vector2(-3, length - 16),
		Vector2(3, length - 16), Vector2(16, length - 11), Vector2(15, length - 6), Vector2(-15, length - 6)]), body)
	var motors: Array = [-18.5, 18.5] if friendly else [-27.0, 27.0] if spec.twin else [0.0]
	for x in motors:
		var nose := -18.0 if spec.twin else -length
		if spec.twin:
			c.draw_rect(Rect2(x - 4, nose, 8, 34), SHADOW)
			c.draw_rect(Rect2(x - 3, nose, 6, 31), body)
		c.draw_line(Vector2(x - 10, nose - 2), Vector2(x + 10, nose - 2), Color(LIGHT, 0.4 + 0.15 * sin(time * 45)), 1.5)
		c.draw_rect(Rect2(x - 2, nose - 4, 4, 4), accent)
	if detailed:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-3, -15), Vector2(3, -15), Vector2(4, -4), Vector2(-4, -4)]), GLASS)
		c.draw_line(Vector2(-3, -14), Vector2(2, -14), LIGHT, 1)
		c.draw_line(Vector2(-3, -9), Vector2(3, -9), SHADOW, 1)
		c.draw_line(Vector2(0, 0), Vector2(0, length - 10), SHADOW, 1)
		for sign in [-1, 1]:
			c.draw_line(Vector2(sign * 8, 5), Vector2(sign * (w - 5), 6), SHADOW, 1)
			c.draw_line(Vector2(sign * (w - 12), 1), Vector2(sign * (w - 12), 7), SHADOW, 1)
			c.draw_circle(Vector2(sign * (w - 14), 2), 3, accent)
			c.draw_circle(Vector2(sign * (w - 14), 2), 1, LIGHT)
		c.draw_rect(Rect2(-3, length - 17, 6, 9), accent)
		for y in [8, 11]: c.draw_line(Vector2(-4, y), Vector2(4, y), accent, 1)

static func _draw_side(c: Node2D, spec: Dictionary, body: Color, accent: Color,
	friendly: bool, detailed: bool, time: float) -> void:
	var length: float = spec.length + 5
	c.draw_colored_polygon(PackedVector2Array([Vector2(length, 0), Vector2(length - 5, -5),
		Vector2(7, -7), Vector2(-length + 6, -4), Vector2(-length, -17),
		Vector2(-length - 3, 4), Vector2(-12, 7), Vector2(length - 7, 5)]), body)
	if spec.round:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-16, 0), Vector2(8, -3),
			Vector2(13, 3), Vector2(-4, 11), Vector2(-18, 8)]), SHADOW)
	else:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-13, 0), Vector2(5, -3),
			Vector2(10, 2), Vector2(-5, 14), Vector2(-16, 12)]), SHADOW)
	c.draw_line(Vector2(length, -12), Vector2(length, 12), Color(LIGHT, 0.35 + 0.15 * sin(time * 45)), 1.5)
	c.draw_rect(Rect2(length - 2, -3, 4, 6), accent)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-length + 2, -4), Vector2(-length + 4, -15),
		Vector2(-length + 9, -5)]), accent)
	if detailed:
		c.draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(4, -13),
			Vector2(13, -12), Vector2(17, -6)]), GLASS)
		c.draw_line(Vector2(5, -12), Vector2(12, -11), LIGHT, 1)
		c.draw_line(Vector2(9, -12), Vector2(10, -7), SHADOW, 1)
		c.draw_line(Vector2(-length + 8, 3), Vector2(length - 8, 3), SHADOW, 1)
		c.draw_circle(Vector2(-15, -1), 3, accent)
		c.draw_circle(Vector2(-15, -1), 1, LIGHT)
		if spec.twin:
			c.draw_rect(Rect2(-1, 7, 15, 5), body)
			c.draw_line(Vector2(14, 4),Vector2(14, 14),Color(LIGHT, 0.35),1)
			if not friendly:
				c.draw_arc(Vector2(-15,-7),4,PI,TAU,8,GLASS,2)
				c.draw_rect(Rect2(13,-5,7,4),GLASS)
				c.draw_line(Vector2(-15,-11),Vector2(-21,-15),SHADOW,1)
		for x in [18, 21]: c.draw_line(Vector2(x, -4), Vector2(x, 1), INK, 1)
