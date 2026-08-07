# 《遮天》发布计划（Release Plan）

- 作者：路远行（Release Ops Lead）
- 日期：2026-08-07
- 阶段：打磨期收口 → 首个可玩版本（MVP Alpha）
- 关联：`export_presets.cfg`、`project.godot`、`tools/compress_icons.py`、`tools/size_gate.py`、`design/reviews/QA-PLAN-SPRINT-POLISH.md`
- 状态：**草案 · 待主理人审批**

---

## 0. 现状快照（本计划输入）

| 项 | 现状 | 来源 |
|---|---|---|
| 引擎/平台 | Godot 4.4 · Web 导出（gl_compatibility 单线程） | project.godot / export_presets.cfg |
| 应用名 | `ZheTian - 遮天` | project.godot |
| 版本号字段 | **未配置**（`config/version` 缺失，需补） | project.godot |
| 存档 schema 版本 | `SaveModel.VERSION := 5`（V3→V5 迁移口径已统一，G-02 已闭环） | src/core/save_model.gd |
| 测试 | 单测 + 集成 **66/66 全绿**；tests/unit 11 文件 + tests/integration/test_smoke_core.gd | tests/ |
| CI | 5 阶段：Lint → Schema → GUT 单测 → Web 导出 → 体积门禁 | .github/workflows/ci.yml |
| 数据表 | 8 张：battle/character/constants/drop/equipment/gacha/realm/skill_sets（validate_tables 校验） | data/tables/ |
| 构建产物 | build/web/：index.html + index.js + index.wasm + index.pck（**pck 4.22MB**） | build/web/ |
| 体积门禁 | 引擎壳 gzip **9.03MB**（target 9MB 超 0.03MB 警告级 / hard 12MB 内通过） | tools/size_gate.py |
| 本地预览 | python http.server :8137 可达（no-cache，仅开发用） | .server.log |
| 图标压缩 | tools/compress_icons.py：PNG→WebP（160px / Q82） | tools/ |
| 版本控制 | **非 git 仓库**（无 .git → 变更日志需人工维护） | 文件系统 |
| 本地化 | UI 硬编码中文：main.gd 2126 行中 **341 行含中文**；另有 13 个 .gd 含少量中文（日志/提示） | 扫描 src/ |

**首版范围（MVP 可玩闭环）**：单主角修仙（修炼/突破/推关）+ 装备（4 槽）+ 功法修炼/命座/残卷 + 背包 + 宝物抽卡（保底 60/90）+ 副本（源石秘境/灵石矿脉/试炼道场）+ 试炼塔（30 层）+ 战斗演出。

---

## 1. 版本方案

### 1.1 首个可玩版本号：`0.1.0-alpha.1`

SemVer 对齐存档 schema：**产品版本号（SemVer）与 `SaveModel.VERSION`（存档格式版本）解耦，但发布时锁同一次构建**。

| 字段 | 值 | 说明 |
|---|---|---|
| 产品版本 | `0.1.0-alpha.1` | 首个可玩 MVP：功能完整但未到公测/正式 |
| 存档 schema | `5` | `save_model.gd VERSION`；0.x 阶段允许破坏性迁移（玩家数据少） |
| 分支标签 | `release/0.1.0-alpha.1` | 建议引入 git 后使用（当前无 git） |
| 构建目录 | `build/web/`（每次发布打 tag 后归档为 `releases/0.1.0-alpha.1/`） | 回滚锚点 |

### 1.2 版本管理约定

1. **产品版本**：`MAJOR.MINOR.PATCH[-pre][.n]`
   - `0.1.0-alpha.1`：MVP 可玩（当前）→ `0.2.0-alpha`（加系统）→ `0.9.0-beta`（公测）→ `1.0.0`（正式）。
   - 0.x 阶段：加功能 = MINOR+；修 Bug = PATCH+；破坏性存档迁移 = MINOR+（同时 `SaveModel.VERSION+1`）。
   - 1.0 后：严格 SemVer。
2. **存档 schema 版本**（`SaveModel.VERSION`）：任何 `to_dict/from_dict` 字段增删改 → +1，并补 `test_save_migration.gd` 用例（MIG-xxx）。当前 5。
3. **版本唯一来源**：在 `project.godot` 增加 `config/version="0.1.0-alpha.1"`（发布前必做），游戏内 UI 展示版本号。
4. **变更日志**：`CHANGELOG.md` 人工维护（项目非 git 仓库，无法自动生成；见 §6 风险 R-01）。
5. **发布节奏**：MVP 阶段按"功能里程碑"发布（不做固定日历）；进入 Live Ops 后改双周/月度节奏（见 §7 展望）。

