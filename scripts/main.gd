extends Node2D
## Two screen-space modes and one actual x/y/depth simulation, all drawn in 2D.

enum Mode { SIDE, TOP, CHASE }
const CHASE_FLIGHT := preload("res://scripts/chase_flight.gd")
const SIZE := Vector2(960, 540)
const INK := Color("091526")
const TEAL := Color("69e6d2")
const AMBER := Color("ffba68")
const RED := Color("ff6872")
const WHITE := Color("edf7eb")
const MUTED := Color("93afb6")
const MODE_NAMES := ["01 / CORE RUN", "02 / OCEAN STRIKE", "03 / SKY INTERCEPT"]
const MODE_NOTES := ["SIDE  /  terrain + trailing wingmen", "TOP  /  formations + deck guns", "CHASE  /  turn + altitude / sea crash"]

var flight = CHASE_FLIGHT.new()
var failure_reason := ""
var crash_elapsed := 0.0
var demonstration := false

var mode := Mode.CHASE
var player := Vector2(0.5, 0.64)
var energy := 100.0
var score := 0
var kills := 0
var power := 1
var wave := 0
var elapsed := 0.0
var visual_time := 0.0
var bank := 0.0
var fire_timer := 0.0
var special_timer := 0.0
var spawn_timer := 0.0
var invulnerable := 0.0
var transition := 0.0
var flash := 0.0
var title := true
var paused := false
var game_over := false
var muted := false
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var hostile: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var trail: Array[Vector2] = []
var font: Font
var rng := RandomNumberGenerator.new()
var sound: AudioStreamPlayer

func _ready() -> void:
	font = ThemeDB.fallback_font
	rng.seed = 1943
	sound = AudioStreamPlayer.new()
	sound.volume_db = -10
	add_child(sound)
	_reset_trail()
	if "--smoke" in OS.get_cmdline_user_args():
		call_deferred("_smoke_test")
	elif "--capture" in OS.get_cmdline_user_args():
		call_deferred("_capture_views")
	elif "--capture-flight" in OS.get_cmdline_user_args():
		call_deferred("_capture_flight")
	elif "--flight-demo" in OS.get_cmdline_user_args():
		muted = true
		demonstration = true
		start_game()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if title or game_over: start_game()
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ENTER, KEY_SPACE:
			if title or game_over: start_game()
		KEY_1, KEY_2, KEY_3:
			if not title and not game_over: switch_mode(int(event.keycode - KEY_1))
		KEY_ESCAPE, KEY_P:
			if not title and not game_over: paused = not paused
		KEY_R: start_game()
		KEY_M: muted = not muted
		KEY_X:
			if not title and not paused and not game_over: special()

func start_game() -> void:
	title = false
	paused = false
	game_over = false
	failure_reason = ""
	crash_elapsed = 0
	flight.reset()
	score = 0
	kills = 0
	power = 1
	energy = 100.0
	elapsed = 0.0
	visual_time = 0.0
	bank = 0.0
	wave = 0
	special_timer = 0.0
	mode = Mode.CHASE
	player = Vector2(0.5, 0.64)
	_clear_combat()
	spawn_timer = 0.4
	transition = 0.8
	invulnerable = 2.0

func switch_mode(next_mode: int) -> void:
	if next_mode == mode: return
	mode = next_mode
	# Preserve campaign state, discard threats with incompatible spatial rules.
	_clear_combat()
	player = Vector2(0.24, 0.48) if mode == Mode.SIDE else Vector2(0.5, 0.72)
	if mode == Mode.CHASE: flight.reset()
	_reset_trail()
	transition = 0.8
	invulnerable = 1.6
	spawn_timer = 0.9
	_beep(220.0, 0.16)

func _clear_combat() -> void:
	enemies.clear()
	shots.clear()
	hostile.clear()
	particles.clear()
	pickups.clear()
	fire_timer = 0.0
	_reset_trail()

func _reset_trail() -> void:
	trail.clear()
	for i in range(48): trail.append(player * SIZE)

func _process(delta: float) -> void:
	if title: visual_time += delta
	if game_over and flight.crashed:
		crash_elapsed += delta
	if not title and not paused and not game_over:
		if demonstration:
			var movement := Vector2.ZERO
			if elapsed >= 1.0 and elapsed < 2.5: movement = Vector2.RIGHT
			elif elapsed >= 2.5 and elapsed < 4.8: movement = Vector2.UP
			elif elapsed >= 5.8: movement = Vector2.DOWN
			step(minf(delta, 0.04), movement, true)
		else:
			step(minf(delta, 0.04), _movement(), Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_Z))
	queue_redraw()

func _movement() -> Vector2:
	var x := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var y := float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	return Vector2(x, y).limit_length(1.0)

