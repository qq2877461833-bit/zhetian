# 《遮天》项目长期笔记（MEMORY.md）

## 项目定位
- 《遮天》IP 修仙玄幻游戏 · 目标平台 Web/多端（浏览器优先）· 评审强度 Full
- 工作室流水线推进（主理人游承峰编排，成员：design-strategist / art-director / engineering-lead / audio-director / quality-lead / release-ops-lead）
- **项目主路径：E:/林珩/数据库/遮天**（2026-08-07 从 C 盘搬迁；C 盘旧档用户自行删除）

## 方向调整（2026-08-07 用户拍板）
- **玩法形态改为「单主角修仙」**（一念逍遥式）：主角修炼→突破→推关，装备/功法培养；**非**抽卡多角色战斗
- **禁忌词**：「一念逍遥」字样禁止出现在游戏任何内容（已清零，UI/注释/数据表）
- 页签：修炼 / 抽卡 / 装备 / 副本 / 功法（图鉴、帝路已移除）
- 战斗：BattleService.simulate_solo（单主角+装备加成+功法加成 vs 敌人，K=300）
- 装备：equipment.json（4槽 武器/防具/饰品/符箓 + 强化，成长1.15，上限25级，升阶源石1/2/3/5/8）
- 功法：skill_sets.json（3类6本 + 修炼 + 装备3格；源天书0.15防倒挂）
- 数值审查（文策渊）4 项已修订；技术审查（程基岩）致命 bug（装备不落盘）已修复

## 美术（art-director 审查后统一）
- icon 统一模板：东方荒古修仙·Q版·墨青底·鎏金#C9A86A描边·符箓刻纹·无水印
- 15 张关键图已统一（装备4/资源4/功法3/副本4/主角）+ 敌人2（妖兽/魔修）
- 压缩管线：tools/compress_icons.py（webp 82q，icon 160px）→ pck 4.2MB
- 战斗演出：_battle_layer 独立层（不动 _popup）；伤害飘字纯文本（字体不含 ⚔/✕ → 乱码）

## 测试/构建
- 单测 46/46 全绿（GUT）；数据表校验 8 张通过（tools/validate_tables.py）
- 服务器：http://localhost:8137（E 盘 build/web，no-cache 头）
- 调试：?debug=1 显示调试区

## 产物路径约定
- 概念/策划：design/concept/、design/gdd/；美术：design/art-bible/；评审：design/reviews/
- 技术：docs/architecture/；表格：data/tables/；核心层：src/core/
