# 《遮天》主架构文档（Master Architecture）

- 文档编号：ARCH-ENG-006
- 阶段：Phase 3 技术搭建 · 主架构（P0）
- 作者：engineering-lead（程基岩）
- 日期：2026-08-06
- 版本：V1.1（评审门控 PASS · 项目方拍板：服务端 GDScript 复用定案）
- 状态：已审批（Full 评审 PASS，Phase 4 Story 拆分唯一架构依据）
- 输入基线：
  - ADR-0001（Godot 4.x / GDScript，已审批）；ARCH-ENG-002（预算口径）；ARCH-ENG-003（引擎参考）；ARCH-ENG-004（分层草案）；ARCH-ENG-005（CI 原型）
  - GDD-001~005（全部定稿）；美术圣经 v0.2；概念文档（主推放置修仙 × 卡牌收集）
- 需求锚点约定：本文以 `REQ-<GDD>-<节>` 标注需求来源（如 `REQ-001-3.2.1` = GDD-001 §3.2.1），供 Phase 4 Story 拆分直接引用。

---

## 1. 架构总览

沿用 ARCH-ENG-004 三层模型：**基础层（Foundation）→ 核心层（Core）→ 玩法层（Gameplay）**，依赖单向，禁止反向。

```
┌─────────────────────────────────────────────────────────┐
│ 玩法层（7 模块）  主界面/战斗演出/副本/帝路/突破演出/抽卡/结算  │
├─────────────────────────────────────────────────────────┤
│ 核心层（8 服务 + 数据模型）  境界/放置/经济/角色/抽卡/战斗/   │
│                        副本掉落/帝路   ← 纯逻辑、可单测      │
├─────────────────────────────────────────────────────────┤
│ 基础层（6 模块）  Bootstrapper/资源管理/网络/存档/时间/遥测    │
└─────────────────────────────────────────────────────────┘
        ↕ 服务端（权威：结算/掉落/抽卡/离线/帝路镜像）
```

**服务端角色（详见 §7）**：本项目为 Web 放置 × 卡牌，经济/数值/竞争相关全部**服务端权威**；Godot Web 客户端只做表现与意图上报。单机/离线不成立（在线游戏），登录即同步存档。

---

## 2. 基础层模块接口（Godot 4.4 / GDScript）

> 接口为**签名级草案**，Phase 4 实现校验；依赖引擎参考 ARCH-ENG-003。

### 2.1 Bootstrapper（Autoload 单例）
```gdscript
## 启动与加载阶段机：stage0 引擎壳 → stage1 首屏 → stage2 远程 Bundle
class_name Bootstrapper extends Node

signal stage_changed(stage: int, progress: float)

func boot() -> void            ## 读取启动配置、校验引擎/浏览器能力（WebGL2）
func load_first_screen() -> void   ## 加载首屏资源（阶段1），失败走占位回退
func start_game() -> void      ## 进入主场景
```
- 约束：不引用任何核心/玩法业务；只做编排。

### 2.2 ResourceManager（Autoload）
```gdscript
## 资源分组加载：首包 / 远程 Bundle（.pck）按需加载，版本清单驱动
class_name ResourceManager extends Node

func load_bundle(bundle_id: String) -> PackedScene   ## 远程 Bundle 按需加载
func preload_first_screen() -> void
func get_manifest() -> Dictionary                    ## manifest.json（CI 生成）
```
- 约束：加载失败必须回退（本地占位 + 重试），禁静默失败；对应 ARCH-ENG-005 §3 回退策略。

### 2.3 NetManager（Autoload）
```gdscript
## HTTP/WS 传输封装：协议编解码、超时重试、会话
class_name NetManager extends Node

func request(action: String, payload: Dictionary) -> Dictionary   ## 同步语义封装（内部异步）
func request_async(action: String, payload: Dictionary, callback: Callable) -> void
func get_server_time() -> int      ## 服务器时间戳（防回拨，REQ-001-3.4）
```
- 约束：动作白名单；签名与请求体版本化；超时重试幂等（防重复结算）。

