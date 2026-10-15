extends RefCounted
## Shared unchanged sky/sea drawing for live play and the cinematic bridge.

const SKY := preload("res://src/rendering/chase_sky.gd")
const SCENE := preload("res://src/rendering/scene_art.gd")

static func draw(c: Node2D, flight) -> void:
	var h: float = flight.horizon()
	for row in range(0,540,4):
		var t := clampf(float(row)/maxf(h,1),0,1)
		c.draw_rect(Rect2(0,row,960,4),Color("111d38").lerp(Color("99555b"),t))
	var sun_x: float = flight.bearing_screen(0.52)
	c.draw_circle(Vector2(sun_x,h-48),37,Color("ffba68"))
	for stripe in range(5): c.draw_rect(Rect2(sun_x-42,h-44+stripe*8,84,3+stripe),Color("704453"))
	SKY.draw_clouds(c,flight)
	var sea_start := clampf(h,0,540)
	if sea_start<540:
		c.draw_rect(Rect2(0,sea_start,960,540-sea_start),Color("12384b"))
		waves(c,flight,12,18,sea_start)
		waves(c,flight,4,12,sea_start)
		if h>=0: c.draw_line(Vector2(0,h),Vector2(960,h),Color("f4a374"),2)
	SCENE.draw_chase_landmarks(c,flight)

static func waves(c: Node2D, flight, spacing: float, radius: int, sea_start: float) -> void:
	var tile_x := int(floor(flight.position.x/spacing))
	var tile_z := int(floor(flight.position.z/spacing))
	for x in range(tile_x-radius,tile_x+radius+1):
		for z in range(tile_z-radius,tile_z+radius+1):
			var point := Vector3(x*spacing+sin(float(z)*1.7)*spacing*0.2,0,z*spacing)
			var depth: float = flight.depth(point)
			if depth<6: continue
			var p: Vector2 = flight.project(point)
			if p.y<sea_start or not Rect2(-20,65,1000,440).has_point(p): continue
			var length := clampf(spacing*10/depth,1.5,15)
			c.draw_line(p-Vector2(length,0),p+Vector2(length,0),Color("387287"),1.5)
