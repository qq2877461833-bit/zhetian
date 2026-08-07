# EPIC-01 基础框架（Foundation）

- Epic ID：EPT-01
- 目标：落地基础层 6 模块（Bootstrapper/ResourceManager/NetManager/SaveManager/TimeService/Telemetry）+ Godot 4.4 脚手架 + CI 体积门禁 + 数据表 Schema 校验，为全部玩法 Epic 提供地基。
- 架构依据：ARCH-ENG-006 §2/§5/§6/§8；ARCH-ENG-005（CI）；ARCH-ENG-002（预算）；ADR-0002/0003/0004
- 依赖：无（首个 Epic；但 Story 拆分依赖 EPIC-02~06 的需求定义，实施顺序上 EPT-01 先行）
- 验收总口径：CI 绿（Lint + Schema 校验 + 单测 + 导出 + 体积门禁）；空项目 Web 导出通过 ARCH-ENG-002 实测清单

## Stories

### EPT-01-S01 Godot 4.4 脚手架与版本锁定
- REQ 锚点：ADR-0001；ARCH-ENG-003 §1
- ADR 指引：ADR-0002/0003/0004 上下文
- 验收标准（可测）：
  1. `godot --version` 输出 4.4.x；项目 `project.godot` 声明 GDScript 主语言；
  2. 空项目 Web 导出（单线程）无报错；
  3. 目录骨架（src/core、tests、production）建立。
- 依赖：无

### EPT-01-S02 启动与加载阶段机（Bootstrapper）
- REQ 锚点：ARCH-ENG-006 §2.1；ARCH-ENG-002 §5（阶段0→1→2）
- ADR 指引：ADR-0003（登录即联网）
- 验收标准（可测）：
  1. stage0→1 转换在首屏资源就绪后触发；stage1 失败走占位回退不白屏；
  2. 阶段进度信号 `stage_changed` 可被 UI 订阅；
  3. 单测：阶段机状态转移矩阵通过。
- 依赖：EPT-01-S01

### EPT-01-S03 资源管理（ResourceManager：首包/远程 Bundle）
- REQ 锚点：ARCH-ENG-006 §2.2；ARCH-ENG-002 §5.3；美术圣经 §8.4
- ADR 指引：ADR-0004（清单/版本）
- 验收标准（可测）：
  1. 远程 .pck Bundle 按需加载；失败回退（本地占位 + 重试），禁静默失败；
  2. manifest.json 读取 + 版本校验；
  3. 单测：mock 服务器场景下加载成功/失败/回退三路径。
- 依赖：EPT-01-S02

### EPT-01-S04 网络层（NetManager）
- REQ 锚点：ARCH-ENG-006 §2.3；ADR-0003（幂等、request_id）
- ADR 指引：ADR-0003
- 验收标准（可测）：
  1. `request_async` 超时重试幂等（同一 request_id 不重复结算）；
  2. 动作白名单 + 协议版本化；
  3. 单测：mock 传输层，验证重试/去重/超时。
- 依赖：EPT-01-S02

### EPT-01-S05 存档加密与版本迁移（SaveManager）
- REQ 锚点：ARCH-ENG-006 §2.4/§3.9；GDD-001 §3.4（时间回拨）
- ADR 指引：ADR-0002
- 验收标准（可测）：
  1. 加密落盘 + 校验失败回退默认档；
  2. `migrate_if_needed` 按版本链顺序迁移；迁移失败保留 .bak；
  3. 单测：v1→v2 迁移、坏档回退、缺字段 fail-fast。
- 依赖：EPT-01-S01

### EPT-01-S06 时间服务与遥测（TimeService/Telemetry）
- REQ 锚点：GDD-001 §7.3（last_breakthrough_ts 埋点）；GDD-002 §7.3（character_acquired）
- ADR 指引：ADR-0003（服务器时间权威）
- 验收标准（可测）：
  1. `TimeService.now()` 统一服务器时间戳；未同步时结算调用拒绝；
  2. Telemetry 事件字典含 `realm_breakthrough`/`character_acquired`；
  3. 单测：偏移计算、未同步拒绝路径。
- 依赖：EPT-01-S04

### EPT-01-S07 CI 流水线与体积门禁
- REQ 锚点：ARCH-ENG-005 §1/§2/§3
- ADR 指引：ADR-0004（Schema 校验）
- 验收标准（可测）：
  1. CI 五阶段（Lint→Schema→单测→导出→体积门禁）全部可运行；
  2. 门禁数值：首屏 <5MB / 引擎壳 ≤12MB / Bundle ≤3MB / Shader Variant ≤24，超限 fail；
  3. 产物哈希命名 + manifest.json + CDN immutable 头配置说明。
- 依赖：EPT-01-S01~S06
