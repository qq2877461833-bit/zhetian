class_name DropService
extends RefCounted
## 副本掉落服务（核心层 · 纯逻辑）· Sprint 3
## REQ-004-2.1~2.5：5 资源副本（体力/日限/档位/精英）+ 试炼塔（30 层/每日 10 层/每 10 层节点奖励）
## 数据来源：data/tables/drop.json（唯一事实来源）；服务端权威（ADR-0003）后续替换

var _drop_tbl: Dictionary


func _init(drop_tbl: Dictionary = {}) -> void:
	_drop_tbl = drop_tbl


## 副本结算：返回 { ok, drops:{type->count}, reason }
## 校验：体力足够 + 当日次数未超限；消耗体力并累计次数
func run_dungeon(model: SaveModel, dungeon_id: String, tier: int, day_key: String) -> Dictionary:
	var dun := _find_dungeon(dungeon_id)
	if dun.is_empty():
		return { "ok": false, "reason": "dungeon_not_found" }
	var tier_cfg := _find_tier(dun, tier)
	if tier_cfg.is_empty():
		return { "ok": false, "reason": "tier_not_found" }
	var cost := int(dun.get("energy_cost", 10))
	if model.energy < cost:
		return { "ok": false, "reason": "no_energy", "need": cost }
	## 当日次数限制
	var daily_key := "dun_%s_%s" % [dungeon_id, day_key]
	var done := int(model.stats.get(daily_key, 0))
	if done >= int(dun.get("daily_limit", 99)):
		return { "ok": false, "reason": "daily_limit" }
	## 扣体力、记次数
	model.energy -= cost
	model.stats[daily_key] = done + 1
	## 掉落结算
	var drops := _roll_drops(tier_cfg)
	for k in drops:
		if k == "yuan":
			model.yuan += int(drops[k])
		elif k == "ling":
			model.ling += int(drops[k])
		## exp_book / artifact_mat / skill_mat / yuan_shard 先进背包（简化：记入 stats 计数）
		model.stats[k] = int(model.stats.get(k, 0)) + int(drops[k])
	return { "ok": true, "drops": drops }


## 试炼塔挑战当前层：返回 { ok, floor, drops, reason }
## 简化：按战力判定胜败（胜则推进；败不耗次数但耗体力）
func run_tower(model: SaveModel, power: float, day_key: String) -> Dictionary:
	var tower: Dictionary = _drop_tbl.get("tower", {})
	var cur := int(model.stats.get("tower_floor", 1))
	var max_f := int(tower.get("max_floors", 30))
	if cur > max_f:
		return { "ok": false, "reason": "tower_cleared" }
	## 每日爬塔上限
	var daily_key := "tower_daily_%s" % day_key
	var done := int(model.stats.get(daily_key, 0))
	if done >= int(tower.get("daily_max_floors", 10)):
		return { "ok": false, "reason": "daily_limit" }
	## 体力
	var cost := int(tower.get("energy_per_floor", 5))
	if model.energy < cost:
		return { "ok": false, "reason": "no_energy", "need": cost }
	## 简化胜败：敌方战力 = 1000 + floor*150；玩家战力 = power
	var enemy_power := 1000.0 + cur * 150.0
	var win := power * 1.15 >= enemy_power  ## 略宽松：略低于也能过（P3 片刻修仙）
	model.energy -= cost
	if not win:
		model.stats[daily_key] = done + 1  ## 失败也计一次尝试
		return { "ok": false, "reason": "defeat", "floor": cur }
	model.stats[daily_key] = done + 1
	model.stats["tower_floor"] = cur + 1
	## 每 10 层节点奖励源石（REQ-004-2.4）
	var drops := { "ling": 2000 + cur * 500 }
	if cur % int(tower.get("node_every", 10)) == 0:
		drops["yuan"] = 10  ## NUM-021：塔节点 5→10（一次性供给恢复）
	model.ling += int(drops["ling"])
	model.yuan += int(drops.get("yuan", 0))
	return { "ok": true, "floor": cur, "drops": drops }


func _roll_drops(tier_cfg: Dictionary) -> Dictionary:
	var out := {}
	for d in tier_cfg.get("drops", []):
		var t := String(d.get("type", ""))
		var min_v := int(d.get("min", 0))
		var max_v := int(d.get("max", min_v))
		out[t] = randi_range(min_v, max_v)
	return out


func _find_dungeon(dungeon_id: String) -> Dictionary:
	for d in _drop_tbl.get("dungeons", []):
		if String(d.get("id", "")) == dungeon_id:
			return d
	return {}


func _find_tier(dun: Dictionary, tier: int) -> Dictionary:
	for t in dun.get("tiers", []):
		if int(t.get("tier", 0)) == tier:
			return t
	return {}
