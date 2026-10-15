extends RefCounted
## Original WWII-era aircraft; all views keep gameplay dimensions and gun anchors.

const INK := Color("162831")
const SILVER := Color("c3cfcb")
const SHADOW := Color("526a70")
const GLASS := Color("234657")
const LIGHT := Color("eee6cc")
const MUZZLES := [Vector2(-18.5, -3), Vector2(18.5, -3)]
const PLAYER_SPRITE := preload("res://src/rendering/player_sprite.gd")

static func draw_plane(c: Node2D, pos: Vector2, scale: float, accent: Color,
	perspective: int, friendly: bool, roll: float, kind: String, time: float,
	visual_pose := Vector2.INF) -> void:
	if friendly:
		var pose: Vector2 = Vector2(roll/0.34,0) if visual_pose==Vector2.INF else visual_pose
		PLAYER_SPRITE.draw(c,pos,scale,perspective,pose,time)
		return
	var spec := dimensions(kind, friendly)
	var angle := roll if perspective == 2 else (PI if perspective == 1 and not friendly else 0.0)
	var stretch := Vector2(-scale, scale) if perspective == 0 and not friendly else Vector2.ONE * scale
	c.draw_set_transform(pos, angle, stretch)
	var body := SILVER if friendly else Color("dab85c") if kind == "courier" else Color("949d83") if kind == "interceptor" else Color("b9ad8d") if kind == "raider" else Color("8b9789")
	var detailed := scale >= 0.4
	if perspective == 2:
		if friendly: _draw_rear(c,spec,body,accent,detailed)
		else: _draw_front(c,spec,body,accent,detailed,time)
	elif perspective == 0: _draw_side(c, spec, body, accent, friendly, detailed, time)
	else: _draw_top(c, spec, body, accent, friendly, detailed, time)
	c.draw_set_transform(Vector2.ZERO)

static func dimensions(kind: String, friendly: bool) -> Dictionary:
	if friendly: return {"span": 36.0, "top_span": 27.0, "length": 29.0, "twin": true, "round": false, "style": "boom"}
	match kind:
		"courier": return {"span": 25.0, "length": 27.0, "twin": false, "round": true, "style": "long_nose"}
		"bomber": return {"span": 58.0, "length": 38.0, "twin": true, "round": false, "style": "bomber"}
		"raider": return {"span": 33.0, "length": 28.0, "twin": false, "round": true, "style": "long_nose"}
	return {"span": 28.0, "length": 29.0, "twin": false, "round": false, "style": "radial"}

static func front_wing(spec: Dictionary) -> PackedVector2Array:
	var w: float = spec.span
	if spec.style == "boom":
		return _points([[-w,2],[-w+3,-2],[-11,-5],[0,-4],[11,-5],[w-3,-2],[w,2],[w-2,5],[12,7],[-12,7],[-w+2,5]])
	if spec.style == "long_nose":
		return _points([[-w,2],[-w+1,-2],[-w+6,-4],[-8,-2],[8,-2],[w-6,-4],[w-1,-2],[w,2],[w-4,7],[9,5],[-9,5],[-w+4,7]])
	if spec.style == "bomber":
		return _points([[-w,-3],[-w+3,-6],[-14,-7],[14,-7],[w-3,-6],[w,-3],[w-3,3],[13,4],[-13,4],[-w+3,3]])
	return _points([[-w,-2],[-w+3,-5],[-7,-3],[7,-3],[w-3,-5],[w,-2],[w-2,4],[8,6],[-8,6],[-w+2,4]])

