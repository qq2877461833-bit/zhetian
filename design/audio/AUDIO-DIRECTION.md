# 《遮天》音频方向文档（AUDIO-DIRECTION）

- 文档编号：AUDIO-DIR-001
- 阶段：打磨期 · 音频维度启动（V1.0 草案）
- 作者：audio-director（阮和鸣）
- 关联基线：
  - `design/art-bible/art-bible.md`（视觉身份：荒古苍凉为骨，仙道星辉为魂；色板/特效三分法/可访问性 Standard）
  - `design/concept/concept-doc.md`（P1 逆天争锋 / P3 片刻亦修仙）
  - `design/gdd/gdd-001-realm-and-idle.md`（突破演出 / 出关结算仪式）
  - `design/gdd/gdd-003-combat-and-stages.md`（战斗演出 / 星级 / 副本与试炼塔）
  - `src/main.gd`（Sprint 2 主控制器：全部玩法事件触发点）
  - `docs/architecture/engine-selection.md`、`docs/architecture/godot44-technical-validation.md`（Godot 4.4 / Web 预算）
- 目标平台：Web / 多端（Godot 4.4 · `gl_compatibility` · 1280×720）
- 状态：待主理人与工程线评审
- 范围声明：**本稿只定义方向与规格，不含任何实际音频文件**；资产清单（§6）供后续制作/采购排期。

---

## 0. 现状盘点与前提

| 项 | 现状 | 结论 |
|---|---|---|
| 音频资产 | 无（assets/ 下无 audio 目录，无 wav/ogg/mp3） | 从 0 起步 |
| 音频系统 | 无 AudioServer 总线配置、无播放器管理、无 AudioManager | 需工程线新建 |
| 玩法事件点 | 已从 `src/main.gd` 全部 handler 对齐（见 §5.10） | 触发点明确，可直接对接 |
| 技术底座 | Godot 4.4 · Web 导出 · gl_compatibility · 首包预算（阶段0 引擎壳 ≤9MB / 阶段1 首屏 ≤10MB，美术增量 ≤5MB） | 音频须让位预算，见 §5.8 |

**本稿立场**：音频不追"电影级铺陈"，只做三件事——(1) 用最少的声音确立"荒古修仙"的听觉身份；(2) 用「突破/抽卡揭示/大境界完成」三个高频情绪峰值的音效设计承接 P1 支柱；(3) 用克制、可循环、低干扰的 BGM 支撑 P3「片刻亦修仙」的长驻体验。

---

## 1. 听觉身份总述（一句话审美主张）

> **「荒古苍凉为骨，仙道星辉为魂——以青铜的沉重承载万古岁月，以星辉的空灵点亮超脱之路。」**

与视觉主张完全同构。听觉上建立一组**二元张力**：

| 极 | 对应视觉 | 听觉语言 |
|---|---|---|
| **荒古之骨** | 青铜绿/锈棕、封印、荒古禁地、九龙拉棺 | 低频 drone（持续低音）、铜钟长鸣、埙的气声、石磨/砂砾质感、长混响、听觉留白 |
| **仙道之魂** | 鎏金/月白/星紫、飞升、帝气、紫气东来 | 编钟/磬的高泛音、古筝泛音与轮指、箫笛气声、琉璃铃/水晶高音、上升 shimmer（星辉感） |
| **禁忌之锋**（点缀 ≤5%） | 朱砂、杀伐、邪修、黑暗动乱 | 重低音 + 轻微失真/嘶鸣、不规则节奏、突发强音——只在 Boss 大招/危险时刻出现，必须克制 |

**三条听觉禁令**（对应美术圣经 §2.4 风格禁令）：
1. 不做电子合成器主导向的"赛博/霓虹"音色（禁 neon 感的合成波）；
2. 不做密集轰炸式音效墙——保留水墨留白式的静默，音效密度克制；
3. 不做"直抄某游戏"的照搬——所有音色以东方乐器 + 拟音（Foley）质感为基础，调性上允许对标作品做"风格参照"，但不复制其母题旋律。

**调性参照（风格定位参照，非模仿对象）**：黑神话的铜钟/苍凉感、凡人修仙传的仙道器乐语言、敦煌乐器（箜篌/琵琶/编钟）的异域仙气；明确不借鉴：现代流行打击乐堆叠、暗黑系低音轰炸、日式和风太鼓主导（本作是"荒古东方"，非"江户和风"）。

---

## 2. 声音调色板（乐器 / 音色语言）

> 用于指导资产制作/采购，所有 BGM 与 SFX 音色从下列池中取材，禁止引入池外"异色"主音色（偏离即标注）。

### 2.1 乐器池

