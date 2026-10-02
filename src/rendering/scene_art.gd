extends RefCounted
## Original fictional island-chain scenery; subdued compared with live targets.

static func draw_chase_landmarks(c: Node2D, flight) -> void:
	var h: float = flight.horizon()
	if not flight.sea_visible(): return
	# Distant islands fade in over the first 48 pixels of exposed sea, so the
	# new altitude threshold cannot pop a whole coastline into a sky-only view.
	var reveal := clampf((flight.SEA_VIEW_BOTTOM - h) / 48.0, 0, 1)
	# Distant silhouettes use fixed bearings, not the aircraft's screen position.
	# They share the sun/cloud scroll and remain continuous at the heading seam.
	for i in range(5):
		var x: float = flight.bearing_screen(0.05 + i * TAU / 5)
		var width := 190.0 + (i % 3) * 38
		var peak := 27.0 + (i % 3) * 12
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - width * 0.55, h + 4),
			Vector2(x - width * 0.35, h - 8), Vector2(x - width * 0.22, h - peak * 0.7),
			Vector2(x - width * 0.05, h - peak), Vector2(x + width * 0.13, h - peak * 0.55),
			Vector2(x + width * 0.3, h - 9), Vector2(x + width * 0.5, h + 4)]), Color(Color("394e59"), reveal))
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - width * 0.35, h + 4),
			Vector2(x - 14, h - 13), Vector2(x + width * 0.3, h - 2), Vector2(x + width * 0.5, h + 4)]), Color(Color("506469"), reveal))
		c.draw_line(Vector2(x - width * 0.42, h + 5), Vector2(x + width * 0.44, h + 5), Color(Color("ad9580"), reveal), 2)
		if i % 2 == 0:
			c.draw_rect(Rect2(x + 12, h - 11, 28, 10), Color(Color("697575"), reveal))
			c.draw_rect(Rect2(x + 20, h - 16, 10, 5), Color(Color("758180"), reveal))
			c.draw_line(Vector2(x + 26, h - 16), Vector2(x + 26, h - 30), Color(Color("87928c"), reveal), 1)
			c.draw_line(Vector2(x + 19, h - 28), Vector2(x + 33, h - 28), Color(Color("87928c"), reveal), 1)
	# Sparse world-space navigation buoys reinforce forward movement at sea.
	var tile_z := int(floor(flight.position.z / 180))
	for n in range(tile_z - 3, tile_z + 4):
		for x in [-95.0, 95.0]:
			var point := Vector3(x, 0.0, n * 180.0)
			if not flight.visible(point): continue
			var p: Vector2 = flight.project(point)
			if p.y < h + 9 or p.y > 492: continue
			var scale := clampf(50.0 / flight.depth(point), 0.15, 1.0)
			c.draw_line(p - Vector2(0, 8 * scale), p, Color("718b88"), 2 * scale)
			c.draw_line(p + Vector2(-4, 2) * scale, p + Vector2(4, 2) * scale, Color("718b88"), 1)

static func draw_top(c: Node2D, time: float) -> void:
	c.draw_rect(Rect2(0, 0, 960, 540), Color("123b51"))
	for i in range(72):
		var x := fposmod(float(i * 137), 960)
		var y := fposmod(float(i * 83) + time * 64, 540)
		c.draw_line(Vector2(x, y), Vector2(x + 12 + i % 4 * 6, y), Color("215064"), 1.5)
	# A scrolling coastline, runway and working port occupy the left third.
	for section in range(-1, 2):
		_draw_coastal_airfield(c, section * 1200 + fposmod(time * 28, 1200) - 90)
	# Convoy silhouettes are scenery, not shootable objectives in this lab.
	for i in range(3):
		var pos := Vector2(660 + i * 94, fposmod(i * 218 + time * 28, 1040) - 110)
		_draw_convoy(c, pos, 0.75 if i != 1 else 1.0)
	# Clouds are translucent so they never hide live bullets or aircraft.
	for i in range(3):
		var pos := Vector2(fposmod(i * 391 - time * 9, 1190) - 100, fposmod(i * 211 + time * 33, 920) - 170)
		c.draw_rect(Rect2(pos, Vector2(130, 9)), Color("9badb0", 0.13))
		c.draw_rect(Rect2(pos + Vector2(25, -6), Vector2(86, 21)), Color("9badb0", 0.1))