---

## 2. 发布清单（Release Checklist · MVP v0.1.0-alpha.1）

> 勾选标准：`[x]` = 已满足；`[ ]` = 未满足（Blocker）；`[~]` = 有风险/待定（须记录处置）。**任一 `[ ]` Blocker 未清 → Go/No-Go 判定为 NO-GO。**

### 2.1 构建（Build）

- [x] **B-01 构建可达**：`godot --headless --export-release "Web" build/web/index.html` 跑通（实测成功）。
- [x] **B-02 产物完整**：build/web/ 含 index.html / index.js / index.wasm / index.pck / index.audio.*.js / 图标。
- [x] **B-03 排除项正确**：export_presets exclude_filter 排除 addons/gut、build、tests、production、tools、docs、design、.github、备份/生成图（不污染 pck）。
- [ ] **B-04 版本号落地**：`project.godot` 补 `config/version="0.1.0-alpha.1"`（当前缺失）。
- [x] **B-05 引擎壳体积**：gzip 9.03MB < hard 12MB 通过（target 9MB 超 0.03MB → 警告级，记录不阻塞）。
- [x] **B-06 pck 体积**：index.pck 4.22MB（含全部资源，stage1 总下载口径内）。

### 2.2 测试（QA Gate）

- [x] **T-01 CI 全绿**：Lint / Schema / GUT 单测 / Web 导出 / 体积门禁 5 阶段通过（ENABLE_GODOT_JOBS=true）。
- [x] **T-02 单测+集成**：66/66 全绿（含新增 test_equipment_service / test_skill_service / test_arena_service / test_smoke_core）。
- [x] **T-03 存档迁移**：MIG-001~010 覆盖 V3→V5（version=5 已统一）。
- [ ] **T-04 GATE-F 全链路 Smoke**：SMK-001~022 人工跑一遍（QA 严守真执行）；**待执行**（发布前必须）。
- [~] **T-05 QA 缺口闭环确认**：G-03（抽卡分段）、G-04（保底宝物池 di/tian/di_pin）、G-05（副产物入账）需工程确认已实现（测试已补，代码实现需复核）。

### 2.3 数据校验（Data）

- [x] **D-01 Schema 校验**：`python tools/validate_tables.py data/tables` 0 error。
- [ ] **D-02 DB-001 宝物池稀有度覆盖**：standard.treasures 含 di/tian/di_pin（保底 60/90 兑现前提）；**待确认**。
- [ ] **D-03 DB-002 功法上限一致**：sk_010/sk_012 max_level(30) vs train.max_level_cap(20)；**待策划/工程裁定**（非 Blocker，P2）。
- [~] **D-04 数值手感**：NUM-001~024 回归（装备强化回本、功法强度曲线、源石长线 pacing、碎片死货币）——策划复核中。

### 2.4 体积（Size Gate）

- [x] **S-01 体积门禁**：`python tools/size_gate.py build/web` 通过（engine gzip 9.03MB / stage1 总下载 ≤14MB）。
- [~] **S-02 target 警告**：engine gzip 超 target 9MB 0.03MB → 需预算评审签字（不影响发布，记录）。
- [x] **S-03 图标压缩**：compress_icons.py 已落地（PNG→WebP 160px/Q82），后续美术资产统一走该工具。

### 2.5 服务器 / 预览（Serve）

- [x] **SRV-01 本地预览**：`python -m http.server 8137` 可达，index.html/wasm/pck 均 200。
- [x] **SRV-02 MIME 正确**：.wasm 需 `application/wasm`、.pck 需 `application/octet-stream`（Godot 官方模板自带，本地已验证）。
- [ ] **SRV-03 生产服务器**：静态托管就绪（见 §3.1）；**待部署**。

### 2.6 域名 / HTTPS（Domain & TLS）

