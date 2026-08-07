class_name CharacterService
extends RefCounted
## 角色养成服务（核心层 · 纯逻辑）· Sprint 2
## REQ-002-3.2 / 3.3：五维养成（等级/破境/升星/法宝/功法）+ 账号境界上限
## 数据来源：data/tables/character.json（数据表唯一事实来源）

var _char_tbl: Dictionary


func _init(char_tbl: Dictionary = {}) -> void:
	_char_tbl = char_tbl


func char_def(char_id: String) -> Dictionary:
	for c in _char_tbl.get("characters", []):
		if c.get("id") == char_id:
			return c
	return {}


## 升等级：消耗经验书数量，返回 {ok, level, cost}
func level_up(model: SaveModel, char_id: String, books: int) -> Dictionary:
	var c := model.get_character(char_id)
	if c.is_empty():
		return { "ok": false, "reason": "char_not_found" }
	var cost_per := 10  ## 每级 10 经验书（占位，数值表细化后替换）
	if books < cost_per:
		return { "ok": false, "reason": "insufficient_books", "need": cost_per }
	var lv := int(c.get("level", 1))
	var gained := floori(books / cost_per)
	c["level"] = lv + gained
	return { "ok": true, "level": c["level"], "cost": gained * cost_per }


## 升星：消耗同名碎片，返回 {ok, star}
func promote_star(model: SaveModel, char_id: String, fragments: int) -> Dictionary:
	var c := model.get_character(char_id)
	if c.is_empty():
		return { "ok": false, "reason": "char_not_found" }
	var need := int(char_def(char_id).get("fragments_for_star", 30))
	if fragments < need:
		return { "ok": false, "reason": "insufficient_fragments", "need": need }
	var star := int(c.get("star", 1))
	if star >= 5:
		return { "ok": false, "reason": "max_star" }
	c["star"] = star + 1
	return { "ok": true, "star": c["star"], "cost": need }


## 装备法宝：{ok, artifact}
func equip_artifact(model: SaveModel, char_id: String, artifact_id: String) -> Dictionary:
	var c := model.get_character(char_id)
	if c.is_empty():
		return { "ok": false, "reason": "char_not_found" }
	c["artifact"] = artifact_id
	return { "ok": true, "artifact": artifact_id }


## 修炼功法：{ok, skills}
func train_skill(model: SaveModel, char_id: String, skill_id: String) -> Dictionary:
	var c := model.get_character(char_id)
	if c.is_empty():
		return { "ok": false, "reason": "char_not_found" }
	var skills: Array = c.get("skills", [])
	if not skills.has(skill_id):
		skills.append(skill_id)
	c["skills"] = skills
	return { "ok": true, "skills": skills }


## 账号境界上限（GDD-002 §3.3）：非主角 ≤ 主角 - 1 大境
## 主角 = 账号主线境界（以主角 ye_fan 为代表）
func realm_ceiling(model: SaveModel, char_id: String) -> int:
	if char_id == "ye_fan":
		return 99  ## 主角无上限（账号进度本身）
	var main_sub := int(model.get_character("ye_fan").get("sub_index", 0))
	## 主角在轮海(0-3) → 上限轮海；主角在道宫(4-8) → 配角上限 = 主角-1大境（轮海毕业）
	if main_sub < 4:
		return 3
	return main_sub - 4


## 角色能否破境到 sub_index（账号上限校验）
func can_breakthrough(model: SaveModel, char_id: String, target_sub: int) -> Dictionary:
	var ceiling := realm_ceiling(model, char_id)
	if target_sub > ceiling:
		return { "ok": false, "reason": "realm_ceiling", "ceiling": ceiling }
	return { "ok": true, "ceiling": ceiling }