func step(delta: float, movement: Vector2, shooting: bool) -> void:
	elapsed += delta
	visual_time += delta
	bank = lerpf(bank, movement.x * 0.3, 1.0 - exp(-delta * 8))
	transition = maxf(0, transition - delta)
	invulnerable = maxf(0, invulnerable - delta)
	flash = maxf(0, flash - delta)
	fire_timer -= delta
	special_timer = maxf(0, special_timer - delta)
	if mode == Mode.CHASE:
		flight.advance(delta, movement)
		bank = flight.bank
		if flight.crashed:
			# Sea contact is fatal even during a transition or damage protection.
			energy = 0
			game_over = true
			failure_reason = "SEA IMPACT / TOO LOW"
			_beep(55, 0.3)
			return
	else:
		player += movement * Vector2(0.47, 0.67) * delta
		player.x = clampf(player.x, 0.06, 0.94)
		player.y = clampf(player.y, 0.14, 0.88)
	trail.push_front(player * SIZE)
	if trail.size() > 48: trail.pop_back()
	energy = maxf(0, energy - delta * 0.18)
	if energy <= 0:
		game_over = true
		return
	if transition <= 0:
		if shooting and fire_timer <= 0: fire()
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_wave()
			spawn_timer = 3.3
	_update_enemies(delta)
	_update_shots(delta)
	_update_hostile(delta)
	_update_pickups(delta)
	for i in range(particles.size() - 1, -1, -1):
		particles[i].p += particles[i].v * delta
		particles[i].life -= delta
		if particles[i].life <= 0: particles.remove_at(i)
	if mode == Mode.SIDE:
		var p := player * SIZE
		if p.y < _ceiling(p.x) + 13 or p.y > _floor(p.x) - 13: damage(14)

func _player_world() -> Vector3:
	return flight.position

func fire() -> void:
	fire_timer = 0.16
	_beep(980.0, 0.018)
	if mode == Mode.CHASE:
		var p := _player_world() + flight.forward() * 1.5
		shots.append({"p": p, "v": flight.forward() * 78, "surface": false, "life": 3.2})
		if power > 1:
			for offset in [-1.2, 1.2]:
				shots.append({"p": p + flight.right() * offset, "v": flight.forward() * 78, "surface": false, "life": 3.2})
	else:
		var p := player * SIZE
		var velocity := Vector2(650, 0) if mode == Mode.SIDE else Vector2(0, -620)
		shots.append({"p": p, "v": velocity, "surface": false})
		if power > 1:
			for wingman in _wingmen(): shots.append({"p": wingman, "v": velocity, "surface": false})

func special() -> void:
	if special_timer > 0 or energy <= 18 or transition > 0: return
	energy -= 15
	special_timer = 1.5
	_beep(90, 0.24)
	if mode == Mode.CHASE:
		var p := _player_world() + flight.forward() * 8
		p.y = 0.22
		shots.append({"p": p, "v": flight.forward() * 58, "surface": true, "life": 4.0})
	else:
		flash = 0.32
		hostile.clear()
		for i in range(enemies.size() - 1, -1, -1):
			enemies[i].hp -= 4
			if enemies[i].hp <= 0: _destroy_enemy(i)

func spawn_wave() -> void:
	wave += 1
	var count := 3 + mini(int(wave / 5.0), 2)
	for i in range(count):
		var p: Variant
		if mode == Mode.SIDE:
			p = Vector2(990 + i * 64, 260 + sin(float(wave) * 1.8) * 84)
		elif mode == Mode.TOP:
			p = Vector2(170 + fmod(float(wave) * 121, 570) + (i - 1) * 60, -40 - i * 52)
		else:
			p = flight.position + flight.forward() * (150 + i * 18) + flight.right() * (sin(float(wave) * 1.2) * 22 + (i - 1) * 9)
			p.y = clampf(flight.position.y + 0.3 + sin(float(wave)) * 1.2, 1.5, 6.0)
		enemies.append({"p": p, "base": p, "v": -flight.forward() * 8, "hp": 3, "age": 0.0, "fire": 1.5 + i * 0.28, "surface": false})
	if wave % 3 == 0 and mode != Mode.SIDE:
		var p: Variant = Vector2(360 + sin(float(wave)) * 180, -130)
		if mode == Mode.CHASE:
			p = flight.position + flight.forward() * 190 + flight.right() * sin(float(wave)) * 25
			p.y = 0.22
		enemies.append({"p": p, "base": p, "v": Vector3.ZERO, "hp": 7, "age": 0.0, "fire": 1.8, "surface": true})

func _update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		e.age += delta
		e.fire -= delta
		if mode == Mode.SIDE:
			e.p.x -= delta * 145
			e.p.y = e.base.y + sin(e.age * 2.4) * 42
		elif mode == Mode.TOP:
			e.p.y += delta * (42 if e.surface else 105)
			e.p.x = e.base.x + sin(e.age * 1.9) * (0 if e.surface else 48)
		else:
			e.p += e.v * delta
			if not e.surface: e.p.y = e.base.y + sin(e.age * 1.4) * 0.35
		if e.fire <= 0:
			e.fire = 2.5
			if mode == Mode.CHASE:
				if flight.visible(e.p) and e.p.distance_to(flight.position) < 140:
					hostile.append({"p": e.p, "v": (_player_world() - e.p).normalized() * 30.0, "life": 9.0})
			else:
				var p: Vector2 = e.p
				hostile.append({"p": p, "v": (player * SIZE - p).normalized() * 155})
		var offscreen: bool = e.age > 18 or e.p.distance_to(flight.position) > 420 if mode == Mode.CHASE else (e.p.x < -70 if mode == Mode.SIDE else e.p.y > 580)
		if not e.surface:
			if mode == Mode.CHASE:
				var pp := _player_world()
				if Vector2(e.p.x - pp.x, e.p.z - pp.z).length() < 2 and absf(e.p.y - pp.y) < 0.8: damage(18)
			elif e.p.distance_to(player * SIZE) < 25: damage(18)
		if offscreen: enemies.remove_at(i)

