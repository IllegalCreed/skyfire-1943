extends Node2D
## Render catalog portraits with the exact game drawing functions, not mockup art.

const ART := preload("res://src/rendering/aircraft_art.gd")
const VESSEL := preload("res://src/rendering/vessel_art.gd")
const ROSTER := preload("res://src/gameplay/enemy_roster.gd")
const FLIGHT := preload("res://src/gameplay/chase_flight.gd")
const GUN := preload("res://src/gameplay/chase_gun.gd")
const BOSS := preload("res://src/gameplay/chase_boss.gd")
const BOSS_ART := preload("res://src/rendering/boss_art.gd")
const TEAL := Color("69e6d2")
const GOLD := Color("ffba68")
const RED := Color("ff6872")
var kind := "allied"
var view := 0

func _draw() -> void:
	draw_rect(Rect2(0,0,768,480),Color("102236"))
	for x in range(0,769,48): draw_line(Vector2(x,0),Vector2(x,480),Color("193144"),1)
	for y in range(0,481,48): draw_line(Vector2(0,y),Vector2(768,y),Color("193144"),1)
	if kind=="seagull-demo":
		BOSS_ART.draw_boss(self,Vector2(384,253),2.5,{"hp":BOSS.MAX_HP,"age":6.0,"fire":2.0,"bank":0.0},1.43)
	elif kind in ["escort","cargo"]:
		VESSEL.draw_vessel(self,Vector2(384,253),4.2,view==2,kind,RED)
	else:
		ART.draw_plane(self,Vector2(384,253),3.8,TEAL if kind=="allied" else GOLD if ROSTER.is_bonus(kind) else RED,view,kind=="allied",0,kind,1.43)

