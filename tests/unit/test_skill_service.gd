extends GutTest
## 功法服务单测（G-01 补测试缺口）

var svc: SkillService
var model: SaveModel


func before_each() -> void:
	var tbl: Dictionary = ResourceManager.load_table("res://data/tables/skill_sets.json")
	svc = SkillService.new(tbl)
	model = SaveModel.default_save()
	model.ling = 100000
	model.inventory["mat_skill_shard"] = 5
	model.active_skills = ["sk_001"]


func test_find_book() -> void:
	var b := svc.find_book("sk_001")
	assert_false(b.is_empty())
	assert_eq(String(b.get("name", "")), "荒古炼体术")


func test_train_cost_ling() -> void:
	var r := svc.train(model, "sk_001")
	assert_true(r.get("ok", false), "修炼成功")
	assert_eq(int(r.get("level", 0)), 2, "升 2 级")
	assert_true(model.ling < 100000, "消耗灵石")


func test_train_shard_after_lv5() -> void:
	model.stats["sk_lv_sk_001"] = 5
	model.stats["sk_con_sk_001"] = 2
	var r := svc.train(model, "sk_001")
	assert_true(r.get("ok", false), "Lv5 修炼成功")
	assert_eq(int(r.get("shard_cost", 0)), 1, "消耗 1 残卷")
	assert_eq(int(model.inventory.get("mat_skill_shard", 0)), 4, "残卷减少")


func test_train_no_shard() -> void:
	model.stats["sk_lv_sk_001"] = 5
	model.inventory["mat_skill_shard"] = 0
	var r := svc.train(model, "sk_001")
	assert_false(r.get("ok", true), "无残卷修炼失败")
	assert_eq(String(r.get("reason", "")), "no_shard")


func test_equip_and_unequip() -> void:
	var r1 := svc.equip_skill(model, "sk_003")
	assert_true(r1.get("ok", false), "装备功法")
	assert_eq(model.active_skills.size(), 2)
	var r2 := svc.equip_skill(model, "sk_003")
	assert_true(r2.has("unequipped"), "卸下功法")
	assert_eq(model.active_skills.size(), 1)


func test_total_bonus_with_constellation() -> void:
	## 荒古炼体术 idle_rate 8%×lv，命座 1 → ×1.5
	model.stats["sk_lv_sk_001"] = 3
	model.stats["sk_con_sk_001"] = 1
	var bonus := svc.total_bonus(model)
	var expect := 0.08 * 3 * 1.25
	assert_almost_eq(float(bonus.get("idle_rate", 0.0)), expect, 0.001, "命座强化效果")