### 2.4 SaveManager（Autoload）— 见 ADR-0002
```gdscript
class_name SaveManager extends Node

func load_save() -> SaveModel             ## 解密加载，失败回退到默认档
func save(model: SaveModel) -> void        ## 加密落盘（user://）+ 版本迁移
func migrate_if_needed(raw: Dictionary) -> Dictionary   ## 存档版本迁移
```

### 2.5 TimeService（Autoload）
```gdscript
class_name TimeService extends Node

var server_offset_ms: int                 ## 服务器-本地时钟偏移
func now() -> int                         ## 权威时间戳（结算一律用此）
func is_server_synced() -> bool
```

### 2.6 Telemetry（Autoload）
```gdscript
class_name Telemetry extends Node

func track(event: String, props: Dictionary) -> void
## 锚点埋点：realm_breakthrough / character_acquired / last_breakthrough_ts（REQ-001-7.3 / REQ-002-7.3）
func report_anchors() -> Dictionary
```

---

## 3. 核心层模块接口（纯逻辑，零渲染，可 headless 单测）

> 核心层只依赖数据表（JSON）+ 数据模型；不 import 任何 Godot 渲染节点（`RefCounted`/纯类）。

### 3.1 RealmEngine（境界）
```gdscript
class_name RealmEngine extends RefCounted

## REQ-001-3.1 / REQ-001-3.3
func calc_cost(realm_index: int, sub_index: int) -> Dictionary   ## {ling, yuan, stage_req}
func can_breakthrough(profile: SaveModel, char_id: String) -> Dictionary   ## 校验资源/关卡/等待
func begin_big_breakthrough(profile: SaveModel, char_id: String) -> int     ## 启动大境界等待，返回结束时间戳
func complete_breakthrough(profile: SaveModel, char_id: String) -> Dictionary ## 结算突破结果
```

### 3.2 IdleIncomeEngine（放置收益）
```gdscript
class_name IdleIncomeEngine extends RefCounted

## REQ-001-3.2.1 / 3.2.2 / 3.2.3
func calc_rate(profile: SaveModel, char_id: String) -> float     ## R_c = R0×B^big×(1+0.05×sub)
func calc_total_rate(profile: SaveModel) -> float                ## Σ R_c
func settle_offline(profile: SaveModel, from_ts: int, to_ts: int) -> Dictionary  ## 离线结算（服务端调用）
func cap_offline(delta_sec: int) -> int                          ## min(Δt, 43200)
```

### 3.3 EconomyService（经济）
```gdscript
class_name EconomyService extends RefCounted

## REQ-001-5 / REQ-004-7
func add(profile: SaveModel, currency: String, amount: int, reason: String) -> int
func spend(profile: SaveModel, currency: String, amount: int, reason: String) -> bool
func balance_of(profile: SaveModel, currency: String) -> int
## 双币：LING（灵石）/ YUAN（源石）；禁止直接改字段（防绕过）
```

### 3.4 CharacterService（角色/养成）
```gdscript
class_name CharacterService extends RefCounted

## REQ-002-3.2 / 3.3
func level_up(profile: SaveModel, char_id: String, books: int) -> Dictionary
func promote_star(profile: SaveModel, char_id: String) -> Dictionary      ## 升星（碎片）
func equip_artifact(profile: SaveModel, char_id: String, artifact_id: String) -> void
func train_skill(profile: SaveModel, char_id: String, skill_id: String) -> void  ## 功法
func realm_ceiling(profile: SaveModel, char_id: String) -> int   ## 账号上限：主角-1 大境（REQ-002-3.3）
```

### 3.5 GachaService（抽卡）— 服务端权威（ADR-0003）
```gdscript
class_name GachaService extends RefCounted

## REQ-002-3.1.2（概率/保底公开）
func draw(profile: SaveModel, pool_id: String, count: int) -> Dictionary   ## 服务端 RNG + 保底计数持久化
func pity_state(profile: SaveModel, pool_id: String) -> Dictionary         ## {di_pity, tian_pity}
```

