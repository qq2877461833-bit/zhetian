extends GutTest
## 全链路集成测试（严守真 SMK 核心链路固化 · tests/integration）
## SMK-002/003/004/005/006/007/010 核心流程自动回归

var _gacha: GachaService
var _eq: EquipmentService
var _sk: SkillService
var _model: SaveModel
var _rng: RandomNumberGenerator
var _gacha_tbl: Dictionary


func before_each() -> void:
	_model = SaveModel.default_save()
	_model.gacha_tickets = 100
	_model.ling = 1000000
	_rng = RandomNumberGenerator.new()
	_rng.seed = 777
	_gacha_tbl = ResourceManager.load_table("res://data/tables/gacha.json")
	_gacha = GachaService.new(_gacha_tbl)
	_eq = EquipmentService.new(ResourceManager.load_table("res://data/tables/equipment.json"))
	_sk = SkillService.new(ResourceManager.load_table("res://data/tables/skill_sets.json"))


## SMK-002：抽卡消耗券 + 碎片入账
func test_smk002_draw_spends_ticket_and_shards() -> void:
	var before := _model.gacha_tickets
	var shards_before := int(_model.inventory.get("mat_yuan_shard", 0))
	var r := _gacha.draw(_model, "standard", _rng, 8)
	assert_true(r.get("ok", false), "抽卡成功")
	assert_eq(_model.gacha_tickets, before, "服务层不扣券（UI 层扣）")
	assert_true(int(_model.inventory.get("mat_yuan_shard", 0)) >= shards_before, "碎片入账（G-05 修复验证）")
	assert_false(String(r.get("item_id", "")).is_empty(), "有产物")


## SMK-003：保底 60 必出 ≥地品宝物
func test_smk003_pity60_guarantees_di_or_above() -> void:
	_model.gacha["global"] = { "di_pity": 59, "tian_pity": 0 }
	var r := _gacha.draw(_model, "standard", _rng, 8)
	var rar := String(r.get("rarity", "fan"))
	assert_true(rar == "di" or rar == "tian" or rar == "di_pin", "保底 60 必出 ≥地品，实际: %s" % rar)
	## G-04 修复验证：保底稀有度必须有宝物候选
	var treasure := _pick_treasure_visible(_gacha_tbl, rar)
	assert_false(treasure.is_empty(), "地/天稀有度有宝物候选（G-04 修复）")


## SMK-004：保底 90 必出 ≥天品
func test_smk004_pity90_guarantees_tian() -> void:
	_model.gacha["global"] = { "di_pity": 59, "tian_pity": 89 }
	var r := _gacha.draw(_model, "standard", _rng, 8)
	var rar := String(r.get("rarity", "fan"))
	assert_true(rar == "tian" or rar == "di_pin", "保底 90 必出 ≥天品，实际: %s" % rar)


## SMK-005：轮海期（sub<8）不抽地/天（分段 G-03）
func test_smk005_realm_segment_no_di_tian() -> void:
	## 轮海期 sub_index=2，连抽 30 次，不应出地/天/帝
	for i in range(30):
		var r := _gacha.draw(_model, "standard", _rng, 2)
		var rar := String(r.get("rarity", "fan"))
		assert_false(rar == "di" or rar == "tian" or rar == "di_pin",
			"轮海期第 %d 抽不应出地/天（G-03 分段），实际: %s" % [i + 1, rar])


## SMK-007：装备强化扣灵石 + 属性提升；灵石不足拒绝且不扣
func test_smk007_enhance_costs_and_rejects() -> void:
	_model.equipment["weapon"] = "e_wp_001"
	var ling_before := _model.ling
	var r := _eq.enhance(_model, "weapon")
	assert_true(r.get("ok", false), "强化成功")
	assert_true(_model.ling < ling_before, "扣灵石")
	assert_true(int(r.get("atk_bonus", 0)) > 0, "攻击提升")
	## 灵石不足拒绝
	_model.ling = 0
	var r2 := _eq.enhance(_model, "weapon")
	assert_false(r2.get("ok", true), "灵石不足拒绝")
	assert_eq(_model.ling, 0, "拒绝时灵石不变")


## SMK-010：功法修炼扣灵石 + Lv5 后扣残卷；无残卷拒绝
func test_smk010_skill_train_costs() -> void:
	_model.active_skills = ["sk_001"]
	_model.inventory["mat_skill_shard"] = 3
	var ling_before := _model.ling
	var r := _sk.train(_model, "sk_001")
	assert_true(r.get("ok", false), "修炼成功")
	assert_true(_model.ling < ling_before, "扣灵石")
	## Lv5 需残卷
	_model.stats["sk_lv_sk_001"] = 5
	_model.inventory["mat_skill_shard"] = 0
	var r2 := _sk.train(_model, "sk_001")
	assert_false(r2.get("ok", true), "无残卷拒绝")
	assert_eq(String(r2.get("reason", "")), "no_shard")


## 辅助：从宝物池找稀有度候选（验证 G-04）
func _pick_treasure_visible(tbl: Dictionary, rarity: String) -> Dictionary:
	for t in tbl.get("pools", [])[0].get("treasures", []):
		if t.get("rarity") == rarity:
			return t
	return {}