- [ ] **H-01 域名**：确定线上域名（建议 `zhetian.example.com` 或独立域名）；**待定**。
- [ ] **H-02 HTTPS**：Web 游戏必须 HTTPS（WebGL 安全上下文要求 + 音频 worklet 需 Secure Context）；**待配置**。
- [~] **H-03 COOP/COEP**：当前单线程导出**不需要**跨源隔离头；若未来启用多线程/SharedArrayBuffer，需加 `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp`（届时回归测试）。

### 2.7 合规 / 法务 / 商店（MVP 简化）

- [x] **L-01 无商店上架**：MVP 仅 Web 链接分发，不涉及商店审核。
- [x] **L-02 无付费项**：MVP 无内购/广告 → 支付合规 N/A（付费项上线前需法务，列入 1.0 前）。
- [~] **L-03 素材版权**：AI 生成素材（generated-images/）——版权归属确认，记录存档。

---

## 3. 上线清单（Web 部署步骤）

### 3.1 静态托管建议方案

MVP 为纯静态 Web 游戏（无服务端），**推荐按序选择**：

| 方案 | 适合 | 备注 |
|---|---|---|
| **A. 腾讯云 COS + CDN**（首选） | 国内玩家、正式上线 | 静态托管 + 边缘缓存 + 自有域名 HTTPS；成本低、可控回滚 |
| **B. Cloudflare Pages** | 海外/全球玩家、快速上线 | 免费、自动 HTTPS、版本回滚方便；国内访问不稳定 |
| **C. GitHub Pages** | 内部预览/试玩分享 | 免费、快，但国内访问不稳定，**不建议正式运营** |
| **D. 自建 Nginx** | 已有服务器 | 需自行配 HTTPS 证书与缓存头 |

> 决策建议：**MVP 试玩用 C（GitHub Pages）或 B（Cloudflare Pages）快速分发；正式运营切 A（COS+CDN）**。

### 3.2 部署步骤（以 COS+CDN 为例）

1. **产物归档**：`releases/0.1.0-alpha.1/` = 本次 build/web/ 全量快照（回滚锚点）。
2. **上传**：build/web/ 全量上传至 COS Bucket（建议 `zhetian-web/` 前缀）。
3. **CDN 绑定域名**：CNAME 至 CDN 加速域名，开启 HTTPS 证书（腾讯云免费 DV 证书即可）。
4. **缓存策略**（见 §3.3）配置响应头。
5. **冒烟**：部署后按 SMK-001/002/012/018 关键链路回归（新档可玩 + 突破可点）。
6. **发布公告**：按 §4 补丁说明对外（内部群/试玩链接）。
7. **记录发布台账**：版本 / 构建 hash（建议取 pck sha256）/ 时间 / 部署人 / 回滚锚点。

### 3.3 CDN / 缓存策略

**当前本地 no-cache 仅开发用，上线必须显式配置**：

| 文件 | 建议 Cache-Control | 理由 |
|---|---|---|
| `index.html` | `no-cache`（每次回源校验） | 入口文件，发布时保证拿最新 |
| `index.js` / `index.wasm` / `index.pck` | `public, max-age=31536000, immutable` + **发布时强制刷新** | Godot 导出文件名固定（index.*），靠"版本目录+刷新"避免旧缓存 |
| `index.audio.*.js` | 同上 | 同上 |
| 图标/静态图 | `public, max-age=86400` | 低变更 |

> 注意：Godot Web 导出文件名**不随版本变化**，因此**禁止**仅靠长缓存；正确做法是发布时 CDN 全量刷新（或每版本用独立子目录 + index.html 指向）。**版本目录方案**（`/v/0.1.0-alpha.1/index.html`）最稳妥，回滚=切目录。

### 3.4 回滚方案

| 场景 | 触发 | 动作 | 恢复时间目标 |
|---|---|---|---|
| 白屏/崩溃（wasm 加载失败） | 监控/玩家反馈 | CDN 回源至上一版本目录（index.html 切回 `releases/0.1.0-alpha.0/`） | ≤15 min |
| 数值/存档问题（P0） | 存档损坏上报 | 热修流程：改代码 → 出 hotfix 版本 → 版本号 PATCH+ → 重新部署 | ≤4 h |
| CDN 异常 | 监控 | CDN 开关切换（备用源站） | ≤30 min |

**回滚原则**：① 每发布版本保留完整归档；② 回滚后 pck 与 wasm 必须同版本（防"壳新包旧"）；③ 回滚动作由人工审批，记录台账。

---

