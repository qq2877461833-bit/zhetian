# -*- coding: utf-8 -*-
"""扩充装备+功法数据表"""
import json

# ===== 装备扩充：6 -> 16 件 =====
d = json.load(open('data/tables/equipment.json', encoding='utf-8'))
d['items'] = [
  {'id': 'e_wp_001', 'name': '青铜古剑', 'slot': 'weapon', 'rarity': 'fan', 'base_atk': 50, 'base_def': 0, 'base_hp': 0, 'growth': 0.12, 'max_level': 25, 'desc': '荒古禁地出土的青铜古剑，刻有模糊铭文。'},
  {'id': 'e_wp_002', 'name': '紫电神剑', 'slot': 'weapon', 'rarity': 'ling', 'base_atk': 120, 'base_def': 0, 'base_hp': 0, 'growth': 0.15, 'max_level': 25, 'desc': '雷音寺秘藏，剑身蕴紫电之力。'},
  {'id': 'e_wp_003', 'name': '大罗仙剑', 'slot': 'weapon', 'rarity': 'xuan', 'base_atk': 250, 'base_def': 30, 'base_hp': 0, 'growth': 0.18, 'max_level': 25, 'desc': '虚空经中记载的仙剑图谱所铸。'},
  {'id': 'e_wp_004', 'name': '荒古天剑', 'slot': 'weapon', 'rarity': 'di', 'base_atk': 450, 'base_def': 60, 'base_hp': 200, 'growth': 0.20, 'max_level': 25, 'desc': '荒古禁地深处寻得的天兵，剑意通天。'},
  {'id': 'e_wp_005', 'name': '帝兵·虚空剑', 'slot': 'weapon', 'rarity': 'tian', 'base_atk': 800, 'base_def': 100, 'base_hp': 500, 'growth': 0.22, 'max_level': 25, 'desc': '虚空大帝遗兵，一剑可斩山河。'},
  {'id': 'e_ar_001', 'name': '荒古战甲', 'slot': 'armor', 'rarity': 'fan', 'base_atk': 0, 'base_def': 60, 'base_hp': 200, 'growth': 0.10, 'max_level': 25, 'desc': '荒古禁地妖兽鳞甲所制。'},
  {'id': 'e_ar_002', 'name': '天蚕道衣', 'slot': 'armor', 'rarity': 'ling', 'base_atk': 0, 'base_def': 150, 'base_hp': 500, 'growth': 0.12, 'max_level': 25, 'desc': '东荒天蚕丝织就，水火不侵。'},
  {'id': 'e_ar_003', 'name': '玄龟灵甲', 'slot': 'armor', 'rarity': 'xuan', 'base_atk': 0, 'base_def': 300, 'base_hp': 1000, 'growth': 0.14, 'max_level': 25, 'desc': '万年玄龟甲炼制，防御惊世。'},
  {'id': 'e_ar_004', 'name': '天衣无缝', 'slot': 'armor', 'rarity': 'di', 'base_atk': 20, 'base_def': 500, 'base_hp': 2000, 'growth': 0.16, 'max_level': 25, 'desc': '天外玄纱织就，刀枪不入。'},
  {'id': 'e_ac_001', 'name': '玉佩', 'slot': 'accessory', 'rarity': 'fan', 'base_atk': 20, 'base_def': 20, 'base_hp': 100, 'growth': 0.08, 'max_level': 25, 'desc': '九龙拉棺中所得古玉。'},
  {'id': 'e_ac_002', 'name': '辟火珠', 'slot': 'accessory', 'rarity': 'ling', 'base_atk': 50, 'base_def': 40, 'base_hp': 300, 'growth': 0.10, 'max_level': 25, 'desc': '南海鲛人泪所化，万火不侵。'},
  {'id': 'e_ac_003', 'name': '紫金铃', 'slot': 'accessory', 'rarity': 'xuan', 'base_atk': 100, 'base_def': 80, 'base_hp': 600, 'growth': 0.12, 'max_level': 25, 'desc': '紫金神铁所铸，铃声可镇心神。'},
  {'id': 'e_ac_004', 'name': '镇魂钟', 'slot': 'accessory', 'rarity': 'di', 'base_atk': 180, 'base_def': 150, 'base_hp': 1200, 'growth': 0.14, 'max_level': 25, 'desc': '荒古至宝，钟声可碎人魂魄。'},
  {'id': 'e_tl_001', 'name': '火灵符', 'slot': 'talisman', 'rarity': 'fan', 'base_atk': 30, 'base_def': 0, 'base_hp': 0, 'growth': 0.08, 'max_level': 25, 'desc': '朱砂书就的火系灵符。'},
  {'id': 'e_tl_002', 'name': '遁地符', 'slot': 'talisman', 'rarity': 'ling', 'base_atk': 60, 'base_def': 30, 'base_hp': 200, 'growth': 0.10, 'max_level': 25, 'desc': '刻有遁地法阵的宝符。'},
  {'id': 'e_tl_003', 'name': '雷法符', 'slot': 'talisman', 'rarity': 'xuan', 'base_atk': 130, 'base_def': 60, 'base_hp': 500, 'growth': 0.12, 'max_level': 25, 'desc': '蕴九天神雷之力的雷符。'},
]
json.dump(d, open('data/tables/equipment.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('装备扩充完成:', len(d['items']), '件')

# ===== 功法扩充：6 -> 12 本 =====
s = json.load(open('data/tables/skill_sets.json', encoding='utf-8'))
s['books'] = [
  {'id': 'sk_001', 'name': '荒古炼体术', 'category': 'cultivation', 'rarity': 'fan', 'effect': 'idle_rate', 'value': 0.08, 'max_level': 10, 'desc': '荒古禁地流传的炼体法门，修炼产出 +8%'},
  {'id': 'sk_002', 'name': '道宫心法', 'category': 'cultivation', 'rarity': 'ling', 'effect': 'idle_rate', 'value': 0.15, 'max_level': 15, 'desc': '道宫秘境悟得心法，修炼速率 +15%'},
  {'id': 'sk_003', 'name': '六道轮回拳', 'category': 'combat', 'rarity': 'ling', 'effect': 'atk_bonus', 'value': 0.12, 'max_level': 12, 'desc': '从圣体中悟出拳法，攻击力 +12%'},
  {'id': 'sk_004', 'name': '虚空经·镇', 'category': 'combat', 'rarity': 'xuan', 'effect': 'atk_bonus', 'value': 0.25, 'max_level': 20, 'desc': '虚空大帝镇世功法，攻击力 +25%'},
  {'id': 'sk_005', 'name': '紫气东来诀', 'category': 'utility', 'rarity': 'fan', 'effect': 'energy_recover', 'value': 0.20, 'max_level': 10, 'desc': '紫气导引术，体力恢复 +20%'},
  {'id': 'sk_006', 'name': '源天书', 'category': 'utility', 'rarity': 'ling', 'effect': 'yuan_bonus', 'value': 0.15, 'max_level': 15, 'desc': '天书奇技，源石收益 +15%'},
  {'id': 'sk_007', 'name': '混沌诀', 'category': 'cultivation', 'rarity': 'xuan', 'effect': 'idle_rate', 'value': 0.25, 'max_level': 20, 'desc': '混沌初开之秘，修炼速率 +25%'},
  {'id': 'sk_008', 'name': '神魔拳', 'category': 'combat', 'rarity': 'di', 'effect': 'atk_bonus', 'value': 0.40, 'max_level': 25, 'desc': '神魔之躯演化拳法，攻击力 +40%'},
  {'id': 'sk_009', 'name': '一气化三清', 'category': 'cultivation', 'rarity': 'di', 'effect': 'idle_rate', 'value': 0.40, 'max_level': 25, 'desc': '道家无上秘术，修炼速率 +40%'},
  {'id': 'sk_010', 'name': '斩我明道诀', 'category': 'combat', 'rarity': 'tian', 'effect': 'atk_bonus', 'value': 0.60, 'max_level': 30, 'desc': '斩尽自我方见真我，攻击力 +60%'},
  {'id': 'sk_011', 'name': '欺天术', 'category': 'utility', 'rarity': 'di', 'effect': 'energy_recover', 'value': 0.50, 'max_level': 25, 'desc': '欺瞒天道之术，体力恢复 +50%'},
  {'id': 'sk_012', 'name': '无字天书', 'category': 'utility', 'rarity': 'tian', 'effect': 'yuan_bonus', 'value': 0.60, 'max_level': 30, 'desc': '无字胜有字，源石收益 +60%'},
]
json.dump(s, open('data/tables/skill_sets.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('功法扩充完成:', len(s['books']), '本')