### 3.6 BattleService（战斗结算）— 服务端权威（ADR-0003）
```gdscript
class_name BattleService extends RefCounted

## REQ-003-3 / 5；确定性模拟，客户端只播放演出
func simulate(attacker_team: TeamSnapshot, defender_team: TeamSnapshot, stage: Dictionary, manual_actions: Array = []) -> BattleResult
## BattleResult: {winner, rounds, hp_log, rewards, stars}
func calc_damage(atk: float, skill_coef: float, counter_mult: float, def_: float) -> float  ## REQ-003-5.1
```

### 3.7 DungeonService（副本/掉落）— 服务端权威（ADR-0003）
```gdscript
class_name DungeonService extends RefCounted

## REQ-004-3 / 5
func roll_drops(dungeon_id: String, tier: int, seed: int) -> Array      ## 掉落表（drop.json）+ 种子
func check_daily(dungeon_id: String, profile: SaveModel) -> bool         ## 次数+体力双闸门
func consume_entry(profile: SaveModel, dungeon_id: String) -> bool
func settle_clear(profile: SaveModel, dungeon_id: String, tier: int, stars: int) -> Dictionary
```

### 3.8 EmperorRoadService（帝路）— 服务端权威（ADR-0003）
```gdscript
class_name EmperorRoadService extends RefCounted

## REQ-005-3 / 5
func list_opponents(profile: SaveModel) -> Array[TeamSnapshot]          ## 5 名推荐（±1 段 / 战力 ±15%）
func challenge(profile: SaveModel, opponent_snapshot: TeamSnapshot) -> BattleResult  ## 镜像结算
func apply_rank_delta(profile: SaveModel, win: bool, streak: int) -> int ## 积分 ±30/连胜
func snapshot_defense(profile: SaveModel) -> void                       ## 防守快照（最后布阵）
```

### 3.9 数据模型（SaveModel / PlayerProfile）
```gdscript
class_name SaveModel extends RefCounted
## 序列化为加密存档（ADR-0002）：
## {version, player:{ling, yuan, energy, energy_ts, last_offline_ts, main_realm},
##  characters:{id:{realm,sub,level,star,artifact,skills,rate_cache}},
##  slots:{0:char_id,...}, gacha:{pool:{di_pity,tian_pity}}, dungeon:{daily_count},
##  emperor:{rank,points,streak,defense_snapshot}, flags:{...}}
```

---

## 4. 核心层模块 ↔ GDD 映射表（Phase 4 Story 拆分依据）

| 核心模块 | GDD | 需求锚点（REQ） | 关键定案项 |
|---|---|---|---|
| RealmEngine | GDD-001 | REQ-001-3.1/3.3/8.1 | 小段即时、大境界 1h/2h 等待；突破成本指数；关卡验证 stage_req=3i+1 |
| IdleIncomeEngine | GDD-001 | REQ-001-3.2.1~3.2.5/3.4/7.1 | 多修炼位并行；R_c 公式；离线 80%/12h 封顶；MVP 3 位解锁节奏 |
| EconomyService | GDD-001/004 | REQ-001-5/7.1；REQ-004-7 | 双币分层（灵石/源石）；源石不入挂机；不卖成长 |
| CharacterService | GDD-002 | REQ-002-3.2/3.3/7.1/7.2 | 每角色独立境界+账号上限-1 大境；五维养成；原著向克制环归属 |
| GachaService | GDD-002 | REQ-002-3.1.2/7.3 | 概率公开；保底 60 地/90 天；卡池分段；源石碎片副产物 |
| BattleService | GDD-003/005 | REQ-003-3.1~3.6/5；REQ-005-5.1 | 半即时自动战斗；伤害公式 K=300；克制 1.50/0.67；3 技能/角色；手动收益 5–10% |
| DungeonService | GDD-004 | REQ-004-3.1~3.5/5/7 | 6 类副本；精英档；源石供给 3/次；试炼塔 30 层；次数+体力双闸门 |
| EmperorRoadService | GDD-005 | REQ-005-3.1~3.4/5.2/7 | 异步镜像；六段+扩展位；赛季 30 天；5 名/日；不耗体力；防守门员 |

