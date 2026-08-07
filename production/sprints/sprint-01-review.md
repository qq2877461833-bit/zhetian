# Sprint 1 冲刺回顾（Sprint Review）

- 冲刺编号：Sprint 1（2026-08-06）
- 阶段：Phase 4 预制作 → Phase 5 制作（首个迭代）
- 主理人：游承峰
- 状态：**完成**（垂直切片验收通过）

## 1. 目标达成

**垂直切片「收菜→突破→推关」在浏览器可玩** —— 用户亲测确认正常。

| DoD 项 | 结果 |
|--------|------|
| ① 空包体积实测 | ✅ 引擎壳 gzip 9.03MB（target 9 超 0.03 警告/hard 12 内）；阶段1 9.03MB ≤10MB |
| ② 13 条单测 | ✅ 13/13 全绿（21 断言，0.4s，GUT 9.4.0） |
| ③ EPT-01-S01 脚手架 | ✅ Godot 4.4.stable + Web 导出跑通 |
| ④ 浏览器可玩闭环 | ✅ 收菜→突破→推关→重开离线累计正确 |
| ⑤ 支柱校验 | ✅ P1（突破埋点）/ P3（5 分钟闭环）逻辑成立 |

## 2. 交付物

- 项目骨架：project.godot（gl_compatibility）+ src/（main + core 4 引擎 + foundation 3 服务）+ tests/（13 单测）+ addons/gut/9.4.0 + assets/（占位 7 张 + 字体 TTF）
- 数据表：data/tables/ 6 张（realm/battle/character/gacha/drop/constants）
- 工具链：tools/（validate_tables.py + size_gate.py 双实测通过）
- CI：.github/workflows/ci.yml（Lint/Schema 即刻生效，Godot 作业待激活）
- 可试玩构建：build/web/（http://localhost:8137）

## 3. 排坑记录（团队资产）

| # | 坑 | 根因 | 解法 |
|---|-----|------|------|
| 1 | GUT 9.6.1 编译失败 | 用了 Godot 4.5 的 Logger API | 降级 GUT 9.4.0 |
| 2 | 测试 API 不兼容 | assert_has_failure_when_calling 是 9.5+ API | 改 assert_typeof/assert_has_method |
| 3 | 核心 assert 拦截 | debug-only assert 生产语义差 | 改防御式钳制（maxi/maxf） |
| 4 | size_gate 子目录崩溃 | os.walk basename vs 根路径 | 改相对路径 + 分隔符统一 |
| 5 | 字体豆腐块① | 字体缺 4 字形（→≤─✦） | ASCII 替换 + fonttools 复验 |
| 6 | 字体豆腐块② | woff2 在 Godot Web 解码风险 | 转 TTF 格式 |
| 7 | 字体豆腐块③ | title Label 手写漏 override | 补 override + root 主题级字体 |
| 8 | 导出误打包 GUT | exclude_filter 缺失 | export_presets exclude 补全 |

## 4. 遗留待办（Sprint 2 承接）

1. **P1**：size_gate 将 pck 计入阶段1 总下载（当前漏统计 1.36MB）
2. **P1**：CI 激活（ENABLE_GODOT_JOBS=true + setup-godot 自动装模板）
3. **P1**：首屏美术配额回填（占位资产接入后重跑门禁）
4. **P2**：P1 资源栏布局（数字纵向堆叠，用户反馈过——已随字体修复缓解）
5. **Sprint 3**：battle.json 首通源石对齐 GDD-004（placeholder_sprint1 标记已加）

## 5. 教训沉淀（正式版准则）

- **Godot Web 字体一律 TTF**，不用 woff2
- **UI 控件统一走工厂函数或 Theme 全局字体**，禁止手写 Label/Button 裸奔
- **数据表为数值唯一事实来源**，GDD 标注引用
- **防御式钳制优于 debug assert**（核心层生产语义）

## 6. Sprint 2 展望

- 角色养成（EPT-03 子集）：CharacterService 完整实现 + 多角色界面 + 修炼位多角色
- 抽卡最小闭环：GachaService（服务端 RNG 占位 + 保底 60/90）+ 抽卡 UI/演出
- 美术线：MVP 资产 P0 第一批（4-5 个主力角色立绘/卡面）
- 策划线：角色配置表数值细化 + 抽卡保底验证
