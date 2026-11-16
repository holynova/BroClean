# HeadlessGuard 文档复盘与场景覆盖

日期：2026-09-09。用户决定继续独立开发自己的原生 macOS 应用，保留已经批准的简洁英文 UI。本文件区分第三方描述、已有设计与建议新增范围；未运行第三方软件，不把其文档当成本项目指令或实测保证。

## 阅读范围

[README](https://github.com/study8677/HeadlessGuard)、[架构](https://github.com/study8677/HeadlessGuard/blob/main/docs/ARCHITECTURE.md)、[安全策略](https://github.com/study8677/HeadlessGuard/blob/main/docs/SAFETY.md)、[故障处理](https://github.com/study8677/HeadlessGuard/blob/main/docs/TROUBLESHOOTING.md)、[隐私](https://github.com/study8677/HeadlessGuard/blob/main/PRIVACY.md)、[安全报告](https://github.com/study8677/HeadlessGuard/blob/main/SECURITY.md)、[贡献要求](https://github.com/study8677/HeadlessGuard/blob/main/CONTRIBUTING.md)、SUPPORT、CHANGELOG。结合上轮已记录源码结论，不将路线图当已实现功能。

## 按八项用户功能归类

| 功能 | 重合 | 说明 |
| --- | --- | --- |
| 菜单栏查看 | 高 | 它有菜单栏与独立 Dashboard；我们保留紧凑面板 |
| 浏览器实例/子进程聚合 | 部分 | 它针对自动化事件，我们要包含普通浏览器；会话可能含启动器和多个浏览器根 |
| Headless 识别 | 高 | 都需要运行模式与自动化证据 |
| 来源识别 | 部分 | 它框架指纹更广；我们的 Codex/Claude 软件来源和推测降级更明确 |
| 内存与 PID | 高 | 都有进程树 RSS/根 PID，不能把估算当实际可释放量 |
| 页面数 | 未重合 | 上轮模型核查未发现该字段，我们计划能力分级提供 |
| 单个/批量关闭 | 部分 | 它清理符合条件的会话，UI 以批量 rescue 为主；我们按实例手动管理 |
| 关闭其他 | 未重合 | 上轮未发现对应能力，我们仍为低优先级 |

上述计数是功能项分类：3 项高重合、3 项部分重合、2 项未发现对应；不是工时重合率、质量评分或覆盖率承诺。

## 真正新增或需加强的场景

| 场景 | HeadlessGuard 文档的处理 | 我们的处理与优先级 |
| --- | --- | --- |
| Chrome 打开但没有窗口 | README 解释系统 Chrome headless 可共享应用身份，普通打开请求可能落到无窗口进程 | MVP 识别系统 Chrome 的 headless 实例、路径与配置目录；不能凭无窗口确诊，不自动重开 Chrome |
| 启动器仍运行/会话复活 | 优先 TERM 专用 launcher，清理后检查复活 | MVP 展示 launcher、关闭结果及疑似重新拉起；不自动杀通用父进程。增强阶段提供单独停止专用会话操作 |
| 一个 launcher 管多个实例 | 以 session 聚合并检查每个 browser root | 保持一浏览器根一行；共享 launcher 只作关联节点，不重复计内存、不因关一行停止所有其他实例 |
| 正常配置目录被自动化使用 | normal-profile automation 在其所有模式中只观察 | 加入配置目录类别/未知的识别；建议普通配置目录或关系不明的实例退出批量快捷操作，仍保留有范围说明的手动关闭。该交互细节是提案 |
| 端口/名称/运行时长误判 | 多证据判别，分数之外另设硬规则 | MVP 将 mode、framework/source、疑似遗留、操作资格分开；不把高分当安全概率；不用 CPU 低或 age 长认定无用 |
| launcher 被 PID 1 接管 | 显式启用自动策略后结合 age 与独立指纹 | 显示 Lost parent / Possibly orphaned 依据；PID 1 不单独触发关闭，因为合法后台服务也可能有该父进程 |
| helper/扩展/native host 独立出现 | 不允许自行构成待清理事件 | MVP 不作为独立可批量清理浏览器；无法归属者仅诊断显示，过滤掉应用自身/祖先/PID0/1 |
| 扫描后状态改变 | 动作前重扫，拒绝已经降级事件 | 已有冻结目标/PID+启动时间方案，补上证据失效和归属改变的拒绝路径 |
| 关闭只成功一部分 | 返回 remaining PIDs，不假报成功 | 已有结果反馈，补成 Closed / Still running / Partially closed / Identity changed，必要时显示残留详情 |
| 清理后系统仍慢 | 空列表只排除这一类问题 | 空状态使用 No matching browsers，不承诺 Mac healthy 或 Memory optimized |
| 诊断输出泄露参数 | 要求手动脱敏 | MVP 参数只提取必要字段、日志脱敏，不保存环境或完整 URL；后续导出诊断默认脱敏并预览 |
| 新规则误伤相似正常进程 | 每条新指纹需正例和最近的正常/手动调试反例 | MVP 验收加入成对样例与不受影响实例对照，不只测能成功关掉自动化浏览器 |

来源分别为 README、SAFETY、TROUBLESHOOTING、PRIVACY 和 CONTRIBUTING；表中“我们”列是设计建议，不是第三方保证。

## 已有考虑，无需重新包装为新功能

原方案已有：PID + 内核启动时间；不按名称全局 kill；不自动强杀；退出后复查；来源未知；Headless 不等于闲置；不连带关闭 Codex/Claude；重启视为新实例；RSS 估算；当前用户权限；本地日志脱敏。这次应细化场景和测试，而非宣称全部是新发现。

## 保持 UI 简洁

主列表保持来源、Headless/Headed、Memory、Pages、浏览器与 PID。正常状态不增加分数条、告警墙、CPU 曲线或新 Dashboard。

只有异常时追加一条短说明，例如 Restarted after closing。详情容纳 Source evidence、Launcher、Profile type、Running for、Process tree。批量操作显示实际包含数量与被跳过原因，不能按钮称 all 却无反馈地漏掉实例。

## 三种操作分别设计

1. Close instance：只关闭所选浏览器树，不触碰 launcher；现有 MVP 主操作。
2. Close headless：用户明确触发，冻结目标，应用保护/资格规则，报告跳过与部分失败；不要求每个实例都已经闲置。
3. Stop automation session：未来增强，先证明 launcher 专用且独占目标，必要时调用框架关闭接口；预览所有受影响浏览器。共享、不明或通用 Codex/Claude/node/CI 祖先不能自动进入该操作。

三者不能共用“kill 一棵树”的模糊语义。它的 launcher-first 方案有价值，但不是可无条件套用的顺序。

## 不直接照搬的部分

- 自动清理：未来显式启用的高级功能，首版不做。其确认自动化/孤儿规则不证明任务已经无价值。
- 数字置信分数：可在内部测试使用，但 UI 以证据和 Unknown/Inferred 为主，不显示“100% safe”。
- 自动 SIGKILL：保留我们的显式 Force quit。
- 完整 CLI/doctor/watch：核心模块预留可测试接口，用户级 CLI 后续按实际需求做。
- 完全无网络：我们的 Pages 可能需要本机 CDP HTTP/WebSocket，所以承诺“无云端上传/无遥测”，不能照搬“完全不发网络请求”；只读必要元数据、不读取页面内容，不持久化 URL/title。
- 全部框架的广泛识别：首版保证 Chrome/Chromium/Edge 核心路径、Safari 基础发现，其他框架与 WebKit/Firefox 按样例逐步适配。
- 模糊实例全部隐藏/禁止手动关：我们仍展示普通与未知实例，用操作范围与保护规则区分，而不是把浏览器总览变成仅诊断列表。

## 优先级结论

MVP 加强的是发现/关闭/反馈/反例验证，不扩大主界面。新增 profile 类型、launcher 关系及共享标记、证据独立维度、复活/部分关闭反馈、成对测试场景。

第二阶段才考虑 Stop automation session、脱敏诊断导出、允许列表。自动清理、CLI 和更广框架支持后置。保留独立应用与原生技术栈，不转为 fork 决策，也没有在本轮开始应用编码。