> 覆盖率：GDD-001~005 全部需求锚点已映射；未映射项（活动剧本、运营排期、角色配置表数值）不属工程 Story 输入，标注为运营/配置线。

---

## 5. 数据表 Schema 草案（JSON 驱动，不入代码）

> 约定：所有数值表 `res://data/tables/*.json`；Schema 版本 `schema_version`；CI 校验（ARCH-ENG-005 §2）。示例为草案字段，Phase 4 细化。
> **数值唯一事实来源（与设计线确认口径，2026-08-06）**：可配置数值（掉落/概率/成本曲线等）以数据表为唯一事实来源，GDD 仅标注引用；发现出入按数据表修正并回传，无需等待设计侧逐项确认（例：GDD-002 §3.1.2 概率和 100.3% → 凡品 60%→59.7%，已按此口径修正）。

### 5.1 realm.json（境界 + 突破成本）
```json
{
  "schema_version": 1,
  "params": {
    "R0": 10, "B": 1.6, "sub_bonus": 0.05,
    "cost_growth_ling": 1.65, "cost_growth_yuan": 1.55, "c0_ling": 50000, "c0_yuan": 20,
    "eff_offline": 0.8, "cap_offline_sec": 43200,
    "big_breakthrough_wait_sec": { "lunhai_to_daogong": 3600, "default": 7200 }
  },
  "realms": [
    { "id": "lunhai", "name": "轮海境", "index": 0, "sub_stages": [
      { "id": "kuhai", "name": "苦海", "index": 0 },
      { "id": "mingquan", "name": "命泉", "index": 1 },
      { "id": "shenqiao", "name": "神桥", "index": 2 },
      { "id": "bian", "name": "彼岸", "index": 3 }
    ]},
    { "id": "daogong", "name": "道宫境", "index": 1, "sub_stages": [
      { "id": "xinzang", "name": "心藏", "index": 4 },
      { "id": "ganzang", "name": "肝藏", "index": 5 },
      { "id": "pizang", "name": "脾藏", "index": 6 },
      { "id": "feizang", "name": "肺藏", "index": 7 },
      { "id": "shenzang", "name": "肾藏", "index": 8 }
    ]}
  ],
  "breakthrough_costs": [
    { "sub_index": 0, "cost_ling": 50000, "cost_yuan": 20, "stage_req": 1 },
    { "sub_index": 1, "cost_ling": 82500, "cost_yuan": 20, "stage_req": 4 }
  ]
}
```

### 5.2 character.json（角色 + 养成基础）
```json
{
  "schema_version": 1,
  "characters": [
    {
      "id": "ye_fan", "name": "叶凡", "rarity": "di_pin", "origin": "plot",
      "class": "huanggu_tizhi", "faction": "donghuang", "is_original": false,
      "base": { "atk": 120, "def": 80, "hp": 1500, "spd": 100 },
      "growth": { "atk_per_level": 6, "hp_per_level": 60 },
      "skills": ["pu_gong", "zhu_dong_1", "da_zhao_1"],
      "artifact_slots": 2, "fragments_for_star": 30
    }
  ]
}
```

### 5.3 battle.json（伤害/克制/关卡）
```json
{
  "schema_version": 1,
  "damage": { "k_def": 300, "crit_mult": 1.5, "timeout_sec": 120 },
  "counter": {
    "huanggu_tizhi": { "huanggu_tizhi": 1.00, "xiandao_shentong": 1.50, "bingqi_liupai": 0.67 },
    "xiandao_shentong": { "huanggu_tizhi": 0.67, "xiandao_shentong": 1.00, "bingqi_liupai": 1.50 },
    "bingqi_liupai":   { "huanggu_tizhi": 1.50, "xiandao_shentong": 0.67, "bingqi_liupai": 1.00 }
  },
  "energy": { "cap": 120, "recover_per_sec": 0.003333, "free_claim_daily": 2, "free_claim_amount": 30,
              "paid_claim_daily": 3, "paid_claim_amount": 60 },
  "stages": [
    { "id": "s001", "chapter": 1, "order": 1, "is_verify": true, "verify_sub_index": 0,
      "enemy_power": 1000, "turn_limit": 12, "first_clear": { "ling": 80000, "yuan": 2 } }
  ]
}
```

