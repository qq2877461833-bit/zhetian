# -*- coding: utf-8 -*-
"""飘字真实伤害 + 暴击/闪避统计（逐条独立替换）"""
import io

p = 'src/main.gd'
s = io.open(p, encoding='utf-8').read()
cnt = 0

# 1. 四段飘字 → 真实伤害数组
repl = [
    ('dmg.text = "伤害 %d" % (300 + rounds * 7)',
     'dmg.text = "伤害 %d" % int(enemy_dmgs[0])'),
    ('dmg.text = "敌伤 %d" % (150 + rounds * 4)',
     'dmg.text = "敌伤 %d" % int(hero_dmgs[0])'),
    ('dmg.text = "伤害 %d" % (200 + rounds * 5)',
     'dmg.text = ("伤害 %d" % int(enemy_dmgs[1])) if enemy_dmgs.size() > 1 else ("伤害 %d" % int(enemy_dmgs[0]))'),
    ('dmg.text = "敌伤 %d" % (120 + rounds * 3)',
     'dmg.text = ("敌伤 %d" % int(hero_dmgs[1])) if hero_dmgs.size() > 1 else ("敌伤 %d" % int(hero_dmgs[0]))'),
]
for old, new in repl:
    if old in s:
        s = s.replace(old, new)
        cnt += 1

# 2. 结果文案加暴击/闪避统计
old_note = '\t\tresult_label.text += "\\n" + note)'
new_note = '''\t\tvar stats_txt := ""
\t\tvar cc := int(result.get("crit_count", 0))
\t\tvar dc := int(result.get("dodge_count", 0))
\t\tif cc > 0: stats_txt += "暴击 %d 次" % cc
\t\tif dc > 0: stats_txt += (" · " if stats_txt != "" else "") + "闪避 %d 次" % dc
\t\tresult_label.text += "\\n" + note + (("  （" + stats_txt + "）") if stats_txt != "" else ""))'''
if old_note in s:
    s = s.replace(old_note, new_note)
    cnt += 1

io.open(p, 'w', encoding='utf-8').write(s)
print("替换完成，共 %d 处" % cnt)