static func describe() -> Dictionary:
	var units: Array[Dictionary] = []
	units.append({"id":"allied","name":"我方双发战斗机","role":"我方 / 僚机","status":"已实现","category":"allied","summary":"双发动机、双尾撑与中央座舱。三个视角和僚机使用同一造型语言。","traits":["金属灰机身、青绿识别条与原创双折线标记","带框座舱、发动机散热槽、动画螺旋桨","追尾双炮口继续与实际弹道起点对齐"],"views":[0,1,2],"weapons":"机炮；X 在横版 / 俯视清弹，追尾发射水面鱼雷。","stats":{"能量上限":"100 点","机炮间隔":"0.16 秒；追尾强化后 0.11 秒","追尾有效帧":"第 %d–%d 帧；第 %d 帧失效"%[GUN.FIRST_HIT_FRAME,GUN.LAST_PATH_FRAME,GUN.EXPIRE_FRAME],"双弹上限":"%d 组"%GUN.MAX_PAIRS,"追尾前进":"%.0f 内部单位 / 秒（不是米）"%FLIGHT.SPEED,"二维移动":"横向 451.2 / 纵向 361.8 逻辑像素 / 秒"},"reward":"拾取补给恢复 18 点能量、强化到二级并加 100 分。"})
	var names := {"interceptor":"轻型截击机","raider":"长鼻袭扰机","bomber":"双发攻击机","courier":"金色奖励敌机"}
	var descriptions := {"interceptor":"短鼻星形发动机、窄翼和紧凑座舱。基础接敌单位。","raider":"长鼻、宽翼、侧向摆动更明显，带来持续横移的瞄准压力。","bomber":"宽翼双发动机与玻璃机鼻，速度慢、耐久高，发射稀疏双弹。","courier":"金色机身与浅色识别条，快速接近并摆动逃离；击落必掉补给。"}
	for id in ROSTER.KINDS+[ROSTER.BONUS_KIND]:
		var spec := ROSTER.profile(id)
		var bonus := ROSTER.is_bonus(id)
		units.append({"id":id,"name":names[id],"role":"奖励敌机" if bonus else "空中敌机","status":"已实现","category":"bonus" if bonus else "air","summary":descriptions[id],"traits":["金色涂装，取代当波第一架敌机" if bonus else "暖红识别条，军用金属 / 橄榄灰机身","持续自主侧飞，完整轮廓越界后清除","不放宽原有追尾有效距离与汇聚窗口"],"views":[0,1,2],"weapons":"不主动开火，优先逃离；接触仍会伤害我机。" if bonus else "每次发射 %d 枚瞄准弹；发射后不追踪。"%spec.burst,"stats":{"横版耐久":"%d 次主炮命中"%spec.hp_2d,"俯视耐久":"%d 次主炮命中"%spec.hp_2d,"追尾耐久":"%d 次有效汇聚命中"%spec.hp,"横版速度":"%.0f 逻辑像素 / 秒"%spec.speed_side,"俯视速度":"%.0f 逻辑像素 / 秒"%spec.speed_top,"追尾路线时长":"%.1f 秒（接近结束仍继续侧飞）"%spec.duration,"每次发弹":"%d 枚"%spec.burst,"追尾开火间隔":"不主动开火" if bonus else "%.1f 秒"%spec.fire_chase,"二维开火间隔":"不主动开火" if bonus else "%.1f 秒"%spec.fire_2d,"敌弹速度":"追尾 %.0f / 二维 %.0f 逻辑像素 / 秒"%[spec.bullet_speed,spec.bullet_2d] if not bonus else "—","出场":"每 %d 波第一架；不额外加密"%ROSTER.BONUS_INTERVAL if bonus else "按普通波次轮换"},"reward":"必掉一件金色 B 补给：恢复 18 能量、强化至二级、+100 分；仍需拾取。" if bonus else "参与每四次击落的综合补给；追尾按距离计 150 / 200 / 300 分。"})
	for id in ["escort","cargo"]:
		var spec := ROSTER.vessel_profile(id)
		units.append({"id":id,"name":"护航炮舰" if id=="escort" else "武装运输船","role":"水面敌舰","status":"已实现","category":"sea","summary":"细长船体、分层舰桥、双烟囱、前后炮塔与甲板鱼雷管。" if id=="escort" else "大货舱、交叉舱盖、吊货桅杆、后部舰桥和烟囱，区别于护航炮舰。","traits":["俯视显示甲板布局，追尾显示船体与上层建筑","追尾海面隐藏时不绘制，也不发射不可见攻击","炮塔、鱼雷管和桅杆属于外观；当前不是独立可破坏部件"],"views":[1,2],"weapons":"每次一枚瞄准炮弹；运输船开火更疏。甲板鱼雷管尚无独立攻击。","stats":{"耐久":"%d 次普通机炮命中 / 1 枚追尾鱼雷"%spec.hp,"俯视开火间隔":"%.1f 秒"%spec.fire_2d,"追尾开火间隔":"%.1f 秒"%spec.fire_chase,"俯视滚动":"42 逻辑像素 / 秒；无自主横移","追尾世界移动":"固定世界位置；我机前进产生视差","炮弹速度":"俯视 %.0f 逻辑像素 / 秒；追尾 %.0f 内部单位 / 秒"%[spec.bullet_2d,spec.bullet_chase],"适用视角":"俯视 / 追尾（追尾只受水面鱼雷伤害）"},"reward":"舰船基础得分双倍；参与每四次击落补给。"})
	for unit in units:
		if unit.category=="allied":
			unit.stats["瞄准提示"]="机枪准心与鱼雷投弹点独立可选，默认均关闭"
			unit.stats["姿态动画"]="横版 / 俯视各 9 档；追尾 9×9 组合；每姿态 8 帧白桨盘"
			unit.traits=["暖象牙 / 冷灰机体与青蓝折线装饰","v3 同一模型烘焙的像素姿态；固定中心、松手逐帧回正","高速白桨盘有亮暗交替与弧形残影；原炮口和弹道规则保留"]
		unit["view_labels"] = {"0":"横版侧视","1":"俯视","2":"追尾后视" if unit.category=="allied" else "追尾船体观察" if unit.category=="sea" else "迎面正视（追尾接敌）"}
	units.append({"id":"seagull-demo","name":"海鸥 · Boss 验证版","role":"单人样段 Boss","status":"已实现 · 待试玩调校","category":"air","summary":"宽翼双发重型拦截机，一次接近后保持作战距离，横纵摆动躲避炮弹。不是完整发动机部件版。","traits":["固定交战深度，持续摆动；不离场或重新出现","半血后冒烟，炮火更密、摆动幅度略增","持续可受伤，取消旧每轮三次伤害和护甲等待"],"views":[2],"view_labels":{"2":"迎面正视（追尾 Boss）"},"weapons":"稀疏双弹，炮口提前亮起；发射后不追踪。","stats":{"耐久":"%d 次有效汇聚伤害"%BOSS.MAX_HP,"接近":"%.1f 秒，从深度 220 到 %.0f"%[BOSS.ENTRY_SECONDS,BOSS.HOLD_DEPTH],"保持深度":"%.0f 内部单位，不是米"%BOSS.HOLD_DEPTH,"横向摆动":"基础幅度上限 %.0f 逻辑像素"%BOSS.SWAY_X,"纵向摆动":"±%.0f 逻辑像素"%BOSS.SWAY_Y,"开火间隔":"%.1f 秒；半血后 %.1f 秒"%[BOSS.fire_interval(BOSS.MAX_HP),BOSS.fire_interval(1)],"命中规则":"原第 16–19 帧窗口和有效距离，未放宽"},"reward":"击破 +%d 分并触发结算；通关 +1000 分，剩余能量每点 +10 分。"%BOSS.POINTS})
	return {"version":"0.16","date":"2026-10-14","units":units}
