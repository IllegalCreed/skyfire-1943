extends RefCounted
## Original code-drawn demo heavy aircraft, no separate destructible parts yet.

const AIR := preload("res://src/rendering/aircraft_art.gd")
const BOSS := preload("res://src/gameplay/chase_boss.gd")
const RED := Color("ff6872")
const INK := Color("162831")
const LIGHT := Color("eee6cc")

static func draw_boss(c: Node2D, pos: Vector2, factor: float, enemy: Dictionary, time: float) -> void:
	var size := factor*BOSS.DRAW_SCALE
	AIR.draw_plane(c,pos,size,RED,2,false,enemy.get("bank",0.0),"bomber",time)
	c.draw_set_transform(pos,enemy.get("bank",0.0),Vector2.ONE*size)
	# Armoured central nose and a raised twin-gun station distinguish the Boss.
	c.draw_rect(Rect2(-5,-2,10,7),INK)
	c.draw_line(Vector2(-5,-2),Vector2(-7,5),LIGHT,1.2,true)
	c.draw_line(Vector2(5,-2),Vector2(7,5),LIGHT,1.2,true)
	c.draw_circle(Vector2(0,2),2.2,RED)
	for side in [-1,1]:
		c.draw_line(Vector2(side*40,-5),Vector2(side*40,2),RED,2.8,true)
		c.draw_line(Vector2(side*8,-13),Vector2(side*10,-20),INK,2.0,true)
		if enemy.get("fire",9.0)<0.65:
			c.draw_circle(Vector2(side*10,-20),2.4,Color("ffba68"))
		if enemy.hp<=BOSS.MAX_HP/2:
			for i in range(4):
				var age := fmod(time*1.6+i*0.27,1.0)
				c.draw_circle(Vector2(side*27,-5-age*22),2+age*4,Color("536471",(1-age)*0.5))
	c.draw_set_transform(Vector2.ZERO)
