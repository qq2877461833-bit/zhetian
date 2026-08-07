class_name SaveModel
extends RefCounted
## Sprint 3 存档数据模型（核心层 · 纯逻辑）
## 多角色 + 多修炼位 + 抽卡保底 + 体力（GDD-002 §3.3 / GDD-001 §3.2.4 / GDD-003 §3.5）

const VERSION := 5
const ENERGY_CAP := 120  ## 体力上限（REQ-003-3.5：120）

var ling := 0
var yuan := 0
var energy := ENERGY_CAP  ## 体力（GDD-003 §3.5：上限 120 / 1per5min / 不可付费无限购买）
var cleared_stages: Array[String] = []
var last_offline_ts := 0
var gacha_tickets := 0  ## 抽卡券（GDD-002 §3.1：抽卡货币；付费/活动获取，MVP 演示新档发放）
var characters := {}  ## char_id -> { realm, sub_index, level, star, artifact, skills }
var slots := {}       ## slot_index(int) -> char_id；空位为 ""（多修炼位，MVP 上限 3）
var gacha := {}       ## pool_id -> { di_pity, tian_pity }（保底计数，跨池继承）
var stats := {}       ## 杂项统计/背包计数（副本日次/塔进度/经验书/材料等；day_key 以日期字符串标记）
var equipment := {}   ## slot_id -> item_id（单主角修仙装备系统；武器/防具/饰品/符箓）
var active_skills := [] ## 已装备功法（ids，单主角修仙；最多 3 个）
var inventory := {}   ## item_id -> count（背包：装备/功法/材料/残卷）
var pending_ling := 0.0  ## 在线待领取（出关结算用；不入存档，随出关合并入 ling）


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"player": { "ling": ling, "yuan": yuan, "energy": energy, "last_offline_ts": last_offline_ts },
		"cleared_stages": cleared_stages,
		"gacha_tickets": gacha_tickets,
		"characters": characters,
		"slots": slots,
		"gacha": gacha,
		"stats": stats,
		"equipment": equipment,
		"active_skills": active_skills,
		"inventory": inventory,
	}


static func from_dict(d: Dictionary) -> SaveModel:
	var m := SaveModel.new()
	var p: Dictionary = d.get("player", {})
	m.ling = int(p.get("ling", 0))
	m.yuan = int(p.get("yuan", 0))
	m.energy = int(p.get("energy", ENERGY_CAP))
	m.last_offline_ts = int(p.get("last_offline_ts", 0))
	## 抽卡券迁移：v2 新档发 30；旧档（v1 无字段）补发 10
	m.gacha_tickets = int(d.get("gacha_tickets", 10))
	var cs: Array = d.get("cleared_stages", [])
	for s in cs:
		m.cleared_stages.append(String(s))
	var ch: Dictionary = d.get("characters", {})
	for k in ch:
		m.characters[k] = (ch[k] as Dictionary).duplicate(true)
	var sl: Dictionary = d.get("slots", {})
	for k in sl:
		m.slots[int(k)] = String(sl[k])
	var gc: Dictionary = d.get("gacha", {})
	for k in gc:
		m.gacha[k] = (gc[k] as Dictionary).duplicate(true)
	var st: Dictionary = d.get("stats", {})
	for k in st:
		m.stats[k] = st[k]
	## 装备/功法序列化（V4 新字段；旧档默认空）
	var eq: Dictionary = d.get("equipment", {})
	for k in eq:
		m.equipment[k] = String(eq[k])
	var as_: Array = d.get("active_skills", [])
	for s in as_:
		m.active_skills.append(String(s))
	var inv: Dictionary = d.get("inventory", {})
	for k in inv:
		m.inventory[k] = int(inv[k])
	return m


## 默认新档：主角 ye_fan 上阵（槽位 0），境界 轮海·苦海(0,0)，1 级，演示抽卡券 30 张
static func default_save() -> SaveModel:
	var m := SaveModel.new()
	m.add_character("ye_fan", 0)
	m.slots[0] = "ye_fan"
	m.gacha_tickets = 30
	return m


## 注册/获取角色（char_id 已存在则 no-op）
func add_character(char_id: String, slot_index: int = -1) -> void:
	if not characters.has(char_id):
		characters[char_id] = { "realm": "lunhai", "sub_index": 0, "level": 1, "star": 1, "artifact": "", "skills": [] }
	if slot_index >= 0:
		assign_slot(slot_index, char_id)


func assign_slot(slot_index: int, char_id: String) -> void:
	## 占用中的角色从原槽位移出（一个角色只占一个修炼位）
	for s in slots:
		if slots[s] == char_id:
			slots[s] = ""
	slots[slot_index] = char_id


func remove_from_slot(slot_index: int) -> void:
	if slots.has(slot_index):
		slots[slot_index] = ""


func get_character(char_id: String) -> Dictionary:
	return characters.get(char_id, {})


## 修炼位解锁判断（GDD-001 §3.2.4）：0 初始解锁 / 1 轮海毕业(sub>=3) / 2 道宫毕业(sub>=8)
func is_slot_unlocked(slot_index: int, main_sub_index: int) -> bool:
	if slot_index == 0:
		return true
	if slot_index == 1:
		return main_sub_index >= 3  ## 轮海毕业（彼岸）
	if slot_index == 2:
		return main_sub_index >= 8  ## 道宫毕业（肾藏）
	return false


## 当前可用的修炼位数量（按主角境界进度）
func unlocked_slot_count(main_sub_index: int) -> int:
	var n := 0
	for i in range(3):
		if is_slot_unlocked(i, main_sub_index):
			n += 1
	return n


func highest_cleared_order() -> int:
	## 按关卡 order 求最高已通关（简化：cleared_stages 存 stage id，顺序即通关数）
	return cleared_stages.size()