func _update_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var s := shots[i]
		var old: Variant = s.p
		s.p += s.v * delta
		var consumed := false
		for j in range(enemies.size() - 1, -1, -1):
			var e := enemies[j]
			var hit := false
			if mode == Mode.CHASE:
				var closest := _closest_segment3d(e.p, old, s.p)
				var offset: Vector3 = closest - e.p
				hit = s.surface == e.surface and Vector2(offset.x, offset.z).length() < (4.2 if e.surface else 1.7) and absf(offset.y) < 0.85
			else:
				# Segment tests prevent tunnelling on slow frames.
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(e.p, old, s.p)
				hit = closest.distance_to(e.p) < (32 if e.surface else 20)
			if hit:
				e.hp -= 7 if s.surface else 1
				if e.hp <= 0: _destroy_enemy(j)
				else: _burst(_entity_screen(e.p), TEAL, 3)
				consumed = true
				break
		var expired: bool
		if mode == Mode.CHASE:
			s.life = s.get("life", 3.2) - delta
			expired = s.life <= 0
		else: expired = not Rect2(-40, -40, 1040, 620).has_point(s.p)
		if consumed or expired: shots.remove_at(i)

func _update_hostile(delta: float) -> void:
	for i in range(hostile.size() - 1, -1, -1):
		var b := hostile[i]
		var old: Variant = b.p
		b.p += b.v * delta
		var hit := false
		var expired := false
		if mode == Mode.CHASE:
			var p := _player_world()
			var closest := _closest_segment3d(p, old, b.p)
			var offset := closest - p
			hit = Vector2(offset.x, offset.z).length() < 1.15 and absf(offset.y) < 0.6
			b.life = b.get("life", 9.0) - delta
			expired = b.life <= 0 or b.p.distance_to(p) > 400
		else:
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(player * SIZE, old, b.p)
			hit = closest.distance_to(player * SIZE) < 10
			expired = not Rect2(-40, -40, 1040, 620).has_point(b.p)
		if hit: damage(12)
		if hit or expired: hostile.remove_at(i)

func _destroy_enemy(index: int) -> void:
	var e := enemies[index]
	var points := 200
	if mode == Mode.CHASE:
		var distance: float = e.p.distance_to(flight.position)
		points = 300 if distance < 60 else (200 if distance < 110 else 150)
	score += points * (2 if e.surface else 1)
	kills += 1
	_burst(_entity_screen(e.p), AMBER, 18)
	_beep(150, 0.09)
	if kills % 4 == 0: pickups.append({"p": e.p, "life": 14.0})
	enemies.remove_at(index)

func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var item := pickups[i]
		var hit := false
		var expired := false
		if mode == Mode.CHASE:
			var p := _player_world()
			var offset: Vector3 = item.p - p
			hit = Vector2(offset.x, offset.z).length() < 4.5 and absf(offset.y) < 1.3
			item.life = item.get("life", 14.0) - delta
			expired = item.life <= 0
		else:
			item.p += (Vector2(-90, 0) if mode == Mode.SIDE else Vector2(0, 100)) * delta
			hit = item.p.distance_to(player * SIZE) < 34
			expired = not Rect2(-50, -50, 1060, 640).has_point(item.p)
		if hit:
			power = 2
			energy = minf(100, energy + 18)
			score += 100
			_beep(1400, 0.15)
		if hit or expired: pickups.remove_at(i)

func damage(amount: float) -> void:
	if invulnerable > 0 or transition > 0: return
	energy = maxf(0, energy - amount)
	invulnerable = 1.2
	flash = 0.13
	_burst(_ship_screen(), RED, 12)
	_beep(65, 0.18)
	if energy <= 0: game_over = true

