class_name ArenaService
extends RefCounted
## 帝路竞技服务（核心层 · 纯逻辑）· Sprint 4
## REQ-005-2.1~2.6：异步 PvP（镜像快照/服务端结算）+ 六段位 + 30 天赛季 + 每日 10 次
## 数据来源：data/tables/arena.json（唯一事实来源）；服务端权威（ADR-0003 防篡改点⑦）后续替换

## 六段位（REQ-005-2.2 定案：凡人→修士→真人→道宫→王者→帝路）
const TIERS := [
	{ "id": "fanren", "name": "凡人", "min_score": 0 },
	{ "id": "xiushi", "name": "修士", "min_score": 1000 },
	{ "id": "zhenren", "name": "真人", "min_score": 1200 },
	{ "id": "daogong", "name": "道宫", "min_score": 1400 },
	{ "id": "wangzhe", "name": "王者", "min_score": 1600 },
	{ "id": "dilu", "name": "帝路", "min_score": 1800 },
]
const SEASON_DAYS := 30          ## 赛季长度（REQ-005-2.3）
const DAILY_CHALLENGES := 10     ## 每日挑战次数（REQ-005-2.1：不耗体力耗次数）
const SCORE_WIN := 30            ## 胜利加分
const SCORE_LOSE := -15          ## 失败扣分
const OPPONENT_COUNT := 5        ## 对手列表 5 名（REQ-005-2.4）


## 按积分取段位
func tier_for(score: int) -> Dictionary:
	var tier := TIERS[0]
	for t in TIERS:
		if score >= int(t.get("min_score", 0)):
			tier = t
	return tier


## 生成对手快照列表（基于玩家战力 ± 浮动，镜像风格）
## power: 玩家队伍战力估算；返回 Array[Dictionary]（id/name/class/base/power）
func generate_opponents(power: float, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var classes := ["huanggu_tizhi", "xiandao_shentong", "bingqi_liupai"]
	for i in range(OPPONENT_COUNT):
		var ratio := 0.85 + rng.randf() * 0.35  ## 0.85 ~ 1.20
		var op_power := power * ratio
		var cls := String(classes[i % 3])
		out.append({
			"id": "opp_%d" % (i + 1),
			"name": "修士·%d" % (i + 1),
			"class": cls,
			"base": {
				"hp": op_power * 1.2, "atk": op_power * 0.08,
				"def": op_power * 0.06, "spd": 90 + (i * 7),
			},
			"power": op_power,
		})
	return out


## 挑战结算：返回 { ok, win, score_delta, new_score, tier, reason }
## model.stats: arena_score / arena_daily_<day> / arena_season_start
func challenge(model: SaveModel, day_key: String, win: bool) -> Dictionary:
	## 赛季校验（简化：赛季开始后 30 天）
	var season_start := int(model.stats.get("arena_season_start", 0))
	if season_start > 0:
		var elapsed := _days_since(season_start)
		if elapsed >= SEASON_DAYS:
			return { "ok": false, "reason": "season_ended" }
	## 每日次数
	var daily_key := "arena_daily_%s" % day_key
	var used := int(model.stats.get(daily_key, 0))
	if used >= DAILY_CHALLENGES:
		return { "ok": false, "reason": "daily_limit" }
	model.stats[daily_key] = used + 1
	## 积分结算
	var score := int(model.stats.get("arena_score", 1000))
	score += SCORE_WIN if win else SCORE_LOSE
	score = maxi(score, 0)
	model.stats["arena_score"] = score
	return { "ok": true, "win": win, "score_delta": SCORE_WIN if win else SCORE_LOSE, "new_score": score, "tier": tier_for(score) }


## 赛季状态：{ started, days_left, season }
func season_status(model: SaveModel) -> Dictionary:
	var start := int(model.stats.get("arena_season_start", 0))
	if start <= 0:
		return { "started": false, "days_left": SEASON_DAYS }
	return { "started": true, "days_left": maxi(SEASON_DAYS - _days_since(start), 0) }


func _days_since(unix_ts: int) -> int:
	var now := Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system())
	return int((now - float(unix_ts)) / 86400.0)
