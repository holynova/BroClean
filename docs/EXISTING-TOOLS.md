# 同类工具调研与复用建议

检索日期：2026-09-09。通过公开搜索、官方产品页、GitHub README/代码与 GitHub API 核对。未安装、启动或运行任何清理工具，未验证作者的安全性与性能宣传。未发现完全覆盖所有已确认需求的现成产品；这不是对整个市场不存在同类产品的证明。

## 最相关候选

### HeadlessGuard — 最接近原始问题

[仓库](https://github.com/study8677/HeadlessGuard) · [v0.1.0](https://github.com/study8677/HeadlessGuard/releases/tag/v0.1.0)

Swift/SwiftUI 原生 macOS 应用，菜单栏 + dashboard + CLI。识别 Playwright/Puppeteer/Rod/WebDriver/Selenium 等指纹，聚合 launcher/browser/helper，展示证据和资源，默认 observe-only，针对满足条件的自动化实例清理，保护正常浏览器。与我们的目标有明显重复。

差别：定位为自动化浏览器遗留清理，不是普通浏览器也能任意关闭的统一管理器。没有发现 Pages/CDP 页面枚举的支持承诺；AI 软件归属与框架指纹不能等同。README roadmap 明确将原生 macOS process API 与 PID start-time identity 列为未来工作，不能把它当作已实现的 libproc 采集器。清理流程会先结束专用 launcher，继而 TERM/必要时 KILL，与我们计划的显式 Force quit 策略不同。

源码补充核查：检测器仅列自动化评分 >=60 的候选；没有 Codex/Claude 软件归属，普通 Safari 不在该目录；模型无页面计数。引擎提供单会话清理 API，但检查的 UI 只有确认会话批量清理。采集使用 ps；清理身份检查采用 PID、命令前 512 字符及 elapsed 差值，不是内核启动时间。详见[源码调研](browser-tools-research.md)，以及 [ProcessDetector](https://github.com/study8677/HeadlessGuard/blob/main/Sources/HeadlessGuardKit/ProcessDetector.swift)、[ProcessCleaner](https://github.com/study8677/HeadlessGuard/blob/main/Sources/HeadlessGuardKit/ProcessCleaner.swift)。因此既不能当完全替代品，也不能未经审查直接复用全部清理策略。

MIT；GitHub API 查得创建与最近 push 均为 2026-08-02；最新公开 release v0.1.0，发布于同日。当前是很早期的项目；README 声明 macOS 13+、预编译包 Apple Silicon、ad-hoc 签名但未公证。它适合先做受控验证，再决定直接使用或抽取模块。

### ProcessSpy — 最接近通用进程观察面板

[官网](https://process-spy.app/) · [公开仓库](https://github.com/robert-v/ProcessSpy-public)

官网明确有菜单栏 dashboard、树状聚合 CPU/Memory/Threads、命令行/路径、JS 与正则过滤、进程历史、Launched By/responsible PID。可用它查看浏览器树、资源和来源线索。

没有在公开功能说明中发现浏览器 Pages 统计或专门的 Headless 批量关闭。Launched By 不是当前 AI 任务控制者证明。官网提供免费基础功能，Launched By 等属于付费功能；查阅时官网 lifetime 标价 $34.99。公开 GitHub 主要提供问题、文档、过滤示例和翻译，不应因为有 GitHub 链接就当作完整开源应用来 fork。官网当前显示 v1.15.0、macOS 14+，本机系统符合声明要求，但未实测。

### Playwright CLI — 最可能免去自建“受管会话管理”

[官方文档](https://playwright.dev/docs/getting-started-cli) · [仓库](https://github.com/microsoft/playwright-cli)

官方提供 show 可视化 dashboard（workspace 分组、session 名称、页面预览、tab bar）、list、tab-list、单会话 close 与 close-all。属于 Playwright CLI 会话工作流，不能把其“all”扩大解释为自动发现全机所有独立浏览器、Puppeteer 进程或日常 Safari；普通 Playwright 脚本也不自动成为 CLI 注册会话。未见聚合 RSS 或通用 AI 来源扫描能力承诺。

Apache-2.0；GitHub API 最近 push 2026-09-03。若用户可统一使用该 CLI，会话管理与页面可视化已有现成方案。此次没有运行任何命令，尤其未运行 close-all / kill-all。

### cc-reaper — AI 进程遗留清理，范围更广

[仓库](https://github.com/theQuert/cc-reaper)

清理 Claude Code/MCP/subagent 及 stale agent-browser/Puppeteer/Codex 等进程；提供监测报告、分类、树 RSS 等，也有 macOS companion app。对“AI 留下一堆进程”有明显帮助。

不是专门的多浏览器 Pages 管理器；具有 hooks/后台清理及更广的规则，不能直接将默认策略移植到我们以用户手动选择为主的浏览器工具。Apache-2.0，API 最近 push 2026-09-01。适合借鉴识别案例和过程报告，不宜不经审查直接调用清理脚本。

其 [macOS companion 规范](https://github.com/theQuert/cc-reaper/blob/main/openspec/specs/macos-menu-bar-companion/spec.md) 将 Codex Computer Use 列为不可覆盖的保护对象，故不能视为所有 Codex 浏览器清理成品；目前未发现 GitHub release，companion 需要本地构建。

### PortKiller — 外观/进程操作邻近，核心发现方式不同

[productdevbook/port-killer](https://github.com/productdevbook/port-killer) · [gupsammy/PortKiller](https://github.com/gupsammy/PortKiller)

这是两个不同的同名项目，避免混淆。前者 MIT，原生 macOS 菜单栏、自动发现 TCP 监听端口、关闭、过滤、Kubernetes 与 Cloudflare 集成；后者 README 表述 MIT，Rust 原生菜单栏、端口/项目识别、Docker/Homebrew 集成。

它们以端口为中心，Playwright 的 pipe-only 实例不因存在浏览器就监听 TCP，因此此类发现模型不覆盖我们的目标。[Playwright pipe 实现](https://github.com/microsoft/playwright/blob/main/packages/playwright-core/src/server/chromium/chromium.ts)。可参考 UI、打包和操作反馈，不建议从端口业务框架改造浏览器语义。

### 其他已筛除方向

[Agent Mac Agent Browser](https://www.agentmac.app/agentbrowser) 是本机菜单栏浏览器自动化运行时，提供 headless/headed 和 tab registry；它通过自己的引擎向 AI 提供浏览器，不是扫描已有任意浏览器的资源清理器。官网的性能、AI 评分、优惠等没有独立验证，不作为推荐依据。

Kerstel/Stats/系统 Activity Monitor 等更偏系统或端口监控，没有证据表明提供本需求全部浏览器语义。无需为了参考增加这些依赖。

## 决策建议

1. 暂缓从零开发，优先验证 HeadlessGuard：只读扫描在独立测试夹具上看是否发现、聚合、解释正确；受控关闭只针对专门启动的测试实例。
2. 如果已解决用户大部分实际痛点，直接使用，保留 UI 方案而不急于实现。
3. 若识别核心可用而来源/Pages/UI 不满足，在源码审查后决定 fork 或借鉴其模块；优先补可证明的缺口，而不是再造同一清理器。
4. 仍需区分新产品的价值：不改变现有 AI 使用方式、跨工具浏览器实例总览、来源优先、Pages 能力分级、手动精确关闭。不是仅“换成更好看的菜单栏”。

现阶段尚无实测结果，所以不能宣称某候选已可安全替代。建议下一步是对 HeadlessGuard 做受控适配评估，不是立即安装后台自动清理。
