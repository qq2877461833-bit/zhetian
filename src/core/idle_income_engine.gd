class_name IdleIncomeEngine
extends RefCounted
## 放置收益引擎（核心层 · 纯逻辑）· 最小闭环骨架
## REQ-001-3.2.1 / 3.2.3：单修炼位速率 + 离线结算
## 完整实现（多修炼位汇总/修炼位解锁/边际收益）见 EPT-02；此处仅落地公式供单测闭环。

const R0 := 10.0                ## 基础速率 灵/s（REQ-001-3.2.1）
const B := 1.6                  ## 大境界产出倍率
const SUB_BONUS := 0.05         ## 每小段 +5%
const EFF_OFFLINE := 0.8        ## 离线效率 80%（REQ-001-3.2.3）
const CAP_OFFLINE_SEC := 43200  ## 离线封顶 12h


## 单修炼位产出速率 R_c = R0 × B^big × (1 + 0.05 × sub)
## 防御式钳制：负索引按 0 处理（与 calc_offline/RealmEngine.calc_cost 保持一致）
func calc_rate(big_realm_index: int, sub_realm_index: int) -> float:
	big_realm_index = maxi(big_realm_index, 0)
	sub_realm_index = maxi(sub_realm_index, 0)
	return R0 * pow(B, big_realm_index) * (1.0 + SUB_BONUS * sub_realm_index)


## 单修炼位离线收益 L_off = R_c × eff_off × min(Δt, CAP_off)
func calc_offline(rate: float, delta_sec: int) -> float:
	## 防御式钳制（生产语义优于 debug-only assert）：
	## 负时长按 0 处理（收益为 0），负速率按 0 处理
	rate = maxf(rate, 0.0)
	delta_sec = maxi(delta_sec, 0)
	var capped := mini(delta_sec, CAP_OFFLINE_SEC)
	return rate * EFF_OFFLINE * capped


## 离线收益是否触发"已达闭关上限"标记（超 12h）
func is_over_cap(delta_sec: int) -> bool:
	return delta_sec > CAP_OFFLINE_SEC
