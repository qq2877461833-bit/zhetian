class_name BattleService
extends RefCounted
## 战斗结算完整版（核心层 · 纯逻辑）· Sprint 3
## REQ-003-3.1~3.6 / 5：4 人上阵（前后排）+ 行动条制半即时 + 克制环 + 3 技能
## 服务端权威（ADR-0003）：确定性模拟（同输入同结果），客户端只播放 BattleResult
## 伤害公式：damage = ATK × skill_coef × counter_mult × (1 − DEF/(DEF+K))，K=300（REQ-003-5.1）

const K_DEF := 300.0
const ACTION_BAR := 100.0   ## 行动条满值（spd=100 → 每回合出手 1 次，spd 翻倍 → 2 次）
const TIMEOUT_ROUNDS := 120 ## 超时回合上限（防无限循环）
const COOLDOWN_ACTIVE := 2  ## 主动技能冷却（回合）
const COOLDOWN_ULT := 4     ## 大招冷却（回合）

## 克制矩阵（REQ-003-3.3 拍板：荒古体质/仙道神通/兵器流派 三角 ×1.50/0.67）
const COUNTER_TABLE := {
	"huanggu_tizhi":    { "huanggu_tizhi": 1.00, "xiandao_shentong": 1.50, "bingqi_liupai": 0.67 },
	"xiandao_shentong": { "huanggu_tizhi": 0.67, "xiandao_shentong": 1.00, "bingqi_liupai": 1.50 },
	"bingqi_liupai":    { "huanggu_tizhi": 1.50, "xiandao_shentong": 0.67, "bingqi_liupai": 1.00 },
}


## 伤害公式（REQ-003-5.1）
func calc_damage(atk: float, skill_coef: float, counter_mult: float, def_: float) -> float:
	atk = maxf(atk, 0.0)
	skill_coef = maxf(skill_coef, 0.0)
	counter_mult = maxf(counter_mult, 0.0)
	def_ = maxf(def_, 0.0)
	return atk * skill_coef * counter_mult * (1.0 - def_ / (def_ + K_DEF))


## 克制倍率：攻方 class 打 守方 class
func counter_mult(attacker_class: String, defender_class: String) -> float:
	var row: Dictionary = COUNTER_TABLE.get(attacker_class, {})
	return float(row.get(defender_class, 1.0))


## 完整战斗模拟：4 人队 vs 关卡敌人（行动条制）
## team: Array[Dictionary]（角色快照：id/class/base{atk,def,hp,spd}/skills[]）
## stage: battle.json 关卡行（enemies: Array[{class, power}], turn_limit）
## 返回 { winner, rounds, player_survivors, enemy_survivors, stars, log }
func simulate_full(team: Array, stage: Dictionary, skills_tbl: Dictionary = {}) -> Dictionary:
	var enemies := _build_enemies(stage)
	var players := _build_players(team)
	if players.is_empty():
		return { "winner": "enemy", "rounds": 0, "stars": 0, "player_survivors": 0, "enemy_survivors": enemies.size(), "log": [] }

	var turn_limit := int(stage.get("turn_limit", 12))
	var rounds := 0
	var log: Array = []
	while _alive(players) > 0 and _alive(enemies) > 0 and rounds < TIMEOUT_ROUNDS:
		rounds += 1
		## 行动条制：全体累积 SPD 点，满 ACTION_BAR 出手（spd 越高出手越快）
		var act_order: Array = []
		for u in players + enemies:
			var spd := float(u.get("spd", 100))
			u["bar"] = float(u.get("bar", 0.0)) + spd
			if u["bar"] >= ACTION_BAR:
				u["bar"] -= ACTION_BAR
				act_order.append(u)
		## 按出手顺序结算（bar 高者先，同分 spd 高者先）
		act_order.sort_custom(func(a, b) -> bool: return float(a["bar"]) > float(b["bar"]))
		for u in act_order:
			if _alive(players) <= 0 or _alive(enemies) <= 0:
				break
			_execute_turn(u, players, enemies, log)
	## 结算
	var win := _alive(enemies) <= 0 and _alive(players) > 0
	var stars := 0
	if win:
		if rounds <= turn_limit:
			stars = 3
		elif rounds <= turn_limit * 2:
			stars = 2
		else:
			stars = 1
	return {
		"winner": "player" if win else "enemy",
		"rounds": rounds,
		"player_survivors": _alive(players),
		"enemy_survivors": _alive(enemies),
		"stars": stars,
		"log": log,
	}