func _burst(p: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		particles.append({"p": p, "v": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(35, 180), "life": rng.randf_range(0.18, 0.65), "color": color})

func _wingmen() -> Array[Vector2]:
	if mode == Mode.SIDE: return [trail[14] - Vector2(30, 0), trail[30] - Vector2(60, 0)]
	return [player * SIZE + Vector2(-34, 12), player * SIZE + Vector2(34, 12)]

func _project(p: Vector3) -> Vector2:
	return flight.project(p)

func _closest_segment3d(point: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var segment := b - a
	if segment.length_squared() < 0.000001: return a
	return a + segment * clampf((point - a).dot(segment) / segment.length_squared(), 0, 1)

func _entity_screen(p: Variant) -> Vector2:
	return _project(p) if mode == Mode.CHASE else p

func _ship_screen() -> Vector2:
	return flight.aircraft_screen() if mode == Mode.CHASE else player * SIZE

func _ceiling(x: float) -> float:
	return 104 + 22 * sin(x * 0.006 + visual_time * 0.65) + 11 * sin(x * 0.018 + visual_time)

func _floor(x: float) -> float:
	return 452 + 25 * sin(x * 0.008 + visual_time * 0.8)

func _beep(frequency: float, duration: float) -> void:
	if muted or paused: return
	var samples := int(duration * 22050)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var envelope := 1.0 - float(i) / samples
		var value := (1 if sin(float(i) / 22050 * TAU * frequency) > 0 else -1) * int(4200 * envelope)
		data.encode_s16(i * 2, value)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	audio.data = data
	sound.stream = audio
	sound.play()

func _exit_tree() -> void:
	sound.stop()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), INK)
	match mode:
		Mode.SIDE: _draw_core()
		Mode.TOP: _draw_ocean()
		Mode.CHASE: _draw_horizon()
	if title:
		_draw_title()
		return
	var sorted_enemies := enemies.duplicate()
	if mode == Mode.CHASE:
		sorted_enemies.sort_custom(func(a, b): return flight.depth(a.p) > flight.depth(b.p))
	for e in sorted_enemies:
		if mode == Mode.CHASE and not flight.visible(e.p): continue
		var pos := _entity_screen(e.p)
		var factor: float = clampf(22.0 / maxf(flight.depth(e.p), 1.0), 0.12, 2.8) if mode == Mode.CHASE else 1.0
		if e.surface: _draw_boat(pos, factor)
		else: _draw_plane(pos, factor, RED, mode, false)
	for item in pickups:
		if mode == Mode.CHASE and not flight.visible(item.p): continue
		var p := _entity_screen(item.p)
		draw_circle(p, 13 + 2 * sin(visual_time * 6), Color(TEAL, 0.15))
		draw_rect(Rect2(p - Vector2(8, 8), Vector2(16, 16)), TEAL, false, 2)
		_text("+", p + Vector2(-5, 5), 16, WHITE)
	for s in shots:
		if mode == Mode.CHASE and not flight.visible(s.p): continue
		var pos := _entity_screen(s.p)
		var color: Color = AMBER if s.surface else TEAL
		var end := pos + (Vector2(-15, 0) if mode == Mode.SIDE else Vector2(0, 12))
		if mode == Mode.CHASE: end = _project(s.p - s.v.normalized() * 3)
		draw_line(pos, end, Color(color, 0.15), 8)
		draw_line(pos, end, color, 3)
	for b in hostile:
		if mode == Mode.CHASE and not flight.visible(b.p): continue
		var p := _entity_screen(b.p)
		draw_circle(p, 7, Color(RED, 0.2))
		draw_circle(p, 4, RED)
		draw_circle(p, 1.6, WHITE)
	for effect in particles:
		draw_rect(Rect2(effect.p, Vector2(3, 3)), Color(effect.color, clampf(effect.life * 2, 0, 1)))
	if power > 1 and mode != Mode.CHASE:
		for wingman in _wingmen():
			draw_circle(wingman, 6, TEAL)
			draw_circle(wingman, 3, WHITE)
	var p := _ship_screen()
	if mode == Mode.CHASE and flight.crashed:
		var splash := Vector2(p.x, 487)
		for i in range(3):
			draw_arc(splash, 12 + i * 14 + minf(crash_elapsed, 0.7) * 32, PI, TAU, 20, Color(TEAL, 0.65), 2)
		if crash_elapsed < 0.5:
			_draw_plane(p + Vector2(0, crash_elapsed * 110), 1.35, RED, mode, true)
	else:
		if invulnerable <= 0 or int(visual_time * 12) % 2 == 0:
			_draw_plane(p, 1.35 if mode == Mode.CHASE else 1.0, TEAL, mode, true)
			draw_circle(p, 3, WHITE)
	if mode == Mode.CHASE:
		var aim := _player_world() + flight.forward() * 45
		var reticle := _project(aim)
		draw_arc(reticle, 12, 0, TAU, 24, Color(TEAL, 0.6), 1)
		draw_line(reticle + Vector2(-19, 0), reticle + Vector2(-8, 0), TEAL)
		draw_line(reticle + Vector2(8, 0), reticle + Vector2(19, 0), TEAL)
		_text("AIR", reticle + Vector2(-11, -19), 10, TEAL)
		var sea_aim := _player_world() + flight.forward() * 70
		sea_aim.y = 0.22
		var sea_pos := _project(sea_aim)
		draw_line(sea_pos + Vector2(-8, 0), sea_pos + Vector2(8, 0), AMBER, 2)
		_text("X / SEA", sea_pos + Vector2(-18, 15), 10, AMBER)
		_draw_altimeter()
	_draw_hud()
	if flash > 0: draw_rect(Rect2(Vector2.ZERO, SIZE), Color(AMBER, flash * 0.65))
	if transition > 0:
		draw_rect(Rect2(0, 210, 960, 82), Color(INK, 0.94))
		_center(MODE_NAMES[mode], 244, 26, TEAL)
		_center("REORIENTING  /  SHARED ENERGY & SCORE", 272, 12, MUTED)
	if paused or (game_over and (not flight.crashed or crash_elapsed >= 0.6)):
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.8))
		_center("FLIGHT ENDED" if game_over else "PAUSED", 246, 38, AMBER)
		_center("SCORE %06d   /   R TO RESTART" % score if game_over else "ESC / P TO RESUME", 286, 16, WHITE)
		if game_over and not failure_reason.is_empty(): _center(failure_reason, 320, 16, RED)

