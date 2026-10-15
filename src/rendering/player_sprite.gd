extends RefCounted
## Approved v3 mesh baked as original pixel sprites. Runtime stays Node2D.

const TEXTURES := [preload("res://assets/aircraft/player/side.png"),
	preload("res://assets/aircraft/player/top.png"),preload("res://assets/aircraft/player/chase.png")]
const FRAME_SIZE := [Vector2i(80,60),Vector2i(64,64),Vector2i(112,84)]
const PHASE_COUNT := 8
const PHASE_SECONDS := 0.04
const POSE_STEPS := 9
const COLUMNS := 16
const PADDING := 2

static func pose_step(value: float) -> int:
	return clampi(roundi(clampf(value,-1,1)*4)+4,0,8)

static func phase_at(time: float) -> int:
	return int(floor(maxf(0,time)/PHASE_SECONDS+0.00001))%PHASE_COUNT

static func frame_index(view: int, pose: Vector2, time: float) -> int:
	var pitch := pose_step(pose.y) if view==2 else 0
	return (pitch*POSE_STEPS+pose_step(pose.x))*PHASE_COUNT+phase_at(time)

static func source_rect(view: int, pose: Vector2, time: float) -> Rect2:
	var size: Vector2i = FRAME_SIZE[view]
	var index := frame_index(view,pose,time)
	var stride := size+Vector2i.ONE*PADDING*2
	return Rect2(Vector2i(index%COLUMNS,index/COLUMNS)*stride+Vector2i.ONE*PADDING,size)

static func draw(c: Node2D, pos: Vector2, size_scale: float, view: int, pose: Vector2, time: float) -> void:
	# Player-scale native pixels: side 80x60, top 64x64, chase 112x84.
	# Transparent margins are fixed for every pose; no silhouette auto-centering.
	var factor := size_scale/(1.35 if view==2 else 1.0)
	var size := Vector2(FRAME_SIZE[view])*factor
	# The drawing owner keeps nearest filtering (other aircraft/environment
	# are vector primitives). Restoring it before submission would blur sprites.
	c.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	c.draw_texture_rect_region(TEXTURES[view],Rect2(pos-size*0.5,size),source_rect(view,pose,time),Color.WHITE,false,true)