| 类别 | 乐器 | 用途 | 角色 |
|---|---|---|---|
| 打击·重 | 铜钟（大/中） | 史诗、突破高潮、荒古巨兽 | 荒古之骨 |
| 打击·清 | 石磬、编钟（高音区） | 仙道、UI 确认、星级点亮 | 仙道之魂 |
| 打击·律 | 木鱼/梆子、大鼓、板鼓 | 节奏锚点、战斗驱动、修炼时间流动 | 节奏骨架 |
| 弦乐 | 古筝（泛音/轮指/滑音）、古琴、二胡（叙事）、阮 | 旋律与意境 | 仙道之魂 + 叙事 |
| 管乐 | 埙（荒古苍凉）、箫/笛（气声飘渺）、号角式长音 | 氛围底色、战斗开场 | 双极皆可 |
| 吟唱 | 人声吟唱（无词，远场） | 仅大境界突破/帝品揭示等至高点 | 仙道之魂（至稀用） |
| 拟音 | 砂砾摩擦、石门磨启、纸卷展开、铜钱轻碰、气流 | SFX 基底 | 荒古之骨 |

### 2.2 音色质感规则

- **荒古类**：低通滤波 + 长混响（教堂/大厅类，尾音 2–4s），起音钝、衰减长；用砂砾/石质噪声做贴面。
- **仙道类**：高泛音、通透，短混响 + 微延迟（ping-pong），起音亮、衰减中；用"上升 shimmer"（高频噪声包络上扬）做星辉符号。
- **禁忌类**：压缩 + 轻微饱和/失真，突发强音后快速衰减，营造"危险一闪"。
- **听觉留白**：BGM 小节间保留 0.5–1 拍静默，SFX 同帧并发 ≤ 2 个主音效（可叠加的仅是低音 drone 类）。

---

## 3. 音乐基调（分场景）

> 每场景给出：情绪关键词 / 速度 / 乐器构成 / 循环长度 / 动态角色。BGM 全部为**循环段**（除抽卡为单次段落）。

### 3.1 主界面 / 标题（荒古禁地 · 九龙拉棺基调）

- **情绪**：孤寂苍凉 → 暗涌的逆命感（不悲不丧，有"与天争锋"的底色）
- **速度**：缓板 55–65 BPM，弱拍起，留白多
- **构成**：埙长音（主旋律，极简）+ 低频 drone（荒古底色）+ 铜钟稀疏敲击（每 8–16 小节一次）+ 古筝泛音点缀（星辉微光）+ 极轻风噪声
- **循环**：60–90s，循环点无缝（末音回落 drone）
- **动态角色**：首屏加载即起；进入主界面后让位给 3.2（可交叉淡入）

### 3.2 修炼 / 挂机（最长驻层 · 荒古禁地修炼洞府）

- **情绪**：静谧、流动、专注；"片刻亦修仙"的容器
- **速度**：60–70 BPM，节奏弱化（木鱼/水滴般极轻的点）
- **构成**：箫气声长音（低音量、低音区）+ 木鱼/水滴节奏点（象征时间流动，每拍 1 下或每 2 拍 1 下，音量 -30dB 以下）+ 古筝极轻拨弦（每 4–8 小节一次呼吸）
- **循环**：90–120s，**音量是全游戏最低的一层**（BGM -18～-14dB 区间内再压 3–6dB），保证长驻不腻
- **动态角色**：主界面/修炼/图鉴/装备/功法页默认驻留此 BGM，页签切换**不切 BGM**（减少交叉淡入次数，见 §5.4）

### 3.3 战斗（推关 / 副本 / 试炼塔）

- **情绪**：紧张、对决、节奏驱动；不血腥、不焦虑（自动战斗为主，别给玩家压迫感）
- **速度**：110–125 BPM（与自动战斗回合节奏合拍）
- **构成**：板鼓/大鼓快节奏 + 梆子（节拍锚）+ 二胡/笛短句（战斗主题，2–4 小节）+ 低频 drone
- **循环**：30–45s（战斗单关 60–90s，循环 2 次内即可，防腻）
- **动态角色**：进入战斗演出层时从 3.2 交叉淡入 3.3（1.0–1.5s）；胜利/失败不切 BGM，用 stinger + SFX 表达（减少切换次数）；演出层关闭后淡回 3.2

### 3.4 抽卡（宝物池 · 星紫调性）

- **情绪**：神秘 → 期待 → 揭示（一次性的"铺垫—上扬"段落，非循环）
- **速度**：自由节奏（rubato），无稳定拍
- **构成**：编钟/琉璃铃高泛音稀疏点缀 + 缓慢古筝拨弦 + 呼吸感混响；**揭示瞬间**：短促上行编钟音阶 + 星辉 shimmer（0.6–1.2s）
- **时长**：与 main.gd 抽卡演出对齐——紫气三帧轮播（0.35s×3 ≈ 1.05s）+ 卡面展示（~1.47s），音乐段落设计为 ~2s 的"悬念→揭示"单次 stinger 段，**不建议独立循环 BGM**（抽卡演出仅 2s，BGM 切换成本大于收益）
- **动态角色**：抽卡演出期间对 3.2 做 ducking（压低 3–6dB），演出结束恢复

### 3.5 突破（小段 / 大境界 · P1 情绪峰值）