## 4. 补丁说明（Patch Notes）

### 4.1 模板（玩家语言）

```markdown
# 《遮天》v<版本号> 更新公告

道友们好！本次更新带来 <一句话主题>。

## ✨ 新内容
- <玩家可感知的新系统/功能，说人话，不写字段名>

## ⚖️ 数值调整
- <影响战斗/成长的数值变化，给到"之前→现在"或百分比>

## 🛠️ 修复
- <玩家可见的 Bug 修复，避免内部术语>

## 📌 已知问题
- <未修复但已记录的问题，给玩家预期>

— 《遮天》开发组
```

### 4.2 首版示例（v0.1.0-alpha.1 · MVP 首秀）

```markdown
# 《遮天》v0.1.0-alpha.1 更新公告

道友们好！《遮天》首个可玩版本上线——单主角修仙闭环首次完整可玩：
修炼 → 突破 → 推关，配合装备与功法养成。本版为 Alpha 测试版，
欢迎试玩并反馈问题。

## ✨ 新内容
- **装备系统**：武器/防具/饰品/符箓 4 个槽位，可装备、可强化（消耗灵石，最高 25 级），实时提升属性与战力。
- **功法修炼**：习得功法后修炼升级（灵石+残卷），可同时装备 3 本；**命座系统**上线——重复功法转化为命座，每命 +50% 功法效果（6 命 ×4 倍）。
- **背包**：装备/功法/材料/残卷统一管理，来源与消耗实时计数。
- **宝物抽卡**：常驻池含凡/灵/玄/地/天/帝品宝物；**保底机制**：60 抽必出地品、90 抽必出天品，跨池继承进度可见。
- **副本**：源石秘境（日限 2）/ 灵石矿脉（日限 3）/ 试炼道场（日限 3），掉落源石与灵石。
- **试炼塔**：30 层推进，10/20/30 层节点奖励源石。
- **战斗演出**：攻防回合、血条增减、暴击/闪避提示，战斗结算与数值一致。

## ⚖️ 数值调整（Alpha 首版基准）
- 放置产出 R0=10 灵/s，离线效率 80%，封顶 12 小时。
- 突破成本曲线与副本产出对齐（轮海毕业 ≈1 天灵石 + 3 天源石）。
- 装备强化成本 1000×1.15^lv，单件满级 ≈18.4 万灵（矿脉日产出 24 万，1 天内可回本）。

## 🛠️ 修复
- （首版无历史版本，此为基线）

## 📌 已知问题
- 源石碎片（yuan_shard）暂无可兑换出口，将随后续版本开放兑换。
- 高稀有功法满级后强度可能溢出，数值仍在调优中。

— 《遮天》开发组
```

> 内部变更日志（CHANGELOG.md）与玩家补丁说明分开维护：内部用模块+字段+引用，玩家版如上。

---

## 5. 本地化准备（Localization Readiness）

### 5.1 现状审计（覆盖率）

| 区域 | 硬编码中文规模 | 说明 |
|---|---|---|
| `src/main.gd` | **341 行含中文**（2126 行总，约 16%） | 全部 UI 文案：按钮/标签/提示/弹窗/属性说明 |
| `src/core/*.gd`（13 文件） | 少量（日志/错误提示/常量名） | 玩家可见较少，多为 push_warning/日志 |
| 数据表 `data/tables/*.json` | 名称字段为中文（如装备名/功法名/段位名） | 属于内容本地化，非 UI 代码字符串 |
| **合计** | **UI 硬编码为主，MVP 中文单语** | 无 i18n 管线 |

**结论：MVP 阶段维持中文单语，但 UI 字符串 100% 硬编码 → 后续多语言需先抽取。**

### 5.2 抽取方案（后续 i18n，MVP 后立项）

采用 **Godot 4 内置 i18n（tr() + CSV → .translation）**，轻量、引擎原生、无第三方依赖：

