extends SceneTree
## Pack native Blender renders. Run with Godot --headless --script this file.
## Geometry is already rasterized at final pixel size: no image resizing.

const INPUT := "res://work/player-sprite-bake/"
const OUTPUT := "res://assets/aircraft/player/"
const COLUMNS := 16
const PADDING := 2
const BODY_COLORS := ["293446","5b6878","969c9b","c0c1b4","e6dec5","fff1d6",
	"202c42","44556d","6e8091","9ba7ae","c5cbd0","e3e6df",
	"081529","103b58","1a6786","279cc2","75dbef","d5faff",
	"12385b","176187","298eb1","53c8e1","a4f0f7","e7ffff",
	"0c1726","182539","2c3c50","4d5b69","70818a","9baab1",
	"684720","9b6a24","d9a83f","f5cd69","ffedaf","fff9d8"]

func _init() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT+"manifest.json"))
	var body_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT+"body-manifest.json"))
	assert(manifest.source_unchanged and manifest.geometry_unchanged)
	assert(body_manifest.source_sha256==manifest.source_sha256 and body_manifest.geometry_sha256==manifest.geometry_sha256,
		"Body coverage and propeller pass must come from the same original model")
	assert(body_manifest.views==manifest.views,"Both passes use the same camera frame sizes")
	for key in manifest.poses:
		for field in ["forward","roll_degrees","pitch_degrees","top_facing_camera_dot"]:
			assert(body_manifest.poses[key][field]==manifest.poses[key][field],"Both passes must use identical rigid poses")
	assert(manifest.poses.size()==99)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for view in ["side","top","chase"]:
		var spec: Dictionary = manifest.views[view]
		var size := Vector2i(int(spec.size[0]),int(spec.size[1]))
		var stride := size+Vector2i.ONE*PADDING*2
		var count: int = spec.pitch_steps*9*8
		var rows := ceili(float(count)/COLUMNS)
		var atlas := Image.create(COLUMNS*stride.x,rows*stride.y,false,Image.FORMAT_RGBA8)
		var different_phases := 0
		for pose in range(spec.pitch_steps*9):
			var body := Image.load_from_file(INPUT+view+"/p%d-r%d-body.png"%[pose/9,pose%9])
			assert(body!=null and body.get_size()==size,"Independent body coverage pass is required")
			var hashes := {}
			for phase in range(8):
				var path: String = INPUT+view+"/p%d-r%d-f%d.png" % [pose/9,pose%9,phase]
				var frame := Image.load_from_file(path)
				assert(frame!=null and frame.get_size()==size,path)
				frame.convert(Image.FORMAT_RGBA8)
				hashes[frame.get_data().hex_encode().sha256_text()]=true
				var result := pixel_contour(frame,body)
				var index := pose*8+phase
				var origin := Vector2i(index%COLUMNS,index/COLUMNS)*stride+Vector2i.ONE*PADDING
				atlas.blit_rect(result,Rect2i(Vector2i.ZERO,size),origin)
			assert(hashes.size()>=2,"Every pose needs real propeller alternation")
			different_phases+=hashes.size()
		assert(atlas.save_png(OUTPUT+view+".png")==OK)
		print("ATLAS PASS: ",view," ",count," frames; ",different_phases," unique phases; ",atlas.get_size())
	# Keep provenance with the distributed assets, not a runtime dependency on
	# work/, Blender, the reference image or a local absolute path.
	manifest["atlas_columns"]=COLUMNS
	manifest["padding"]=PADDING
	manifest["outline"]="36-color opaque body from independent coverage pass; outside-only 1px contour; transparent prop FX retained"
	var output := FileAccess.open(OUTPUT+"provenance.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest,"\t"))
	print("PLAYER ATLAS PASS: 99 poses, 792 frames, 3 sheets")
	quit()

func pixel_contour(frame: Image, body: Image) -> Image:
	var result := frame.duplicate() as Image
	var mask := Image.create(frame.get_width(),frame.get_height(),false,Image.FORMAT_RGBA8)
	for y in range(frame.get_height()):
		for x in range(frame.get_width()):
			var metal := body.get_pixel(x,y)
			if metal.a>=0.4:
				var chosen := Color(BODY_COLORS[0])
				var closest := INF
				for hex in BODY_COLORS:
					var color := Color(hex)
					var distance := Vector3(metal.r-color.r,metal.g-color.g,metal.b-color.b).length_squared()
					if distance<closest:
						closest=distance
						chosen=color
				mask.set_pixel(x,y,chosen)
				result.set_pixel(x,y,chosen)
			elif metal.a>0:
				# Strip only anti-aliased body coverage, retaining independently
				# visible exposure behind it. No white flashes on the opaque metal.
				var combined := frame.get_pixel(x,y)
				combined.a=maxf(0,(combined.a-metal.a)/(1-metal.a))
				result.set_pixel(x,y,combined)
	for y in range(frame.get_height()):
		for x in range(frame.get_width()):
			if mask.get_pixel(x,y).a>0.5: continue
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var point: Vector2i = Vector2i(x,y)+offset
				if point.x<0 or point.y<0 or point.x>=frame.get_width() or point.y>=frame.get_height(): continue
				# Only body mask creates ink, never the white exposure rings.
				if mask.get_pixelv(point).a>0.5:
					result.set_pixel(x,y,Color("233447"))
					break
	return result