## 单回合出手：普攻优先，冷却就绪时用主动/大招
func _execute_turn(u: Dictionary, players: Array, enemies: Array, log: Array) -> void:
	var targets := enemies if u.get("side") == "player" else players
	if targets.is_empty():
		return
	var t := _pick_target(targets)
	var skill := _pick_skill(u)
	var atk := float(u.get("atk", 100))
	var dmg := calc_damage(atk, skill["coef"], counter_mult(u.get("class", ""), t.get("class", "")), float(t.get("def", 50)))
	t["hp"] = float(t.get("hp", 0.0)) - dmg
	## 冷却推进（仅玩家角色，简化：敌方无冷却）
	if u.get("side") == "player":
		_advance_cooldowns(u, skill["id"])
	log.append({ "actor": u.get("id", "?"), "skill": skill["id"], "target": t.get("id", "?"), "dmg": dmg })


func _pick_target(targets: Array) -> Dictionary:
	## 优先打存活的最低 HP 目标（简化集火逻辑）
	var alive := _alive_list(targets)
	if alive.is_empty():
		return {}
	var min_hp: float = 1e18
	var pick: Dictionary = {}
	for t in alive:
		if float(t.get("hp", 0.0)) < min_hp:
			min_hp = float(t.get("hp", 0.0))
			pick = t
	return pick


func _pick_skill(u: Dictionary) -> Dictionary:
	## 冷却就绪的大招 > 主动 > 普攻
	var skills: Array = u.get("skills", [])
	for s in skills:
		var sk: Dictionary = s
		if sk.get("type") == "ult" and int(u.get("cd_ult", 0)) <= 0:
			return sk
		if sk.get("type") == "active" and int(u.get("cd_active", 0)) <= 0:
			return sk
	return { "id": "pu_gong", "name": "普攻", "type": "basic", "coef": 1.0, "target": "single" }


func _advance_cooldowns(u: Dictionary, used_skill_id: String) -> void:
	u["cd_ult"] = maxi(int(u.get("cd_ult", 0)) - 1, 0)
	u["cd_active"] = maxi(int(u.get("cd_active", 0)) - 1, 0)
	## 用技能后置冷却（以技能 id 前缀判断：s_*_ult / s_*_active）
	if used_skill_id.contains("ult"):
		u["cd_ult"] = COOLDOWN_ULT
	elif used_skill_id.contains("active"):
		u["cd_active"] = COOLDOWN_ACTIVE


func _build_players(team: Array) -> Array:
	var out: Array = []
	for c in team:
		if c.is_empty():
			continue
		var base: Dictionary = c.get("base", {})
		var u := {
			"id": c.get("id", "?"), "side": "player", "class": c.get("class", ""),
			"hp": float(base.get("hp", 1500)), "atk": float(base.get("atk", 120)),
			"def": float(base.get("def", 80)), "spd": float(base.get("spd", 100)),
			"skills": [], "bar": 0.0, "cd_ult": 0, "cd_active": 0,
		}
		## 角色技能引用（外部已解析为带 coef/type 的技能定义）
		for sk in c.get("skills", []):
			u["skills"].append(sk)
		out.append(u)
	return out


func _build_enemies(stage: Dictionary) -> Array:
	var out: Array = []
	var raw: Array = stage.get("enemies", [])
	if raw.is_empty():
		## 兼容旧数据：单一敌人（power 驱动）
		var power := float(stage.get("enemy_power", 1000))
		raw = [{ "class": "huanggu_tizhi", "power": power }]
	for e in raw:
		var power := float(e.get("power", 1000))
		out.append({
			"id": "enemy", "side": "enemy", "class": e.get("class", "huanggu_tizhi"),
			"hp": power * 1.0, "atk": power * 0.05, "def": power * 0.05, "spd": 100,
			"skills": [{ "id": "e_attack", "name": "敌方攻击", "type": "basic", "coef": 1.0, "target": "single" }],
			"bar": 0.0, "cd_ult": 0, "cd_active": 0,
		})
	return out


func _alive(units: Array) -> int:
	return _alive_list(units).size()


func _alive_list(units: Array) -> Array:
	var out: Array = []
	for u in units:
		if float(u.get("hp", 0.0)) > 0.0:
			out.append(u)
	return out