static func _draw_coastal_airfield(c: Node2D, y: float) -> void:
	var coast := PackedVector2Array([Vector2(-15,y-70),Vector2(160,y-70),Vector2(176,y+20),
		Vector2(222,y+92),Vector2(215,y+236),Vector2(260,y+310),Vector2(232,y+410),
		Vector2(160,y+475),Vector2(118,y+570),Vector2(-15,y+600)])
	c.draw_colored_polygon(coast, Color("a69471"))
	var inland := PackedVector2Array([Vector2(-15,y-70),Vector2(142,y-70),Vector2(158,y+26),
		Vector2(198,y+96),Vector2(194,y+244),Vector2(238,y+312),Vector2(211,y+399),
		Vector2(145,y+461),Vector2(98,y+556),Vector2(-15,y+580)])
	c.draw_colored_polygon(inland, Color("405c54"))
	c.draw_line(Vector2(218,y+272),Vector2(271,y+319),Color("527780"),2)
	c.draw_line(Vector2(180,y+447),Vector2(219,y+420),Color("527780"),2)
	# Runway, service road, hangars and perimeter marks.
	c.draw_rect(Rect2(65,y+48,38,274),Color("314950"))
	c.draw_rect(Rect2(68,y+51,32,268),Color("64706b"))
	for i in range(9): c.draw_rect(Rect2(83,y+62+i*28,2,12),Color("c4c4a7"))
	for x in [71,78,85,92]:
		c.draw_rect(Rect2(x,y+54,2,12),Color("c4c4a7"))
		c.draw_rect(Rect2(x,y+302,2,12),Color("c4c4a7"))
	c.draw_line(Vector2(121,y+33),Vector2(121,y+390),Color("788374"),4)
	for i in range(3):
		var p := Vector2(130,y+94+i*65)
		c.draw_rect(Rect2(p+Vector2(3,4),Vector2(42,29)),Color("253e40"))
		c.draw_rect(Rect2(p,Vector2(42,26)),Color("8a9385"))
		c.draw_line(p+Vector2(0,13),p+Vector2(42,13),Color("b4b6a0"),2)
		c.draw_rect(Rect2(p+Vector2(4,21),Vector2(34,5)),Color("344b4c"))
	# Harbor piers and cranes; cool greys separate scenery from red live vessels.
	for i in range(2):
		var p := Vector2(198,y+336+i*29)
		c.draw_rect(Rect2(p,Vector2(92,12)),Color("657e7a"))
		c.draw_line(p+Vector2(42,3),p+Vector2(42,-19),Color("a1a488"),2)
		c.draw_line(p+Vector2(42,-19),p+Vector2(70,-19),Color("a1a488"),2)
		c.draw_line(p+Vector2(70,-19),p+Vector2(70,-6),Color("a1a488"),1)
	for i in range(18):
		var p := Vector2(15+(i*31)%37,y+23+i*28)
		c.draw_circle(p,9,Color("354f47"))
		c.draw_line(p-Vector2(7,0),p+Vector2(7,0),Color("597260"),1.5)
		c.draw_line(p-Vector2(0,7),p+Vector2(0,7),Color("597260"),1.5)

