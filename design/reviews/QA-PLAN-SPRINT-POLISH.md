# QA 门控计划：打磨期（Sprint Polish）

- 作者：严守真（QA / 质量保障与测试）
- 日期：2026-08-07
- 范围：单主角修仙全链路（修炼/突破/推关 + 装备 + 功法/命座 + 背包 + 宝物抽卡 + 副本 + 战斗演出）
- 输入文档：`data/tables/*.json`、`tools/validate_tables.py`、`tests/unit/*.gd`、`src/core/{gacha,equipment,skill,battle}_service.gd`、`src/core/save_model.gd`、`src/foundation/save_manager.gd`、`src/core/{realm_engine,idle_income_engine,drop_service}.gd`
- 关联 GDD：GDD-001（放置/境界）、GDD-002（抽卡/成长）、GDD-003（战斗/关卡）、GDD-004（副本/塔/经济）
- 状态：**草稿 · 待主理人审批**

---

## 0. 现状盘点（本次代码/测试评审结论）

### 0.1 已有测试覆盖（tests/unit/，7 个文件）

| 测试文件 | 覆盖对象 | 备注 |
|---|---|---|
| test_realm_engine.gd | 突破成本公式/关卡映射 | 已绿 |
| test_idle_income_engine.gd | 放置速率/离线结算 | 已绿 |
| test_character_service.gd | 升级/升星/法宝/账号境界上限/修炼位解锁 | 已绿 |
| test_battle_service.gd | 伤害公式/克制/行动条/星级/确定性 | 已绿 |
| test_gacha_service.gd | 概率和/保底60/90/跨池/碎片副产物 | 已绿（但见缺口 G-04） |
| test_drop_service.gd | 副本体力/日限/掉落/塔推进/节点奖励 | 已绿 |
| test_save_migration.gd | V3→新档迁移/回环/默认档 | 已绿 |

CI 门禁（`.github/workflows/ci.yml`）：Lint → Schema → GUT 单测（`ENABLE_GODOT_JOBS=true` 激活）→ 导出+体积门禁。

### 0.2 评审发现的缺口（建议本迭代一并处理）

