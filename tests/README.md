# 测试框架脚手架（GUT 接入方案）

- 作者：engineering-lead（程基岩）
- 日期：2026-08-06
- 关联：ARCH-ENG-005（CI）；ARCH-ENG-006 §8.5（测试覆盖）；TASK-013
- 状态：**骨架已就位，运行待 Phase 4 实测环境**（本机无 Godot，未执行）

---

## 1. GUT 接入方案（Godot 4.4 / GDScript）

| 项 | 方案 |
|---|---|
| 框架 | **GUT（Godot Unit Test）**，版本 **9.x**（GUT 9 对应 Godot 4；9.4.0 要求 Godot ≥4.3，**main 分支支持 4.4**，本项目用 9.4.0+） |
| 安装 | GitHub Releases 下载 GUT **9.4.0+（main 分支）** zip → 解压后将 `addons/gut/` 拷入项目 `addons/gut/`（标准插件目录）；或编辑器 AssetLib 搜索 "GUT" 一键安装 |
| 激活 | `project.godot` 添加插件 `gut` 到 `[editor_plugins]`（或纯命令行运行无需激活） |
| 本地运行 | `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` |
| CI 运行 | 同命令，接入 ARCH-ENG-005 §1 流水线（Lint → Schema → 单测 → 导出 → 体积门禁） |
| 覆盖率目标 | 核心层 8 服务 100% 单测覆盖（Phase 4 按 Epic 逐模块达成） |

> 测试目录约定：`tests/unit/`（核心层纯逻辑单测）、`tests/integration/`（跨模块）、`tests/fixtures/`（mock/样本数据）。

## 2. 最小单测骨架（已落盘）

| 文件 | 覆盖 |
|---|---|
| `src/core/realm_engine.gd` | 境界引擎最小实现（成本公式，REQ-001-3.3） |
| `src/core/idle_income_engine.gd` | 放置引擎最小实现（速率/离线公式，REQ-001-3.2.1/3.2.3） |
| `tests/unit/test_realm_engine.gd` | 6 用例：首段成本/指数增长/源石档位/关卡映射/全表抽查/非法参数 |
| `tests/unit/test_idle_income_engine.gd` | 7 用例：速率样例×3/离线 12h/超限封顶/0s 边界/非法参数 |

> 设计说明：核心层为纯 `RefCounted` 类（零渲染），GUT 可直接 headless 运行——这是 ARCH-ENG-006 §8.5"核心层单测"的落地证明。用例数值全部锚定 GDD-001 §3.2.1/§3.3 样例表，测试即需求验证。

## 3. 运行状态（2026-08-06 更新）

- **已跑通**：本机 Godot 4.4.stable + GUT 9.4.0 → `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` → **13/13 测试、21 断言全绿**（realm 6 + idle 7），约 0.02~0.06s。
- 排坑记录：①GUT 9.6.1 用了 Godot 4.5 Logger API → 固定 **9.4.0**；②`assert_has_failure_when_calling` 为 9.5+ API → 改用 `assert_typeof`/`assert_has_method`；③核心层 `assert()` 改为防御式钳制（maxi/maxf，负值按 0）——生产语义优于 debug-only assert。
- CI 运行前需先 `godot --headless --import`（刷新全局类缓存，避免新 class_name 在 autoload 解析期未注册——已在 ci.yml 补该步骤）。

## 4. 后续

- 按 EPT-01-S07 CI 落地后，单测自动门禁（失败即阻断构建）；
- 每个 Story 完成时补充对应 `tests/unit/test_*.gd`，附测试证据路径（验收标准要求）。
