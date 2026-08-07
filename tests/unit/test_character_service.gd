extends GutTest
## CharacterService 单测（Sprint 2）
## REQ-002-3.2（五维养成）/ REQ-002-3.3（账号境界上限）

var service: CharacterService
var model: SaveModel


func before_each() -> void:
	service = CharacterService.new({
		"characters": [
			{ "id": "ye_fan", "rarity": "tian", "class": "huanggu_tizhi", "fragments_for_star": 30 },
			{ "id": "pang_bo", "rarity": "di", "class": "huanggu_tizhi", "fragments_for_star": 30 },
			{ "id": "ji_ziyue", "rarity": "tian", "class": "xiandao_shentong", "fragments_for_star": 30 },
		]
	})
	model = SaveModel.default_save()
	model.add_character("pang_bo", 1)


## 升级：10 书/级，消耗与等级提升正确
func test_level_up() -> void:
	var r := service.level_up(model, "ye_fan", 30)
	assert_true(r.ok, "30 本书应可升级")
	assert_eq(r.level, 4, "30 书 = 3 级提升（1→4）")
	assert_eq(r.cost, 30)


## 升级：书不足应拒绝
func test_level_up_insufficient() -> void:
	var r := service.level_up(model, "ye_fan", 5)
	assert_false(r.ok, "5 本书不足升级")
	assert_eq(r.reason, "insufficient_books")


## 升星：30 碎片升一星，5 星封顶
func test_promote_star() -> void:
	var r := service.promote_star(model, "ye_fan", 30)
	assert_true(r.ok)
	assert_eq(r.star, 2)
	# 升到满星
	for i in range(4):
		service.promote_star(model, "ye_fan", 30)
	var r5 := service.promote_star(model, "ye_fan", 30)
	assert_false(r5.ok, "满 5 星后不可再升")
	assert_eq(r5.reason, "max_star")


## 装备法宝 / 修炼功法
func test_equip_and_train() -> void:
	var r1 := service.equip_artifact(model, "ye_fan", "artifact_01")
	assert_true(r1.ok)
	assert_eq(model.get_character("ye_fan").get("artifact"), "artifact_01")
	var r2 := service.train_skill(model, "ye_fan", "skill_shengti")
	assert_true(r2.ok)
	assert_eq(model.get_character("ye_fan").get("skills"), ["skill_shengti"])


## 账号境界上限：主角无上限；配角 ≤ 主角-1 大境
func test_realm_ceiling() -> void:
	assert_eq(service.realm_ceiling(model, "ye_fan"), 99, "主角无上限")
	# 主角轮海(0) → 配角上限 = 轮海(3)
	assert_eq(service.realm_ceiling(model, "pang_bo"), 3)
	# 主角道宫(5) → 配角上限 = 道宫(1)
	model.characters["ye_fan"]["sub_index"] = 5
	assert_eq(service.realm_ceiling(model, "pang_bo"), 1)


## 破境上限校验
func test_can_breakthrough_ceiling() -> void:
	var r1 := service.can_breakthrough(model, "pang_bo", 3)
	assert_true(r1.ok, "配角到轮海毕业应允许")
	var r2 := service.can_breakthrough(model, "pang_bo", 4)
	assert_false(r2.ok, "配角突破到道宫应被账号上限拦截")
	assert_eq(r2.reason, "realm_ceiling")


## 修炼位解锁节奏（GDD-001 §3.2.4：初始1 → 轮海毕业2 → 道宫毕业3）
func test_slot_unlock() -> void:
	assert_eq(model.unlocked_slot_count(0), 1, "苦海期仅 1 位")
	assert_eq(model.unlocked_slot_count(3), 2, "轮海毕业(彼岸)解锁第 2 位")
	assert_eq(model.unlocked_slot_count(8), 3, "道宫毕业解锁第 3 位")
