# 现有浏览器遗留进程管理工具

核查日期：2026-09-09。只读网页与源码核查，未安装或执行候选软件。

## 结论

**先评估 Headless Guard，值得避免从零重做它已有的检测与清理引擎。** 它直接解决 macOS 自动化浏览器遗留、菜单栏观察、会话树内存与清理，远比端口管理器接近。但当前版本并非「全部正常与无头浏览器实例总览」，也未实现 Safari 实例、页面计数、Codex/Claude 来源归属或任意单实例关闭。若这些都是必需项，现成项目仍有明显缺口。[项目](https://github.com/study8677/HeadlessGuard)、[检测实现](https://github.com/study8677/HeadlessGuard/blob/main/Sources/HeadlessGuardKit/ProcessDetector.swift)

## Headless Guard：最直接候选

- 原生 Swift macOS 菜单栏 + Dashboard + CLI，MIT。提供 Apple Silicon v0.1.0 下载；要求 macOS 13+，README 明示首版 ad-hoc 签名、未公证。[README](https://github.com/study8677/HeadlessGuard)、[发行版](https://github.com/study8677/HeadlessGuard/releases/tag/v0.1.0)
- 浏览器识别包含 Chrome、Chromium、Edge、Firefox、带 `--headless` 的 WebKit。仅将评分达到 60 的自动化候选纳入列表；**不能把 WebKit 支持理解成 Safari 桌面实例支持**。来源判别是 Playwright/Puppeteer/WebDriver/Rod 等控制器或浏览器名，未识别 Codex/Claude 上游任务。[检测源码](https://github.com/study8677/HeadlessGuard/blob/main/Sources/HeadlessGuardKit/ProcessDetector.swift)
- 实例模型包含根 PID、进程集合、RSS 求和、CPU 求和、时长及孤儿判断。UI 展示来源、浏览器家族、根 PID、汇总内存与检测理由；模型没有页面、URL、标签页数。汇总 RSS 也不是系统去重后的实际物理内存。[模型](https://github.com/study8677/HeadlessGuard/blob/main/Sources/HeadlessGuardKit/Models.swift)、[卡片](https://github.com/study8677/HeadlessGuard/blob/main/Sources/HeadlessGuardApp/Components.swift)
- Dashboard 提供确认会话批量清理，自动清理默认关闭。`ProcessCleaner.clean(incident)` 已有单会话引擎，但检查的卡片/UI 没有逐会话关闭按钮。自动清理只处理符合阈值的确认孤儿；不能等同「关闭所有 headless，包括仍活跃任务」。[Dashboard](https://github.com/study8677/HeadlessGuard/blob/main/Sources/HeadlessGuardApp/DashboardView.swift)、[ViewModel](https://github.com/study8677/HeadlessGuard/blob/main/Sources/HeadlessGuardApp/GuardViewModel.swift)
- 维护证据：GitHub API 显示仓库创建于 2026-08-02，最近 push 2026-08-02，未归档；仅 v0.1.0（2026-08-02）。这是非常早期项目，不能凭 README 认定已长期验证。[仓库元数据](https://api.github.com/repos/study8677/HeadlessGuard)、[releases API](https://api.github.com/repos/study8677/HeadlessGuard/releases)

## cc-reaper：适合整个 AI 进程树治理，范围更广

- 已有 macOS 14+ Swift 菜单栏 companion、Dashboard、CPU/RSS/分类/PID 预览与确认批量清理。覆盖 Claude 子代理/MCP，以及 agent-browser、Puppeteer Chrome、Codex 遗留会话。Apache-2.0。[项目](https://github.com/theQuert/cc-reaper)
- 同伴 App 依赖现有 `cc-monitor --once --json` 与 `claude-cleanup`，正常浏览器受保护。它按进程家族与清理候选管理，并非完整浏览器实例/页面目录；规范未提供 Safari 页面汇总或逐浏览器关闭。[App 规范](https://github.com/theQuert/cc-reaper/blob/main/openspec/specs/macos-menu-bar-companion/spec.md)
- **与需求相关的限制**：规范明确 Codex Computer Use 进程属于 immutable，不允许用户规则扩大清理范围；因此不能假设能“一键关所有 Codex 启动的浏览器”。[规则规范](https://github.com/theQuert/cc-reaper/blob/main/openspec/specs/macos-menu-bar-companion/spec.md)
- 维护证据：创建于 2026-03-01，最近 push 2026-09-01，未归档；releases API 返回空数组，README 要求本地构建可选 App。[元数据](https://api.github.com/repos/theQuert/cc-reaper)、[releases API](https://api.github.com/repos/theQuert/cc-reaper/releases)

## 选用判断

| 需要解决的核心问题 | 更合适的起点 |
| --- | --- |
| 清理孤儿 headless 浏览器、回收内存 | Headless Guard |
| Claude/Codex/MCP 整体孤儿与过量资源占用 | cc-reaper |
| Chrome/Safari/Edge 全实例 + 页面数 + AI 来源 + 单个与全部 headless 关闭 | 本轮没有核实到完整成品；可在 Headless Guard 上扩展，但检测/清理策略与普通浏览器目录需拆开 |

以上缺口结论基于已检查的当前 README、模型、检测器及 UI/规范；未实机测试，不等同发行版行为保证。

## Headless Guard 引擎复用前的实现注意

当前扫描使用 `/bin/ps -axo uid=,pid=,ppid=,pgid=,state=,%cpu=,rss=,etime=,command=`，不是 libproc 原生采样。清理前重扫确认根 PID；SIGTERM 后匹配同 PID、命令前 512 字符与运行时长差小于 120 秒，再 SIGKILL。**这不是基于内核启动时间的稳定进程身份校验**；README 也把原生 API 与 PID start-time identity 列为路线图。可复用其会话模型和指纹，但不应直接宣传成已解决 PID 重用问题。[Scanner](https://github.com/study8677/HeadlessGuard/blob/main/Sources/HeadlessGuardKit/ProcessScanner.swift)、[Cleaner](https://github.com/study8677/HeadlessGuard/blob/main/Sources/HeadlessGuardKit/ProcessCleaner.swift)