func _draw_horizon() -> void:
	var h: float = flight.horizon()
	for row in range(0, 540, 4):
		var t := clampf(float(row) / maxf(h, 1), 0, 1)
		draw_rect(Rect2(0, row, 960, 4), Color("111d38").lerp(Color("99555b"), t))
	# Persistent bearings: turn right and the same sun/clouds sweep left.
	var sun_x: float = flight.bearing_screen(0.52)
	draw_circle(Vector2(sun_x, h - 48), 37, AMBER)
	for stripe in range(5): draw_rect(Rect2(sun_x - 42, h - 44 + stripe * 8, 84, 3 + stripe), Color("704453"))
	for i in range(15):
		var x: float = flight.bearing_screen(float(i) * TAU / 15)
		var y: float = h - 80 - (i % 4) * 34
		draw_rect(Rect2(x - 46, y, 105 + i % 3 * 16, 5), Color("cc8d7c"))
		draw_rect(Rect2(x - 20, y - 6, 45, 6), Color("bb827c"))
	var sea_start := clampf(h, 0, 540)
	if sea_start < 540:
		draw_rect(Rect2(0, sea_start, 960, 540 - sea_start), Color("12384b"))
		_draw_wave_layer(12, 18, sea_start)
		_draw_wave_layer(4, 12, sea_start)
		if h >= 0: draw_line(Vector2(0, h), Vector2(960, h), Color("f4a374"), 2)

func _draw_wave_layer(spacing: float, radius: int, sea_start: float) -> void:
	# World-space marks: denser near the aircraft so low flight still has texture.
	var tile_x := int(floor(flight.position.x / spacing))
	var tile_z := int(floor(flight.position.z / spacing))
	for x in range(tile_x - radius, tile_x + radius + 1):
		for z in range(tile_z - radius, tile_z + radius + 1):
			var point := Vector3(x * spacing + sin(float(z) * 1.7) * spacing * 0.2, 0, z * spacing)
			var depth: float = flight.depth(point)
			if depth < 6: continue
			var p: Vector2 = flight.project(point)
			if p.y < sea_start or not Rect2(-20, 65, 1000, 440).has_point(p): continue
			var length := clampf(spacing * 10 / depth, 1.5, 15)
			draw_line(p - Vector2(length, 0), p + Vector2(length, 0), Color("387287"), 1.5)

func _draw_altimeter() -> void:
	var low: bool = flight.position.y < CHASE_FLIGHT.LOW_ALTITUDE
	var color := RED if low else TEAL
	_text("ALT", Vector2(890, 290), 11, MUTED)
	draw_rect(Rect2(905, 307, 12, 136), Color(INK, 0.8))
	draw_rect(Rect2(905, 443 - flight.position.y / CHASE_FLIGHT.MAX_ALTITUDE * 136, 12, flight.position.y / CHASE_FLIGHT.MAX_ALTITUDE * 136), color)
	draw_rect(Rect2(905, 420, 12, 23), Color(RED, 0.3))
	_text("%03d" % int(flight.position.y * 100), Vector2(891, 466), 13, color)
	_text("HDG %03d" % int(rad_to_deg(flight.heading)), Vector2(24, 90), 13, MUTED)
	if low and not game_over:
		_center("LOW ALTITUDE / PULL UP", 478, 19, RED if int(visual_time * 5) % 2 == 0 else AMBER)

func _draw_ocean() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("123b51"))
	for i in range(85):
		var x := fmod(float(i * 137), 960)
		var y := fmod(float(i * 83) + visual_time * 64, 540)
		draw_line(Vector2(x, y), Vector2(x + 13 + i % 4 * 8, y), Color("21556a"), 2)
	var y := fmod(visual_time * 22, 950) - 300
	draw_colored_polygon(PackedVector2Array([Vector2(696,y),Vector2(727,y+30),Vector2(741,y+245),Vector2(712,y+302),Vector2(681,y+245),Vector2(681,y+35)]), Color("25485a"))
	draw_rect(Rect2(702,y+40,17,208), Color("416072"))
	for n in range(6): draw_rect(Rect2(709,y+47+n*31,3,13), Color("66838c"))
	for i in range(4):
		var p := Vector2(fmod(float(i) * 329 + visual_time * 6, 1170) - 100, fmod(float(i) * 179 + visual_time * 38, 760) - 110)
		draw_rect(Rect2(p, Vector2(150, 10)), Color("62848b"))
		draw_rect(Rect2(p + Vector2(28, -7), Vector2(100, 24)), Color("7c9a9b"))

func _draw_core() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("172335"))
	for i in range(40):
		var x := fmod(float(i) * 163 - visual_time * 47, 1020)
		if x < 0: x += 1020
		draw_circle(Vector2(x, 130 + fmod(float(i) * 67, 280)), 1.5, Color("335367"))
	var ceiling_poly := PackedVector2Array([Vector2(0, 0), Vector2(960, 0)])
	var floor_poly := PackedVector2Array([Vector2(0, 540), Vector2(960, 540)])
	for x in range(960, -1, -12):
		ceiling_poly.append(Vector2(x, _ceiling(x)))
		floor_poly.append(Vector2(x, _floor(x)))
	draw_colored_polygon(ceiling_poly, Color("503f55"))
	draw_colored_polygon(floor_poly, Color("503f55"))
	for x in range(0, 960, 12):
		draw_line(Vector2(x, _ceiling(x)), Vector2(x + 12, _ceiling(x + 12)), RED, 3)
		draw_line(Vector2(x, _floor(x)), Vector2(x + 12, _floor(x + 12)), AMBER, 3)
	for i in range(18):
		var x := fposmod(float(i * 77) - visual_time * 135, 1080) - 60
		draw_rect(Rect2(x, _ceiling(x) - 28, 20, 18), Color("96626b"))
		draw_rect(Rect2(x + 35, _floor(x) + 10, 30, 10), Color("98695d"))