| 编号 | 缺口 | 影响 | 建议级别 |
|---|---|---|---|
| G-01 | **无 `test_equipment_service.gd` / `test_skill_service.gd`**：强化成本/槽位校验/总加成、功法修炼/残卷回滚/装备3格/命座均无单测 | 核心养成链路零断言 | P1 |
| G-02 | **存档版本号不一致**：`save_model.gd` `VERSION := 4`，但迁移测试与需求口径为「V3 旧档→V5 新档」 | 若后续按版本做迁移门禁，版本号将错位 | P1 |
| G-03 | **抽卡分段未落地**：`gacha.json` 有 `segment.open_di_tian_after: daogong`，但 `GachaService._roll_rarity` 未实现分段，轮海期也可能抽到 地/天 | 违反 GDD-002 §3.1.2 分段拍板 | P1 |
| G-04 | **宝物池缺 地/天/帝品 条目**：`standard.treasures` 最高只到 `xuan`，无 di/tian/di_pin → 保底 60/90 触发时 `_pick_treasure` 无候选 → 实际发**材料安慰奖**（mat_ling_pack），保底承诺落空 | 核心玩法严重受损 | **P1（若发布验收含保底承诺则升 P0）** |
| G-05 | **抽卡副产物未持久化**：`draw()` 返回 `yuan_shards: 1`，但服务层未写入 `model.inventory`/`stats`，需确认 UI 层是否补入 | 若 UI 不补入则碎片丢失 | P1 |
| G-06 | **保底回退用非注入 RNG**：`_tier_di_or_above`/`_tier_tian` 内新建 `RandomNumberGenerator.randomize()`，破坏 ADR-0003 确定性 | 同输入不同结果、测试 flaky | P2 |
| G-07 | **功法 max_level 与训练上限不一致**：`skill_sets.train.max_level_cap=20`，但 sk_010/sk_012 `max_level=30`（服务用 book.max_level） | 数据一致性 | P2 |
| G-08 | **无 tests/integration/ 与 tests/fixtures/**（README 约定存在但未建） | 跨模块链路无自动覆盖 | P2 |
| G-09 | `from_dict` 对 `characters[k]` 直接 `as Dictionary`，坏档（非字典值）会抛错；`save_manager` 仅兜底整体解析失败 | 存档健壮性边缘 | P2 |

---

## 1. 测试策略总览（四层）

```
┌──────────────────────────────────────────────────────────────┐
│ L1 核心逻辑单测（tests/unit/，GUT headless，CI 阶段 3 门禁）      │
│   覆盖：全部 src/core/*.gd 纯逻辑服务；确定性输入→确定性输出       │
├──────────────────────────────────────────────────────────────┤
│ L2 数据表校验（tools/validate_tables.py，CI 阶段 2 门禁）         │
│   覆盖：schema/必填/类型/跨表引用/数值合理性；本计划新增专项校验     │
├──────────────────────────────────────────────────────────────┤
│ L3 存档迁移测试（tests/unit/test_save_migration.gd 扩展）        │
│   覆盖：V3→V5 字段默认行为 / 回环 / 坏档兜底 / 版本号一致性         │
├──────────────────────────────────────────────────────────────┤
│ L4 UI Smoke + 手动验收（本计划 §5 全链路用例；发布前人工跑一遍）    │
│   覆盖：新档→抽卡→装备→修炼→推关→副本→塔→突破 全链路              │
└──────────────────────────────────────────────────────────────┘
```

### 1.1 质量门（Gate）定义

| 门 | 触发时机 | 命令/方式 | 通过标准 |
|---|---|---|---|
| GATE-A Lint | push/PR | `gdformat --check src/ tests/` | 0 差异 |
| GATE-B Schema | push/PR | `python tools/validate_tables.py data/tables` | 0 error（退出码 0） |
| GATE-C 单测 | push/PR（ENABLE_GODOT_JOBS=true） | `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` | 全绿，0 失败 |
| GATE-D 存档迁移 | 随 GATE-C | 同 GUT 套件 | MIG-xxx 全过 |
| GATE-E 数值手感 | 打磨期每轮调表后 | 手动跑 §4 清单 + 抽 3 档存档验证 | 无 P0/P1 |
| GATE-F 全链路 Smoke | 发布候选 | 手动跑 §5 用例 | 无 P0/P1，P2 有明确处置 |

### 1.2 优先级/严重度（项目约定）

| 级别 | 定义 | 处置 |
|---|---|---|
| **P0 Blocker** | 崩溃 / 存档损坏 / 数据丢失 / 核心流程不可达 / 安全越权 | 立即修，阻塞发布 |
| **P1 Critical** | 核心玩法错误（保底失效、货币错账、升级回滚、付费项异常）、明确违反 GDD 验收 | 发布前必修，进本轮迭代 |
| **P2 Minor** | 体验/文案/边界/一致性/性能小问题，有绕行方案 | 可排期，不阻塞发布（须记录） |

---

## 2. 存档迁移测试用例（V3 旧档 → V5 新档）

> 目标：旧档**缺少 `equipment` / `active_skills` / `inventory` 字段**时必须安全加载、默认空、不崩；既有字段完整保留。

| 用例 | 前置存档 | 步骤 | 预期 | 级别 |
|---|---|---|---|---|
| MIG-001 | V3 旧档：`{version:3, player:{ling,yuan,energy,last_offline_ts}, cleared_stages, gacha_tickets, characters, slots, gacha, stats}`（无 equipment/active_skills/inventory） | `SaveModel.from_dict(old)` | ling/yuan/energy/gacha_tickets/cleared_stages/characters/slots/gacha/stats 全部保留；`equipment` 空、`active_skills` 空、`inventory` 空；不抛错 | P0 违规 |
| MIG-002 | V3 旧档部分新字段：有 `equipment` 但无 `active_skills`/`inventory` | `from_dict` | equipment 保留（slot→item_id 为 String），另两个默认空 | P0 违规 |
| MIG-003 | V4/V5 新档 to_dict → from_dict 回环（装备/功法/背包/命座/功法等级/装备等级齐全） | 回环 | 全字段等值保留（现有 `test_v4_save_roundtrip` 覆盖） | P0 违规 |
| MIG-004 | 缺 `player` 键 / 缺 `energy` / 缺 `gacha_tickets` | `from_dict` | ling/yuan=0；energy=ENERGY_CAP(120)；gacha_tickets=10（旧档补发口径，需与策划确认）；不崩 | P1 |
| MIG-005 | 坏 JSON（非 Dictionary） | `save_manager.load_save()` | 回退 `default_save()`，push_warning，不崩 | P0 违规 |
| MIG-006 | 无存档文件 | `save_manager.load_save()` | 返回 `default_save()`：主角 ye_fan、槽位0、抽卡券 30 | P0 违规 |
| MIG-007 | `characters` 值为非 Dictionary（脏数据） | `from_dict` | 现状会 `as Dictionary` 抛错 → **期望改为防御式跳过/转空**（G-09） | P1 |
| MIG-008 | 缺 `version` 字段的极旧档 | `from_dict` | 无显式版本门禁 → 仍按字段默认加载（建议加版本白名单日志，不阻塞） | P2 |
| MIG-009 | V5 新档（含全部新字段）再存盘 | `to_dict()` | `version` 应输出**目标版本号（当前代码为 4，口径为 V5，见 G-02 需统一）**；字段键齐全 | P1 |
| MIG-010 | 背包计数边界：`inventory` 值非 int / 为负 | `from_dict` | 防御式 `int()` 转换；负值建议钳 0（当前直接 int()，负值保留） | P2 |

> 附注：`save_manager.save()` 为明文 JSON（加密待 ADR-0002 落地）；迁移测试聚焦 `from_dict` 纯逻辑，无需磁盘。

---

## 3. 数值手感回归清单

> 口径锚定：放置 R0=10 灵/s、离线效率 0.8、封顶 12h；突破成本 realm.json；副本产出 drop.json；强化/功法成本 equipment.json / skill_sets.json；关卡强度 battle.json。

### 3.1 装备强化成本 vs 灵石产出

| 用例 | 计算口径 | 期望（PASS） | 告警阈值 | 级别 |
|---|---|---|---|---|
| NUM-001 | 单件武器满级(1→25)总成本 = Σ 1000×1.15^(k-1) ≈ **184k 灵** | 灵石矿脉 T1 日产出 240k → ≤1 天可回本 | >3 天 | P1 |
| NUM-002 | 4 槽全满级 ≈ **736k 灵** | 矿脉+离线周产出（约 1.68M+）→ 4~5 天 | >10 天 | P1 |
| NUM-003 | 强化数值 vs 关卡：青铜古剑满级 atk ≈ 194（+0.12×24×50） | s030 敌 hp 1354、def 67.7，应能 10 回合内击杀 | 强化后仍打不过同境界验证关 | P1 |
| NUM-004 | 每级成本曲线 1.15^lv：Lv20 单次 16.4k、Lv25 单次 28.6k | 与矿脉单次 80k 匹配 | 单次强化 > 单次矿脉收益 2 倍 | P2 |

### 3.2 功法修炼 vs 关卡强度

| 用例 | 计算口径 | 期望（PASS） | 告警阈值 | 级别 |
|---|---|---|---|---|
| NUM-010 | sk_003（六道轮回拳）满级 12：atk 增益 = 0.12×12 = **+144%**，成本 ≈ 18.7k 灵 + 7 残卷 | 训练后有明显成长但不碾压全图 | 满级后 s030 被 1~2 回合秒杀 → 强度溢出 | P1 |
| NUM-011 | sk_010（斩我明道诀，tian）Lv10：0.6×10=**+600%**；Lv30：+1800%（×命座 1+0.5con） | 与关卡 power 950→1354（+42%）曲线匹配 | 高稀有功法满级后任意关卡秒杀 → 数值乘法爆炸 | P1 |
| NUM-012 | 残卷供给 vs 消耗：Lv5+ 每级 1 残卷；残卷来源 = 重复功法转化/副本 | 满级一条功法所需残卷 ≤ 可获取量 | 残卷完全卡死成长 | P2 |
| NUM-013 | 命座倍率 1+0.5×con（6 命 4x）叠加 value×lv | 与同类功法增速可比 | 命座 + 满级组合远超关卡需求 | P2 |

### 3.3 副本每日产出 vs 突破需求

| 用例 | 计算口径 | 期望（PASS） | 告警阈值 | 级别 |
|---|---|---|---|---|
| NUM-020 | 轮海毕业(i=3)：需 224.6k 灵 + 累计 18 源石 | 矿脉 T1 日 240k 灵 + 源石秘境 T1 日 6 源石 → 灵石约 1 天、源石约 3 天 | 源石 >5 天 | P2 |
| NUM-021 | 道宫毕业(i=8)：需 2.75M 灵 + 累计 230 源石 | 源石 T1 6/日 → **约 38 天**；T2 10/日 → 约 23 天；加塔节点/首通/抽卡碎片 | 若目标留存周期不符 → 需策划确认长线 pacing | P1 |
| NUM-022 | 源石来源盘点：首次通关 6 关×2=12、塔节点 10/20/30 层共 15、抽卡碎片、源石秘境 | 与突破需求总和可覆盖 | 出现「除源石秘境外无其他日源石来源」且秘境被日限卡死 | P2 |
| NUM-023 | **yuan_shard（源石碎片）转化路径缺失**：drop/gacha 均产 shard，但代码无 shard→yuan 兑换 | 有明确用途或兑换口 | 碎片成死货币且无法消费 | P1 |
| NUM-024 | 体力预算：日可得 ≈ 120 + 免费领 2×30 = 180（付费领另 +3×60）；MVP 三副本（源石秘境2+灵石矿脉3+试炼道场3）=8 次=80 + 塔 10×5=50 → 核心循环 130/日；全开 5 副本则 12 次=120 | 日预算可覆盖核心循环并留有余量 | 全投入副本后推关/塔体力不足 | P2 |

### 3.4 数据一致性专项（并入 GATE-B）

| 用例 | 校验点 | 期望 | 级别 |
|---|---|---|---|
| DB-001 | **宝物池稀有度覆盖**：standard.treasures 需含 di/tian/di_pin 条目（当前缺失，见 G-04） | 保底 60/90 可抽到对应稀有度宝物 | P1 |
| DB-002 | 功法 max_level ≤ train.max_level_cap（sk_010/sk_012=30 > cap=20） | 表内一致 | P2 |
| DB-003 | equipment.items slot 引用合法（validate_tables 已覆盖） | 现有 | - |
| DB-004 | gacha 概率和=1.0、保底 60/90（validate_tables 已覆盖） | 现有 | - |
| DB-005 | 副本 min≤max、unlock_realm 注册（validate_tables 已覆盖） | 现有 | - |
| DB-006 | 新增：gacha.byproduct 副产物必须有入账消费点（对齐 NUM-023） | 存在 | P1 |

---

## 4. 全链路 Smoke 用例（新档 → … → 突破）

> 用途：发布候选 GATE-F。每条给出复现路径与「失败即」级别。P0/P1 任一失败 → 门控 FAIL。

| 用例 | 步骤 | 预期 | 失败级别 |
|---|---|---|---|
| SMK-001 | 新档创建 → 主界面 → 主角叶凡在场（槽位0）、抽卡券 30、体力 120 | 无报错，数据正确 | P0 |
| SMK-002 | 抽卡 ×10：每次消耗 1 券、返回稀有度+类型+item_id、`yuan_shards` 入账（**须确认实际入账**，见 G-05） | 券递减、碎片+10 | P1 |
| SMK-003 | 抽卡至 60 抽无地品（可用测试档预置 pity=59）→ 第 60 抽 | 必出 ≥地品**宝物**（当前会出材料，见 G-04） | P1 |
| SMK-004 | 抽卡至 90 抽无天品（预置 tian_pity=89）→ 第 90 抽 | 必出 ≥天品宝物 | P1 |
| SMK-005 | 轮海期（sub_index<4）连抽 20 次 | 只出 凡/灵/玄（分段生效，见 G-03） | P1 |
| SMK-006 | 抽到装备 → 打开装备详情 → 装备到对应槽位（4 槽：武器/防具/饰品/符箓） | 槽位匹配校验生效；错槽拒绝 | P1 |
| SMK-007 | 装备强化 ×N：扣灵石、等级+1、属性预览变化；灵石不足时拒绝且不扣 | 数值正确；拒绝幂等 | P0 |
| SMK-008 | 强化至 max_level → 再强化 | 返回 max_level，不崩 | P1 |
| SMK-009 | 抽到功法 → 修炼：扣灵石/残卷（Lv5+）、等级提升 | 成本正确；残卷不足时回滚灵石（现有 no_shard 回滚逻辑需补测） | P0 |
| SMK-010 | 装备功法 ×3 → 第 4 本 | 返回 slots_full，不覆盖 | P1 |
| SMK-011 | 命座提升（重复功法转化）→ 功法总加成变化 | 加成=value×lv×(1+0.5con) | P2 |
| SMK-012 | 推关 s001（验证关）→ 胜利 → 首通奖励入账（8 万灵+2 源石）→ 下一关解锁 | 通关/奖励/解锁正确 | P0 |
| SMK-013 | 战斗演出：攻防回合、血条增减、暴击/闪避提示 | 演出与结算一致，不卡死 | P2 |
| SMK-014 | 副本·源石秘境（日限2）跑 3 次 | 第 3 次 daily_limit 拒绝 | P1 |
| SMK-015 | 副本·灵石矿脉（日限3）跑 3 次 → 灵石入账 3×80k | 入账正确 | P1 |
| SMK-016 | 试炼塔：战力满足层数 → 推进 1 层 + 扣 5 体力；每日 10 层封顶；10/20/30 层节点 +5 源石 | 推进/封顶/节点奖励正确 | P1 |
| SMK-017 | 塔战力不足 → 失败不推进（但计次数） | 不推进、体力照扣 | P2 |
| SMK-018 | 攒足突破条件（灵石+源石+关卡）→ 突破 苦海→命泉 | 境界提升、成本扣除、stats 更新 | P0 |
| SMK-019 | 突破资源不足 → 拒绝并给出缺额 | 不扣资源 | P0 |
| SMK-020 | 中途退出/重进（读档）→ 状态与退出前一致 | 存档往返一致 | P0 |
| SMK-021 | 旧档（V3 无新字段）直接进游戏操作 | 不崩，新系统按默认空态可玩（MIG-001） | P0 |
| SMK-022 | 背包：材料/装备/功法/残卷计数增减正确 | 与掉落/抽卡/消耗一致 | P1 |

---

## 5. Bug 报告模板（项目约定格式）

```markdown
## Bug 报告

- **ID**：BUG-<迭代>-<序号>（如 BUG-POL-001）
- **标题**：<一句话，含模块与现象>
- **严重度**：P0 Blocker / P1 Critical / P2 Minor
- **模块**：修炼 / 突破 / 推关 / 装备 / 功法 / 背包 / 抽卡 / 副本 / 试炼塔 / 战斗演出 / 存档 / 数据表 / UI
- **环境**：<平台 / 版本 / 分支 / 存档档位>

### 前置条件
<需要先具备的状态，如：V3 旧档、预置 di_pity=59、体力=120>

### 复现步骤
1. <步骤 1>
2. <步骤 2>
3. ...

### 预期结果
<符合 GDD/需求的行为，附引用，如 GDD-002 §3.1.2>

### 实际结果
<当前行为；含数值/截图/日志片段>

### 证据
- 截图 / 录屏 / 日志 / 测试命令与输出
- 相关测试文件：<tests/unit/xxx.gd>（如有）

### 影响面与建议
<影响玩家/留存/经济；建议修复方向；是否需回归用例>
```

**Bug 分级判定速查**
- 崩溃/坏档/丢数据/核心流程不可达 → P0
- 保底失效/货币错账/升级回滚/分段失效/GDD 验收点不满足 → P1
- 文案/边界/一致性/性能/体验 → P2

---

## 6. 质量门判定标准（回传用）

| 判定 | 条件 |
|---|---|
| **PASS** | GATE-A~D 全绿；GATE-E/F 无 P0/P1；P2 有记录与排期 |
| **CONCERNS** | 无 P0；有 P1 但已开 Bug 且排期本轮修复；或 P2 积压需关注 |
| **FAIL** | 任一 P0 存在；或 GATE-C 失败；或 GATE-F 存在未排期 P1 |

---

## 7. 已知缺口与下一步（供团队处置）

1. **立即补测**：`test_equipment_service.gd`（强化成本/槽位/总加成/边界）、`test_skill_service.gd`（修炼/残卷回滚/3 格/命座）—— G-01
2. **修复确认**：G-03 分段、G-04 保底宝物池、G-05 副产物入账 —— 需工程（程基岩）确认实现口径
3. **数值评审**：NUM-011（功法乘法爆炸）、NUM-021（源石长线 pacing）、NUM-023（碎片死货币）—— 需策划（文策渊）复核
4. **版本号统一**：G-02 VERSION=4 vs V5 口径 —— 需主理人拍板
5. **新增 L2 校验**：DB-001 宝物池稀有度覆盖、DB-002 功法上限一致 —— 扩展 validate_tables.py
6. **集成测试层**：建 `tests/integration/`，把 SMK-002~020 核心链路固化为可自动运行脚本（后续迭代）