- **小段突破**（高频事件，每 1–4h 一次）：
  - 不切 BGM；用 SFX stinger（§4.3 `break_small_success`）承接"紫气东来"上扬，2s 内完成，随后回到修炼 BGM
- **大境界突破**（轮海→道宫等，低频至高点事件）：
  - **情绪**：庄严 → 史诗 → 升华（鎏金星辉）
  - **构成**：铜钟长鸣（开场）+ 编钟上行音阶 + 大鼓渐强 + 人声吟唱（至稀用）+ 星辉 shimmer；全段 4–6s，是**全游戏最强的音乐/SFX moment**
  - **动态角色**：突破完成瞬间（`break_big_complete`）BGM ducking → stinger 全响 → 恢复；"破境中"等待期（1h/2h）用 3.2 + 铭文刻录感的低频节拍提示（极轻）

### 3.6 出关结算 / 离线回归（P3 回归仪式）

- **情绪**：温暖、满足、欢迎回归（"离开越久越有收获"）
- **构成**：轻柔磬音 + 古筝拨弦 + 铜钱轻碰序列（象征灵石入账）+ 数字滚动轻点
- **时长**：1.0–1.5s 仪式段 + 0.3–0.6s 数字滚动循环点（随数字滚动反复）
- **动态角色**：结算弹窗期间 BGM ducking 3dB，突出"收获"音

### 3.7 动态层级总览

| 层级 | 何时进入 | BGM | 音量（相对 Master） | 说明 |
|---|---|---|---|---|
| 常态 | 主界面/修炼/养成页 | 3.2 修炼 | -18～-14dB | 最长驻 |
| 战斗 | 推关/副本/试炼塔演出层 | 3.3 战斗 | -16～-12dB | 淡入 1.0–1.5s |
| 高潮 | 突破成功/大境界完成/抽卡揭示 | 3.4/3.5 stinger（非 BGM） | stinger -6～-2dB | 覆盖型，非切换型 |
| 结算 | 出关结算/抽卡结果/战斗结果 | 3.2（ducking -3dB） | -21～-17dB | 突出 SFX |

> 原则：**BGM 只在"常态 ↔ 战斗"之间切换**；其余高潮一律用 stinger + ducking，避免频繁交叉淡入造成听感抖动与性能开销。

---

## 4. 音效清单（按事件分组）

> 每条含：**事件 ID（事件命名约定见 §5.5）/ 触发点 / 情绪 / 建议时长 / 音色方向 / 变体数 / 优先级**（P0=首包必做，P1=第二优先，P2=打磨可选）。
> 时长指"完整播放时长"，含自然衰减；触发点以 `src/main.gd` 现有 handler 为准。

### 4.0 通用约定

- 所有 UI/SFX 用**变体随机**（每事件 2–6 个变体，随机播放），避免连点时的"机关枪感"。
- 失败类音效（资源不足/体力不足/验证未过）统一温和：不刺耳、不惩罚感，时长 ≤0.3s。
- 音量遵循 §5.6 总线基准；高优先级事件（突破/抽卡揭示/大境界完成）允许短暂压过其他音（ducking）。

### 4.1 UI 层

| 事件 ID | 触发点 | 情绪 | 建议时长 | 音色方向 | 变体 | 优先级 |
|---|---|---|---|---|---|---|
| `ui_click` | 所有按钮 `pressed` | 清脆确认 | 0.08–0.15s | 木鱼/竹签短敲，或金石轻叩 | 4 | P0 |
| `ui_hover` | `mouse_entered`（`_mk_button` 内） | 极轻的"可点"提示 | 0.05–0.08s | 磬音/气流微拂 | 2 | P1 |
| `ui_tab_switch` | `_switch_tab` 页签切换 | 卷轴翻页 | 0.15–0.25s | 纸张展开"唰" + 一声磬 | 1 | P0 |
| `ui_popup_open` | `_show_popup` 弹窗入场 | 丝绸/卷轴展开 | 0.2–0.3s | 布帛 + 磬（对应缩放回弹动画） | 1 | P0 |
| `ui_popup_close` | 弹窗关闭 | 收回 | 0.1–0.15s | 布帛回落 | 1 | P1 |
| `ui_confirm` | "确定"类按钮 | 确认 | 0.12s | 金石轻叩 | 2 | P0 |
| `ui_error` | 资源不足/体力不足/置灰点击 | 温和受阻 | 0.15–0.25s | 低闷钝响（木鱼重击或闷钟） | 2 | P0 |
| `ui_resource_gain` | 灵石/资源入账（顶部栏 +%d） | 收获 | 0.15–0.3s | 铜钱轻碰（东方质感金属片） | 3 | P0 |
| `ui_count_up` | 数字滚动（结算/结果列表） | 递增满足 | 0.3–0.6s 循环点 | 轻快"点点点" | 2 | P1 |

### 4.2 修炼 / 收菜

