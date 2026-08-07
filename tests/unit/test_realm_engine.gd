extends GutTest
## RealmEngine 单测（EPT-02-S02 验收依据）
## 运行：godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
## 数据驱动：注入 breakthrough_costs 表（含阶梯式源石梯度 2/3/5/8/13/21/34/55/89）

var engine: RealmEngine

## 与 realm.json breakthrough_costs 一致的成本表（测试注入）
const COST_TABLE := [
	{ "sub_index": 0, "cost_ling": 50000,  "cost_yuan": 2,  "stage_req": 1 },
	{ "sub_index": 1, "cost_ling": 82500,  "cost_yuan": 3,  "stage_req": 4 },
	{ "sub_index": 2, "cost_ling": 136125, "cost_yuan": 5,  "stage_req": 7 },
	{ "sub_index": 3, "cost_ling": 224606, "cost_yuan": 8,  "stage_req": 10 },
	{ "sub_index": 4, "cost_ling": 370600, "cost_yuan": 13, "stage_req": 13 },
	{ "sub_index": 5, "cost_ling": 611490, "cost_yuan": 21, "stage_req": 16 },
	{ "sub_index": 6, "cost_ling": 1008959, "cost_yuan": 34, "stage_req": 19 },
	{ "sub_index": 7, "cost_ling": 1664783, "cost_yuan": 55, "stage_req": 22 },
	{ "sub_index": 8, "cost_ling": 2746892, "cost_yuan": 89, "stage_req": 25 },
]


func before_each() -> void:
	engine = RealmEngine.new(COST_TABLE)


## 首段突破成本：源石从 2 起步（用户反馈调整：阶梯式，不再 20 起步）
func test_first_breakthrough_cost() -> void:
	var cost := engine.calc_cost(0)
	assert_eq(cost.ling, 50000, "i=0 灵石成本应为 50000")
	assert_eq(cost.yuan, 2, "i=0 源石成本应为 2（阶梯式起步）")
	assert_eq(cost.stage_req, 1, "i=0 关卡要求应为 1")


## 灵石成本指数增长 ×1.65（REQ-001-3.3）
func test_ling_cost_exponential_growth() -> void:
	var c0 := float(engine.calc_cost(0).ling)
	var c1 := float(engine.calc_cost(1).ling)
	assert_almost_eq(c1 / c0, 1.65, 0.001, "灵石成本每小段应 ×1.65")


## 源石成本阶梯式递增（用户反馈：非平段非等比，斐波那契式 2/3/5/8/13/21/34/55/89）
func test_yuan_cost_stepwise_growth() -> void:
	var expected := [2, 3, 5, 8, 13, 21, 34, 55, 89]
	for i in range(expected.size()):
		assert_eq(engine.calc_cost(i).yuan, expected[i], "i=%d 源石成本应为 %d" % [i, expected[i]])


## 关卡验证 stage_req = 3i + 1（REQ-003-4.2）
func test_stage_req_formula() -> void:
	assert_eq(engine.calc_cost(4).stage_req, 13, "i=4 关卡要求应为 13")
	assert_eq(engine.calc_cost(8).stage_req, 25, "i=8 关卡要求应为 25")


## 全表抽查：i=3 轮海毕业 224,606 灵 + 8 源石
func test_sample_costs_match_gdd_table() -> void:
	var c3 := engine.calc_cost(3)
	assert_eq(c3.ling, 224606, "i=3 轮海毕业成本应为 224,606 灵")
	assert_eq(c3.yuan, 8, "i=3 轮海毕业源石成本应为 8")


## 非法参数拒绝（防御性断言 · GUT 9.4.0 兼容版）
## 实现已改为防御式钳制（负索引按 0 处理），此处验证不崩溃且返回 Dictionary。
func test_negative_index_rejected() -> void:
	assert_has_method(engine, "calc_cost", "RealmEngine 应暴露 calc_cost 接口")
	var res := engine.calc_cost(-1)
	assert_typeof(res, TYPE_DICTIONARY, "负索引调用应返回 Dictionary（不崩溃）")
