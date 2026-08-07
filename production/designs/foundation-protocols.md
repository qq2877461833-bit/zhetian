# 基础层协议设计细化（EPT-01 S02-S06）

- 作者：engineering-lead（程基岩）
- 日期：2026-08-06
- 关联：production/epics/EPT-01-foundation.md（S02-S06）；ARCH-ENG-006 §2；ADR-0002/0003/0004
- 状态：**设计细化（不依赖 Godot 环境）**；实现随环境就绪落地

---

## 1. S02 Bootstrapper 加载阶段机

| 状态 | 名称 | 进入条件 | 动作 | 失败处理 |
|---|---|---|---|---|
| STAGE_BOOT | 启动 | 应用加载 | 读 manifest、校验引擎能力（WebGL2） | 引导页提示升级浏览器 |
| STAGE_SHELL | 引擎壳（阶段0） | 能力校验通过 | 加载 wasm + 引导壳（loading UI） | 重试 ×3 → 占位页 |
| STAGE_FIRST | 首屏（阶段1） | 引擎壳就绪 | 加载首屏 Bundle（标题+新手区+UI 核心） | 本地占位资源回退 |
| STAGE_MAIN | 主界面 | 首屏就绪 | 进入 Main.tscn，触发登录同步 | 弱网重试，不阻塞单机演示 |

- 信号：`stage_changed(stage: int, progress: float)`；progress 为加载字节进度（0~1）。
- 约束：阶段机不持有业务；只做编排（ARCH-ENG-006 §2.1）。

## 2. S03 manifest.json 协议定义（资源清单）

CI 每次构建生成 `build/web/manifest.json`（ARCH-ENG-005 §3）：

```json
{
  "version": "1.0.0",
  "schema_version": 1,
  "built_at": "2026-08-06T00:00:00Z",
  "engine": { "godot": "4.4.1", "threaded": false },
  "bundles": [
    { "id": "first_screen", "file": "first_screen.<hash>.pck", "size_bytes": 1048576, "hash": "sha256:...", "required": true },
    { "id": "huanggu_newbie", "file": "huanggu_newbie.<hash>.pck", "size_bytes": 2097152, "hash": "sha256:...", "required": false }
  ],
  "size_gate": { "first_screen_art_bytes": 5242880, "engine_shell_bytes": 12582912, "bundle_max_bytes": 3145728 }
}
```

- 加载流程：读 manifest → 校验 `schema_version` → 按 `required` 依次加载 → 进度回调 → 完成。
- 远程 Bundle 协议：`ResourceManager.load_bundle(bundle_id)` 按 manifest 定位文件；加载失败 → 本地占位 + 重试（指数退避 ≤3 次）；Bundle 版本不兼容 → 提示刷新。
- 缓存：哈希命名 + `Cache-Control: immutable`；index.html `no-cache`（每次校验 manifest）。

## 3. S04 NetManager 协议（动作白名单 + 幂等）

| 字段 | 规则 |
|---|---|
| `proto_version` | 整数，随协议变更递增（当前 1）；不匹配拒绝 |
| `action` | 白名单字符串（见下），禁任意字符串 |
| `request_id` | UUID（客户端生成），服务端去重 → **幂等**（重试不重复结算，ADR-0003） |
| `payload` | JSON 对象，按 action 校验 |

**动作白名单（Sprint 1 最小集，随 Epic 扩展）**：

| action | 用途 | 权威侧 |
|---|---|---|
| `auth.login` | 登录 + 拉取权威存档 | 服务端 |
| `idle.settle_offline` | 离线收益结算 | 服务端 |
| `realm.begin_breakthrough` | 启动大境界等待 | 服务端 |
| `realm.complete_breakthrough` | 领取突破结果 | 服务端 |
| `battle.simulate` | 主线/副本战斗结算 | 服务端 |
| `telemetry.report` | 埋点上报 | 服务端（追加） |

- 约束：客户端无写权限直通；一切改状态动作经服务端（ADR-0003）。
- 超时/重试：请求超时 8s，重试携带同一 `request_id`（幂等）。

## 4. S05 SaveModel 序列化格式 + 迁移链

`user://save.json`（加密缓存，ADR-0002；明文展示结构）：

```json
{
  "version": 1,
  "player": { "ling": 0, "yuan": 0, "energy": 120, "energy_ts": 0,
              "last_offline_ts": 0, "main_realm": "lunhai", "main_sub_index": 0 },
  "slots": { "0": "ye_fan" },
  "characters": {
    "ye_fan": { "realm": "lunhai", "sub_index": 0, "level": 1, "star": 0,
                "artifact": null, "skills": {} }
  },
  "gacha": { "standard": { "di_pity": 0, "tian_pity": 0 } },
  "dungeon": { "daily_count": {} },
  "emperor": { "rank": 0, "points": 0, "streak": 0, "defense_snapshot": null },
  "flags": {}
}
```

- 迁移链（v1 → v2 示例）：`migrate_if_needed(raw)` 依 `version` 顺序执行迁移函数；迁移失败保留 `save.json.bak`，回退默认档（ADR-0002）。
- 关键字段不可由客户端信任：数值/进度以服务端权威为准，本地仅为缓存展示。

## 5. S06 遥测事件字典 + 时间同步

**事件字典（Sprint 1 最小集）**：

| event | 字段 | 锚点 |
|---|---|---|
| `realm_breakthrough` | char_id, realm, sub_index, ts | GDD-001 §7.3（P1 失守告警） |
| `idle_offline_settle` | delta_sec, ling_gained, capped | GDD-001 §3.2.3 |
| `battle_clear` | stage_id, stars, rounds | GDD-003（难度曲线） |
| `last_breakthrough_ts` | 账号级最近突破（告警用派生） | GDD-001 §7.3 |
| `session_start` / `session_end` | ts, duration | P3 会话时长校验 |

**TimeService 同步协议**：
- 登录响应携带 `server_ts`；客户端记录偏移 `offset = server_ts - local_ts`；`now() = local_ts + offset`。
- 偏移漂移 >5s 触发重同步；结算一律用 `now()`（服务端权威，防系统回拨，GDD-001 §3.4）。
- 未同步时：结算类动作拒绝（`is_server_synced() == false` 时 `settle_offline` 报错）。

---

## 6. 与 Story 验收标准的对应

| Story | 本文档提供 |
|---|---|
| EPT-01-S02 | §1 阶段机状态表 |
| EPT-01-S03 | §2 manifest 协议 + Bundle 加载流程 |
| EPT-01-S04 | §3 动作白名单 + 幂等规则 |
| EPT-01-S05 | §4 SaveModel 格式 + 迁移链 |
| EPT-01-S06 | §5 遥测字典 + 时间同步协议 |