| 事件 ID | 触发点 | 情绪 | 建议时长 | 音色方向 | 变体 | 优先级 |
|---|---|---|---|---|---|---|
| `collect_success` | `_on_collect_pressed` 成功（`gain > 0`） | 收获满足 | 0.4–0.8s | 灵石哗啦入袋 + 一声上扬磬 | 3 | P0 |
| `collect_empty` | `_on_collect_pressed` 无待领取 | 温和空感 | 0.2s | 竹筒空心敲击（不刺耳） | 1 | P1 |
| `idle_tick`（可选） | 修炼位挂机循环（低频环境） | 时间流动 | 每 1–2s 一下 | 水滴/木鱼点，音量 ≤ -30dB | 2 | P2 |

### 4.3 突破（P1 核心）

| 事件 ID | 触发点 | 情绪 | 建议时长 | 音色方向 | 变体 | 优先级 |
|---|---|---|---|---|---|---|
| `break_ready_hint`（可选） | 可突破按钮高亮脉动（周期 1s） | 轻微催促 | 0.08s | 一声轻磬（可关，防烦） | 1 | P2 |
| `break_small_success` | `_do_breakthrough`（小段成功 + `_flash_purple`） | 明朗上扬 | 1.2–2.0s | 编钟上行 3–4 音 + 紫气 shimmer（上升气流/星辉） | 3 | P0 |
| `break_big_start` | `_start_big_wait`（大境界等待开始） | 庄严史诗 | 1.5–2.5s | 铜钟长鸣 + 低鼓 + 上升编钟 | 1 | P0 |
| `break_big_complete` | 大境界等待结束回归/加速完成（全屏紫气演出） | 升华至高点 | 3–4s | 铜钟大鸣 + 编钟上行 + 人声吟唱（可选）+ 紫气 shimmer | 1 | P0 |
| `break_fail` | `_on_break_pressed` 任一不足（灵石/源石/关卡） | 温和受阻 | 0.25s | 复用 `ui_error` 变体 + 弹窗 | 1 | P0 |
| `break_wait_tick`（可选） | "破境中"计时条（铭文刻录） | 进行中 | 每 2s 一下 | 低频节拍，极轻 | 2 | P2 |

### 4.4 战斗（推关 / 副本 / 试炼塔）

> 战斗演出层 `_show_battle_result`：攻防回合 + 双血条 + 胜负。暴击/闪避在数值层已存在（暴击率/闪避率属性），演出层飘字触发处接音。

| 事件 ID | 触发点 | 情绪 | 建议时长 | 音色方向 | 变体 | 优先级 |
|---|---|---|---|---|---|---|
| `combat_start` | 战斗演出层开场（VS 出现） | 对决 | 0.4–0.6s | 低鼓 + 号角式埙长音 | 1 | P0 |
| `combat_hit` | 普攻命中（伤害结算/飘字） | 打击感 | 0.1–0.2s | 金属碰撞（兵器流派）/ 石青铜重击（荒古体质）/ 气流（仙道神通） | 6 | P0 |
| `combat_crit` | 暴击（暴击飘字） | 爽快爆发 | 0.25–0.4s | 更亮更重的打击 + 高频星辉 shimmer + 上挑滑音 | 3 | P0 |
| `combat_dodge` | 闪避（闪避飘字） | 灵巧 | 0.15–0.25s | 气流"嗖"（风/移形换位） | 2 | P0 |
| `combat_skill` | 技能释放（按特效三分法分层） | 华丽 | 0.4–0.8s | 仙道=上升 shimmer+筝轮指；荒古=低鸣+铭文嗡；禁忌=重低音+轻微失真 | 3/类 | P0 |
| `combat_ult` | 大招（鎏金描边光高光时刻） | 至强一击 | 0.6–1.0s | 高亮 stinger：编钟 + 鼓 + shimmer | 1 | P1 |
| `combat_victory` | 战斗胜利结算 | 达成 | 0.8–1.2s | 上扬小调 + 磬收尾 | 2 | P0 |
| `combat_defeat` | 战斗失败结算 | 温和挫败（不惩罚） | 0.6–0.8s | 下行二音（悲怆但轻） | 2 | P0 |
| `stage_star` | 星级点亮（1–3 星逐颗） | 阶梯成就 | 0.15s/颗 | 磬音阶梯上行（1 星 1 声 / 3 星 3 声渐高） | 3 | P1 |

### 4.5 抽卡

> 对齐 main.gd 抽卡演出时间线：`dur=0.35s`，紫气三帧轮播在 0 / 0.35 / 0.7s，卡面揭示 ~1.05s，结果弹窗 ~1.47s。