func _draw_plane(pos: Vector2, s: float, accent: Color, perspective: int, friendly: bool) -> void:
	var angle := PI / 2 if perspective == Mode.SIDE else 0.0
	if not friendly and perspective == Mode.TOP: angle = PI
	if not friendly and perspective == Mode.SIDE: angle = -PI / 2
	if perspective == Mode.CHASE and friendly: angle = bank
	draw_set_transform(pos, angle, Vector2.ONE * s)
	if perspective == Mode.CHASE:
		# A rear/front silhouette, rather than rotating the top-down sprite.
		draw_colored_polygon(PackedVector2Array([Vector2(-36,3),Vector2(-9,-2),Vector2(-4,-8),Vector2(4,-8),Vector2(9,-2),Vector2(36,3),Vector2(33,8),Vector2(7,5),Vector2(0,11),Vector2(-7,5),Vector2(-33,8)]), WHITE if friendly else Color("d2c8b9"))
		draw_rect(Rect2(-28,5,56,3), accent)
		draw_rect(Rect2(-4,-21,8,23), accent)
		draw_rect(Rect2(-22,-3,7,15), accent)
		draw_rect(Rect2(15,-3,7,15), accent)
		if friendly:
			for x in [-18.5,18.5]:
				draw_circle(Vector2(x,11), 3, AMBER)
				draw_circle(Vector2(x,11), 1.5, WHITE)
		draw_set_transform(Vector2.ZERO)
		return
	# Original twin-boom silhouette, generated from geometry.
	draw_colored_polygon(PackedVector2Array([Vector2(0,-24),Vector2(5,-7),Vector2(25,1),Vector2(27,7),Vector2(7,6),Vector2(4,18),Vector2(-4,18),Vector2(-7,6),Vector2(-27,7),Vector2(-25,1),Vector2(-5,-7)]), WHITE if friendly else Color("d2c8b9"))
	draw_rect(Rect2(-19, -7, 5, 24), accent)
	draw_rect(Rect2(14, -7, 5, 24), accent)
	draw_rect(Rect2(-3, -9, 6, 12), accent)
	draw_rect(Rect2(-2, -5, 4, 6), INK)
	draw_rect(Rect2(-22, 12, 44, 4), accent)
	if friendly:
		var flame := 5 + 5 * sin(visual_time * 45)
		draw_rect(Rect2(-18, 18, 3, flame), AMBER)
		draw_rect(Rect2(15, 18, 3, flame), AMBER)
	draw_set_transform(Vector2.ZERO)

func _draw_boat(pos: Vector2, s: float) -> void:
	draw_set_transform(pos, 0, Vector2.ONE * s)
	if mode == Mode.CHASE:
		draw_colored_polygon(PackedVector2Array([Vector2(-34,2),Vector2(34,2),Vector2(25,15),Vector2(-25,15)]), Color("9d9d94"))
		draw_rect(Rect2(-14,-8,28,12), Color("485c68"))
		draw_rect(Rect2(-4,-19,8,14), RED)
		draw_line(Vector2(0,-19), Vector2(0,-27), AMBER, 2)
		draw_set_transform(Vector2.ZERO)
		return
	draw_colored_polygon(PackedVector2Array([Vector2(0,-44),Vector2(20,-22),Vector2(20,35),Vector2(0,44),Vector2(-20,35),Vector2(-20,-22)]), Color("9d9d94"))
	draw_rect(Rect2(-11, -18, 22, 44), Color("485c68"))
	for y in [-26, 25]:
		draw_circle(Vector2(0, y), 8, RED)
		draw_line(Vector2(0, y), Vector2(0, y - 15), AMBER, 3)
	draw_set_transform(Vector2.ZERO)

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 960, 66), Color(INK, 0.93))
	draw_line(Vector2(24, 66), Vector2(936, 66), Color("335362"))
	_text("SKYFIRE", Vector2(24, 28), 18, WHITE)
	_text("1943", Vector2(112, 28), 18, AMBER)
	_text(MODE_NAMES[mode], Vector2(250, 28), 16, TEAL)
	_text(MODE_NOTES[mode], Vector2(250, 49), 11, MUTED)
	_text("SCORE  %06d" % score, Vector2(755, 27), 16, WHITE)
	_text("WAVE %02d   /   PWR %d" % [wave, power], Vector2(755, 49), 11, MUTED)
	_text("ENERGY", Vector2(24, 49), 10, MUTED)
	draw_rect(Rect2(76, 41, 138, 8), Color("233e50"))
	draw_rect(Rect2(76, 41, 138 * energy / 100, 8), TEAL if energy > 30 else RED)
	draw_rect(Rect2(0, 506, 960, 34), Color(INK, 0.93))
	_text("ARROWS  TURN / ALT     SPACE / Z  FIRE" if mode == Mode.CHASE else "WASD / ARROWS  MOVE     SPACE / Z  FIRE", Vector2(24, 528), 11, MUTED)
	_text("X  TORPEDO" if mode == Mode.CHASE else "X  CLEAR (-15 ENERGY)", Vector2(355, 528), 11, AMBER)
	_text("1 SIDE   2 TOP   3 CHASE     P PAUSE   R RETRY", Vector2(565, 528), 11, MUTED)

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.4))
	_text("FLIGHT LAB  /  0.2", Vector2(48, 54), 12, TEAL)
	_text("FC-INSPIRED  /  ORIGINAL PROTOTYPE", Vector2(622, 54), 12, MUTED)
	_text("SKYFIRE", Vector2(48, 173), 76, WHITE)
	_text("1943", Vector2(382, 173), 76, AMBER)
	_text("ONE AIRCRAFT. THREE FRONTLINES.", Vector2(52, 205), 17, TEAL)
	_draw_plane(Vector2(778, 238), 2.9, TEAL, Mode.CHASE, true)
	for i in range(3):
		var x := 48 + i * 294
		draw_rect(Rect2(x, 292, 276, 104), Color(INK, 0.9))
		draw_line(Vector2(x, 292), Vector2(x + 276, 292), AMBER if i == 2 else TEAL, 2)
		_text(["01  SIDE", "02  TOP", "03  CHASE"][i], Vector2(x + 17, 323), 20, WHITE)
		_text(["Thread the living core.", "Break the ocean formation.", "Fight across depth."][i], Vector2(x + 17, 351), 13, MUTED)
		_text(["SALAMANDER", "1943", "SKY DESTROYER"][i], Vector2(x + 17, 377), 10, TEAL)
	draw_rect(Rect2(48, 423, 274, 49), AMBER)
	_text("ENTER / CLICK TO LAUNCH", Vector2(66, 454), 17, INK)
	_text("WASD move  /  SPACE fire  /  1 2 3 switch", Vector2(354, 447), 14, WHITE)
	_text("X special  /  P pause  /  M mute", Vector2(354, 469), 12, MUTED)
	_text("A SMALL PLAYABLE STUDY, NOT A REMAKE.", Vector2(48, 515), 11, MUTED)

