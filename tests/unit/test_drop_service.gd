extends GutTest
## DropService 单测（Sprint 3）
## REQ-004-2.1~2.5：副本体力/日限/掉落 + 试炼塔推进/每日上限/节点奖励

var svc: DropService
var model: SaveModel

## 与 drop.json 一致的最小副本表（测试注入）
const DROP_TBL := {
	"dungeons": [
		{ "id": "yuanshi_mijing", "name": "源石秘境", "energy_cost": 10, "daily_limit": 2,
		  "tiers": [
			{ "tier": 1, "is_elite": false, "unlock_realm": "lunhai",
			  "drops": [ { "type": "yuan", "min": 3, "max": 3 }, { "type": "yuan_shard", "min": 2, "max": 2 } ] },
		  ] },
		{ "id": "lingshi_kuangmai", "name": "灵石矿脉", "energy_cost": 10, "daily_limit": 3,
		  "tiers": [
			{ "tier": 1, "is_elite": false, "unlock_realm": "lunhai",
			  "drops": [ { "type": "ling", "min": 5000, "max": 5000 } ] },
		  ] },
	],
	"tower": { "energy_per_floor": 5, "daily_max_floors": 10, "node_every": 10, "max_floors": 30, "unlock_stage": "s011" },
}


func before_each() -> void:
	svc = DropService.new(DROP_TBL)
	model = SaveModel.default_save()


## 源石秘境：体力消耗 + 源石产出 + 日限
func test_yuanshi_dungeon() -> void:
	model.energy = 120
	var r := svc.run_dungeon(model, "yuanshi_mijing", 1, "20260807")
	assert_true(r.ok)
	assert_eq(r.drops.get("yuan", 0), 3, "T1 源石秘境应产出 3 源石")
	assert_eq(model.energy, 110, "应消耗 10 体力")
	assert_eq(model.yuan, 3, "源石入账")


## 日限 2 次：第 3 次拒绝
func test_daily_limit() -> void:
	model.energy = 120
	svc.run_dungeon(model, "yuanshi_mijing", 1, "20260807")
	svc.run_dungeon(model, "yuanshi_mijing", 1, "20260807")
	var r3 := svc.run_dungeon(model, "yuanshi_mijing", 1, "20260807")
	assert_false(r3.ok)
	assert_eq(r3.reason, "daily_limit")


## 体力不足拒绝且不扣次数
func test_no_energy() -> void:
	model.energy = 5
	var r := svc.run_dungeon(model, "yuanshi_mijing", 1, "20260807")
	assert_false(r.ok)
	assert_eq(r.reason, "no_energy")
	assert_eq(int(model.stats.get("dun_yuanshi_mijing_20260807", 0)), 0, "失败不应记次数")


## 试炼塔推进：胜利前进一层 + 消耗体力
func test_tower_progress() -> void:
	model.energy = 120
	model.stats["tower_floor"] = 1
	var r := svc.run_tower(model, 2000.0, "20260807")
	assert_true(r.ok, "战力 2000 应过第 1 层（敌方 1150）")
	assert_eq(model.stats["tower_floor"], 2, "推进一层")
	assert_eq(model.energy, 115, "消耗 5 体力")


## 试炼塔：战力不足失败（不推进）
func test_tower_defeat() -> void:
	model.energy = 120
	model.stats["tower_floor"] = 20
	var r := svc.run_tower(model, 500.0, "20260807")
	assert_false(r.ok)
	assert_eq(r.reason, "defeat")
	assert_eq(model.stats["tower_floor"], 20, "失败不推进")


## 每 10 层节点奖励源石
func test_tower_node_reward() -> void:
	model.energy = 300
	model.stats["tower_floor"] = 10
	var r := svc.run_tower(model, 5000.0, "20260807")
	assert_true(r.ok)
	assert_eq(r.drops.get("yuan", 0), 10, "第 10 层节点应奖励 10 源石")


## 每日爬塔上限 10 层
func test_tower_daily_limit() -> void:
	model.energy = 999
	model.stats["tower_daily_20260807"] = 10
	var r := svc.run_tower(model, 9999.0, "20260807")
	assert_false(r.ok)
	assert_eq(r.reason, "daily_limit")