| 事件 ID | 触发点 | 情绪 | 建议时长 | 音色方向 | 变体 | 优先级 |
|---|---|---|---|---|---|---|
| `gacha_click` | 单抽/十连按钮按下（`_do_gacha`） | 契定 | 0.12–0.2s | 玉/石扣击（"契"一声） | 2 | P0 |
| `gacha_whoosh` | 紫气帧切换（3 次递增） | 悬念递增 | 0.15s/次 | 气流/上升音，音量与音高逐次 + | 1 | P0 |
| `gacha_reveal_fan` | 卡面揭示·凡/灵品 | 轻拾 | 0.4s | 轻磬 + 小星辉 | 1 | P0 |
| `gacha_reveal_xuan_di` | 卡面揭示·玄/地品 | 中喜 | 0.6s | 编钟 + 中星辉 | 1 | P0 |
| `gacha_reveal_tian` | 卡面揭示·天/帝品（全游戏稀有 moment） | 至喜升华 | 1.2–1.5s | 全编钟上行 + 紫气 shimmer + 人声吟唱（可选），**必须与普通拉开档次** | 1 | P0 |
| `gacha_summary` | 结果弹窗列表（`_show_gacha_summary`） | 汇总确认 | 0.3s | 滚动数字轻点 + 一声磬 | 1 | P1 |

### 4.6 装备强化

| 事件 ID | 触发点 | 情绪 | 建议时长 | 音色方向 | 变体 | 优先级 |
|---|---|---|---|---|---|---|
| `enhance_success` | `_on_enhance` 成功 | 进步锻造 | 0.5–0.8s | 铁匠金属敲击两下 + 上扬磬 | 3 | P0 |
| `enhance_fail` | `_on_enhance` 失败（灵石不足等） | 温和受阻 | 0.3s | 低闷锤 + 冷却气流（复用 ui_error 变体） | 1 | P0 |
| `equip_equip` | 装备穿戴 | 卡扣 | 0.2s | 金属卡扣声 | 2 | P1 |

### 4.7 功法修炼

| 事件 ID | 触发点 | 情绪 | 建议时长 | 音色方向 | 变体 | 优先级 |
|---|---|---|---|---|---|---|
| `skill_train_success` | `_on_train_skill` 成功 | 明悟 | 0.5–0.8s | 书卷翻页 + 铭文点亮（短上升音） | 3 | P0 |
| `skill_train_fail` | `_on_train_skill` 失败（残卷不足等） | 温和受阻 | 0.3s | 复用 ui_error 变体 | 1 | P0 |
| `skill_equip` | `_on_toggle_skill` 装备/卸下 | 符箓贴/揭 | 0.2s | 纸张 + 轻微能量声 | 2 | P1 |

### 4.8 副本 / 试炼塔 / 资源

| 事件 ID | 触发点 | 情绪 | 建议时长 | 音色方向 | 变体 | 优先级 |
|---|---|---|---|---|---|---|
| `dungeon_enter` | 副本入口挑战（`_on_dungeon_pressed`） | 秘境开启 | 0.3–0.5s | 石门磨启（石磨 + 低频） | 1 | P1 |
| `tower_floor` | 试炼塔层数推进（`_on_tower_pressed` 成功） | 一阶一升 | 0.4s | 上行磬（每层一阶） | 1 | P1 |
| `yuan_drop` | 源石入账（稀有资源，比灵石更亮） | 稀有价值 | 0.4–0.6s | 星紫质感：水晶高音 + 微光 | 2 | P1 |
| `shard_exchange` | 源石碎片兑换（`_on_exchange_shards`） | 整合 | 0.4s | 碎片聚合 + 一声磬 | 1 | P2 |

### 4.9 系统 / 结算

| 事件 ID | 触发点 | 情绪 | 建议时长 | 音色方向 | 变体 | 优先级 |
|---|---|---|---|---|---|---|
| `offline_return` | 出关结算弹窗（离线回归，GDD-001 §6.2） | 欢迎回归 | 1.0–1.5s | 卷轴展开（纸张+气流）+ 铜钱入账序列 | 2 | P0 |
| `realm_upgrade_visual` | 境界图标/称号升级（大境界） | 加冕 | 1.0s | 编钟 + 星辉 | 1 | P1 |
| `system_notify` | 通用系统通知 | 提示 | 0.3s | 一声磬 | 1 | P1 |
| `bgm_duck`（非音效） | BGM 侧链压低（战斗/结算/抽卡时） | — | 0.5–1.0s 过渡 | 由 AudioManager 实现 | — | P0 |

---

## 5. 实现策略（Godot 4 · Web）

> 目标：**零外部中间件**（Web 首包预算不允许引入 FMOD/Wwise 运行时），全部用 Godot 4 原生 `AudioStreamPlayer` + `AudioServer` 总线实现。以下为给工程线的实现规格。

### 5.1 架构总览

```
[Autoload] AudioManager (res://src/foundation/audio_manager.gd)
  ├─ 总线管理（创建/命名，AudioServer）
  ├─ 播放器池（SFX：N 个 AudioStreamPlayer 轮转；BGM：A/B 双实例）
  ├─ 事件表（event_id -> { stream, bus, volume, variants[] }，数据驱动）
  ├─ 交叉淡入 / ducking（create_tween 驱动 volume_db）
  └─ 全局开关：Master 静音、BGM/SFX 分音量（持久化到 SaveModel 或 user://）
```

