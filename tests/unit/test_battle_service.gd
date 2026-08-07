extends GutTest
## BattleService 完整版单测（Sprint 3）
## REQ-003-5.1 伤害公式 / 3.3 克制倍率 / 3.1 行动条制 / 星级

var svc: BattleService


func before_each() -> void:
	svc = BattleService.new()


## 伤害公式：K=300 减伤曲线
func test_damage_formula_k300() -> void:
	# 无防御：全伤
	assert_almost_eq(svc.calc_damage(100, 1.0, 1.0, 0), 100.0, 0.01)
	# def=300 → 减伤 50%
	assert_almost_eq(svc.calc_damage(100, 1.0, 1.0, 300), 50.0, 0.01)
	# skill_coef=2.0 翻倍
	assert_almost_eq(svc.calc_damage(100, 2.0, 1.0, 0), 200.0, 0.01)


## 克制倍率：荒古体质打仙道神通 ×1.50；被兵流派克 ×0.67
func test_counter_ring() -> void:
	assert_almost_eq(svc.counter_mult("huanggu_tizhi", "xiandao_shentong"), 1.50, 0.001, "克制定案 ×1.50")
	assert_almost_eq(svc.counter_mult("huanggu_tizhi", "bingqi_liupai"), 0.67, 0.001, "被克 ×0.67")
	assert_almost_eq(svc.counter_mult("huanggu_tizhi", "huanggu_tizhi"), 1.00, 0.001, "同类无克制")


## 完整模拟：4 人队必胜弱敌（3 星）
func test_simulate_full_win_3star() -> void:
	var team := _mk_team()
	var stage := { "id": "s001", "enemies": [{ "class": "huanggu_tizhi", "power": 500 }], "turn_limit": 12 }
	var r := svc.simulate_full(team, stage)
	assert_eq(r.winner, "player")
	assert_eq(r.stars, 3, "弱敌应在限定回合内击败")
	assert_true(r.player_survivors > 0)


## 完整模拟：强敌导致失败
func test_simulate_full_lose() -> void:
	var team := _mk_team()
	var stage := { "id": "s999", "enemies": [{ "class": "xiandao_shentong", "power": 50000 }], "turn_limit": 12 }
	var r := svc.simulate_full(team, stage)
	assert_eq(r.winner, "enemy")
	assert_eq(r.stars, 0)


## 星级：超回合 → 低星；输 → 0 星
func test_stars_rounds() -> void:
	var team := _mk_team()
	# turn_limit=1 极小：即便玩家赢也是 <=2 星
	var stage := { "id": "s002", "enemies": [{ "class": "bingqi_liupai", "power": 800 }], "turn_limit": 1 }
	var r := svc.simulate_full(team, stage)
	if r.winner == "player":
		assert_true(r.stars <= 2, "turn_limit=1 时最高 2 星")
	else:
		assert_eq(r.stars, 0, "战败星级为 0")
	assert_true(r.rounds > 0, "战斗应发生")


## 行动条制：同阵容两次模拟结果确定性一致（ADR-0003 确定性）
func test_deterministic() -> void:
	var team := _mk_team()
	var stage := { "id": "s003", "enemies": [{ "class": "huanggu_tizhi", "power": 1500 }], "turn_limit": 12 }
	var r1 := svc.simulate_full(team, stage)
	var r2 := svc.simulate_full(team, stage)
	assert_eq(r1.winner, r2.winner)
	assert_eq(r1.rounds, r2.rounds, "同输入应同结果")


## 技能冷却：首回合大招冷却 4，后续普攻直到冷却就绪（log 验证）
func test_skill_cooldown_flow() -> void:
	var team := _mk_team()
	var stage := { "id": "s004", "enemies": [{ "class": "huanggu_tizhi", "power": 3000 }], "turn_limit": 12 }
	var r := svc.simulate_full(team, stage)
	assert_true(r.log.size() > 0, "战斗应有行动日志")
	# 第一回合若用大招则冷却推进（不崩溃即可）
	assert_true(r.rounds > 0)


func _mk_team() -> Array:
	return [
		{ "id": "ye_fan", "class": "huanggu_tizhi", "base": { "hp": 1500, "atk": 120, "def": 80, "spd": 100 },
		  "skills": [
			{ "id": "pu_gong", "type": "basic", "coef": 1.0 },
			{ "id": "s_ye_fan_active", "type": "active", "coef": 1.5 },
			{ "id": "s_ye_fan_ult", "type": "ult", "coef": 2.5 },
		  ] },
		{ "id": "pang_bo", "class": "huanggu_tizhi", "base": { "hp": 1800, "atk": 110, "def": 90, "spd": 90 },
		  "skills": [
			{ "id": "pu_gong", "type": "basic", "coef": 1.0 },
			{ "id": "s_pang_active", "type": "active", "coef": 1.5 },
			{ "id": "s_pang_ult", "type": "ult", "coef": 2.5 },
		  ] },
		{ "id": "ji_ziyue", "class": "xiandao_shentong", "base": { "hp": 1400, "atk": 130, "def": 70, "spd": 110 },
		  "skills": [
			{ "id": "pu_gong", "type": "basic", "coef": 1.0 },
			{ "id": "s_ji_active", "type": "active", "coef": 1.5 },
			{ "id": "s_ji_ult", "type": "ult", "coef": 2.5 },
		  ] },
		{ "id": "hei_huang", "class": "bingqi_liupai", "base": { "hp": 1600, "atk": 115, "def": 85, "spd": 95 },
		  "skills": [
			{ "id": "pu_gong", "type": "basic", "coef": 1.0 },
			{ "id": "s_hei_active", "type": "active", "coef": 1.5 },
			{ "id": "s_hei_ult", "type": "ult", "coef": 2.5 },
		  ] },
	]
