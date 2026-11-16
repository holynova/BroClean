# BroClean 产品与验收规格

状态：开发基线，2026-09-09。BroClean 为工作名称。用户已批准原生技术路线、简洁英文 UI 和 HeadlessGuard 场景补充。实际测试结果另外记录，规格不是完成声明。

## 产品目标

本地 macOS 菜单栏应用，帮助用户查看并关闭 AI/测试工具启动的浏览器，同时保留普通浏览器总览。只读扫描无需修改原有工作流。菜单栏点击即进入操作；不增加账号、云服务、仪表盘或营销界面。

## 已确认界面

以 `design/approved-ui.png` 为视觉基准。英文标题 Browsers；All / Automated / Headless 筛选。每行显示真实浏览器图标，来源作为主标题，模式徽标，突出 Memory / Pages 数字，次要显示浏览器名和主 PID。Inferred 必须明确，未知页面显示 —/Unknown，不显示 0。详情与菜单承载复杂信息，主列表不加安全分数和图表。实际系统材质、字体渲染随 macOS 变化。

## MVP 范围

- macOS 14+，当前用户权限运行，原生菜单栏/弹窗，无 Dock 图标；本地 .app。
- Chrome/Chromium/Chrome for Testing/Edge 核心识别；Firefox 基础参数识别；Safari 应用级发现与正常退出（相关 WebKit/XPC 内存不能保证完整）。
- 一浏览器主进程一实例，确认的子进程合并。不将一般 Electron/WebView helper 独立列为浏览器。
- 模式与自动化状态分开：headless/headed/unknown；软件来源/框架独立保存。
- 来源基于父链、可执行路径和必要参数；Codex/Claude/ChatGPT 等只作启动来源推断，不冒充当前控制者或任务 ID。
- RSS 合计为 Estimated memory；未读取到的成员不冒充零，显示 partial/unavailable。
- Pages 为可验证本机 CDP 端点中顶层 page targets 的计数；仅读取元数据，排除 iframe、worker、扩展页，不能用 renderer 数代替。端点不可访问时正常显示 Unknown。Pipe-only 不强行接入。
- 单个 Close instance；Close headless 批量操作冻结目标；Force quit 为显式动作。保留实例、配置目录保护与跳过反馈。
- 详情包含来源证据、运行时长、配置目录类别、启动器、已确认子进程和 PID。参数脱敏，不展示完整原始命令行。
- 关闭结果逐项反馈，检测剩余成员和疑似重新拉起；不会终止 Codex/Claude/node 等祖先。
- 设置提供刷新频率说明与 Launch at login；登录启动默认关闭，无法注册时显示错误。

## 关闭政策

1. 接受实例身份，不提供任意 PID 输入。身份 = PID + 内核启动秒/微秒。
2. 执行前重新读取并核对身份、UID、路径；排除本应用、其祖先、PID 0/1。
3. 普通应用正常退出，无法使用应用退出通道的 headless 用 SIGTERM。信号成功只表示请求已发送。
4. 默认不自动升级 SIGKILL。Force quit 需要显式选择，重验身份后只处理对应浏览器根和已确认成员，不杀共享启动器。
5. 批量只包含 headless、确认独立临时配置、未保留且未受保护的实例。Standard/Unknown profile 跳过并显示原因；独立单实例关闭仍可经明确范围确认进行。
6. 刷新过程中新增实例不加入当前批次。身份改变时拒绝，不重定向至新 PID。
7. 关闭后清点根与快照成员，反馈 partial/still running。仅把相同临时配置目录下的新身份视作疑似 restart，不对常用浏览器名做重启关联。
8. 仅关闭进程，不删除 profile、浏览历史、缓存或下载，不承诺实际回收内存等于 RSS。

## 状态与失败场景

Scanning；No matching browsers；Unknown source；Mode unknown；Unknown pages；Partial memory；Permission denied；Identity changed；Closed；Still running；Partially closed；Possibly restarted。

运行时间长、CPU 低、PPID=1 或一个调试参数都不能单独证明可安全自动清理。MVP 不自动清理。未知或正常浏览器仍可显示，helper 不会自行成为批量清理对象。共享 launcher 的内存不重复并入各实例。

## 隐私

本地处理，无遥测/云上传/账号。仅读必要进程元数据，argv 解析后不保留环境变量。CDP 只连接绑定到该进程的回环地址；不执行页面 JS、不打开页面、不持久化页面 URL/title。偏好用 UserDefaults，快照仅驻内存。诊断默认输出摘要和脱敏证据。无需默认管理员、Accessibility、Screen Recording、Full Disk Access；权限不足正常降级。

## 后续，不阻塞 MVP

Stop automation session（严格区分专用与共享 launcher）、完整 Playwright 主动上报、任务名称、Safari 页面数、自动清理、持久保护规则、Close others、完整用户 CLI、Intel 分发与公证。诊断可执行程序仅用于验证和支持，不是完整 CLI 产品。

## 验收矩阵

| 类别 | 必测 |
| --- | --- |
| 聚合 | 两个 Chrome 根不混组；renderer 合并；Electron 排除；共享 launcher 不重复合并 |
| 识别 | Codex/Claude 祖先；临时目录+headless；手动调试反例；未知参数不判 headed；Safari 主进程 |
| 内存/页面 | 聚合与 partial；0 与 unknown；CDP page/worker/iframe/扩展过滤；端点失败 |
| 关闭 | PID复用、跨用户、自身祖先保护；普通目录批量排除；单实例请求；显式强杀；部分失败；复活 |
| 实机 | 只在专门创建的进程及唯一临时 profile Chrome 上关闭；用户日常浏览器不参与清理 |
| UI | 原生菜单栏、筛选、详情、保留、确认/取消、设置、空/未知/错误、滚动、键盘关闭 |
| 交付 | swift test、release build、.app 打包/签名检查、实际启动与截图对照、测试记录 |

参考：[HeadlessGuard](https://github.com/study8677/HeadlessGuard)、[安全场景](https://github.com/study8677/HeadlessGuard/blob/main/docs/SAFETY.md)。本应用独立实现，不照搬自动清理或 launcher-first 策略。

## 用户确认的紧凑交互修订

面板约为初版尺寸的 70%（400pt 宽），文字按可读性调整。每行常驻 Close 按钮。窗口内部点击、菜单和关闭确认不应导致消失；外部点击收起，确认或关闭进行中保持。常规标准配置、无已知自动化或调试证据的有界面浏览器，主标题显示浏览器名称，副标题显示 Personal browser，详情注明推测依据。

## 0.2.0 功能修订

- 产品名称 BroClean；设置显示版本号与 GitHub 入口，仓库地址可配置。
- 三个筛选标签共用排序选择：名称、类型、内存、页面列可点击切换正反顺序；排序菜单额外提供浏览器、PID、运行时长。未知内存/页面始终置后。
- 底部增加 Close automated，可处理有界面与无界面的自动化实例；保留项、普通/未知/自定义配置仍跳过并说明原因。
