extends Node2D
## A clipped, code-native 2D camera bridge. No Camera3D and no gameplay reprojection.

const DURATION := 2.6
const FLIGHT := preload("res://src/gameplay/chase_flight.gd")

class Backdrop extends Node2D:
	const SKY := preload("res://src/rendering/chase_background.gd")
	const SCENE := preload("res://src/rendering/scene_art.gd")
	var view := 2
	var projection
	var time := 0.0
	func _draw() -> void:
		if view==2: SKY.draw(self,projection)
		else: SCENE.draw_top(self,time)

class Aircraft extends Node2D:
	const ART := preload("res://src/rendering/aircraft_art.gd")
	var view := 2
	var time := 0.0
	var wingmen := false
	var pose := Vector2.ZERO
	func _draw() -> void:
		ART.draw_plane(self,Vector2.ZERO,1.0,Color("69e6d2"),view,true,0,"interceptor",time,pose)
		if wingmen:
			for side in [-1,1]: ART.draw_plane(self,Vector2(side*50,20),0.5,Color("69e6d2"),view,true,0,"interceptor",time,pose)

class CloudVeil extends Node2D:
	var progress := 0.0
	func _draw() -> void:
		var opacity := pow(sin(clampf(progress,0,1)*PI),2)*0.86
		draw_rect(Rect2(0,0,960,440),Color("bec9c6",opacity*0.28))
		# Broad irregular bands echo the existing geometric clouds, not bubbles.
		for row in range(-2,7):
			var y := row*92+(progress-0.5)*180
			for layer in range(3):
				var polygon := PackedVector2Array()
				for x in range(-120,1100,24):
					polygon.append(Vector2(x,y+sin(x*0.01+row*1.8)*22+sin(x*0.024+row)*10-layer*9))
				for x in range(1080,-121,-24):
					polygon.append(Vector2(x,y+62+sin(x*0.013+row*1.4)*15+layer*9))
				draw_colored_polygon(polygon,Color("d6ddd2",opacity*0.12))

var game
var active := false
var elapsed := 0.0
var next_mode := 1
var next_phase := 1
var committed := false
var aircraft_grace := 0.0
var start_anchor := Vector2.ZERO
var end_anchor := Vector2.ZERO
var start_size := 1.35
var end_size := 1.0
var start_roll := 0.0
var start_pose := Vector2.ZERO
var clip: Control
var source: Backdrop
var target: Backdrop
var source_plane: Aircraft
var target_plane: Aircraft
var veil: CloudVeil

func setup(owner_game) -> void:
	game=owner_game
	clip=Control.new()
	clip.position=Vector2(0,66)
	clip.size=Vector2(960,440)
	clip.clip_contents=true
	clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	source=Backdrop.new()
	target=Backdrop.new()
	clip.add_child(source)
	clip.add_child(target)
	veil=CloudVeil.new()
	clip.add_child(veil)
	source_plane=Aircraft.new()
	target_plane=Aircraft.new()
	clip.add_child(source_plane)
	clip.add_child(target_plane)
	reset()

func reset() -> void:
	active=false
	elapsed=0
	committed=false
	aircraft_grace=0
	visible=false

func snapshot(flight):
	var result = FLIGHT.new()
	for field in ["position","heading","view_heading","turn_rate","climb_rate","bank","crashed"]:
		result.set(field,flight.get(field))
	return result

func begin(mode: int, phase: int) -> void:
	active=true
	visible=true
	elapsed=0
	committed=false
	next_mode=mode
	next_phase=phase
	source.view=game.mode
	target.view=mode
	source.projection=snapshot(game.flight)
	target.projection=snapshot(game.flight)
	if mode==game.Mode.CHASE:
		target.projection.reset()
		target.projection.position=game.mission.saved_position
		target.projection.heading=game.mission.saved_heading
		target.projection.view_heading=game.mission.saved_heading
	start_anchor=game._ship_screen()-Vector2(0,66)
	end_anchor=(target.projection.aircraft_screen() if mode==game.Mode.CHASE else Vector2(480,388.8))-Vector2(0,66)
	start_size=1.35 if source.view==game.Mode.CHASE else 1.0
	end_size=1.35 if mode==game.Mode.CHASE else 1.0
	start_roll=game.bank
	start_pose=game.player_pose.value()
	source_plane.view=source.view
	target_plane.view=mode
	source_plane.wingmen=game.power>1 and source.view==game.Mode.TOP
	target_plane.wingmen=game.power>1 and mode==game.Mode.TOP
	update_visuals()

func progress() -> float:
	return clampf(elapsed/DURATION,0,1)

func update_visuals() -> void:
	var t := progress()
	var ease := t*t*(3-2*t)
	var blend := smoothstep(0.2,0.8,t)
	var zoom := 1+0.06*sin(t*PI)
	source.scale=Vector2.ONE*zoom
	target.scale=Vector2.ONE*zoom
	source.position=Vector2(480,220)*(1-zoom)+Vector2(0,-66*zoom)
	target.position=source.position
	source.modulate.a=1
	target.modulate.a=blend
	var anchor := start_anchor.lerp(end_anchor,ease)
	var size_value := lerpf(start_size,end_size,ease)
	for aircraft in [source_plane,target_plane]:
		aircraft.position=anchor
		aircraft.scale=Vector2.ONE*size_value
		# Banking is already baked in the sprite; do not rotate the image again.
		aircraft.rotation=0
		aircraft.pose=start_pose.lerp(Vector2.ZERO,ease)
		aircraft.time=game.visual_time
		aircraft.queue_redraw()
	source_plane.modulate.a=1-blend
	target_plane.modulate.a=blend
	source.time=game.visual_time
	target.time=game.visual_time
	source.queue_redraw()
	target.queue_redraw()
	veil.progress=t
	veil.queue_redraw()

func advance(delta: float) -> void:
	if not active: return
	elapsed=minf(DURATION,elapsed+delta)
	if elapsed>=DURATION-0.000001: elapsed=DURATION
	if not committed and progress()>=0.5:
		committed=true
		game._switch_mission_mode(next_mode)
		game.mission.phase=next_phase
		game.mission.phase_time=0
		game.mission.cursor=0
		game.mission.previewed=false
	game.transition=maxf(0,DURATION-elapsed)
	update_visuals()
	if elapsed>=DURATION:
		active=false
		visible=false
		aircraft_grace=game.invulnerable
		game.transition=0
		game.mission.announce("已进入沿岸攻击航段 · 清除敌方火力" if next_mode==game.Mode.TOP else "重型拦截机海鸥接近 · 保持距离跟踪射击",3.2)