- 注册到 `project.godot` 的 `[autoload]`（放在 `ResourceManager` 之后，`TimeService/SaveManager/ResourceManager` 之后均可，AudioManager 不依赖它们）。
- 事件表建议用 JSON 数据表（`res://data/tables/audio_events.json`，对齐项目 JSON 表驱动惯例），字段：
  ```json
  { "id": "break_small_success",
    "path": "res://assets/audio/sfx/break/small_success_01.ogg",
    "variants": ["..._01.ogg", "..._02.ogg", "..._03.ogg"],
    "bus": "SFX_System", "volume_db": -6.0, "pitch_min": 0.97, "pitch_max": 1.03 }
  ```

### 5.2 总线结构与效果器

```
Master (0 dB)
├─ BGM
│   ├─ BGM_Ambient（修炼/主界面 3.2）
│   └─ BGM_Battle（战斗 3.3）
├─ SFX
│   ├─ SFX_UI（ui_*，音量基准 -12～-8dB）
│   ├─ SFX_Combat（combat_*，-10～-6dB）
│   ├─ SFX_System（break_*/gacha_*/enhance_*/skill_*/collect_*/offline_*，-8～-4dB，stinger 可到 -4～0）
│   └─ SFX_Env（idle_tick/dungeon_enter 等环境，-20dB 以下）
└─ VO（预留；MVP 无配音，架构先建好）
```

- 效果器（Web 端务必克制）：Master 挂轻量 Limiter（防爆音）；BGM 挂低通滤波（切高频 12kHz 以下可省 CPU，可选）+ 轻压缩；SFX 总线不挂效果器（Web 多效果器有性能/兼容风险）。
- `AudioServer` 总线以 `bus_layout` 保存到 `default_bus_layout.tres`（工程线在 Godot 编辑器创建一次即可）。

### 5.3 播放器实例化与池化

- **SFX 池**：预分配 **24 个** `AudioStreamPlayer`（挂在 AudioManager 节点下，`node_name = "SfxPool_00..23"`），轮转索引播放。播放时 `set_stream(事件变体)` → `volume_db`/`pitch_scale`（变体随机用 `pitch_scale` ±3%）→ `play()`。短音（<0.3s）可复用同实例，长音（>1s）优先找空闲实例。
- **BGM**：2 个 `AudioStreamPlayer`（`BgmA` / `BgmB`）做交叉淡入；不新增实例。
- 战斗命中高频场景：连击时 6 个 `combat_hit` 变体 + 24 实例池足够；**同发上限目标 ≤ 10 个并发 SFX**（§5.8）。
- 不推荐 `AudioStreamPlayer3D`（本作以 UI + 2D 演出为主，无 3D 空间需求；若后续有场景演出再评估，MVP 全用 2D 全局播放，省性能且简单）。

### 5.4 BGM 交叉淡入

```gdscript
## 伪代码：切换到 target（bus: BGM_Ambient / BGM_Battle）
func crossfade(target_stream: AudioStream, bus: String, fade := 1.0) -> void:
    var next := _bgm_a if _bgm_cur == _bgm_b else _bgm_b   # 轮换 A/B
    next.stream = target_stream
    next.bus = bus
    next.volume_db = -60.0
    next.play()
    var tw := create_tween().set_parallel(true)
    tw.tween_property(_bgm_cur, "volume_db", -60.0, fade)
    tw.tween_property(next, "volume_db", _bgm_vol, fade)
    _bgm_cur = next
```

- 淡入淡出时长：常态↔战斗 **1.0–1.5s**；抽卡/突破/结算用 **ducking**（对当前 BGM 总线压 3–6dB，0.5–1.0s 过渡，事件结束恢复），不切流。
- BGM 音量基准：`_bgm_vol = -16dB`（可在设置调）。
- 首帧策略：浏览器 Autoplay 限制下，BGM **不自动播放**；首个用户手势（任意按钮 pressed / 点击）后由 AudioManager 恢复 AudioContext 并淡入 BGM。Godot 4 Web 在用户交互后一般自动恢复，但建议工程线在首帧输入事件里显式 `AudioServer` 兜底（见 §5.7）。

### 5.5 事件命名与资产路径约定

- 事件 ID 约定：`{system}_{action}[_{variant}]`，全小写下划线。
  - system：`ui` / `collect` / `break` / `combat` / `gacha` / `enhance` / `skill` / `dungeon` / `tower` / `offline` / `system`
- 资产路径：`res://assets/audio/{bgm|sfx|vo}/{category}/{name}.ogg`
  - 例：`res://assets/audio/bgm/cultivate_loop.ogg`、`res://assets/audio/sfx/break/small_success_01.ogg`
- 文件命名：小写下划线 + 序号（变体从 `_01` 起）。
- 触发点对接：AudioManager 暴露 `Audio.play("event_id")`，工程线在 main.gd handler 内调用（见 §5.10）。

### 5.6 音量平衡基准