func _text(value: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center(value: String, y: float, font_size: int, color: Color) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(value, Vector2((960 - width) / 2, y), font_size, color)

func _smoke_test() -> void:
	set_process(false)
	# The accelerated headless simulation does not advance the audio clock.
	muted = true
	start_game()
	for next_mode in [Mode.CHASE, Mode.TOP, Mode.SIDE]:
		switch_mode(next_mode)
		for frame in range(1200):
			step(1.0 / 60, Vector2(sin(frame * 0.03), cos(frame * 0.021)) * 0.4, true)
			if frame % 240 == 100: special()
			if game_over:
				energy = 100
				game_over = false
		assert(enemies.size() < 40, "Enemy cleanup")
		assert(shots.size() < 100, "Projectile cleanup")
		assert(energy >= 0 and energy <= 100, "Energy range")
		print("SMOKE mode=", next_mode, " score=", score, " enemies=", enemies.size(), " shots=", shots.size())
	mode = Mode.CHASE
	_clear_combat()
	var p := _player_world()
	enemies.append({"p": p + Vector3(0, 0, 10), "hp": 1, "surface": false})
	shots.append({"p": p + Vector3(0, 0, 1), "v": Vector3(0, 0, 20), "surface": false})
	_update_shots(0.01)
	assert(enemies.size() == 1, "No false hit across depth")
	_update_shots(0.5)
	assert(enemies.is_empty(), "Depth hit")
	var saved_energy := energy
	var saved_score := score
	power = 2
	switch_mode(Mode.TOP)
	assert(energy == saved_energy and score == saved_score and power == 2, "Shared state survives switching")
	assert(enemies.is_empty() and hostile.is_empty() and shots.is_empty(), "Safe transition seam")
	# Air fire cannot damage a surface target; torpedoes can.
	mode = Mode.CHASE
	_clear_combat()
	enemies.append({"p": Vector3(0, 0.3, 10), "hp": 7, "surface": true})
	shots.append({"p": Vector3(0, 0.3, 4), "v": Vector3(0, 0, 20), "surface": false})
	_update_shots(0.4)
	assert(enemies[0].hp == 7, "Air/surface separation")
	shots.clear()
	shots.append({"p": Vector3(0, 0.3, 4), "v": Vector3(0, 0, 15), "surface": true})
	_update_shots(0.5)
	assert(enemies.is_empty(), "Torpedo destroys boat")
	# Ordinary 2D hits, pickups, invulnerability, restart, and input routing.
	switch_mode(Mode.TOP)
	transition = 0
	invulnerable = 0
	player = Vector2(0.5, 0.5)
	enemies.append({"p": Vector2(480, 200), "hp": 1, "surface": false})
	shots.append({"p": Vector2(480, 300), "v": Vector2(0, -620), "surface": false})
	_update_shots(0.2)
	assert(enemies.is_empty(), "2D swept hit")
	energy = 50
	pickups.append({"p": player * SIZE})
	_update_pickups(0)
	assert(energy == 68 and power == 2, "Pickup restores energy and upgrades")
	damage(12)
	damage(12)
	assert(energy == 56, "Invulnerability prevents double hit")
	invulnerable = 0
	damage(100)
	assert(game_over and energy == 0, "Game over")
	start_game()
	assert(not game_over and energy == 100 and score == 0 and power == 1, "Restart")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_1
	_unhandled_input(event)
	assert(mode == Mode.SIDE, "Keyboard mode switch")
	event.keycode = KEY_P
	_unhandled_input(event)
	assert(paused, "Keyboard pause")
	_unhandled_input(event)
	assert(not paused, "Keyboard resume")
	if _test_chase_scroll_and_crash() != true:
		get_tree().quit(1)
		return
	print("SMOKE PASS: three modes, combat, cleanup, depth collision, shared state")
	sound.stop()
	sound.stream = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _test_chase_scroll_and_crash():
	var test_flight = CHASE_FLIGHT.new()
	var landmark := Vector3(12, 3.3, -100)
	var before: Vector2 = test_flight.project(landmark)
	for i in range(45): test_flight.advance(1.0 / 60, Vector2.RIGHT)
	var after: Vector2 = test_flight.project(landmark)
	assert(after.x < before.x - 120, "Right turn scrolls stationary world left")
	assert(absf(test_flight.aircraft_screen().x - 480) < 40, "Aircraft stays near chase camera center")
	var held_heading: float = test_flight.heading
	for i in range(120): test_flight.advance(1.0 / 60, Vector2.ZERO)
	assert(absf(angle_difference(held_heading, test_flight.heading)) < 0.1, "Short neutral response, no large drift")
	assert(test_flight.heading > 0.3, "Release keeps the new heading")
	for i in range(900): test_flight.advance(1.0 / 60, Vector2.RIGHT)
	assert(test_flight.heading >= 0 and test_flight.heading < TAU, "360 degree wrap")
	assert(test_flight.turn_rate > 0.9, "No turn stop at screen edge")
	test_flight.reset()
	test_flight.heading = TAU - 0.025
	test_flight.view_heading = test_flight.heading
	before = test_flight.project(landmark)
	for i in range(12): test_flight.advance(1.0 / 60, Vector2.RIGHT)
	after = test_flight.project(landmark)
	assert(absf(after.x - before.x) < 90, "Projection continuous at heading seam")
	test_flight.reset()
	var initial_horizon: float = test_flight.horizon()
	for i in range(150): test_flight.advance(1.0 / 60, Vector2.UP)
	assert(test_flight.horizon() > initial_horizon + 300 and test_flight.horizon() >= 540, "Climb scrolls sea completely off screen")
	for i in range(120): test_flight.advance(1.0 / 60, Vector2.ZERO)
	assert(is_equal_approx(test_flight.position.y, CHASE_FLIGHT.MAX_ALTITUDE) and not test_flight.crashed, "Upper altitude limit is safe")
	test_flight.reset()
	var warned := false
	for i in range(240):
		test_flight.advance(1.0 / 60, Vector2.DOWN)
		if test_flight.position.y < CHASE_FLIGHT.LOW_ALTITUDE and not test_flight.crashed: warned = true
	assert(warned and test_flight.crashed, "Low warning precedes actual sea impact")
	start_game()
	flight.position.y = 0.2
	transition = 10
	invulnerable = 10
	step(0.04, Vector2.DOWN, false)
	assert(game_over and energy == 0 and flight.crashed, "Sea impact bypasses combat invulnerability")
	assert(failure_reason == "SEA IMPACT / TOO LOW", "Explain crash reason")
	start_game()
	assert(not flight.crashed and flight.position.y > CHASE_FLIGHT.LOW_ALTITUDE, "Restart at safe altitude")
	spawn_wave()
	var enemy_count := enemies.size()
	flight.heading = PI
	flight.view_heading = PI
	_update_enemies(0)
	assert(enemies.size() == enemy_count, "Turning away hides targets without deleting them")
	assert(not flight.visible(enemies[0].p), "World targets stay behind the new heading")
	start_game()
	print("CHASE PASS: world scroll, centered aircraft, retained heading, wrap continuity, vertical scroll, sea impact")
	return true

func _capture_views() -> void:
	set_process(false)
	muted = true
	var args := OS.get_cmdline_user_args()
	var folder := "res://work/captures"
	var flag := args.find("--capture-dir")
	if flag >= 0 and flag + 1 < args.size(): folder = args[flag + 1]
	DirAccess.make_dir_recursive_absolute(folder)
	for next_mode in [Mode.CHASE, Mode.TOP, Mode.SIDE]:
		start_game()
		switch_mode(next_mode)
		for frame in range(200): step(1.0 / 60, Vector2.ZERO, true)
		visual_time = 3.3
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder + "/mode-%d.png" % next_mode)
	title = true
	mode = Mode.CHASE
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "/title.png")
	sound.stop()
	sound.stream = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _capture_flight() -> void:
	set_process(false)
	muted = true
	var args := OS.get_cmdline_user_args()
	var folder := "res://work/flight-captures"
	var flag := args.find("--capture-dir")
	if flag >= 0 and flag + 1 < args.size(): folder = args[flag + 1]
	DirAccess.make_dir_recursive_absolute(folder)
	start_game()
	for i in range(90): step(1.0 / 60, Vector2.ZERO, true)
	await _save_flight_frame(folder, "cruise")
	for i in range(35): step(1.0 / 60, Vector2.RIGHT, true)
	await _save_flight_frame(folder, "right-turn")
	for i in range(150): step(1.0 / 60, Vector2.UP, true)
	await _save_flight_frame(folder, "high-altitude")
	start_game()
	for i in range(120): step(1.0 / 60, Vector2.DOWN, false)
	await _save_flight_frame(folder, "low-altitude")
	for i in range(20):
		if not game_over: step(1.0 / 60, Vector2.DOWN, false)
	crash_elapsed = 0.8
	await _save_flight_frame(folder, "sea-impact")
	get_tree().quit()

func _save_flight_frame(folder: String, label: String) -> void:
	invulnerable = 0
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "/" + label + ".png")
	print("CAPTURE ", label, " hdg=", rad_to_deg(flight.heading), " alt=", flight.position.y, " horizon=", flight.horizon(), " game_over=", game_over)