## 单主角修仙单主角战斗（Sprint 4·方向调整）
## hero_base: 主角五维 {atk, def, hp}（含装备加成后）
## equip_bonus: 装备总加成 {atk, def, hp}
## skill_bonus: 功法总加成 {atk, idle_rate, ...}——atk用比例，def/hp 后续扩展
## stage: 关卡数据（enemies[0]）
func simulate_solo(hero_base: Dictionary, equip_bonus: Dictionary, skill_bonus: Dictionary, stage: Dictionary) -> Dictionary:
	var hero_atk := float(hero_base.get("atk", 120))
	var hero_matk := float(hero_base.get("matk", 0))
	var hero_def := float(hero_base.get("def", 80))
	var hero_hp := float(hero_base.get("hp", 1500))
	var hero_crit := float(hero_base.get("crit_rate", 0.05))
	var hero_crit_dmg := float(hero_base.get("crit_dmg", 1.5))
	var hero_dodge := float(hero_base.get("dodge", 0.03))
	## 装备加成（直接加算）
	hero_atk += float(equip_bonus.get("atk", 0))
	hero_matk += float(equip_bonus.get("matk", 0))
	hero_def += float(equip_bonus.get("def", 0))
	hero_hp += float(equip_bonus.get("hp", 0))
	hero_crit += float(equip_bonus.get("crit_rate", 0.0))
	hero_crit_dmg += float(equip_bonus.get("crit_dmg", 0.0))
	hero_dodge += float(equip_bonus.get("dodge", 0.0))
	## 功法加成（比例）
	hero_atk *= (1.0 + float(skill_bonus.get("atk", 0.0)))

	var enemies := _build_enemies(stage)
	if enemies.is_empty():
		return { "winner": "player", "rounds": 0, "stars": 3 }
	var enemy: Dictionary = enemies[0]
	var enemy_atk := float(enemy.get("atk", 50))
	var enemy_matk := float(enemy.get("matk", 0))
	var enemy_def := float(enemy.get("def", 50))
	var enemy_hp := float(enemy.get("hp", 1000))
	var enemy_crit := float(enemy.get("crit_rate", 0.05))
	var enemy_crit_dmg := float(enemy.get("crit_dmg", 1.5))
	var enemy_dodge := float(enemy.get("dodge", 0.03))

	var turn_limit := int(stage.get("turn_limit", 12))
	var hero_max := hero_hp
	var enemy_max := enemy_hp
	var hero_dmgs: Array = []  ## 怪物每回合打我方的伤害（演出用）
	var enemy_dmgs: Array = [] ## 我方每回合打怪物的伤害
	var crit_count := 0  ## 我方暴击次数
	var dodge_count := 0 ## 我方闪避次数
	var rounds := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260807 + int(hero_atk)  ## 确定性模拟（同输入同结果）
	while hero_hp > 0.0 and enemy_hp > 0.0 and rounds < TIMEOUT_ROUNDS:
		rounds += 1
		## 我方攻击：暴击判定
		var d1 := calc_damage(hero_atk, 1.0, counter_mult("huanggu_tizhi", enemy.get("class", "huanggu_tizhi")), enemy_def)
		var is_crit := rng.randf() < clampf(hero_crit, 0.0, 0.9)
		if is_crit:
			d1 *= hero_crit_dmg
			crit_count += 1
		enemy_hp -= d1
		enemy_dmgs.append(d1)
		if enemy_hp <= 0.0:
			break
		## 敌方攻击：我方闪避判定
		if rng.randf() < clampf(hero_dodge, 0.0, 0.6):
			dodge_count += 1
			continue
		var d2 := calc_damage(enemy_atk, 1.0, counter_mult(enemy.get("class", "huanggu_tizhi"), "huanggu_tizhi"), hero_def)
		hero_hp -= d2
		hero_dmgs.append(d2)

	var win := hero_hp > 0.0 and enemy_hp <= 0.0
	var stars := 0
	if win:
		if rounds <= turn_limit:
			stars = 3
		elif rounds <= turn_limit * 2:
			stars = 2
		else:
			stars = 1
	return {
		"winner": "player" if win else "enemy", "rounds": rounds, "stars": stars,
		"crit_count": crit_count, "dodge_count": dodge_count,
		"hero_hp": hero_hp, "hero_max": hero_max,
		"enemy_hp": enemy_hp, "enemy_max": enemy_max,
		"hero_dmgs": hero_dmgs, "enemy_dmgs": enemy_dmgs,
	}
