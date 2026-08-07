extends GutTest
## ArenaService 单测（Sprint 4）
## REQ-005-2.1~2.6：六段位/每日次数/赛季/积分结算/对手生成

var svc: ArenaService
var model: SaveModel


func before_each() -> void:
	svc = ArenaService.new()
	model = SaveModel.default_save()
	model.stats["arena_score"] = 1000
	model.stats["arena_season_start"] = int(Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system()))


## 六段位划分
func test_tiers() -> void:
	assert_eq(String(svc.tier_for(500).get("id", "")), "fanren", "0-999 凡人")
	assert_eq(String(svc.tier_for(1000).get("id", "")), "xiushi", "1000 修士")
	assert_eq(String(svc.tier_for(1300).get("id", "")), "zhenren", "1200+ 真人")
	assert_eq(String(svc.tier_for(1500).get("id", "")), "daogong", "1400+ 道宫")
	assert_eq(String(svc.tier_for(1700).get("id", "")), "wangzhe", "1600+ 王者")
	assert_eq(String(svc.tier_for(2000).get("id", "")), "dilu", "1800+ 帝路")


## 挑战胜利加分 / 失败扣分
func test_challenge_score() -> void:
	var r1 := svc.challenge(model, "20260807", true)
	assert_true(r1.ok)
	assert_eq(r1.score_delta, 30)
	assert_eq(model.stats["arena_score"], 1030, "胜 +30")
	var r2 := svc.challenge(model, "20260807", false)
	assert_eq(model.stats["arena_score"], 1015, "败 -15")


## 每日 10 次上限
func test_daily_limit() -> void:
	model.stats["arena_daily_20260807"] = 10
	var r := svc.challenge(model, "20260807", true)
	assert_false(r.ok)
	assert_eq(r.reason, "daily_limit")


## 对手生成：5 名，战力在玩家 ±20% 区间
func test_generate_opponents() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var opps := svc.generate_opponents(1000.0, rng)
	assert_eq(opps.size(), 5, "应生成 5 名对手")
	for o in opps:
		var p := float(o.get("power", 0))
		assert_true(p >= 800.0 and p <= 1250.0, "对手战力应在 0.8~1.25 倍玩家")


## 赛季状态：初始未开始 / 开始后 30 天
func test_season_status() -> void:
	var s0 := svc.season_status(model)
	assert_true(s0.started, "有 season_start 应视为已开始")
	assert_eq(s0.days_left, 30, "首日剩余 30 天")
	var m2 := SaveModel.default_save()
	var s1 := svc.season_status(m2)
	assert_false(s1.started, "无 season_start 未开始")


## 负积分不跌穿 0
func test_score_floor() -> void:
	model.stats["arena_score"] = 10
	var r := svc.challenge(model, "20260807", false)
	assert_eq(model.stats["arena_score"], 0, "扣分不低于 0")
	assert_eq(r.new_score, 0)
