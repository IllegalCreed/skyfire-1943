extends RefCounted
## Fictional 1943-era escort and armed freighter, in top and chase views.

const INK := Color("152c36")
const HULL := Color("6f8587")
const DECK := Color("a4aa91")
const LIGHT := Color("d1d3b9")
const SHADOW := Color("425e65")

static func draw_vessel(c: Node2D, pos: Vector2, scale: float, chase: bool,
	vessel: String, accent: Color, scenery := false) -> void:
	c.draw_set_transform(pos, 0, Vector2.ONE * scale)
	if chase: _chase(c,vessel,accent,scale>=0.35)
	else: _top(c,vessel,accent,not scenery)
	c.draw_set_transform(Vector2.ZERO)

static func _poly(c: Node2D, coordinates: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for pair in coordinates: points.append(Vector2(pair[0],pair[1]))
	c.draw_colored_polygon(points,color)
	points.append(points[0])
	c.draw_polyline(points,INK,0.8,true)

static func _top(c: Node2D, vessel: String, accent: Color, detailed: bool) -> void:
	var sea := Color("123b51")
	var hull := HULL if detailed else HULL.lerp(sea,0.5)
	var deck := DECK if detailed else DECK.lerp(sea,0.5)
	var metal := LIGHT if detailed else LIGHT.lerp(sea,0.6)
	var shadow := SHADOW if detailed else SHADOW.lerp(sea,0.3)
	# Hull remains within the old 20x44 half-extents; no hidden collision expansion.
	_poly(c,[[0,-44],[10,-37],[18,-22],[20,19],[17,35],[9,42],[-9,42],[-17,35],[-20,19],[-18,-22],[-10,-37]],hull)
	_poly(c,[[0,-40],[8,-34],[15,-20],[16,20],[13,33],[7,38],[-7,38],[-13,33],[-16,20],[-15,-20],[-8,-34]],deck)
	for side in [-1,1]:
		c.draw_line(Vector2(side*15,-19),Vector2(side*15,28),metal,0.8,true)
		c.draw_line(Vector2(side*15,33),Vector2(side*10,37),metal,0.8,true)
	if vessel == "cargo":
		# Period freighter: hatch covers, derricks and an aft bridge, not containers.
		for y in [-27,-10,8]:
			c.draw_rect(Rect2(-9,y,18,12),shadow)
			c.draw_rect(Rect2(-7,y+1,14,9),Color("788b7e"))
			if detailed:
				c.draw_line(Vector2(-6,y+2),Vector2(6,y+8),metal,0.6,true)
				c.draw_line(Vector2(6,y+2),Vector2(-6,y+8),metal,0.6,true)
		_poly(c,[[-10,22],[-7,19],[7,19],[10,22],[10,29],[-10,29]],metal)
		c.draw_rect(Rect2(-8,23,16,3),INK)
		c.draw_rect(Rect2(-3,30,6,7),shadow)
		c.draw_rect(Rect2(-3,31,6,2),accent)
		if detailed:
			for y in [-15,6]:
				c.draw_circle(Vector2(0,y),1.6,INK)
				c.draw_line(Vector2(-11,y+4),Vector2(11,y-5),metal,0.8,true)
			c.draw_circle(Vector2(0,-34),3,shadow)
			c.draw_line(Vector2(0,-34),Vector2(0,-40),accent,1.2,true)
	else:
		# Separate gun housings, bridge wings, twin funnels and torpedo tubes.
		for y in [-27,29]:
			_poly(c,[[-5,y-4],[0,y-7],[5,y-4],[5,y+4],[-5,y+4]],shadow)
			c.draw_line(Vector2(0,y-1),Vector2(0,y-12),metal,2,true)
			c.draw_line(Vector2(-4,y+3),Vector2(4,y+3),accent,1.3,true)
		_poly(c,[[-9,-16],[-5,-21],[5,-21],[9,-16],[10,-9],[-10,-9]],hull.lightened(0.2))
		c.draw_rect(Rect2(-7,-16,14,3),INK)
		c.draw_rect(Rect2(-5,-10,10,8),metal)
		for y in [2,12]:
			_poly(c,[[-4,y-3],[4,y-3],[5,y+2],[3,y+5],[-3,y+5],[-5,y+2]],shadow)
			c.draw_rect(Rect2(-3,y-2,6,2),INK)
		if detailed:
			c.draw_line(Vector2(0,-9),Vector2(0,-23),metal,0.8,true)
			c.draw_line(Vector2(-6,-20),Vector2(6,-20),metal,0.8,true)
			for side in [-1,1]:
				c.draw_rect(Rect2(side*11-2,4,4,12),shadow)
				c.draw_line(Vector2(side*11,5),Vector2(side*11,15),metal,0.8,true)
			c.draw_rect(Rect2(-6,19,12,3),accent.darkened(0.4))
	if detailed:
		for side in [-1,1]:
			c.draw_line(Vector2(side*7,-33),Vector2(side*3,-38),shadow,0.8,true)
			c.draw_circle(Vector2(side*11,33),1.2,shadow)

static func _chase(c: Node2D, vessel: String, accent: Color, detailed: bool) -> void:
	_poly(c,[[-34,1],[-30,8],[-23,14],[25,14],[33,8],[34,1]],HULL)
	_poly(c,[[-34,1],[-30,-2],[29,-2],[34,1],[30,4],[-30,4]],DECK)
	c.draw_line(Vector2(-24,11),Vector2(25,11),LIGHT,0.8,true)
	if vessel == "cargo":
		for x in [-23,-8]:
			_poly(c,[[x,-2],[x,-5],[x+11,-5],[x+11,-2]],Color("788b7e"))
		_poly(c,[[11,-3],[11,-12],[16,-16],[28,-16],[29,-2]],LIGHT)
		c.draw_rect(Rect2(14,-12,13,3),INK)
		_poly(c,[[17,-16],[17,-22],[22,-22],[24,-16]],SHADOW)
		c.draw_line(Vector2(18,-20),Vector2(22,-20),accent,1.7,true)
		for x in [-19,1]:
			c.draw_line(Vector2(x,0),Vector2(x,-26),LIGHT,0.8,true)
			c.draw_line(Vector2(x-7,-20),Vector2(x+8,-20),LIGHT,0.8,true)
			if detailed: c.draw_line(Vector2(x,-23),Vector2(x+11,-3),SHADOW,0.6,true)
	else:
		_poly(c,[[-16,-3],[-16,-13],[-12,-18],[-3,-18],[1,-13],[1,-3]],HULL.lightened(0.2))
		c.draw_rect(Rect2(-14,-14,13,3),INK)
		c.draw_rect(Rect2(-10,-20,8,3),LIGHT)
		c.draw_line(Vector2(-5,-18),Vector2(-5,-27),LIGHT,0.8,true)
		c.draw_line(Vector2(-11,-24),Vector2(1,-24),LIGHT,0.8,true)
		for x in [6,17]:
			_poly(c,[[x-3,-3],[x-3,-16],[x+2,-16],[x+4,-3]],SHADOW)
			c.draw_line(Vector2(x-2,-14),Vector2(x+2,-14),INK,1.8,true)
		for x in [-25,26]:
			_poly(c,[[x-4,-2],[x-3,-7],[x+3,-7],[x+5,-2]],HULL.lightened(0.15))
			c.draw_line(Vector2(x,-5),Vector2(x+4,-12),LIGHT,1.2,true)
			c.draw_line(Vector2(x-3,-3),Vector2(x+3,-3),accent,1.2,true)
	if detailed:
		for x in range(-23,29,7): c.draw_circle(Vector2(x,7),0.8,INK)
		c.draw_line(Vector2(-29,-2),Vector2(29,-2),LIGHT,0.6,true)