1. **字符串扫描**：工具扫 src/ 中 `_mk_label("...")` / `_mk_button("...")` / `_mk_dim("...")` 及字符串拼接 `%` 格式。
2. **抽取为 key**：所有玩家可见字符串改为 `tr("KEY")`；格式串保留 `%s/%d` 占位，翻译表维护同一 key 的译文（避免拆句导致语序错乱）。
3. **生成 CSV 翻译表**：`localization/zh_CN.csv`（key, source, zh_CN），用 `ConfigFile` 或 CSV 导入生成 `.translation`；Godot 项目设置启用多语言。
4. **覆盖率报告**：脚本对比代码中 tr key 与翻译表 key，输出缺失率（目标 ≥99% 发布）。
5. **文化/敏感性评审**：修仙术语（如"命座"）本地化时需对照英文术语表；涉及历史/宗教意象文案须评审。
6. **字符串冻结**：发布候选前 N 天冻结字符串（禁止改动 UI 文案），翻译并行；热修例外需走审批。

> MVP 先行项：**不阻塞发布**，但建议在 `project.godot` 预留 `[internationalization]` 段（空 locale 列表），并在新写 UI 时从第一天起用 `tr()` 包装——**存量 341 行等 i18n 专项统一抽取，避免边写边抽的碎片化**。

---

## 6. 已知发布风险与缓解

| # | 风险 | 级别 | 缓解 |
|---|---|---|---|
| R-01 | **非 git 仓库**：无法自动生成变更日志、无法打 tag 归档、回滚无版本锚 | P1 | 发布前建议 `git init` + 首提交；立即建立 `CHANGELOG.md` 人工维护 + `releases/<版本>/` 目录归档 |
| R-02 | 引擎壳 gzip 9.03MB 超 target 9MB（0.03MB） | P2 | 预算评审签字接受；后续可评估 wasm 裁剪/压缩选项 |
| R-03 | QA 缺口 G-03/G-04/G-05 实现复核未完成（保底兑现/分段/副产物入账） | **P1** | 发布前工程（程基岩）确认；未确认则 GATE-F 前阻塞 |
| R-04 | project.godot 无 version 字段 | P1 | B-04 发布前补 `config/version` |
| R-05 | PWA 未启用（offline/安装能力缺失） | P2 | MVP 不阻塞；Live Ops 阶段启用（export_presets 已预留字段） |
| R-06 | 缓存策略误配导致玩家拿旧版本 | P1 | 严格执行 §3.3：index.html no-cache + 版本目录 + 发布时 CDN 刷新 |
| R-07 | 数值长线 pacing（源石 38 天/碎片死货币） | P2 | 策划复核 NUM-021/023；MVP 演示档可先用短 pacing 兜底 |

---

## 7. 发布门控判定（Go/No-Go · v0.1.0-alpha.1）

**当前判定：`CONCERNS`（有条件放行）** —— 无 P0，但存在 2 项 P1 待清：

| 门 | 状态 | 说明 |
|---|---|---|
| 构建/体积/数据 | ✅ PASS | 导出跑通、size_gate 通过、validate_tables 0 error |
| 测试 | ✅ PASS（待 GATE-F） | 66/66 全绿；SMK 人工冒烟待执行 |
| P1 待清 | ⚠️ | R-03（QA 缺口复核）、R-04（version 字段）；T-04（GATE-F 冒烟） |
| P2 待定 | 📋 | R-02 预算签字、D-03 上限一致、D-04 数值复核 |

**Go 条件**：① T-04 GATE-F 冒烟无 P0/P1；② R-03 工程复核通过；③ R-04 版本字段补齐；④ H-01/H-02 域名 HTTPS 就绪（线上分发时）。满足后由主理人签字 → GO。

---

## 8. 待用户审批项（高影响动作）

1. **版本号拍板**：`0.1.0-alpha.1` 是否采纳；是否在 project.godot 落 `config/version`。
2. **线上域名/托管方案**：A 腾讯云 COS+CDN（正式）/ B Cloudflare Pages / C GitHub Pages（试玩）选择。
3. **是否上线分发**：MVP 是否对外发试玩链接（或仅内部验收）。
4. **QA 缺口处置授权**：G-03/G-04/G-05 是否作为本版本 Blocker（若保底承诺纳入验收则升 P0）。

---

## 9. 下一步建议（Live Ops 展望）

- **发布后**：建立反馈收集渠道（表单/社区群），按 SMK 用例引导试玩反馈。
- **0.2.0 展望**：i18n 字符串抽取专项、PWA 启用、赛季/活动框架（与文策渊对齐经济）、帝路竞技（arena_service 已备）。
- **1.0 前必做**：git 引入、付费合规（若有）、隐私政策、服务端权威迁移（ADR-0003）。
