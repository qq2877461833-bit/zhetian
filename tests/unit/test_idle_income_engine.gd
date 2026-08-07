extends GutTest
## IdleIncomeEngine 最小单测骨架（EPT-02-S03/S04 验收依据）
## 运行：godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

var engine: IdleIncomeEngine

func before_each() -> void:
	engine = IdleIncomeEngine.new()


## 速率公式与 GDD-001 §3.2.1 样例一致
func test_rate_kuhai() -> void:
	# 苦海 (0,0) → 10 × 1.6^0 × 1.00 = 10
	assert_almost_eq(engine.calc_rate(0, 0), 10.0, 0.001, "苦海速率应为 10 灵/s")


func test_rate_bi_an() -> void:
	# 彼岸 (0,3) → 10 × 1.15 = 11.5
	assert_almost_eq(engine.calc_rate(0, 3), 11.5, 0.001, "彼岸速率应为 11.5 灵/s")


func test_rate_shen_zang() -> void:
	# 肾藏 (1,4) → 10 × 1.6 × 1.20 = 19.2
	assert_almost_eq(engine.calc_rate(1, 4), 19.2, 0.001, "肾藏速率应为 19.2 灵/s")


## 离线结算：12h 封顶内 = R × 0.8 × Δt
func test_offline_12h() -> void:
	var rate := engine.calc_rate(0, 0)
	var total := engine.calc_offline(rate, 43200)
	assert_almost_eq(total, 10.0 * 0.8 * 43200, 0.001, "离线 12h = 345,600 灵")
	assert_false(engine.is_over_cap(43200), "恰好 12h 不算超限")


## 离线超限：超出 12h 不产出（REQ-001-3.2.3 封顶）
func test_offline_over_cap_capped() -> void:
	var rate := engine.calc_rate(0, 0)
	var over := engine.calc_offline(rate, 90000)
	assert_almost_eq(over, 10.0 * 0.8 * 43200, 0.001, "超过 12h 仍按 12h 封顶结算")
	assert_true(engine.is_over_cap(90000), "90,000s 应标记已达闭关上限")


## 离线 0s 边界
func test_offline_zero() -> void:
	var rate := engine.calc_rate(0, 0)
	assert_almost_eq(engine.calc_offline(rate, 0), 0.0, 0.001, "离线 0s 收益为 0")


## 非法参数拒绝（防御性断言 · GUT 9.4.0 兼容版）
## 注：assert_has_failure_when_calling 为 GUT 9.5+ API，9.4.0 不可用；
## 负时长语义上按 0 收益处理（max(0, delta)），不崩溃即可。
func test_negative_delta_rejected() -> void:
	assert_has_method(engine, "calc_offline", "IdleIncomeEngine 应暴露 calc_offline 接口")
	var res := engine.calc_offline(10.0, -5)
	assert_almost_eq(res, 0.0, 0.001, "负离线时长收益应为 0（不崩溃）")
