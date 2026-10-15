extends RefCounted
## Display preferences must not alter either air convergence or sea swept hits.

const GUN := preload("res://src/gameplay/chase_gun.gd")
const ENCOUNTER := preload("res://src/gameplay/chase_encounter.gd")

static func run(game) -> void:
	assert(not game.aim_helper and not game.torpedo_helper, "Fresh defaults hide both guides")
	var baseline: Array = []
	for air in [false,true]:
		for sea in [false,true]:
			game.apply_setting("aim_helper",air,false)
			game.apply_setting("torpedo_helper",sea,false)
			game.start_game()
			assert(game.aim_helper==air and game.torpedo_helper==sea,"Restart preserves independent display choices")
			game.transition = 0
			game.flight.position.y = 1.2
			var pair := GUN.make_pair(game.flight)
			var points := GUN.positions(pair,game.flight,16.0/60)
			var enemy := ENCOUNTER.make_enemy(game.flight,1,0)
			enemy.air_position = game.flight.air_position_from_screen((points[0]+points[1])*0.5)
			enemy.chase_depth = 60
			game.enemies.append(enemy)
			game.shots.append(pair)
			game._update_shots(15.0/60)
			assert(game.enemies.size()==1,"Hidden or visible aim does not open an early hit window")
			game._update_shots(1.0/60)
			assert(game.enemies.is_empty() and game.score==200,"Valid air hit works in every guide combination")
			var ship_position: Vector3 = game.flight.position+game.flight.forward()*40
			ship_position.y = 0.22
			game.enemies.append({"p":ship_position,"hp":7,"surface":true})
			game.special()
			game._update_shots(1.0)
			assert(game.enemies.is_empty(),"Torpedo still hits without its projected point")
			var result: Array = [game.score,game.kills,game.energy,game.shots.size(),game.flight.position]
			if baseline.is_empty(): baseline=result
			else: assert(result==baseline,"Guide choices cannot alter gameplay outcomes")
	game.apply_setting("aim_helper",false,false)
	game.apply_setting("torpedo_helper",true,false)
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_H
	game._unhandled_input(event)
	assert(game.aim_helper and game.torpedo_helper,"H toggles gun guide independently")
	game._unhandled_input(event)
	assert(not game.aim_helper and game.torpedo_helper,"H never toggles torpedo guide")
	game.apply_setting("torpedo_helper",false,false)
	game.return_to_menu()
	game.menu.open_settings("main")
	game.menu.select_settings_section("game")
	assert(not game.menu.buttons.aim.button_pressed and not game.menu.buttons.torpedo.button_pressed,"Settings show both defaults off")
	game.menu.buttons.aim.button_pressed = true
	assert(game.aim_helper and not game.torpedo_helper,"Gun setting is independent")
	game.menu.buttons.torpedo.button_pressed = true
	game.menu.buttons.aim.button_pressed = false
	assert(not game.aim_helper and game.torpedo_helper,"Torpedo setting is independent")
	game.apply_setting("torpedo_helper",false,false)
	game.return_to_menu()
	print("GUIDES PASS: both off by default, independent controls, air frames and sea hits unchanged")