static func _draw_convoy(c: Node2D, pos: Vector2, scale: float) -> void:
	c.draw_set_transform(pos,0,Vector2.ONE*scale)
	c.draw_colored_polygon(PackedVector2Array([Vector2(0,-40),Vector2(13,-24),Vector2(13,32),
		Vector2(0,39),Vector2(-13,32),Vector2(-13,-24)]),Color("577779"))
	c.draw_rect(Rect2(-9,-21,18,45),Color("87968b"))
	for y in [-15,2]: c.draw_rect(Rect2(-7,y,14,12),Color("4a6364"))
	c.draw_rect(Rect2(-7,23,14,6),Color("a0ac99"))
	c.draw_line(Vector2(0,37),Vector2(0,93),Color("477483"),2)
	c.draw_line(Vector2(-4,43),Vector2(-13,87),Color("3b6878"),1)
	c.draw_line(Vector2(4,43),Vector2(13,87),Color("3b6878"),1)
	c.draw_set_transform(Vector2.ZERO)

static func draw_side(c: Node2D, time: float, ceiling: Callable, floor_line: Callable) -> void:
	for row in range(0,540,8):
		c.draw_rect(Rect2(0,row,960,8),Color("152a40").lerp(Color("886461"),float(row)/540))
	c.draw_circle(Vector2(783,206),31,Color("c39470"))
	# Layered, slow-moving distant ridges behind the active flight corridor.
	for layer in range(3):
		var points := PackedVector2Array([Vector2(0,540)])
		var speed := 8+layer*11
		for x in range(0,985,24):
			var height := 332+layer*36+sin((x+time*speed)*0.008)*26+sin((x+time*speed)*0.017)*17
			points.append(Vector2(x,height))
		points.append(Vector2(960,540))
		c.draw_colored_polygon(points,[Color("4d6266"),Color("3b565a"),Color("2a464c")][layer])
	# Upper danger remains the existing collision boundary, expressed as an
	# offshore flak curtain, not an invisible wall or an underground cave roof.
	var flak := PackedVector2Array([Vector2(0,0),Vector2(960,0)])
	var cliff := PackedVector2Array([Vector2(0,540),Vector2(960,540)])
	for x in range(960,-1,-12):
		flak.append(Vector2(x,ceiling.call(x)))
		cliff.append(Vector2(x,floor_line.call(x)))
	c.draw_colored_polygon(flak,Color("413847",0.7))
	c.draw_colored_polygon(cliff,Color("806955"))
	for x in range(0,960,12):
		var upper: float = ceiling.call(x)
		var lower: float = floor_line.call(x)
		if (x/12)%2==0: c.draw_line(Vector2(x,upper),Vector2(x+8,ceiling.call(x+8)),Color("ff6872",0.8),1.5)
		c.draw_line(Vector2(x,lower),Vector2(x+12,floor_line.call(x+12)),Color("ffba68"),2)
		c.draw_line(Vector2(x,lower+12),Vector2(x+12,floor_line.call(x+12)+12),Color("a08b6c"),2)
		for band in range(2):
			c.draw_line(Vector2(x,lower+30+band*21),Vector2(x+12,floor_line.call(x+12)+29+band*21),Color("5c574e"),1.5)
	for i in range(10):
		var x := fposmod(i*137-time*72,1200)-120
		var y: float = ceiling.call(x)-18
		c.draw_circle(Vector2(x,y),9+i%3*3,Color("817b7c",0.23))
		c.draw_line(Vector2(x-5,y),Vector2(x+5,y),Color("b79282",0.45),1)
	# Ground structures are below the collision line; distant silhouettes are
	# explicitly background scenery rather than unmarked solid obstacles.
	for i in range(4):
		var x := fposmod(i*341-time*72,1400)-150
		var y: float = floor_line.call(x)+16
		c.draw_rect(Rect2(x,y,72,30),Color("4d5955"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(x-4,y),Vector2(x+7,y-9),
			Vector2(x+62,y-9),Vector2(x+76,y)]),Color("a29a80"))
		for n in range(5): c.draw_rect(Rect2(x+7+n*12,y+9,6,6),Color("b8b39a"))
