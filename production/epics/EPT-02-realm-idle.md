# EPIC-02 核心循环：境界与放置（Realm & Idle）

- Epic ID：EPT-02
- 目标：落地核心循环两根支柱——境界系统（RealmEngine）与放置收益（IdleIncomeEngine）+ 经济基础（EconomyService 最小闭环）。P1/P3 支柱的直接实现。
- 架构依据：ARCH-ENG-006 §3.1/§3.2/§3.3；GDD-001 全量；ADR-0002/0003/0004
- 依赖：EPT-01（S04 网络 / S06 时间）
- 验收总口径：境界突破与离线结算闭环可 headless 单测；服务端结算与客户端只读打通

## Stories

### EPT-02-S01 境界数据表（realm.json）
- REQ 锚点：REQ-001-3.1/3.3；REQ-001-8.1（大境界等待 1h/2h）
- ADR 指引：ADR-0004（Schema + 引用完整性）
- 验收标准（可测）：
  1. realm.json 含轮海 4 段 + 道宫 5 段结构、突破成本数组、params（R0/B/sub_bonus/等待时长）；
  2. CI Schema 校验通过；`schema_version` 一致；
  3. 加载器解析后与 GDD-001 §3.3 样例表逐项一致。
- 依赖：EPT-01-S07（CI Schema）

### EPT-02-S02 突破成本与验证（RealmEngine.calc_cost / can_breakthrough）
- REQ 锚点：REQ-001-3.3（C_ling/C_yuan/stage_req）；REQ-003-4.2（三星验证）
- ADR 指引：ADR-0003（服务端结算）
- 验收标准（可测）：
  1. `calc_cost(0)` = {50000, 20, 1}；`calc_cost(8)` stage_req=25；
  2. 成本指数增长（×1.65/段）、源石每大境 ×1.55；
  3. `can_breakthrough` 校验资源/关卡/等待三要素，缺口返回可读信息；
  4. 单测覆盖样例表（GDD-001 §3.3 表 i=0..8）。
- 依赖：EPT-02-S01

### EPT-02-S03 放置产出速率（IdleIncomeEngine.calc_rate / calc_total_rate）
- REQ 锚点：REQ-001-3.2.1/3.2.2（R_c 公式、账号汇总）
- ADR 指引：ADR-0003
- 验收标准（可测）：
  1. 苦海 (0,0)=10、彼岸 (0,3)=11.5、肾藏 (1,4)=19.2（GDD-001 样例）；
  2. 多修炼位账号汇总 = Σ R_c；
  3. 单测覆盖样例与边界（负数索引拒绝）。
- 依赖：EPT-02-S01；EPT-01-S05（SaveModel）

### EPT-02-S04 离线结算（IdleIncomeEngine.settle_offline）
- REQ 锚点：REQ-001-3.2.3/3.4（80%/12h 封顶/服务器时间戳）；REQ-001-6.2（出关结算仪式）
- ADR 指引：ADR-0002（存档缓存）/ADR-0003（服务端结算）
- 验收标准（可测）：
  1. 离线 12h = R×0.8×43200；超 12h 截断不产出；
  2. 多修炼位分结算后汇总；结算用服务端时间戳（TimeService）；
  3. 结算结果含"已达闭关上限"标记（超时场景）；
  4. 单测：0s/边界 43200s/超限 90000s 三路径。
- 依赖：EPT-02-S03；EPT-01-S06（TimeService）

### EPT-02-S05 大境界等待（服务端计时）
- REQ 锚点：REQ-001-3.1/6.2.1（轮海→道宫 1h、后续 2h；离线不重置；加速道具）
- ADR 指引：ADR-0003（防篡改点 #6）
- 验收标准（可测）：
  1. 启动等待返回结束时间戳（服务器计时）；离线不重置；
  2. 回归时若已结束，自动完成突破并合并离线结算展示；
  3. 加速道具缩短等待（付费只买时间，REQ-001-5.3）；
  4. 单测：等待完成/未完成/加速三路径。
- 依赖：EPT-02-S02/S04

### EPT-02-S06 经济基础（EconomyService：双币）
- REQ 锚点：REQ-001-5.1/5.2/7.1（双币分层、源石不入挂机、防通胀）
- ADR 指引：ADR-0003（所有改动经服务端）
- 验收标准（可测）：
  1. add/spend 幂等且带 reason 审计；balance 只读；
  2. 源石不来自放置产出（结算路径禁止）；
  3. 单测：余额不足拒绝、负数拒绝、reason 审计记录。
- 依赖：EPT-02-S04；EPT-01-S05