| 总线 | 基准（相对 Master） | 备注 |
|---|---|---|
| Master | 0 dB | 挂 Limiter |
| BGM_Ambient | -18～-14 dB | 修炼长驻层 |
| BGM_Battle | -16～-12 dB | 战斗层 |
| SFX_UI | -12～-8 dB | 点击/页签/弹窗 |
| SFX_Combat | -10～-6 dB | 命中/暴击/闪避/技能 |
| SFX_System | -8～-4 dB | 突破/抽卡/强化/收菜（stinger 短时可 -4～0） |
| SFX_Env | ≤ -20 dB | 环境/修炼 tick |

> 规则：**BGM 永远低于 SFX 6dB 以上**（避免背景淹没反馈）；stinger 类允许短暂追平 BGM 但不超过 SFX 主层 2dB。

### 5.7 Web 导出注意点

1. **音频格式统一 OGG Vorbis**：Godot 4 Web 对 OGG 解码支持最稳（内置 libvorbis）；MP3 也可但体积/兼容性不如 OGG。**避免 WAV 大文件**（体积大、部分浏览器解码路径不稳）。
2. **Autoplay Policy**：浏览器在用户手势前暂停 AudioContext。BGM 首帧不自动播，首个 `pressed` 后恢复；若 Godot 自动恢复不生效，工程线在首次输入事件里显式处理（`AudioServer` 或播放一个 0.01s 静默触发）。**此点需工程线实测确认（Godot 4.4 Web 行为）**。
3. **流式 vs 预加载**：短 SFX（<2s）可随场景预加载（首包精简集）；BGM 用 `load()` 懒加载（修炼 BGM 常驻则首包预载，战斗/其他 BGM 进远程 Bundle 按需）。
4. **OGG 码率/采样**：BGM 建议 44.1kHz 立体声 64–96kbps（循环段 60–120s ≈ 0.5–1.5MB）；环境层可降 32kHz 单声道；SFX 统一 44.1kHz 单声道短文件。
5. **延迟**：WebAudio 低延迟，无需额外处理；但**禁用 AudioEffect 重链**（每帧重建 effect 会卡顿），全部静态配置。
6. **移动端**：移动浏览器音频策略更严，静音开关与首手势恢复必须可用；`gl_compatibility` 下音频与渲染无冲突（低端机重点看并发 SFX 数）。

### 5.8 性能与内存预算

| 项 | 预算 | 说明 |
|---|---|---|
| 同发 SFX | ≤ 10 | 战斗连击场景上限；超过则最旧实例优先被顶替 |
| BGM 实例 | 2（A/B） | 交叉淡入专用 |
| 首包音频 | ≤ 500KB | 修炼 BGM（短循环）+ 核心 P0 SFX 精简集（ui_click/collect_success/break_small_success/combat_hit/crit/dodge/gacha_reveal 等 ≤15 个） |
| 远程 Bundle 音频 | 每 ≤3MB | 战斗 BGM/突破大曲/抽卡 stinger/剩余 SFX 按场景懒加载，命名 `audio_bgm_battle_...` 对齐阶段2 命名 `区域_类型_名称` |
| 常驻内存 | ≤ 6MB 解码后 | 播放器池 24 实例 + 预载音频；未使用流及时 `unload`（远程 Bundle） |

> 对齐美术圣经 §8.4 分阶段模型：音频**不在阶段 0 引擎壳内**；阶段 1 首屏只带修炼 BGM + P0 精简 SFX；其余全部走阶段 2 远程 Bundle。

### 5.9 可访问性（对齐美术圣经 §9 Standard）

- 设置面板提供：**音乐音量 / 音效音量 / 全局静音** 三控件（持久化到存档）。
- 提供"减少音效"开关（对齐"减少动效"）：关闭后高频 stinger（抽卡揭示/突破/暴击）降为轻磬提示，不改变判定。
- 关键反馈保持**视觉+文字+音效三通道**（§9.1 Standard）：突破成功/抽卡揭示等关键事件音效不作为唯一反馈通道。
- 音效不得依赖闪烁/频闪（无此需求，合规）。

### 5.10 触发点对接清单（给工程线）

> 工程线在 main.gd 各 handler 内一行调用即可（`Audio.play("event_id")`），示例：

