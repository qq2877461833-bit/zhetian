class_name RealmEngine
extends RefCounted
## 境界引擎（核心层 · 纯逻辑）
## REQ-001-3.1 / 3.3：突破成本与关卡验证
## 数据驱动：cost_table 优先（realm.json breakthrough_costs 为唯一事实来源），无表回退公式

const C0_LING := 50000.0          ## 苦海→命泉首段灵石成本（公式回退用）
const C0_YUAN := 2.0              ## 首段源石成本（公式回退用）
const COST_GROWTH_LING := 1.65    ## 灵石成本指数（公式回退用）
const COST_GROWTH_YUAN := 1.55    ## 源石成本指数（公式回退用）

var _cost_table: Array = []       ## 突破成本表（realm.json breakthrough_costs，注入用）


func _init(cost_table: Array = []) -> void:
	_cost_table = cost_table


## 第 i 个小段突破成本与关卡要求（i = 0..8）
## 返回 { ling:int, yuan:int, stage_req:int }
func calc_cost(sub_index: int) -> Dictionary:
	## 防御式钳制：负索引按 0 处理（生产语义优于 debug-only assert）
	sub_index = maxi(sub_index, 0)
	## 表驱动优先（数据表唯一事实来源；含阶梯式源石梯度 2/3/5/8/13/21/34/55/89）
	if sub_index < _cost_table.size():
		var row: Dictionary = _cost_table[sub_index]
		return {
			"ling": int(row.get("cost_ling", 0)),
			"yuan": int(row.get("cost_yuan", 0)),
			"stage_req": int(row.get("stage_req", 0)),
		}
	## 公式回退（表外索引）
	var ling := int(C0_LING * pow(COST_GROWTH_LING, sub_index))
	var yuan := int(C0_YUAN * pow(COST_GROWTH_YUAN, floori(sub_index / 4.0)))
	var stage_req := 3 * sub_index + 1
	return { "ling": ling, "yuan": yuan, "stage_req": stage_req }


## 校验能否突破（骨架：仅校验参数合法性；资源/关卡/等待完整校验由 EPT-02-S02 落地）
func can_breakthrough(profile: Dictionary, char_id: String) -> Dictionary:
	var cost := calc_cost(_sub_index_of(profile, char_id))
	return { "can": true, "cost": cost, "reason": "" }


func _sub_index_of(profile: Dictionary, char_id: String) -> int:
	var c: Dictionary = profile.get("characters", {}).get(char_id, {})
	return int(c.get("sub_index", 0))