### 5.4 drop.json（副本掉落 + 试炼塔）
```json
{
  "schema_version": 1,
  "dungeons": [
    { "id": "yuanshi_mijing", "name": "源石秘境", "energy_cost": 10, "daily_limit": 2, "tiers": [
      { "tier": 1, "unlock_realm": "lunhai", "drops": [
          { "type": "yuan", "min": 3, "max": 3, "weight": 1.0 },
          { "type": "yuan_shard", "min": 2, "max": 2, "weight": 1.0 } ] },
      { "tier": 2, "unlock_realm": "daogong", "drops": [ { "type": "yuan", "min": 5, "max": 5 } ] },
      { "tier": 99, "is_elite": true, "drops": [ { "type": "yuan", "min": 7, "max": 7 } ] }
    ]},
    { "id": "lingshi_kuangmai", "name": "灵石矿脉", "energy_cost": 10, "daily_limit": 3, "tiers": [
      { "tier": 1, "unlock_realm": "lunhai", "drops": [ { "type": "ling", "min": 80000, "max": 80000 } ] }
    ]}
  ],
  "tower": { "energy_per_floor": 5, "daily_max_floors": 10, "node_every": 10, "max_floors": 30 }
}
```

### 5.5 gacha.json（抽卡概率/保底，服务端权威）
```json
{
  "schema_version": 1,
  "pools": [
    { "id": "standard", "name": "常驻池",
      "rarity_prob": { "fan": 0.60, "ling": 0.25, "xuan": 0.10, "di": 0.04, "tian": 0.01, "di_pin": 0.003 },
      "pity_di": 60, "pity_tian": 90,
      "segment": { "open_from": "lunhai", "open_di_tian_after": "daogong" },
      "byproduct": { "type": "yuan_shard", "amount": 1 } }
  ]
}
```

> 说明：以上为四张核心表（realm/character/battle/drop）+ 抽卡表草案；`constants.json`（全局常量）与 `stage_turn_limit[n]`（REQ-003-4.3 逐关配置）随 Phase 4 细化并入 battle.json 或独立表。所有表 Schema 由 CI 校验（ARCH-ENG-005）。

---

## 6. 场景树组织（Godot 场景树草案）

```
Bootstrap（Autoload: Bootstrapper / ResourceManager / NetManager / SaveManager / TimeService / Telemetry）
│
├── Main.tscn（主界面，阶段1首屏）
│   ├── MainUI (Control)
│   │   ├── HUD（灵石/源石栏 · 闭关/出关按钮 · 突破入口）
│   │   ├── RealmPanel（境界/突破/破境中计时条）
│   │   ├── CharacterPanel（五维养成 · 修炼位管理）
│   │   ├── GachaUI（抽卡/保底进度）
│   │   ├── DungeonUI（秘境入口 · 副本列表 · 结算）
│   │   └── EmperorRoadUI（帝路地图 · 对手列表 · 段位）
│   └── World（荒古禁地新手区：Node2D + TileMapLayer + 演出节点）
│
├── Battle.tscn（战斗演出，加载核心层 BattleResult 播放）
│   ├── Battlefield（行动条 · 角色站位 · 粒子/特效 · 手动技能按钮）
│   └── BattleResultUI（星级/掉落/结算 · 跳过/2x）
│
├── Dungeon.tscn（复用 Battle 演出 + SettlementUI 掉落演出）
└── EmperorRoad.tscn（对手列表 → 复用 Battle → 段位结算）
```

- 场景切换：`get_tree().change_scene_to_file()`；战斗演出场景可被主线/副本/帝路复用（同一 Battle 场景组件）。
- 约束：玩法层节点不持有数值状态，只读核心层暴露的视图（`SaveModel` 只读接口或事件快照）。

---

## 7. 服务端/客户端职责切分（防篡改点）

> 总原则（ADR-0003）：**服务端权威，客户端只读**。客户端 Godot Web 只做：输入意图上报、演出播放、只读展示；一切"改状态"的动作经服务端验证后回写。

