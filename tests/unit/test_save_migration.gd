extends GutTest
## 存档迁移测试（打磨期 QA）：V3 旧档 → V5 新档必须安全加载
## 旧档缺少 equipment/active_skills/inventory 字段 → 默认空，不崩

var model: SaveModel


func test_v3_old_save_migrates_safely() -> void:
	## 模拟 V3 存档（无 equipment/active_skills/inventory 字段）
	var old := {
		"version": 3,
		"player": { "ling": 100, "yuan": 5, "energy": 80, "last_offline_ts": 0 },
		"cleared_stages": ["s_001"],
		"gacha_tickets": 10,
		"characters": { "ye_fan": { "sub_index": 2, "level": 3 } },
		"slots": { 0: "ye_fan" },
		"gacha": { "global": { "di_pity": 5, "tian_pity": 2 } },
		"stats": { "tower_floor": 3 },
	}
	var m := SaveModel.from_dict(old)
	assert_eq(m.ling, 100, "灵石迁移")
	assert_eq(m.gacha_tickets, 10, "抽卡券迁移")
	assert_true(m.equipment.is_empty(), "旧档无装备默认空")
	assert_true(m.active_skills.is_empty(), "旧档无功默认空")
	assert_true(m.inventory.is_empty(), "旧档无背包默认空")
	assert_eq(m.stats.get("tower_floor", 0), 3, "stats 保留")


func test_v4_save_roundtrip_with_new_fields() -> void:
	## V5 新档 to_dict → from_dict 回环：装备/功法/背包/命座完整保留
	var m := SaveModel.default_save()
	m.ling = 5000
	m.equipment["weapon"] = "e_wp_001"
	m.equipment["armor"] = "e_ar_001"
	m.active_skills = ["sk_001", "sk_003"]
	m.inventory["mat_skill_shard"] = 3
	m.inventory["e_wp_001"] = 2
	m.stats["sk_con_sk_001"] = 2
	m.stats["sk_lv_sk_001"] = 5
	m.stats["eq_lv_weapon"] = 7
	var d := m.to_dict()
	var m2 := SaveModel.from_dict(d)
	assert_eq(m2.equipment.get("weapon", ""), "e_wp_001", "装备武器保留")
	assert_eq(m2.equipment.get("armor", ""), "e_ar_001", "装备防具保留")
	assert_eq(m2.active_skills.size(), 2, "功法保留")
	assert_eq(m2.inventory.get("mat_skill_shard", 0), 3, "背包残卷保留")
	assert_eq(m2.inventory.get("e_wp_001", 0), 2, "背包宝物保留")
	assert_eq(int(m2.stats.get("sk_con_sk_001", 0)), 2, "命座保留")
	assert_eq(int(m2.stats.get("sk_lv_sk_001", 0)), 5, "功法等级保留")
	assert_eq(int(m2.stats.get("eq_lv_weapon", 0)), 7, "装备等级保留")


func test_default_save_has_hero_and_tickets() -> void:
	var m := SaveModel.default_save()
	assert_true(m.characters.has("ye_fan"), "新档必有主角")
	assert_true(m.equipment.is_empty(), "新档装备空（靠抽卡解锁）")
	assert_true(m.active_skills.is_empty(), "新档功法空")