| main.gd 位置 | 事件 ID |
|---|---|
| `_mk_button` 内 `pressed` | `ui_click`（另 `mouse_entered` → `ui_hover`） |
| `_switch_tab` | `ui_tab_switch` |
| `_show_popup` 开场 | `ui_popup_open` |
| `_on_collect_pressed` 成功 | `collect_success`（`gain<=0` → `collect_empty`） |
| `_do_breakthrough` | `break_small_success`（随 `_flash_purple`） |
| `_start_big_wait` | `break_big_start` |
| 大境界等待结束/加速完成（`_on_wait_speed_pressed`/计时归零） | `break_big_complete` |
| `_on_break_pressed` 任一不足 | `break_fail`（ui_error 变体） |
| `_show_battle_result` 开场 | `combat_start` |
| 战斗伤害结算（暴击判定） | `combat_hit` / `combat_crit` / `combat_dodge`（按结算结果） |
| 战斗技能/大招（演出层） | `combat_skill` / `combat_ult` |
| 战斗结果（胜利/失败） | `combat_victory` / `combat_defeat` |
| 星级点亮（结算） | `stage_star` |
| `_do_gacha` 按下 | `gacha_click` |
| `_play_gacha_show` 帧切换（0/0.35/0.7s） | `gacha_whoosh`（3 次） |
| 卡面揭示（~1.05s，按稀有度） | `gacha_reveal_fan` / `gacha_reveal_xuan_di` / `gacha_reveal_tian` |
| `_show_gacha_summary` | `gacha_summary` |
| `_on_enhance` 成功/失败 | `enhance_success` / `enhance_fail` |
| `_on_train_skill` 成功/失败 | `skill_train_success` / `skill_train_fail` |
| `_on_toggle_skill` | `skill_equip` |
| `_on_dungeon_pressed` / `_on_tower_pressed` | `dungeon_enter` / `tower_floor`（成功时） |
| 源石入账 | `yuan_drop` |
| 离线回归/出关结算弹窗 | `offline_return` |
| BGM 切换（进/出战斗演出层） | `Audio.crossfade(...)` 常↔战 |

---

## 6. 音频资产制作优先级（Roadmap）

> 供制作/采购排期；每批完成后工程线接入并实测 Web 兼容（§5.7）。

| 批次 | 内容 | 数量（估） | 预算 |
|---|---|---|---|
| **P0 · 首包必做** | 修炼 BGM 循环 1 首（90–120s）；P0 SFX：ui_click×4、ui_tab_switch、ui_popup_open、ui_confirm、ui_error、ui_resource_gain、collect_success×3、break_small_success×3、break_big_complete、combat_start、combat_hit×6、combat_crit×3、combat_dodge×2、combat_victory×2、combat_defeat×2、gacha_click、gacha_whoosh、gacha_reveal 三档、enhance_success×3、skill_train_success×3、offline_return×2 | ~45 文件 | ≤500KB（SFX 单声道 OGG） |
| **P1 · 第二优先** | 主界面 BGM、战斗 BGM 循环；剩余 P0/P1 SFX（ui_hover、ui_popup_close、ui_count_up、collect_empty、break_big_start、combat_skill×3、combat_ult、stage_star×3、gacha_summary、equip_equip、skill_equip、dungeon_enter、tower_floor、yuan_drop、realm_upgrade_visual、system_notify） | ~30 文件 | 远程 Bundle ≤3MB/批 |
| **P2 · 打磨可选** | idle_tick、break_ready_hint、break_wait_tick、shard_exchange；大境界突破完整音乐段（含人声吟唱） | ~8 文件 | 按需 |

---

## 7. 待拍板 / 待对齐项

1. **音乐是否全程原创**：本稿按"原创/委托制作"假设（方向+清单已齐）；若改为"资产库采购"，需主理人拍板，我再出采购筛选清单（东方乐器/无词吟唱/循环无接缝）。
2. **战斗 BGM 是否必要**：MVP 战斗 60–90s/关，本稿建议配专属战斗 BGM（收益 > 成本）；若工程线/主理人想省预算，可退化为"修炼 BGM + 战斗 SFX + 低鼓节拍层"，我给出替代方案。
3. **人声吟唱**：仅在大境界突破完成/帝品揭示两处可选使用（至稀用）；是否启用由主理人定（影响制作成本）。
4. **`break_ready_hint` / `idle_tick` / `break_wait_tick` 三个可选音**：默认关闭（P2），避免烦扰；如需启用走主理人确认。
5. **待工程线实测**：Godot 4.4 Web 的 AudioContext 自动恢复行为（§5.7 第 2 点）、OGG 解码兼容、首包音频预算实测（阶段1 总口径）。
6. **与美术线对齐**：突破/抽卡演出音效的节奏点需与紫气粒子演出时间线对齐（`_flash_purple` / 抽卡三帧轮播）；美术线粒子预算变化时同步本稿。

---

## 附：本文档与现有系统的对照自查

- [x] 听觉身份与视觉身份同构（§1 ↔ art-bible §1）
- [x] 音效触发点全部来自 main.gd 现有 handler（§4 / §5.10）
- [x] 突破/大境界完成承接 P1 支柱（§3.5 / §4.3）
- [x] 修炼/离线结算承接 P3"片刻亦修仙"（§3.2 / §3.6 / §4.9）
- [x] 战斗演出（暴击/闪避飘字）已覆盖（§4.4）
- [x] 实现策略对齐 Godot 4.4 Web + gl_compatibility + 首包预算（§5）
- [x] 可访问性对齐美术圣经 §9 Standard（§5.9）
- [ ] 待工程线：总线 layout 创建、AudioManager 落地、触发点接入、Web 实测
- [ ] 待主理人：§7 拍板项（原创/采购、战斗 BGM、吟唱、可选音）