| # | 防篡改点 | 权威侧 | 依据 | 客户端行为 |
|---|---|---|---|---|
| 1 | **战斗结算**（主线/副本/帝路） | 服务端确定性模拟 | REQ-003-3.1 / REQ-005-3.1 | 上报阵容+意图，播放服务端返回的 BattleResult 演出 |
| 2 | **掉落**（副本/扫荡/首通） | 服务端 roll + 种子 | REQ-004-4.3/5.1 | 只展示结算结果；断线补发由服务端保证 |
| 3 | **抽卡保底** | 服务端 RNG + 保底计数持久化 | REQ-002-3.1.2/7.3 | 提交抽卡请求，展示结果；保底进度只读 |
| 4 | **离线结算** | 服务端时间戳（TimeService） | REQ-001-3.2.3/3.4 | 登录时请求结算，展示"闭关结算"演出 |
| 5 | **帝路镜像** | 服务端防守快照 + 结算 | REQ-005-3.1/3.4 | 挑战对手镜像，播放结果；防守快照由服务端保存 |
| 6 | **大境界等待计时** | 服务端计时（离线不重置） | REQ-001-3.1/6.2.1 | 展示"破境中"倒计时；回归请求完成 |
| 7 | **体力恢复/每日重置** | 服务端时间戳 | REQ-003-3.5 / REQ-004-4.2 | 显示剩余体力/次数，不本地改 |
| 8 | **源石供给预算** | 服务端总量控制 | REQ-004-7.1 / REQ-005-7.3 | 只读展示；活动/段位奖励由服务端发放 |

> 实现要点：服务端提供幂等 API（重试不重复结算）；客户端所有写操作经 `NetManager.request`；**核心层服务作为服务端结算逻辑的同一份代码（GDScript 复用，项目方拍板定案）**——服务端运行形态（Godot 无头 / GDScript 托管）留待 Phase 4 技术验证确定，两端逻辑一致性由此保证。

---

## 8. 架构评审自查清单（Full 评审门控用）

### 8.1 依赖方向
- [ ] 玩法层 → 核心层 → 基础层，无反向依赖
- [ ] 核心层不 import 渲染节点；玩法层不持有数值状态
- [ ] Autoload 单例仅限基础层（白名单：Bootstrapper/ResourceManager/NetManager/SaveManager/TimeService/Telemetry）

### 8.2 数据驱动
- [ ] 数值全在 JSON 数据表，代码零硬编码数值（magic number 视为缺陷）
- [ ] 数据表 Schema 版本化 + CI 校验通过才能构建
- [ ] 热更路径：数据表独立打包，可远程更新

### 8.3 防篡改点
- [ ] §7 八项防篡改点全部服务端权威；客户端无写权限直通
- [ ] 所有写操作幂等（重试安全）
- [ ] 服务器时间戳统一（TimeService），无本地时间可信路径

### 8.4 性能预算
- [ ] 首屏可玩 <5MB（美术增量）/ 引擎壳 ≤9MB / Bundle ≤3MB（ARCH-ENG-002）
- [ ] 移动端 2019 中端机 30fps；粒子/纹理/Shader 上限对齐美术圣经 §7/§8
- [ ] 帧循环零热路径分配（对象池、禁 load/字符串拼接）

### 8.5 测试覆盖
- [ ] 核心层 8 服务 headless 单测（CI 必跑）
- [ ] 基础层 mock 化测试（网络/存档/时间）
- [ ] 每个 Story 附测试证据路径（Phase 4 执行）

---

## 9. 下一步（Phase 4 脚手架）

1. 主理人评审本架构 + 3 条 ADR（ADR-0002~0004，见 `adr/`）；
2. 依据映射表（§4）拆分 Epic → Story，每条 Story 嵌 REQ 锚点 + ADR 指引 + 验收标准；
3. 按 ARCH-ENG-005 落地 CI，先跑核心层单测骨架（RealmEngine / IdleIncomeEngine 两个最小闭环）；
4. 补 ADR：网络协议版本化、遥测数据字典（后续）。
