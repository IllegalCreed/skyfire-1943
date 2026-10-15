extends Control
## Read-only Chinese mission HUD, separate from gameplay coordinates and aim helpers.

var game
var heading: Label
var objective: Label
var notice: Label
var boss_name: Label
var health: ProgressBar
var cinematic_title: Label
var cinematic_note: Label

func setup(owner_game) -> void:
	game=owner_game
	size=Vector2(960,540)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	theme=game.menu.theme
	heading=_label(Rect2(250,7,490,26),16,Color("69e6d2"))
	objective=_label(Rect2(250,35,490,21),11,Color("93afb6"))
	notice=_label(Rect2(150,127,660,36),16,Color("ffba68"))
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var backing := StyleBoxFlat.new()
	backing.bg_color=Color("091526",0.88)
	backing.content_margin_top=5
	notice.add_theme_stylebox_override("normal",backing)
	boss_name=_label(Rect2(280,85,400,22),12,Color("edf7eb"))
	boss_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	health=ProgressBar.new()
	health.position=Vector2(280,76)
	health.size=Vector2(400,6)
	health.max_value=game.CHASE_BOSS.MAX_HP
	health.show_percentage=false
	health.add_theme_font_size_override("font_size",1)
	health.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color=Color("ff6872")
	health.add_theme_stylebox_override("fill",fill)
	var background := StyleBoxFlat.new()
	background.bg_color=Color("233e50")
	health.add_theme_stylebox_override("background",background)
	add_child(health)
	health.size=Vector2(400,6)
	cinematic_title=_label(Rect2(180,114,600,32),20,Color("edf7eb"))
	cinematic_note=_label(Rect2(180,150,600,30),13,Color("69e6d2"))
	cinematic_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	cinematic_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	refresh()

func _label(rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position=rect.position
	label.size=rect.size
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	add_child(label)
	return label

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	visible=game.mission.active and not game.title and not game.menu.visible and not game.victory
	if not visible: return
	var mission = game.mission
	var cinema: bool = is_instance_valid(game.view_transition) and game.view_transition.active
	heading.text="01 破晓突袭 · "+mission.phase_title()
	objective.text=mission.objective()+"  %02d:%02d"%[int(mission.time)/60,int(mission.time)%60]
	notice.visible=mission.notice_time>0 and not cinema
	notice.text=mission.notice
	health.visible=mission.phase==2 and not cinema
	boss_name.visible=health.visible
	health.value=mission.boss_hp
	var armour := "正在接近"
	for enemy in game.enemies:
		if enemy.get("boss",false):
			armour="持续交战 · 距离 %.0f"%game.CHASE_BOSS.HOLD_DEPTH if game.CHASE_BOSS.holding(enemy) else "接近中 · 到位后交战"
			var screen: Vector2 = game._entity_screen(enemy)
			if screen.x<0: armour="目标在左侧 ← 转回观察"
			elif screen.x>960: armour="目标在右侧 → 转回观察"
	boss_name.text="海鸥 · %d / %d   %s"%[mission.boss_hp,game.CHASE_BOSS.MAX_HP,armour]
	cinematic_title.visible=cinema
	cinematic_note.visible=cinema
	if cinema:
		cinematic_title.text="切入沿岸攻击" if game.view_transition.next_mode==game.Mode.TOP else "重返空域迎战"
		cinematic_note.text="电台：清除航路上的敌方火力" if game.view_transition.next_mode==game.Mode.TOP else "电台：海鸥拦截机就在前方"
