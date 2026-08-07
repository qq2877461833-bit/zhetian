# CI 原型方案（Phase 4 脚手架落地）

- 文档编号：ARCH-ENG-005
- 阶段：Phase 3 前置（原型方案，Phase 4 脚手架阶段落地）
- 作者：engineering-lead（程基岩）
- 日期：2026-08-06
- 关联：ARCH-ENG-002（预算口径）；ARCH-ENG-003（引擎参考）；ARCH-ENG-004（编码标准）

---

## 0. 目标

1. 一键产出可发布 Web 构建（Godot 4.4 单线程导出，GDScript）；
2. **体积预算门禁**：首屏可玩 <5MB（硬性）、引擎壳 gzip ≤12MB（硬门禁）、远程 Bundle 每 ≤3MB——超限即构建失败；
3. 构建产物哈希命名 + CDN 强缓存（更新即换名，天然防缓存错乱）；
4. 核心层单测必跑（GUT），数据表 Schema 校验必跑。

> 环境声明：本方案为**原型设计 + 待落地**；具体流水线（GitHub Actions 等）在 Phase 4 脚手架按实际仓库落地。

---

## 1. Web 构建流水线设计

```
[push / PR] → Lint(GDScript) → 数据表 Schema 校验 → 核心层单测(GUT)
            → Godot headless 导入/导出 Web(Release, 单线程)
            → 体积门禁脚本(体积审计) → 产物哈希重命名 → 上传 CDN + 生成 manifest
```

### 1.1 阶段说明

| 阶段 | 工具/命令（待落地实测） | 失败即阻断 |
|---|---|---|
| Lint | `gdformat` / 静态检查（GDScript） | 是 |
| 数据表校验 | Schema 校验脚本（JSON 字段/类型） | 是 |
| 单测 | GUT（核心层 headless） | 是 |
| 导出 | `godot --headless --export-release "Web" build/web/index.html` | 是 |
| 体积门禁 | 见 §2 | 是（硬门禁超限 fail） |
| 哈希命名 | 见 §3 | — |
| 发布 | CDN 上传 + manifest.json | — |

---

## 2. 体积预算门禁（硬性）

| 门禁项 | 规则 | 硬门禁 | 动作 |
|---|---|---|---|
| 引擎壳 gzip | 导出后对 godot.wasm 压测 | ≤12MB | 超限 → build fail |
| 首屏可玩（美术增量） | 阶段 1 资源包体积审计 | ≤5MB（硬性） | 超限 → build fail + 报告 Top 资源 |
| 引擎+首场景总下载 | 阶段 1 总量 | ≤14MB（引擎壳>8MB 时口径，见 ARCH-ENG-002 §5） | 超限 → build fail |
| 远程 Bundle | 每个 bundle 体积 | ≤3MB | 超限 → build fail |
| 纹理 | 导入后扫描 2048² 上限 | 超限告警 + 阻断（如超规格） | 依美术圣经 §8.1 |
| Shader Variant | 构建日志审计 | ≤24 | 超限 → build fail |

- **门禁脚本**（CI 内执行，待 Phase 4 实现）：解析导出产物目录，统计 wasm/资源/各 bundle 的原始+gzip 体积；输出体积报告（HTML/JSON）；超限返回非零退出码。
- **体积报告留档**：每次构建产物体积进入 CI artifact + 历史记录，供趋势看板（防资产缓慢膨胀）。

---

## 3. 产物哈希命名 + CDN 缓存策略

- **命名**：`godot.<hash>.wasm`、`index.<hash>.html`、`data.<hash>.pck`；Bundle 同理（`bundle_huanggu.<hash>.pck`）。
- **hash 来源**：内容 hash（如 sha256 前 8–12 位），内容变 → 文件名变。
- **缓存策略**：`Cache-Control: immutable, max-age=31536000` 对哈希产物（永不失效，天然防错版本）；`index.html` 用 `no-cache`（每次校验 manifest）。
- **manifest.json**：列出所有产物名 + hash + 体积 + 版本号；引导页读取 manifest 决定加载哪些资源。
- **回退**：远程 Bundle 加载失败 → 本地占位资源 + 重试（美术圣经 §8.4 口径）。

---

## 4. 接入时机（Phase 4 脚手架阶段落地）

| 里程碑 | 内容 |
|---|---|
| Phase 4 首日 | 跑通 ARCH-ENG-002 实测清单（空包体积/部署头/纹理/远程 Bundle）→ 回填预算口径 |
| Phase 4 脚手架 | 建仓库 + 目录骨架（基础/核心/玩法）+ 最小 CI（Lint → 单测 → 导出 → 体积门禁） |
| 首场景里程碑 | 首个可玩首屏（标题 + 新手区 + UI 核心）产出 → 体积门禁首验，对齐 art-director |
| MVP 阶段 | CI 常态化：每 PR 跑门禁；发版走 CDN 哈希发布 |

---

## 5. 待决策/待实测

1. CI 托管：GitHub Actions / 自建（国内网络/CDN 选型，与主理人确认）——**待主理人决策**；
2. Godot headless 在 CI 的安装/缓存（导出模板下载）——待实测；
3. 数据表 Schema 校验脚本语言（GDScript vs 外部脚本）——待 Phase 4 定；
4. 遥测/发布是否纳入同一条流水线（建议 MVP 后）。

---

## 6. 关联文档

- ARCH-ENG-002 Godot 4.4 技术验证报告（预算口径权威来源）
- ARCH-ENG-004 架构分层与编码标准（测试/数据驱动约定）
- 美术圣经 v0.2 §8（纹理/Shader/粒子/降级档）