static func _points(coordinates: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for pair in coordinates: result.append(Vector2(pair[0], pair[1]))
	return result

static func _metal(c: Node2D, points: PackedVector2Array, color: Color, outlined := true) -> void:
	c.draw_colored_polygon(points, color)
	if outlined:
		var edge := points.duplicate()
		edge.append(points[0])
		c.draw_polyline(edge, INK, 0.8, true)

static func _propeller(c: Node2D, center: Vector2, radius: float, time: float, head_on: bool) -> void:
	if head_on:
		c.draw_circle(center, radius, Color(LIGHT, 0.075))
		c.draw_arc(center, radius, 0, TAU, 32, Color(LIGHT, 0.2), 0.65, true)
		for i in range(3):
			var blade := Vector2.from_angle(time * 34 + i * TAU / 3) * radius
			c.draw_line(center + blade * 0.15, center + blade, Color(LIGHT, 0.43), 1, true)
		c.draw_circle(center, 1.8, LIGHT)
	else:
		var shimmer := 0.28 + 0.14 * sin(time * 43 + center.x)
		c.draw_line(center - Vector2(radius,0), center + Vector2(radius,0), Color(LIGHT, shimmer), 1.5, true)
		c.draw_line(center - Vector2(radius*0.7,1), center + Vector2(radius*0.7,-1), Color(LIGHT, 0.18), 1, true)
		c.draw_circle(center, 1.2, LIGHT)

static func _badge(c: Node2D, center: Vector2, accent: Color) -> void:
	# Fictional chevrons, not national roundels or wartime insignia.
	c.draw_line(center + Vector2(-2.2,-2), center + Vector2(0,1), accent, 1.7, true)
	c.draw_line(center + Vector2(0,1), center + Vector2(2.2,-2), accent, 1.7, true)
	c.draw_line(center + Vector2(-2.2,1), center + Vector2(0,3), accent, 1, true)
	c.draw_line(center + Vector2(0,3), center + Vector2(2.2,1), accent, 1, true)

static func _draw_front(c: Node2D, spec: Dictionary, body: Color, accent: Color,
	detailed: bool, time: float) -> void:
	var w: float = spec.span
	var motors: Array = [-27.0,27.0] if spec.twin else [0.0]
	# Approaching enemies face the observer: engine intakes and spinners are visible.
	if spec.twin:
		var tail_x := 17.0
		_metal(c, _points([[-tail_x-4,-8],[-tail_x,-11],[tail_x,-11],[tail_x+4,-8],[tail_x,-5],[-tail_x,-5]]), SHADOW)
		for side in [-1,1]:
			var x: float = side * tail_x
			_metal(c, _points([[x-2,-5],[x-2,-18],[x,-21],[x+3,-18],[x+3,-5]]), body.darkened(0.2))
			c.draw_line(Vector2(x,-18),Vector2(x,-11),accent,1.7,true)
	else:
		_metal(c, _points([[-12,-8],[0,-11],[12,-8],[10,-5],[-10,-5]]), body.darkened(0.25))
		_metal(c, _points([[-2,-5],[-2,-18],[1,-21],[4,-17],[4,-5]]), body)
		c.draw_line(Vector2(0,-17),Vector2(1,-11),accent,1.5,true)
	_metal(c, front_wing(spec), body)
	_metal(c, _points([[-w+3,3],[-12,5],[12,5],[w-3,2],[w-4,5],[12,8],[-12,8],[-w+4,5]]), body.darkened(0.24), false)
	if detailed:
		for side in [-1,1]:
			c.draw_line(Vector2(side*9,-1),Vector2(side*(w-6),-1),LIGHT,0.65,true)
			c.draw_line(Vector2(side*13,4),Vector2(side*(w-7),3),SHADOW,0.8,true)
			c.draw_line(Vector2(side*(w-9),-2),Vector2(side*(w-9),4),SHADOW,0.7,true)
			c.draw_line(Vector2(side*(w-5),0),Vector2(side*(w-3),1),accent,2,true)
	for x in motors:
		var r := 5.2 if spec.twin else 6.5
		c.draw_circle(Vector2(x,2),r+0.8,INK)
		c.draw_circle(Vector2(x,1),r,body.darkened(0.22))
		c.draw_arc(Vector2(x,1),r-0.5,PI,TAU,16,LIGHT,0.8,true)
		if detailed:
			c.draw_circle(Vector2(x,2),r-1.8,INK)
			for i in range(5):
				var rib := Vector2.from_angle(i*TAU/5+0.25)*(r-2)
				c.draw_line(Vector2(x,2)+rib*0.45,Vector2(x,2)+rib,SHADOW,0.7,true)
			_propeller(c,Vector2(x,2),8.3 if spec.twin else 8.8,time+x,true)
	if spec.twin:
		_metal(c,_points([[-7,-9],[-5,-15],[5,-15],[7,-9],[6,7],[0,11],[-6,7]]),body)
		_metal(c,_points([[-5,-11],[-3,-14],[3,-14],[5,-11],[4,-5],[-4,-5]]),GLASS)
		_metal(c,_points([[-4,-2],[4,-2],[5,5],[0,8],[-5,5]]),GLASS)
		if detailed:
			for x in [-2,2]: c.draw_line(Vector2(x,-12),Vector2(x,6),body,0.7,true)
			c.draw_line(Vector2(-4,2),Vector2(4,2),body,0.7,true)
			c.draw_line(Vector2(-6,-7),Vector2(6,-7),accent,1.8,true)
	else:
		_metal(c,_points([[-4,-6],[-3,-13],[0,-16],[3,-13],[4,-6]]),GLASS)
		if detailed:
			c.draw_line(Vector2(0,-14),Vector2(0,-7),LIGHT,0.7,true)
			for side in [-1,1]: c.draw_line(Vector2(side*9,-1),Vector2(side*9,-6),INK,1.1,true)
			c.draw_arc(Vector2(0,2),6,0.1,PI-0.1,16,accent,1.5,true)

static func _draw_rear(c: Node2D, spec: Dictionary, body: Color, accent: Color,
	detailed: bool) -> void:
	# The observer is behind our fighter. Propellers and intake faces are
	# occluded by engine nacelles; the nearest structures are the twin tails.
	var w: float = spec.span
	_metal(c,front_wing(spec),body)
	_metal(c,_points([[-w+3,3],[-11,5],[11,5],[w-3,3],[w-4,6],[11,8],[-11,8],[-w+4,6]]),body.darkened(0.27),false)
	if detailed:
		for side in [-1,1]:
			c.draw_line(Vector2(side*10,-2),Vector2(side*(w-5),0),LIGHT,0.65,true)
			c.draw_line(Vector2(side*11,4),Vector2(side*(w-7),4),SHADOW,0.8,true)
			c.draw_line(Vector2(side*(w-9),0),Vector2(side*(w-9),5),SHADOW,0.7,true)
			c.draw_line(Vector2(side*(w-4),1),Vector2(side*(w-2),2),accent,1.8,true)
	for x in [-18.5,18.5]:
		# Aft nacelle and boom: solid tapered metal, never a radial intake ring.
		_metal(c,_points([[x-4,-5],[x+4,-5],[x+5,1],[x+3,12],[x-3,12],[x-5,1]]),body.darkened(0.17))
		_metal(c,_points([[x-2,-4],[x+2,-4],[x+3,3],[x+1,10],[x-2,8]]),body,false)
		if detailed:
			c.draw_line(Vector2(x-3,4),Vector2(x-3,8),INK,0.8,true)
			c.draw_line(Vector2(x+3,4),Vector2(x+3,8),INK,0.8,true)
	_metal(c,_points([[-5,-9],[-7,-4],[-6,4],[-3,9],[3,9],[6,4],[7,-4],[5,-9]]),body)
	_metal(c,_points([[-3,-10],[3,-10],[4,-6],[3,-3],[-3,-3],[-4,-6]]),GLASS)
	if detailed:
		# Rear canopy frame and the closed aft end of the central cockpit pod.
		c.draw_line(Vector2(-2,-8),Vector2(2,-8),SHADOW,0.8,true)
		c.draw_line(Vector2(0,-9),Vector2(0,-4),SHADOW,0.7,true)
		c.draw_line(Vector2(-3,6),Vector2(3,6),SHADOW,1.4,true)
		for muzzle in MUZZLES:
			c.draw_line(muzzle+Vector2(0,2),muzzle,INK,1.2,true)
	# Rear stabilizer connects the booms and masks structures farther forward.
	_metal(c,_points([[-23,10],[-20,8],[20,8],[23,10],[21,14],[-21,14]]),body.darkened(0.14))
	c.draw_line(Vector2(-20,12),Vector2(20,12),SHADOW,0.8,true)
	for side in [-1,1]:
		var x: float = side*18.5
		_metal(c,_points([[x-2,12],[x-2,-16],[x,-21],[x+3,-17],[x+3,12]]),body.darkened(0.18))
		if detailed:
			c.draw_line(Vector2(x,-15),Vector2(x,7),SHADOW,0.8,true)
			c.draw_line(Vector2(x,-12),Vector2(x,-5),accent,1.6,true)

static func _draw_top(c: Node2D, spec: Dictionary, body: Color, accent: Color,
	friendly: bool, detailed: bool, time: float) -> void:
	var w: float = spec.get("top_span",spec.span)
	var length: float = spec.length
	var leading := -8.0 if friendly else -4.0 if spec.round else -7.0
	_metal(c,_points([[-7,leading-4],[-w+4,leading],[-w,leading+4],[-w+1,8],[-w+5,10],[-8,12],[8,12],[w-5,10],[w-1,8],[w,leading+4],[w-4,leading],[7,leading-4]]),body)
	for side in [-1,1]:
		_metal(c,_points([[side*9,3],[side*(w-3),4],[side*(w-4),8],[side*9,9]]),body.darkened(0.2),false)
		if detailed:
			c.draw_line(Vector2(side*10,leading),Vector2(side*(w-5),leading+3),LIGHT,0.65,true)
			c.draw_line(Vector2(side*(w-7),leading+3),Vector2(side*(w-7),8),SHADOW,0.65,true)
			_badge(c,Vector2(side*(w-9),0),accent)
	var motors: Array = [-18.5,18.5] if friendly else [-27.0,27.0] if spec.twin else []
	for x in motors:
		var end := length if friendly else 16.0
		_metal(c,_points([[x-3,-20],[x,-23],[x+3,-20],[x+4,0],[x+2,end],[x-2,end],[x-4,0]]),body.darkened(0.15))
		_metal(c,_points([[x-2,-19],[x+2,-19],[x+2,2],[x-2,7]]),body,false)
		c.draw_rect(Rect2(x-3,-18,6,5),SHADOW)
		if detailed:
			for y in [-11,-8,-5]: c.draw_line(Vector2(x-2,y),Vector2(x+2,y),INK,0.6,true)
			_propeller(c,Vector2(x,-23),8.5,time+x,false)
		if friendly:
			c.draw_line(Vector2(x,length-12),Vector2(x,length-2),accent,2,true)
			c.draw_line(Vector2(x,-25),Vector2(x,-21),INK,1.5,true)
	var tail_w := 21.0 if friendly else 21.0 if spec.twin else 13.0
	_metal(c,_points([[-tail_w,length-9],[-tail_w+3,length-13],[tail_w-3,length-13],[tail_w,length-9],[tail_w-1,length-5],[-tail_w+1,length-5]]),body)
	if friendly:
		for x in [-18.5,18.5]: c.draw_line(Vector2(x,length-14),Vector2(x,length),SHADOW,2.2,true)
		_metal(c,_points([[0,-length],[-4,-length+5],[-6,-12],[-6,2],[-3,10],[3,10],[6,2],[6,-12],[4,-length+5]]),body)
	elif spec.twin:
		_metal(c,_points([[0,-length],[-5,-length+4],[-7,-22],[-6,10],[-3,length],[3,length],[6,10],[7,-22],[5,-length+4]]),body)
		for x in [-17,17]: c.draw_line(Vector2(x,length-14),Vector2(x,length-2),accent,2,true)
	else:
		var nose_w := 6.0 if spec.style == "radial" else 4.0
		_metal(c,_points([[-nose_w,-length+3],[0,-length],[nose_w,-length+3],[6,-12],[5,8],[2,length],[-2,length],[-5,8],[-6,-12]]),body)
		c.draw_rect(Rect2(-nose_w,-length+3,nose_w*2,6),SHADOW)
		if detailed: _propeller(c,Vector2(0,-length-1),8.5,time,false)
	if detailed:
		var cockpit_y := -17.0 if spec.twin else -13.0
		_metal(c,_points([[-3,cockpit_y-3],[0,cockpit_y-5],[3,cockpit_y-3],[4,cockpit_y+6],[2,cockpit_y+9],[-2,cockpit_y+9],[-4,cockpit_y+6]]),GLASS)
		c.draw_line(Vector2(-2,cockpit_y-2),Vector2(2,cockpit_y-2),LIGHT,0.8,true)
		c.draw_line(Vector2(-3,cockpit_y+3),Vector2(3,cockpit_y+3),SHADOW,0.8,true)
		c.draw_line(Vector2(0,cockpit_y-3),Vector2(0,cockpit_y+7),SHADOW,0.6,true)
		if spec.twin and not friendly:
			_metal(c,_points([[0,-length+2],[-4,-length+6],[-4,-length+12],[4,-length+12],[4,-length+6]]),GLASS)
			c.draw_line(Vector2(0,-length+4),Vector2(0,-length+12),body,0.7,true)
		else:
			c.draw_line(Vector2(-3,5),Vector2(3,5),accent,2,true)
		c.draw_line(Vector2(0,10),Vector2(0,length-12),SHADOW,0.7,true)
		for side in [-1,1]: c.draw_line(Vector2(side*9,1),Vector2(side*9,-8),INK,1,true)
		if not friendly and not spec.twin: c.draw_line(Vector2(0,length-12),Vector2(0,length-2),accent,2.1,true)

static func _draw_side(c: Node2D, spec: Dictionary, body: Color, accent: Color,
	friendly: bool, detailed: bool, time: float) -> void:
	var length: float = spec.length+5
	if friendly:
		# The boom reaches the tail; the central cockpit pod ends behind the wing.
		_metal(c,_points([[-length+2,-1],[-length+5,-17],[-length+10,-16],[-length+11,-1],[17,-1],[21,3],[17,7],[-length+2,4]]),body.darkened(0.25))
		_metal(c,_points([[-12,-4],[-5,-8],[17,-7],[length-3,-3],[length,0],[length-5,4],[-9,5],[-15,1]]),body)
		_metal(c,_points([[-length-2,2],[-length+13,1],[-length+15,4],[-length+1,6]]),SHADOW)
		_metal(c,_points([[-16,0],[0,-1],[10,2],[-3,13],[-17,10]]),SHADOW)
		_metal(c,_points([[6,3],[17,3],[20,7],[18,11],[5,10]]),body)
		c.draw_line(Vector2(21,-7),Vector2(21,12),Color(LIGHT,0.3+0.12*sin(time*43)),1.2,true)
		c.draw_line(Vector2(-length+5,-14),Vector2(-length+7,-6),accent,2,true)
	else:
		var nose := length-3
		_metal(c,_points([[-length+2,0],[-length+3,-16],[-length+9,-17],[-length+13,-4],[-10,-7],[nose-8,-7],[nose,-5],[length,0],[nose,5],[-13,5],[-length+1,4]]),body)
		_metal(c,_points([[-length+8,3],[nose,3],[nose-1,6],[-length+4,5]]),body.darkened(0.24),false)
		var wing_tip := 12.0 if spec.round else 10.0
		_metal(c,_points([[-16,0],[7,-2],[wing_tip,3],[-3,12],[-18,9]]),SHADOW)
		if spec.twin:
			_metal(c,_points([[4,4],[23,4],[27,7],[24,12],[2,11]]),body)
			c.draw_line(Vector2(28,-2),Vector2(28,16),Color(LIGHT,0.4),1.2,true)
			_metal(c,_points([[nose-7,-5],[nose-2,-4],[length,0],[nose-2,4],[nose-7,3]]),GLASS)
		else:
			c.draw_rect(Rect2(nose-7,-6,6,11),body.darkened(0.35))
			c.draw_line(Vector2(length,-10),Vector2(length,10),Color(LIGHT,0.3+0.12*sin(time*43)),1.2,true)
			c.draw_circle(Vector2(length,0),1.5,LIGHT)
		c.draw_line(Vector2(-length+6,-14),Vector2(-length+10,-7),accent,2,true)
	if detailed:
		_metal(c,_points([[-3,-7],[2,-13],[10,-14],[16,-8],[14,-6]]),GLASS)
		c.draw_line(Vector2(3,-12),Vector2(9,-12),LIGHT,0.8,true)
		c.draw_line(Vector2(6,-12),Vector2(7,-7),SHADOW,0.8,true)
		c.draw_line(Vector2(11,-11),Vector2(12,-7),SHADOW,0.8,true)
		c.draw_line(Vector2(-13,2),Vector2(length-9,2),SHADOW,0.7,true)
		for x in [18,21,24]: c.draw_line(Vector2(x,-4),Vector2(x,0),INK,0.9,true)
		_badge(c,Vector2(-17,-2),accent)
		c.draw_line(Vector2(-11,8),Vector2(-5,9),LIGHT,0.8,true)
		if spec.twin and not friendly:
			c.draw_arc(Vector2(-17,-6),4,PI,TAU,12,GLASS,2,true)
			c.draw_line(Vector2(-17,-10),Vector2(-22,-14),SHADOW,0.8,true)
