extends GutTest
## 装备服务单测（G-01 补测试缺口）

var svc: EquipmentService
var model: SaveModel


func before_each() -> void:
	var tbl: Dictionary = ResourceManager.load_table("res://data/tables/equipment.json")
	svc = EquipmentService.new(tbl)
	model = SaveModel.default_save()
	model.ling = 100000
	model.equipment["weapon"] = "e_wp_001"
	model.equipment["armor"] = "e_ar_001"


func test_find_item() -> void:
	var item := svc.find_item("e_wp_001")
	assert_false(item.is_empty(), "能找到青铜古剑")
	assert_eq(String(item.get("name", "")), "青铜古剑")


func test_enhance_success() -> void:
	var r := svc.enhance(model, "weapon")
	assert_true(r.get("ok", false), "强化成功")
	assert_eq(int(r.get("level", 0)), 2, "升到 2 级")
	assert_true(int(r.get("cost", 0)) > 0, "消耗灵石")
	assert_true(int(r.get("atk_bonus", 0)) > 0, "攻击提升")


func test_enhance_no_item() -> void:
	var r := svc.enhance(model, "accessory")
	assert_false(r.get("ok", true), "空槽强化失败")
	assert_eq(String(r.get("reason", "")), "no_item")


func test_enhance_max_level() -> void:
	model.stats["eq_lv_weapon"] = 25
	var r := svc.enhance(model, "weapon")
	assert_false(r.get("ok", true), "满级强化失败")
	assert_eq(String(r.get("reason", "")), "max_level")


func test_total_bonus_includes_new_stats() -> void:
	model.equipment["accessory"] = "e_ac_004"  ## 镇魂钟：暴击4%+暴伤30%+特攻100
	var bonus := svc.total_bonus(model)
	assert_true(int(bonus.get("atk", 0)) > 0, "攻击加成")
	assert_true(float(bonus.get("crit_rate", 0.0)) > 0.03, "暴击率加成（镇魂钟4%）")
	assert_true(float(bonus.get("crit_dmg", 0.0)) > 0.2, "暴击伤害加成")
	assert_true(int(bonus.get("matk", 0)) > 0, "特攻加成")
