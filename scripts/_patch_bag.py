# -*- coding: utf-8 -*-
"""写背包页到 main.gd"""
import io

p = 'src/main.gd'
s = io.open(p, encoding='utf-8').read()

anchor = '# --------------------------- 功法页 ---------------------------'

bag = '''# --------------------------- 背包页 ---------------------------

func _build_bag() -> void:
\tvar box := VBoxContainer.new()
\tbox.set_anchors_preset(Control.PRESET_FULL_RECT)
\tbox.add_theme_constant_override("separation", 8)
\tbox.offset_left = 4; box.offset_top = 4
\t_content.add_child(box)
\tbox.add_child(_mk_title("背包 · 所有获得物", 20))
\tvar items: Array = _model.inventory.keys()
\tif items.is_empty():
\t\tbox.add_child(_mk_dim("背包空空如也——抽卡/副本获得物品会显示在这里", 14))
\t\treturn
\tfor k in items:
\t\tvar iid := String(k)
\t\tvar count := int(_model.inventory[iid])
\t\tif count <= 0:
\t\t\tcontinue
\t\tvar name := _treasure_name("", iid)
\t\tvar kind := _bag_kind(iid)
\t\tvar row := HBoxContainer.new()
\t\trow.add_theme_constant_override("separation", 10)
\t\trow.add_theme_stylebox_override("panel", _panel_style(C_PANEL, C_GOLD_DIM))
\t\tbox.add_child(row)
\t\tvar icon := TextureRect.new()
\t\tvar tex: Texture2D = load(_bag_icon(iid))
\t\tif tex != null:
\t\t\ticon.texture = tex
\t\t\ticon.custom_minimum_size = Vector2(32, 32)
\t\t\ticon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
\t\t\ticon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
\t\t\trow.add_child(icon)
\t\trow.add_child(_mk_label("%s ×%d" % [name, count], 15))
\t\trow.add_child(_mk_dim(kind, 13))
\tbox.add_child(_mk_dim("提示：重复帝兵/功法会转化为命座或残卷材料；装备强化/功法修炼消耗灵石与残卷", 13))


## 背包物品类别
func _bag_kind(iid: String) -> String:
\tif iid.begins_with("e_"):
\t\treturn "帝兵"
\tif iid.begins_with("sk_"):
\t\treturn "功法"
\tif iid == "mat_equip_shard":
\t\treturn "装备残卷"
\tif iid == "mat_skill_shard":
\t\treturn "功法残卷"
\tif iid == "mat_ling_pack":
\t\treturn "灵石包"
\tif iid == "mat_yuan_shard":
\t\treturn "源石碎片"
\treturn "材料"


## 背包物品 icon
func _bag_icon(iid: String) -> String:
\tif iid.begins_with("e_"):
\t\tvar item := _eq_svc.find_item(iid)
\t\tvar slot := String(item.get("slot", ""))
\t\tvar m := {"weapon": "equip_weapon", "armor": "equip_armor", "accessory": "equip_accessory", "talisman": "equip_talisman"}
\t\treturn "res://assets/icons/%s.webp" % String(m.get(slot, "equip_weapon"))
\tif iid.begins_with("sk_"):
\t\tvar book := _sk_svc.find_book(iid)
\t\tvar cat := String(book.get("category", ""))
\t\tif cat == "cultivation": return "res://assets/icons/skill_cultivation.webp"
\t\tif cat == "combat": return "res://assets/icons/skill_combat.webp"
\t\treturn "res://assets/icons/skill_book.webp"
\tif iid == "mat_ling_pack": return "res://assets/icons/res_ling.webp"
\tif iid == "mat_yuan_shard": return "res://assets/icons/res_yuan.webp"
\treturn "res://assets/icons/skill_book.webp"


# --------------------------- 功法页 ---------------------------'''

assert anchor in s
s = s.replace(anchor, bag, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("bag page added")
