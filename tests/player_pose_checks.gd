extends RefCounted

const POSE := preload("res://src/rendering/player_pose.gd")
const SPRITE := preload("res://src/rendering/player_sprite.gd")
const FLIGHT := preload("res://src/gameplay/chase_flight.gd")

static func run(game) -> void:
	for view in range(3):
		var image: Image = SPRITE.TEXTURES[view].get_image()
		assert(image!=null and not image.is_empty(),"Exported runtime atlas is loaded")
		var pitch_values := range(9) if view==2 else range(1)
		for p in pitch_values:
			for r in range(9):
				var pose := Vector2((r-4)/4.0,(p-4)/4.0 if view==2 else 0)
				var first := PackedByteArray()
				var distinct := false
				for phase in range(8):
					var rect := Rect2i(SPRITE.source_rect(view,pose,phase*0.04))
					assert(Rect2i(Vector2i.ZERO,image.get_size()).encloses(rect),"Pose/phase is inside its atlas")
					var frame := image.get_region(rect)
					assert(frame.get_used_rect().has_area(),"No missing pose cells")
					if phase==0: first=frame.get_data()
					elif frame.get_data()!=first: distinct=true
				assert(distinct,"Every runtime pose has animated propeller pixels")
		var state := POSE.new()
		var input := Vector2.DOWN if view==0 else Vector2.RIGHT
		var seen := {}
		for frame in range(12):
			state.advance(1.0/60,view,input,0)
			seen[SPRITE.pose_step(state.roll)]=true
		assert(seen.size()>=5 and state.roll==1,"Neutral-to-bank visits all intermediate frames")
		state.advance(1.0/60,view,-input,0)
		assert(state.roll>0.8,"Reversal cannot instantly swap bank endpoints")
		for frame in range(24): state.advance(1.0/60,view,Vector2.ZERO,0)
		assert(state.value()==Vector2.ZERO,"Release returns exactly to neutral")
		state.advance(1.0,view,Vector2.RIGHT if view==0 else Vector2.UP,0)
		assert(state.value()==Vector2.ZERO,"Side fore/aft and top vertical movement do not pitch or bank")
	var diagonal := POSE.new()
	diagonal.advance(1,2,Vector2(1,-1),1)
	assert(diagonal.value()==Vector2.ONE,"Chase climb and bank are simultaneous")
	assert(SPRITE.frame_index(2,diagonal.value(),0)==640,"Combined pose uses its own render, not a rotated flat image")
	assert(SPRITE.phase_at(0.32)==0 and SPRITE.phase_at(0.04)==1,"Eight 40-ms exposure phases wrap")
	for view in range(3):
		assert(SPRITE.frame_index(view,Vector2.ONE,1.43)%8==SPRITE.phase_at(1.43),"Pose changes never restart propeller time")
	# Actual game input feeds art without modifying the protected flight path.
	game.start_game()
	game.transition=0
	game.spawn_timer=99
	var control := FLIGHT.new()
	for frame in range(90):
		var movement := Vector2(0.4,-0.25) if frame<45 else Vector2.ZERO
		control.advance(1.0/60,movement)
		game.step(1.0/60,movement,false)
		assert(game.flight.position.is_equal_approx(control.position) and is_equal_approx(game.flight.bank,control.bank),"Visual animation cannot alter flight")
		assert(game.flight.gun_muzzles_screen()==control.gun_muzzles_screen(),"Original gun anchors stay unchanged")
	assert(game.player_pose.value()==Vector2.ZERO or game.player_pose.value().length()<0.001)
	game.player_pose.advance(1,2,Vector2.ONE,1)
	game.switch_mode(game.Mode.TOP)
	assert(game.player_pose.value()==Vector2.ZERO,"Quick view switches reset incompatible visual axes")
	game.start_game()
	print("PLAYER POSE PASS: 792 cells, live prop phases, intermediate/reversal/diagonal poses, reset, unchanged flight and gun anchors")
