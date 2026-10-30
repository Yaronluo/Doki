# 工作记录

记录真实工作与边界，后续按日期追加。秘密与原始账号日志不进入本文件。

## 2026-10-29 · DOC-001 · Apple 原生设计、弹幕与交接包

- 用户纠正参考方向：要独立设计、iOS 样式、Liquid Glass；弹幕指定弹弹play；需要完整交接和约束文件。
- 核对 Apple HIG/SwiftUI Liquid Glass 文档与本机 SDK；核对弹弹play官方指南、Swagger、Bangumi 条目映射、应用签名/302/int64 与额度说明。
- 建立 v0.4，v0.2/v0.3 标记历史；参考源码记录保留事实并纠正“主要复现”的定位。
- 新增 AGENTS、文档入口、原生设计、弹幕接入、架构决策、任务、接口草案、配置、验收、当前状态和交接指南；配置模板与忽略规则不含秘密。
- 新增文档检查脚本；运行 `python3 scripts/check-docs.py`，17 份 Markdown 检查通过；Python 语法检查通过。按官方 Swagger 核对读取/映射端点、int64 和 302 定义，未调用应用鉴权接口。
- DOC-001 达到文档交付条件，标为 verified；所有功能实现任务仍为 not_started。详细边界记录在 CURRENT_STATE，尚未执行任何客户端/Hub 构建。
- 未完成：工程实现、真实应用凭据、真实源/弹幕请求、部署、模拟器/真机播放和性能验收。

## 2026-10-29 · DOC-001 范围修订 · TV 首发与 DeepSeek 提示词

- 用户明确首版只做 TV，其他客户端先不做，并要求交给 DeepSeek 的提示词。
- 保持 v0.4 为唯一基线，修订为 TV 首发；移除首版 iPhone/Mac target、UI、构建与验收依赖，更新相关交接文件与 ADR-009。
- TV 配对/Bangumi OAuth 改为 Hub 轻量网页 + 普通浏览器辅助，避免手机 App 变成隐藏依赖。
- 新增 DEEPSEEK_TV_PROMPT.md，包含实际阅读顺序、实现步骤、TV 验收、失败恢复和交接义务；没有替 DeepSeek 执行应用实现。
- 运行 `python3 scripts/check-docs.py`，18 份 Markdown 检查通过；范围一致性复核通过。结果记录在 CURRENT_STATE；原有 Apple 原生设计、Liquid Glass、在线源和弹弹play弹幕仍保留。

## 后续批次模板

```text
日期 / 任务 ID / 状态：
改动与理由：
文件/迁移/依赖/配置变动：
实际执行的命令与操作：
结果与证据：
未覆盖项 / 阻塞 / 限制：
下一步及依赖：
更新过的设计/契约/决策文件：
```

## 2026-10-30 · ENV-001 / APP-001 / UI-001 / HUB-001 / SRC-001 / PLAY-001 · 首轮 TV + Hub 实现

- 环境：Xcode 27.1（27A9275）、tvOS 27.0 SDK、XcodeGen 2.46.0、Swift 6.4、Node 24.22.1、pnpm 9.14.4、PostgreSQL 18.6。安装 tvOS 27.0 模拟器运行时（Apple TV 4K 3rd gen 1080p，UDID `A3FD875C-F0DC-4BCE-880D-C4F6680D3C97`）。无 GUI Simulator.app；无 Apple TV 真机/签名。
- 工程：新增 `project.yml`、`DokiTV` tvOS target（最低 26.0）、`DokiTVUITests`、四个本地 Swift 包（DokiCore/DokiPlayback/DokiDanmaku/DokiUI）。`xcodegen generate --spec project.yml` 生成 `Doki.xcodeproj`；`xcodebuild ... -destination 'generic/platform=tvOS Simulator' CODE_SIGNING_ALLOWED=NO` 构建成功。
- UI：自造 12 个条目/章节、海报/横幅、24 分钟 1440s 静音演示 MP4；实现发现/追番/日历/搜索/我的、详情/选集、AVPlayerViewController 播放器、源/弹幕/Hub/关于/诊断页面。tvOS 原生 TabView、焦点、系统 Toggle/Picker；自定义控制层使用公开 `glassEffect`/`GlassEffectContainer`，减少透明度时改用实色；内容层不使用玻璃。浅/深色通过启动参数验证并修正对比度（动态 accent、浅色深底 badge），播放器加顶部/底部 scrim 与实心媒体徽标。
- 模拟器证据：`simctl install/launch` 成功；XCUITest 记录默认 Continue Watching 焦点、原生 TabView 标签、详情默认播放焦点、AVPlayer 起播/暂停/Menu 返回、续播 15:09→15:18（演示片）。截图位于 `.local/artifacts/UI-001/final-screens`，自造弹幕 fixture 位于 `tour-danmaku2`。UI 测试运行器有时在测试通过后不退出；未记为 CI 通过。
- Hub：Server/ 新增 Fastify 5.12.7 + Zod 4.6.7 + pg 8.23.1 + pino 10.4.0；严格配置、49 tests（含真实 PG 迁移/约束/Worker）、health/ready/bootstrap/OpenAPI、统一错误/requestId、Postgres job 队列。`TEST_DATABASE_URL=postgres://postgres@127.0.0.1:55432/doki_hub_test pnpm test` 49/49 通过；OpenAPI 已重新生成（37561 bytes，sha256 `dc0575265cbecb2114c0f94f233d50b510b73beb4574e88584063f16e68a3944`）。
- 真实源：采用固定快照 sha256 `7e54969e4d8de3535242927af3c27e09a8e8d47f65ab9649a84a2163c975535c`（提交 d2f58217...）中的樱花动漫规则；新增 `yinghua` adapter（search/detail/episode/player_aaaa/encrypt=0）、SafeFetcher（DNS/IP/redirect/端口/凭据校验，benchmark 网络需显式本地开关）、RequestThrottle、HLS relay（签名 session/resource、playlist URI 重写、Range/HEAD、坏签名 403）和仅非 production 的 `POST /v1/dev/source-preview`。真实请求 200（约 4.94s）；master/variant/segment 200/200/206，TS 首字节 0x47，Range 206 `bytes 0-1023/557232`；坏签名 403。
- TV 真实播放：`--demo-hub-url http://127.0.0.1:18080 --demo-route real-source --demo-real-autoplay` 在模拟器通过 Hub relay 播放；首播 00:09，重开续播 01:30，原生控制条 seek 后 02:59，再次重开 03:03。Hub 日志记录连续 relay 200/206。
- **内容安全阻断**：真实源视频在约 03:03 出现第三方赌博广告。已删除含该源画面的截图和原始媒体/HTML；真实源只保留 adapter/relay 技术验证，不得作为产品默认源或公开部署。该发现写入 CURRENT_STATE、接入文档与 ADR-010。
- 未完成：Apple TV 真机/签名、完整集、PiP/AirPlay、真实 Bangumi/TMDB/弹弹play、AUTH/SYNC/正式 PlaybackSession、真实弹幕、第二源、部署/备份、动画录屏与正式辅助功能验收。Mac 仅作开发主机；没有创建 iPhone/Mac target。
- 未执行：git init/commit/push、公开部署、借用任何其他项目凭据。真实凭据仍未配置。

### 2026-10-30 · 收尾验证与清理

- `swift test`（DokiCore/DokiDanmaku/DokiPlayback）：8 + 9 + 4 = 21 tests 通过（最终源码）。
- `xcodebuild build-for-testing -project Doki.xcodeproj -scheme DokiTV -destination "platform=tvOS Simulator,id=A3FD875C..." CODE_SIGNING_ALLOWED=NO`：`** TEST BUILD SUCCEEDED **`；测试目标只保留 Smoke/PlayerFlow，避免默认测试依赖外部源。
- `pnpm build`（Server）：tsc + migrations 复制成功；`TEST_DATABASE_URL=... pnpm test` 最终 7 文件、49 tests 通过。
- `python3 scripts/check-docs.py`：PASS，18 份 Markdown；链接/表格/代码围栏/引用/JSON 示例通过。该检查不验证编译、真实 API 或播放。
- 收尾：终止 tvOS App、Hub API（PID 文件）、本地 Postgres 测试集群，并关闭模拟器。真实源含广告/版权画面的截图和原始抓取媒体已删除；`PLAY-001` 仅保留脱敏 `uitest-seek.log`，`SRC-001` 仅保留 `source-preview-summary.json`。
- 最终播放器画面：`--demo-route player --demo-subject demo-subject-01 --demo-episode 5 --demo-enable-danmaku` 生成 `.local/artifacts/UI-001/final-screens/17-player-demo-danmaku.png`；画面为自造样片（05:19/24:00）和自造弹幕 fixture，不含真实源画面。
- 最终 app build `build-final-player.log` 通过；`xcodebuild build-for-testing`（generic tvOS Simulator destination）再次通过 `TEST BUILD SUCCEEDED`。
- 未执行：git init/commit/push、公开部署、借用其他项目凭据。未配置真实 Bangumi/TMDB/弹弹play凭据。

## 2026-10-30 · ENV-001 / UI-001 · 打开 TV 模拟器预览与环境纠正

- 用户要求打开模拟器查看效果，并授权安装缺失的图形组件。检查发现 Xcode 27.1 已自带 `Contents/Applications/DeviceHub.app`；此前“无 GUI Simulator.app”被错误推断为没有模拟器图形界面，实际无需安装。
- 执行 `open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app --args -CurrentDeviceUDID A3FD875C-F0DC-4BCE-880D-C4F6680D3C97`；CoreGraphics 窗口列表确认 Device Hub 的 Apple TV 4K (3rd generation) (at 1080p) 窗口已显示。
- `xcrun simctl launch --terminate-running-process A3FD875C-F0DC-4BCE-880D-C4F6680D3C97 com.doki.tv --demo-tab discover --demo-dark` 成功；保持 Doki 和 TV 模拟器运行供用户查看。发现页为自造演示内容，未启动 Hub/Postgres，未调用真实源或配置凭据。
- 同步纠正 CURRENT_STATE/SETUP 的 GUI 入口；本次仅运行既有 App 与修正文档，未重新构建，未扩展功能验收结论。
- 用户随后反馈无法打开软件：截图确认停在 tvOS 系统桌面，Doki 进程仍运行；未发现 Doki 崩溃报告。再次终止并启动 App 后，PineBoard 日志确认前台切换成功（`isFailed=false`），并分别检查模拟器截图和 Device Hub 窗口截图，发现页已显示。证据为 `.local/artifacts/preview/doki-launch-check-2.png` 与 `device-hub-launch-check.png`；不再仅凭进程存在认定用户可见。文档检查 18 份 Markdown 通过。

## 2026-10-30 · REWORK-001 / UI-001 / META-001 · TV 界面大改与真实公开资料

- 用户指出竖封面被大量裁成横图、TMDB 未使用、参考机制/动效不足和玻璃/交互问题，要求大改并尽可能接真实数据；需凭据的部分明确列出获取位置与配置方式。
- 保持一个 tvOS target + 必要 Hub，无 iPhone/Mac 客户端。研究 izuko-tv 提交 `9d9cba2ad0ef7e443ffa3542cee91fba345edafa` 的 hero handoff、媒体流水线、timeline 和详情；只参考机制，SwiftUI 独立实现，未引入其 AGPL 代码/素材。
- 正常启动改为匿名 Bangumi 真实目录；fixture 显式 `--demo-fixtures`。新增 DokiCore CatalogClient（首页/季度、搜索分页、周表、详情/章节/角色/人员），TV 本机追番/显式已看/图片关联；有 Hub 走 Hub，未配置时直读官方。不添加账号/写回成功的假状态。
- UI：发现/日历/搜索/追番使用竖版海报；首页和详情局部预览，TMDB 才用于横幅，缺横幅保留海报比例。重写详情与“我的”主要路径；角色/人员去重保留多个职务、12 位预览/可展开、惰性加载。原生 matched source / zoom 转场、焦点停留预览、Menu 返回原卡片；减少动态效果分支不使用自定义缩放。
- 玻璃改成原生 `.glass` 按钮和关联容器，移除按钮外层手动 interactive 玻璃；减少透明度使用普通系统控件/实色。图片缓存上限 80 MiB、并发同 URL 去重、流读取/缩图离开主线程、同 origin 重定向、失败保留旧图；未做全局清理或修改进度缓存。
- 修复空章节下标、章节焦点前缀不一致、手动未看被推断已看覆盖、地址/查询变化时旧刷新/搜索结果回写、长短标题导致同排海报错位、空类型下多余分隔符、Bangumi `images: null` 导致 Hub 拒绝整页、上游畸形响应错误码。真实条目在未接源时不会误播演示 MP4。
- Hub：新增元数据服务和 Fastify 只读路由、Zod/OpenAPI 契约、缓存/并发去重/每 IP 限流；可选 TMDB TV/movie 搜索、唯一标题/年份匹配、歧义候选/手动修正与固定 origin 横幅代理。无 token 的 artwork 返回 `notConfigured`，上游故障不挡 Bangumi。修改 SafeFetcher 支持搜索 POST body 并对文本流执行前置体积限制；没有新增依赖或数据库迁移。
- 真实 API：Swift 直读与 Hub provider probe、HTTP 均运行。2026-10-30（Mac 原有透明代理网络，Hub 显式本地 benchmark 开关）：24 个本季条目、7 天周表，`554779` 详情、12 话、31 条角色与 288 条职务记录；“葬送的芙莉莲”搜索 5 个结果。Hub probe 约 4.03 秒；`/health`、`/v1/home`、条目/章节/角色/人员/搜索 HTTP 200，artwork 200 且 `notConfigured`。没有账号写入或视频源执行。
- 测试：最终 DokiCore **13 tests 通过**，含一次可选 live 读取（约 4.44s）；Server **47 passed / 10 skipped**，跳过的是数据库集成，本轮未重跑/修改 PG。`pnpm typecheck / openapi / build` 通过。tvOS XcodeGen 构建与真实 UI 测试记录在 `ui-release-check.log`；深色详情/Menu 返回、浅色日历/搜索/设置、减少动态效果/透明度分支以及失败保留目录分别有证据。
- 媒体证据：`.local/artifacts/REWORK-001/`。原始导航录屏 `tvos-navigation.mp4`（187.84s，包含启动/空闲），剪辑 `preview-motion.mp4`（35s，同一模拟器原生画面，无概念动画替代）；AVFoundation 已读取视频轨道并抽帧检查。截图不替代动效；本轮录屏也不宣称真机帧率或完整中断矩阵通过。
- 配置：新增 [INTEGRATIONS_SETUP](../development/INTEGRATIONS_SETUP.md) 和 TV 数据服务页，列明 TMDB/Bangumi/弹弹play申请来源、`.env` 字段、已实现/未实现区别。`init-local-config.py` 0600/独占创建、生成独立本地密钥且不打印。`.env.example` 的 BGM_REDIRECT_URI 改为空，避免只配 TMDB 时因半组 OAuth 字段无法启动。验证用配置位于 `.local/rework-hub.env`，没有写入账号/第三方 token。
- 第三方署名：About 加入 TMDB 要求的声明和官方蓝色短 SVG（保持原色/比例），来源与义务见配置指南。真实动漫封面按 Bangumi URL 读取，未打包成素材。
- 文档：同步 CURRENT_STATE、设计、ROADMAP、API_CONTRACTS、SETUP、Server README、文档入口并追加 ADR-011；`python3 scripts/check-docs.py` 通过 19 份 Markdown。
- 未完成：TMDB 真实 token 取图、Bangumi owner/TV 配对/OAuth/同步、弹弹play真实签名/匹配/取数、可接受的真实播放源、正式 PlaybackSession/epoch、Apple TV 真机/签名/完整集、生产 egress IP 固定/鉴权与部署。`yinghua` 含赌博广告，维持 ADR-010，未扩源。META/UI 仍为 `implemented_unverified`，没有把匿名子集验证当作整个首版完成。
- 未执行：Git init/commit/push、PR、外部发信或公开部署。修改前源码备份为 `.local/backups/before-tv-rework-20261030.tgz`。

### REWORK-001 最终收尾

- 最终 `ui-release-check.log`：3 tests、0 failures、`TEST SUCCEEDED`（68.23s）；Hub 故障保留目录、真实详情/Menu 返回、浅色日历/搜索/设置全部通过。截图导出并命名到 `.local/artifacts/REWORK-001/review-screens/`，已检查深色真实封面、浅色与实色按钮分支。
- 最终 Server 47 passed / 10 skipped；DokiCore 13 tests，通过一次真实角色/人员读取。文档检查 19 份 Markdown 通过。
- 已停止本轮仅 loopback 监听的 Hub 探测进程；没有启动数据库，没有部署。重新启动正常匿名浏览的 TV 预览并打开 Device Hub，仍需以截图确认前台画面，不能仅凭 PID 宣称用户可见。
- 最终前台确认：`simctl launch --terminate-running-process ... --demo-dark --demo-hub-url ''` 后获取并检查 `preview-running.png`，真实番剧发现页实际显示；当前保留 TV 模拟器与 Doki 运行供预览。

## 2026-10-30 · Bangumi 登录 / TMDB / 应用凭据源码复核

- 用户问密钥放哪里、是否全部必要，并指出 izuko 能直接登录。只做只读源码调查和文档纠正，没有真实账号登录、token 生成、密钥提取/复用或功能实现。
- 固定 izuko 提交 `9d9cba2ad0ef7e443ffa3542cee91fba345edafa`：BangumiWebLogin 用邮箱/密码/验证码走官网表单，生成个人令牌；这条路径无需 OAuth 应用密钥。另有 OAuth 和粘贴个人令牌分支。
- TmdbImageService 在 token 检查前先查 GrahamZen/bangumi-tmdb-map；含 backdrop_path 的条目不要求 token，搜索/补查询才要求。原答“一律需要用户申请 TMDB/Bangumi 应用凭据”不准确，已在配置指南/CURRENT_STATE 澄清。Doki 这两条替代路径仍未实现，不能宣称已免密钥接通。
- izuko app-platform 构建字段与 CI 负责注入应用级服务凭据；弹幕网络仍要求 AppId/AppSecret。没有读取或输出任何真实凭据，不能证明特定发行包具备有效配置。
- 确认根目录 `.env` 尚未创建；模板为 `.env.example`，未来本地秘密填根目录 `.env`，内部签名/加密密钥由脚本生成。未创建或修改秘密配置。
- 文档检查：`python3 scripts/check-docs.py`；没有代码改动，因此未重复编译/运行测试。

## 2026-10-30 · REWORK-002 顶部原生标签 / 全宽横幅 / 无密钥账号路径

- 用户要求暂停弹弹play、参考 izuko 重做 TV；随后明确顶部标签栏、保留系统元素、移除侧栏、横幅铺满整个顶端。以最新要求为准，最终没有侧栏；不把中途侧栏方案留作产品基线。架构取舍记为 ADR-012。
- 发现页全宽真实背景延伸至原生 TabView 背后，六列竖版海报、标题 Logo、评分/简介；详情真实人数/评分分布、章节、角色/人员。公开对应表/图片 CDN 实际命中，无 TMDB token。SwiftUI 独立实现，没有复制参考代码或打包其截图/远程番剧素材。
- 修复双导航/横幅安全区留白、详情转场源被后续导航覆盖、章节选择直接改已看、手动横幅保留错误 Logo；保留图片直到替换成功。首选预览/重复选择详情与返回焦点有实际遥控器自动化证据。
- 新增 Hub owner 会话、六位码批准、一次性领取设备 token、Keychain、网页登录/验证码/自动个人令牌、AES-GCM 密文与账号追番只读导入。新迁移 0002。浏览器同源/CSRF/一次性 nonce、限流、固定官方出站、令牌不送图片端点。旧登录任务与解除绑定串行提交；旧账号读取使用 generation，不能覆盖新刷新。
- 实际官网 GET 登录页/验证码成功：3470 字节 GIF，未提交真实邮箱/密码或创建令牌。完整网站登录和账号导入只有自造协议测试；不宣称真实账号已登录、写回/完整同步已实现。申请 365 天不写成确认的过期时间，数据库保存未知 expires_at=NULL；解除本机绑定不代表上游撤销。
- 配对页实际截图发现 CIImage 显示空白，改为 CGImage 渲染；loopback 地址改显示电脑入口提示，避免手机扫到自己的 127.0.0.1。最后追加 UI 测试和截图确认修复；LAN QR/HTTPS 仍未实测。
- 创建根目录 `.env`（0600），独立随机本机加密/签名密钥，不输出值；第三方项全部空。新建实际开发数据库 doki_hub 并迁移 0001/0002，测试仅用独立 doki_hub_test。当前 Hub/数据库保留运行在本机 18080/55432，未公开部署；owner/真实账号未登记。当前 Mac 透明代理环境只在进程启动显式启用 benchmark 开关。
- 弹弹play按用户要求暂缓，没有提交审核/复用凭据。没有启用新视频源；yinghua 仍禁用，未扩大历史技术播放结论。

验证（当前 Mac、Xcode 27.1、tvOS 27.0、Apple TV 4K 1080p 模拟器 A3FD875C-F0DC-4BCE-880D-C4F6680D3C97）：

1. DokiCore：`DOKI_LIVE_METADATA=1 swift test --package-path Packages/DokiCore`，16 tests 通过，含真实公开资料与免 token 横幅/Logo。
2. Hub：`pnpm typecheck`、`pnpm openapi`、`pnpm build` 通过；真实 PG `TEST_DATABASE_URL=postgres://postgres@127.0.0.1:55432/doki_hub_test pnpm test` 最终 65/65，无跳过。初次端口用错（5432/55432）与迁移测试预期错误已修正，重跑通过；失败日志保留。
3. tvOS：CatalogUITests 原三项通过；新增顶部标签位置/浅色完整首页/真实 Hub 配对页面通过，四个不同测试均有通过记录。最后 QR/loopback 修正再跑该测试通过。纯账号 generation 防旧回写修改之后最终 build 通过，未重新声称真实账号测试。
4. 本机 HTTP `/health`、`/ready`、`/`、条目横幅均 200，横幅 ready；未配对账号接口 401。官网只读验证码成功；无真实账号登录/播放验收。
5. `.local/artifacts/REWORK-002/`：`ui-tests.log`（3 项）、`ui-top-tabs-tests.log`（2 项，包含重复详情）、`ui-pairing-final.log`（最后修复重测）、`build-final.log`、`core-live.log`、`server-postgres-final.log`，以及相应 xcresult 图片附件。浅深色/详情/配对截图已实际查看；`tvos-navigation-reviewed.mp4` 取原始录屏 20～62 秒，含加载/选择/进入/返回；不声称全程图片已载入、帧率或全部中断情况已验证。
6. 最终 `simctl install/launch --terminate-running-process ... --demo-dark --demo-hub-url '' --demo-tab discover`；打开 Device Hub，截图 `preview-final-home.png` 确认真实发现页前台，PineBoard running-active-Visible 日志对应 Doki。启动命令本身不当作前台证明。
7. `python3 scripts/check-docs.py` 通过 19 Markdown；无 Git 初始化/提交/push、其他端客户端或公开部署。

后续：用户浏览器实际账号登录；账号只读分页/失效/离线缓存与切换边界；Bangumi 写回/同步/上游撤销；可用视频源、真机/LAN 与完整验收。当前 UI 状态仍 implemented_unverified，不能把模拟器和公开 API 成功等同整产品完成。


## 2026-10-30 · GitHub 私有仓库初始归档

- 用户明确要求创建 GitHub 私有仓库并提交当前代码。初始化本地 `main`，创建 [Yaronluo/Doki](https://github.com/Yaronluo/Doki)，GitHub 返回 `visibility=PRIVATE`，设置 `origin` 指向该仓库。
- 初始提交范围为现有 tvOS App、共享 Packages、Hub、XcodeGen 配置与生成工程、测试、脚本和文档。提交作者使用 GitHub noreply 邮箱，仅配置当前仓库。
- 检查候选文件：排除本机 `.env`、`.local/`、`node_modules/`、Swift `.build/`、Hub `dist/`、Xcode 用户状态；保留 `.env.example`。本机秘密值交叉匹配与常见凭据格式扫描未发现命中，扫描未打印秘密值。
- 初始 commit/push 按本批次授权执行；交付以 GitHub 私有属性及远端 `main` 与本地 HEAD 一致为核验依据。本批次不改业务实现，不重复宣称构建、真实接口、实播或真机验收通过；无 PR 或公开部署。
- 归档检查：`python3 scripts/check-docs.py` 通过 19 份 Markdown；修整历史 v0.3 文档末尾多余空行后，`git diff --cached --check` 通过。该检查不验证编译、接口或播放。

## 2026-10-30 · REWORK-003 · 磨砂侧栏、平面控件与热门轮播

任务：UI-001 / META-001，状态 `implemented_unverified`（模拟器专项通过，真机综合验收未完成）。用户先要求头像式收起导航和热门循环横幅，随后明确纠正为截图中的深色磨砂侧栏，去掉不适合的自定义 Liquid Glass；后一要求覆盖 AGENTS/v0.4 的旧强制玻璃与顶部标签要求。

改动：五个独立 NavigationStack 保留页面状态，左上角账号头像/默认头像入口、昵称和时间，白色圆角焦点条。边缘上/左呼出、右侧和下方离开收起，菜单内上下仍选择目的地；菜单屏蔽内容焦点，动画结束后恢复焦点，取消旧任务。所有自定义玻璃按钮/容器换为 DokiControl* 平面控件，移除 glass API，侧栏采用深色系统 Material，减少透明度使用实色。无 iPhone/Mac target，无 private API。

热门独立使用 Bangumi 收藏热度，新增匿名 GET /v1/popular 和 OpenAPI；与本季评分推荐各自缓存与失败。tvOS 最多六部/8 秒，前后手动选择，菜单/详情/播放/后台/滚离横幅暂停，减少动态效果/VoiceOver 不自动切换。图片先预热再提交标题/背景，generation 防旧请求覆盖预览。快照向后兼容，失败保留旧列表和重试入口。无凭据、依赖、数据库迁移或播放源变更。

环境：2026-10-30，Mac 开发主机原有网络，Xcode 27.1 / Swift 6.4 / tvOS 27.0，Apple TV 4K (3rd generation, 1080p) 模拟器 A3FD875C-F0DC-4BCE-880D-C4F6680D3C97。本地 Hub 127.0.0.1:18080；OUTBOUND_ALLOW_BENCHMARK_NETWORK=1 只供本机透明代理，非 LAN/公开部署。

验证与证据：

- `xcodegen generate --spec project.yml --project .`；`xcodebuild build-for-testing -project Doki.xcodeproj -scheme DokiTV -destination 'platform=tvOS Simulator,id=A3FD875C-F0DC-4BCE-880D-C4F6680D3C97' -derivedDataPath .local/DerivedData/REWORK-003 CODE_SIGNING_ALLOWED=NO` 通过。project.yml 注释的旧生成命令会生成嵌套工程，已修正并删除该次新生成的嵌套目录；未手改 pbxproj。
- `DOKI_LIVE_METADATA=1 swift test --package-path Packages/DokiCore`：16 项通过（core-tests-2.log），含真实热门、主页/搜索/条目/章节/人员与无 token 横幅。首次上游超时记录保留在 core-tests.log。
- `cd Server && pnpm typecheck && pnpm openapi && pnpm test -- test/catalog.test.ts test/openapi.test.ts && pnpm build`：通过，12 项。热门过滤非动画/NSFW/重复身份并共用并发请求，官方排序请求体与公开路径已测。真实本地 Hub 热门 200/12 条，不代表真实账号或播放集成。
- `xcodebuild test` 使用上述同一 destination/DerivedData、`DOKI_LIVE_UI=1`，限定 `SmokeUITests/testCollapsedNavigation`、`CatalogUITests/testPopularCarouselAndMenuPause`、`CatalogUITests/testReducedMatteNavigationAndManualCarousel`：3 项通过，结果 `.local/artifacts/REWORK-003/ui-matte-2.xcresult` 与 ui-matte-2.log，明确 TEST SUCCEEDED。真实自动轮播、打开菜单暂停、收起恢复焦点、详情/返回、浅色减少动态透明度与手动切换均有证据。
- `.local/artifacts/REWORK-003/screens/` 有匿名真实热门/深色导航/详情平面按钮/返回、浅色减少动态透明度与自造手动轮播截图；`navigation-matte.mp4` 为本轮部分模拟器遥控交互录屏。截图不证明动效，录屏不证明真机帧率。
- `python3 scripts/check-docs.py`、`git diff --check` 通过。当前自定义 App/DokiUI 源无 glassEffect/GlassEffectContainer/glass 按钮。

故障修复过程保留：系统 TabView 隐藏未生效后移除该层；侧栏容器 accessibilityIdentifier 传播覆盖子按钮导致测试查找失败，已删除外层 ID；动画期内容禁用导致立即恢复焦点被拒，改为取消安全的动画后恢复。旧失败日志未删除。旧 xcodebuild 测试附件收尾挂起的进程在套件结束后终止；最终 ui-matte-2 正常退出成功。

边界：未用真实账号登录/头像验收，未操作真机、未做完整系统 VoiceOver 遥控验收或性能统计，没有视频实播、没有提交/push/PR/公开部署。原有含广告源继续禁用。下一步：真机验证焦点/长按/距离可读性与系统辅助功能，真实账号头像另验；其余 AUTH/SYNC/DAN/OPS 任务不由本批次关闭。

## 2026-10-30 · REWORK-004 · 彩色磨砂、轻透导航与焦点底板修复

任务 UI-001，状态 `implemented_unverified`：tvOS 模拟器专项通过，真机完整辅助功能/性能尚未验收。用户三图明确纠正：普通背景不能近黑；导航是大圆角、通透带轻磨砂、胶囊选中条；图三筛选按钮出现额外白色胶囊。随后圈图明确右侧横幅/文字/海报应清晰，磨砂只在侧栏内。最终按后一纠正移除根层两个导航状态 blur，不对右侧加蒙层；不会把以前模糊内容的截图当作当前样式。

改动：DokiTheme 蓝灰基底，DokiAmbientBackground 从原始内容图扩散颜色，移除先压黑再磨砂的管线；发现页滚离横幅后使用相同彩色磨砂背景。侧栏 420pt/44pt 圆角、白色胶囊焦点条，公开 UIVisualEffectView/UIBlurEffect 的轻模糊强度（UIViewPropertyAnimator 固定在 0.32）与轻烟色（0.10）保留背景轮廓；不通过降低整片磨砂的 opacity 混入清晰文字，避免背景文字双显；减少透明度使用蓝灰实体底。未恢复普通按钮的 glassEffect。

按钮根因是自绘填充外仍使用 tvOS PlainButtonStyle，会再添加系统焦点底板。筛选、日期、设置行、弹幕选项、源选择、重试统一改为自有 DokiContentButtonStyle 与公开 focusEffectDisabled；筛选固定高度/单一填充，焦点不重叠相邻项。系统输入/Picker/确认面板和 AVKit 保持原生行为；不关闭焦点移动或按钮动作。

实际环境：2026-10-30，Xcode 27.1 / Swift 6.4 / tvOS 27.0，Apple TV 4K (3rd generation, 1080p) 模拟器 A3FD875C-F0DC-4BCE-880D-C4F6680D3C97，Mac 开发主机原有网络与本地 Hub 127.0.0.1:18080。无凭据、API/依赖、数据库迁移、播放源或其他平台变更。

命令：`xcodebuild build-for-testing` 与 `xcodebuild test -project Doki.xcodeproj -scheme DokiTV -destination 'platform=tvOS Simulator,id=A3FD875C-F0DC-4BCE-880D-C4F6680D3C97' -derivedDataPath .local/DerivedData/REWORK-003 CODE_SIGNING_ALLOWED=NO`；真实测试加 `DOKI_LIVE_UI=1`，按下面 identifier 限定。结果在 `.local/artifacts/REWORK-004/`。

- build.log：tvOS build-for-testing 通过。
- ui-colored.log / xcresult：3 项通过，SmokeUITests/testColoredBackgroundAndFocusedSegments、SmokeUITests/testCollapsedNavigation、CatalogUITests/testReducedMatteNavigationAndManualCarousel。实际断言聚焦筛选高度 <80pt、与相邻按钮无交叠，遥控器焦点、浅色减少动态/透明度和手动轮播可用。
- ui-controls-live.log / xcresult：2 项通过，SmokeUITests/testCalendarAndSettingsFocusedControls、CatalogUITests/testPopularCarouselAndMenuPause；日期焦点高度 <115pt、浅色设置行焦点、真实热门自动切换/暂停/返回通过。
- ui-shelf-navigation.log 保留一次真实图片准备延迟导致的自动轮播等待超时；自动切换改为跳过不可用图片候选，仍保留成功显示的内容与取消/generation 边界，手动失败保留重试提示。ui-shelf-navigation-2.log / xcresult 之后通过，含发现页滚到海报货架。
- ui-clear-content.log / xcresult：用户圈图后移除全屏 blur，真实热门/菜单暂停/详情返回/发现货架回归通过，明确 TEST SUCCEEDED。
- ui-light-frost.log / xcresult：半透明材质试验的真实回归通过；视觉检查出现背景文字双显，改为公开原生 blur 强度插值。当前最终证据为 ui-light-frost-native.log / xcresult，同一真实回归通过，TEST SUCCEEDED。
- screens/：真实热门/菜单/详情/海报货架，以及 fixture 彩色背景/聚焦筛选/日期/浅色设置行/减少动态透明度截图。navigation-clear-content.mp4 只记录对应模拟器回归的一段交互，不证明当前最终材质参数或真机性能。
- `python3 scripts/check-docs.py` 与 `git diff --check` 通过。没有清理观看记录、变更账号或扩大缓存管理范围。

边界：5 个独立 UI 场景有本机证据，不宣称真机/完整系统辅助功能/帧率/真实账号头像/实播已验收；没有 commit/push/PR/部署。下一步仍为 TV 真机焦点、长按、观看距离与系统辅助功能专项。

## 2026-10-30 · REWORK-003/004 GitHub 归档

用户明确要求“提交到 github”，本轮授权提交并推送当前 tvOS 导航/材质/焦点修复、Bangumi 热门轮播、Hub 公开热门接口与对应测试/文档至既有私有仓库 Yaronluo/Doki 的 main。此前批次“未提交”是当时状态，本条记录随后取得的归档授权。

归档前核对改动文件、构建/测试记录、本地与 origin/main 分歧；变更文件与本地秘密值交叉检查未发现凭据命中，不打印秘密值。`.env`、`.local`、依赖、构建/测试日志和截图/录屏仍排除，不纳入提交。`python3 scripts/check-docs.py` 和 `git diff --cached --check` 作为归档检查；不重复将文档检查宣称为构建或实播测试。实际功能证据与限制沿用上文，最终交付核验为远端 main 与本地 HEAD 一致、工作树清洁；无 PR、部署或其他平台变更。


## 2026-10-30 · REWORK-005：首页、货架预览与账号胶囊

状态：UI-001 `implemented_unverified`（模拟器专项已实现，真机完整验收未完成）。用户暂停“按参考图重做首页交互”后明确授权当前对话接替；开始时工作树干净，未改 Hub、依赖、工程 target、协议或数据库。实现交接时未 commit/push，随后归档授权见下条。

实现：发现页只有“立即播放”与居中轮播页点，未登录隐藏继续观看；普通海报按货架排列，首次选择在该行上方展开条目信息/独立横幅，再次选择进入详情，返回保留海报，菜单键收起预览。顶部热门条目保持独立。账号胶囊显示头像与昵称/未登录，从胶囊原位变为大圆角导航面板；下方隐藏后边缘仍可呼出。清理首页来源/数量/箭头、菜单方向教学及浏览页装饰副标题，保留必要失败重试、配置授权和来源署名。真实条目播放入口在源缺失时明确反馈，不启用旧广告源或播放自造样片。

验证环境：Mac 开发主机、Xcode 27.1、Apple TV 4K (3rd generation, 1080p) 模拟器 `A3FD875C-F0DC-4BCE-880D-C4F6680D3C97` / tvOS 27.0；原有开发主机网络，真实资料测试匿名直连 Bangumi/公开图片，无 Hub 登录/账号/实播。

命令：`xcodebuild build-for-testing -project Doki.xcodeproj -scheme DokiTV -destination 'platform=tvOS Simulator,id=A3FD875C-F0DC-4BCE-880D-C4F6680D3C97' -derivedDataPath .local/DerivedData/REWORK-005 CODE_SIGNING_ALLOWED=NO`；UI 用同一 destination/DerivedData 的 `xcodebuild test`，逐项 `-only-testing:DokiTVUITests/<suite>/<method>`，真实资料加 `DOKI_LIVE_UI=1`，各次独立 `-resultBundlePath`。

- build.log：TEST BUILD SUCCEEDED。
- ui-final-fixture.log / ui-final-fixture.xcresult：三项通过且 TEST SUCCEEDED，覆盖 `CatalogUITests/testShelfPreviewAndCapsule`、`CatalogUITests/testReducedMatteNavigationAndManualCarousel`、`SmokeUITests/testCollapsedNavigation`。深色货架原位预览/保留热门/海报焦点/详情返回/菜单键收起/隐藏后左边缘呼出，浅色减少动态透明度/手动轮播，普通导航上下选择/右侧收起均通过。
- 初次胶囊仅 opacity/辅助功能隐藏仍留在可访问树，修正为隐藏时不创建按钮；收起态改为系统 Material，避免一直暂停的 UIKit animator 让 XCUITest 等待 60 秒。演示条目已追番的详情断言改为同时接受“加入追番/已加入追番”。失败日志 ui-fixture、ui-shelf-2、ui-shelf-3 保留。前两次套件结束后 xcodebuild 附件收尾停滞，定向终止对应已完成的进程；最终 fixture 运行正常退出成功。
- `ui-shelf-layout.log / ui-shelf-layout.xcresult`：最终全宽背景后货架完整流程通过且 TEST SUCCEEDED。插入预览后等待焦点引擎完成一次布局，再滚动到始终存在的货架锚点，避免焦点自动滚动覆盖新预览定位；旧失败 ui-final-live 保留。
- `ui-live-layout-final.log / ui-live-layout-final.xcresult`：真实目录首页/货架/菜单、浅色减少动态透明度/手动轮播两项通过且 TEST SUCCEEDED。真实首页 TMDB 横幅已显示；该轮部分 Bangumi 海报、标题 Logo 和选中条目横幅仍为缺图回退，不能据此声称所有图片成功。网络专项独立探测返回 image/jpeg / HTTP 200，不把探测当作 App 画面成功。
- 最后启动新版普通浏览后，`screens/final-home-running.png` 记录到真实“乱马1/2”货架预览及多张已加载海报，仍有部分缺图回退；未修改图片网络/缓存策略，也未用独立请求的成功替代所有图片验收。
- 截图在 `.local/artifacts/REWORK-005/screens/`，最终 fixture 附件在 `fixture-attachments/`；录屏 `final-live-navigation.mp4`。`python3 scripts/check-docs.py`：19 份文档 PASS；`git diff --check` 通过。

实现取舍见 ADR-015，设计与专项验收已同步。截图证明对应画面，录屏仅证明对应模拟器交互；未验证真机帧率/完整 VoiceOver/真实账号或视频播放，不因此关闭 UI-001/QA-001。

## 2026-10-30 · REWORK-005 GitHub 归档

用户明确要求“提交到 github”，授权提交并推送本批 tvOS 首页、货架内预览、账号胶囊与对应测试/文档至既有私有仓库 Yaronluo/Doki 的 main。归档前 fetch 确认本地 HEAD 与 origin/main 无分歧；16 个变更文件均属于本批，`.env`、`.local/`、截图/录屏和构建产物保持忽略。文档检查与暂存差异检查通过后提交；交付以远端 main 与本地 HEAD 一致、工作树清洁为核验。功能验证和未完成项沿用上文，不重复宣称实播、真机或部署通过。

## 2026-10-30 · REWORK-006：持续磨砂、统一标题与 izuko Hero

状态：UI-001 `implemented_unverified`。用户最新四图要求普通背景持续磨砂、封面清晰；货架横幅先对齐 izuko 的逻辑/动画；海报下方只要番名。本批仅 tvOS/DokiUI、本地开发，未 commit/push/PR/部署，无 Hub、依赖、协议或迁移变化。

实现：DokiHeroBackdrop 始终以彩色蓝灰磨砂铺底，清晰横幅受右上羽化遮罩限制，菜单状态不再关闭背景的磨砂/羽化。货架 Hero 从滚动内容移到固定屏幕舞台，焦点行停在简介下方，上方行和卡片番名分轨淡出；Hero 内方向换卡直接更新条目，再确认进入详情，返回保留 Hero 和原海报，再返回收起。首页/货架均用 DokiTitleArtwork，真实 Logo 缺失时用同一文字回退；DokiPosterTile 移除评分/类型/年份，只留番名。

重新通过 GitHub 文件工具读取 izuko 固定提交 `9d9cba2ad0ef7e443ffa3542cee91fba345edafa` 的 HeroTimeline、HeroStage、RowWallView、WallFocus 和 WallBackdropView；无压黑模式进入轨道为上方行 150ms、其后背景 400ms、文字延后 100ms / 300ms；退出文字 150ms、背景 250ms、随后上方行 250ms。独立 SwiftUI/Observation 实现逐帧线性采样，反向从当前值开始、取消旧 Task；减少动态效果直接到位。二次确认卡片/简介 200ms 淡出、400ms 交接系统详情；持续磨砂覆盖上游整屏去磨砂对焦，不进行 Android 代码移植。详情转场源改为全屏背景，tvOS 滚动/原生转场不是 Android 逐帧复刻；未运行 Android 对照录屏。决策 ADR-016，设计、v0.4、参考记录和验收同步更新。

环境：Mac 开发主机、Xcode 27.1、Apple TV 4K (3rd generation, 1080p) 模拟器 `A3FD875C-F0DC-4BCE-880D-C4F6680D3C97` / tvOS 27.0；开发主机既有网络；真实资料匿名直读 Bangumi 和公开 TMDB 图片，不涉及账号登录/播放。

命令：`xcodegen generate --spec project.yml --project .`；`xcodebuild build-for-testing` / `build` / `test` / `test-without-building -project Doki.xcodeproj -scheme DokiTV -destination 'platform=tvOS Simulator,id=A3FD875C-F0DC-4BCE-880D-C4F6680D3C97' -derivedDataPath .local/DerivedData/UITests CODE_SIGNING_ALLOWED=NO`，UI 指定 `-only-testing:DokiTVUITests/CatalogUITests/<method>` 与独立 resultBundlePath；真实资料加 `DOKI_LIVE_UI=1`。证据在 `.local/artifacts/REWORK-006/`。

- build.log、build-final.log、build-final2.log 与 build-background.log 构建通过；新增源由 XcodeGen 自动纳入，未手改 pbxproj。已有 App Icon、播放器 UIScreen.main 和旧 PlayerFlowUITests 并发 warning 不属于本次修改。
- ui-initial.log / xcresult 两项通过：testShelfPreviewAndCapsule、testReducedMatteNavigationAndManualCarousel；覆盖深色货架、菜单/焦点、浅色减少动态/透明度、手动轮播。
- ui-final.log / xcresult 两项通过：testAnimatedShelfFocusAndCancellation、testLiveHomeAndShelfPreview；真实横幅/Logo 与海报有成功画面，但背景源修饰顺序导致安全区矩形边缘，已调整为源修饰后忽略安全区，旧截图只作过程记录。
- ui-final2.log / xcresult：真实首页/货架/菜单与浅色减少动态/透明度两项通过；新增二次确认淡出后，动画详情返回的焦点断言失败。全宽截图在 fullwidth-screens/，这次部分海报仍为网络缺图回退，不能声称所有图片成功。
- ui-focus-fixed.log：仅延后恢复仍失败；testShelfPreviewAndCapsule 通过，之后附件收尾停滞，定向终止该 xcodebuild，未将不完整 xcresult 记成成功。根因为焦点状态保持同一 ID 时重新赋值没有重新申请原生焦点。改为进入详情时显式清除 FocusState、独立保存入口 ID，返回等墙面淡入/转场结束再恢复，期间忽略过渡焦点事件。
- ui-focus-reset.log / xcresult：最终 testAnimatedShelfFocusAndCancellation 通过，TEST SUCCEEDED；包含进入中返回取消、换焦点直接更新、进入详情、返回保留 Hero/第二张焦点、再返回恢复墙面。截图在 focus-reset-screens/。
- 模拟器录屏按批次保存；早期 hero-interactions.mp4、final-hero-interactions.mp4 和 verified-hero-interactions.mp4 属于过程记录，不能代替最终成功流程。截图证明指定状态，录屏只证明对应模拟器交互，不证明真机帧率或实播。

文档结构检查 `python3 scripts/check-docs.py`（19 份文档）与 `git diff --check` 通过。下一步仍为 TV 真机遥控器、观看距离、系统辅助功能/性能专项；没有扩张到 iPhone/Mac 客户端或启用广告视频源。

最终交付复核：`ui-delivery.log / ui-delivery.xcresult` 两项通过且 TEST EXECUTE SUCCEEDED（testAnimatedShelfFocusAndCancellation、testLiveHomeAndShelfPreview）。`delivery-screens/` 的真实学生会横幅、Logo 与八张已加载海报已实际看图检查，无安全区矩形边缘；卡片墙截图仅番名。`delivery-hero-interactions.mp4` 为最终成功两项测试的模拟器录屏。最后文档检查与差异空白检查通过；正常真实资料浏览版本保留在模拟器供查看。


## 2026-10-30 · REWORK-007：真正高斯、连续展开与明显焦点

状态：UI-001 `implemented_unverified`（模拟器专项实现，真机综合验收未完成）。用户追加两图指出 REWORK-006 的背景像灰圈、横幅展开/收起不够连续、上键不能回上一行、卡片焦点不明显。本批基于上一批未提交工作继续实现，未覆盖或撤回其他改动；当前未 commit/push/PR/部署。

实现：全屏图片做 48pt 高斯模糊并保留内容色/蓝灰亮度，移除洗灰材质叠层；清晰封面仅在右上（横向左约 44% 不叠清晰图，纵向首页上限 740pt、货架 Hero 530pt），缺横幅时海报仅作为模糊色源。持续节点 0↔450pt 弹性改变高度，货架同节奏滚动（response 0.62 / damping 0.88），文字加入 28pt 位移，横幅微缩放/位移，保持可中断的独立淡入轨道；减少动态效果/透明度各自回退。方向命令集中在发现页滚动容器，按行/列维护目标，原生焦点交接；首页顶部采用 ScrollPosition 绝对位置和原生 focusScope/resetFocus，旧货架交接时不抢焦点。卡片显式 FocusState 驱动 1.15 倍整卡放大、10pt 抬升、3.5pt 白色描边，匹配转场来源放到缩放层内，保留扩大后的完整海报/标题。追番/搜索/日历只同步共用卡片来源位置，未增加平台、Hub、依赖、协议或迁移。设计与 ADR-017、v0.4、AGENTS、验收同步。

环境：Mac、Xcode 27.1、Apple TV 4K (3rd generation, 1080p) 模拟器 `A3FD875C-F0DC-4BCE-880D-C4F6680D3C97` / tvOS 27.0，原有主机网络；真实资料匿名 Bangumi/公开 TMDB 图片，无真实账号、实播、真机或部署。

命令：`xcodebuild build-for-testing` / `test -project Doki.xcodeproj -scheme DokiTV -destination 'platform=tvOS Simulator,id=A3FD875C-F0DC-4BCE-880D-C4F6680D3C97' -derivedDataPath .local/DerivedData/UITests CODE_SIGNING_ALLOWED=NO`，逐项 only-testing 与独立 resultBundlePath；真实测试加 `DOKI_LIVE_UI=1`。证据均在 `.local/artifacts/REWORK-007/`。新顶部滚动 API 核对 [Apple scrollTo(y:) 文档](https://developer.apple.com/documentation/swiftui/scrollposition/scrollto%28y%3A%29)；没有修改外部协议或依赖版本。

- build.log：TEST BUILD SUCCEEDED。
- ui-shelf / ui-direction-fixed：初次安全区动画方案导致焦点行过低，换卡和上键回首页失败；尝试后改为持久占位高度弹簧。图像检查发现匹配转场来源会裁剪放大效果，已把来源移到缩放层内部，完整图/白边实际截图确认。
- ui-motion-fixed：动画展开中取消、再次展开、换卡、详情返回通过；跨行返回失败。ui-vertical-diagnostic 显示焦点仍停在今日行。方向命令移到容器层后，ui-parent-navigation 的前一行/列恢复通过；第一行回首页仍失败。
- ui-focus-and-live：真实首页/货架/菜单、浅色减少动态/透明度两项通过；第一行回首页失败。ui-hero-return / ui-position-return 继续保留失败记录，不用普通 scrollTo 调用成功代替焦点结果；回首页时旧卡片原生焦点仍将滚动拉回货架。
- ui-default-focus.log / xcresult：修复为原生 focusScope/resetFocus 和交接时旧货架暂禁用焦点后，完整 testShelfVerticalNavigationAndVisibleFocus 通过，TEST SUCCEEDED。该项实际断言聚焦卡比相邻卡宽至少 10%、Hero 下键下一行、上键上一行保留列、第一行上键收起并回播放按钮。
- 过程日志与失败录屏保留。部分失败测试的 xcodebuild 附件收尾停滞，定向停止这些已结束测试的进程；未将不完整 xcresult 记成成功。临时公开条目 ID 焦点日志已移除，无账号/密钥输出。

最终组合测试、截图与录屏结果在下面补充。真机帧率、完整 VoiceOver/观看距离、真实账号和播放不在本批验证范围；没有因模拟器可用而关闭 UI-001/QA-001。


REWORK-007 后续视觉与动效复查：`ui-final.log / xcresult` 的五项组合曾通过；逐帧和截图复查仍发现动画父层未参与、滚动锚点在高度变化时让海报停得过低，不能以这次测试通过代替完整可见性和连续位移。补充 minY <650、maxY <1050 的整卡边界断言，以内容坐标进行点滚动；`ui-geometry-final` 三项（动画取消/返回、真实资料、上下行/完整卡片）通过。

随后将布局动画移到货架父层并用全体货架共享的单一 0↔450pt 占位，避免换行时互换两块占位。父层动画修正的过程结果为 ui-parent-animation / ui-global-expansion（上一行已恢复，但回首页焦点失败），ui-completion-focus / ui-post-layout-focus（头部已可见但没有原生焦点）。最终在头部重现时更新播放按钮焦点身份，再交给原生 focusScope/resetFocus；`ui-header-focus-identity.log / xcresult` 完整纵向/尺寸专项通过，TEST SUCCEEDED。旧过程文件不能当作最终交付视频。


最终交付：`ui-delivery-final.log / ui-delivery-final.xcresult` 五项全部通过，0 failures，TEST EXECUTE SUCCEEDED；包含 testAnimatedShelfFocusAndCancellation、testLiveHomeAndShelfPreview、testReducedMatteNavigationAndManualCarousel、testShelfVerticalNavigationAndVisibleFocus、SmokeUITests/testCollapsedNavigation。相同 tvOS 模拟器/网络/DerivedData，执行 `test-without-building` 并显式 `DOKI_LIVE_UI=1`。整卡几何同时验证宽度超过邻卡 10%、展开后 minY <650 且 maxY <1050，实际截图显示完整放大图和白边。

最终画面在 `delivery-final-screens/`，已看图复查真实横幅/Logo、内容色高斯、完整海报与原生播放焦点；真实画面中八张海报成功显示，不据此承诺每个源图都成功。最终原始录屏 `delivery-motion.mp4`，16 秒摘录 `preview-motion.mp4`（只截取时间段、不改变速度/动画）；逐帧抽样用于检查连续位置和淡入淡出，不作为性能测量或真机帧率证明。此前的 final-motion、final-shelf-motion、continuous-shelf-motion、global-shelf-motion 均是过程证据，交付以 delivery-motion 为准。`python3 scripts/check-docs.py`（19 份文档）和 `git diff --check` 最终通过。普通真实资料浏览版本重新启动于模拟器；未 commit/push，未创建 iPhone/Mac 客户端、真实账号或实播验收。

录屏复核还发现父容器与系统横向导航重复处理，导致一次右键可能跨过相邻卡。移除自定义横向移动，保留原生焦点横移与既有左边缘导航；上下行仍由容器统一协调。增加明确相邻条目断言（首张向右必须是第二张），最终相邻卡复核与录屏以 ui-final-adjacent / verified-motion 为准。

最后归档核验：`ui-final-adjacent.log / ui-final-adjacent.xcresult` 五项全部通过、0 failures、TEST SUCCEEDED，含新增相邻卡断言。最新截图为 `verified-screens/`，已实际检查真实高斯/横幅、完整白边/放大卡片和第二张相邻卡；最终原始录屏 `verified-motion.mp4`，32 秒摘录 `preview-motion-verified.mp4`（原速，仅时间裁剪）。这些文件覆盖之前 delivery-motion 的交付地位。文档/差异检查通过，普通真实资料版本再次启动于模拟器。


## 2026-10-30 · REWORK-006/007 GitHub 归档

用户明确要求“提交到 github”，授权提交并推送本聊天累计的 tvOS 高斯背景、统一标题、货架动画/焦点与测试/文档至既有 origin/main。归档前 git fetch 确认本地 HEAD 与 origin/main 相同；21 个变更文件均属于本批。逐文件与本地秘密值及常见凭据格式检查无命中，未打印秘密值；.env、.local、截图/录屏、xcresult 和构建产物不进入提交。最终 ui-final-adjacent 五项成功记录已核对，不因归档重新扩大验证范围。文档与暂存差异检查通过后归档，交付以远端 main、本地 HEAD 一致和工作树清洁为核验；没有 PR、部署、真机或实播新增结论。


## 2026-10-30 · NET-001：电视端 Bangumi 线路回落与图片抢跑

状态：NET-001 `implemented_unverified`。用户确认当前没有配 Hub，公开 Bangumi 直连不稳定，要求先按 izuko 的线路思路改一版看效果。本批只改 tvOS/DokiCore/DokiUI、单元测试和本机证据；无 Hub、数据库迁移、依赖版本或播放源变化。用户随后明确要求提交 GitHub，已提交并推送 `ac746e0` 至 origin/main。

改动与理由：

- 新增 `Packages/DokiCore/Sources/DokiCore/BangumiRoute.swift`：`BangumiRoute` 做官方/镜像/自建的 `*.bgm.tv` host 映射；`BangumiRoutePolicy` 按顺序发送，官方不是最后一站时 6 秒探测、最后一站 18 秒；连接失败/3xx/5xx/API 返回 HTML 换线，4xx 原样返回；非官方成功后粘 30 分钟；官方连接失败后 60 秒内不再先试官方。带 `Authorization` 的请求只保留官方/自建。镜像根校验拒绝 IP、端口、路径、userinfo 和非 ASCII。
- `CatalogClient` 仅在 `hub == nil` 时启用线路层；Hub 模式保持原逻辑。`CatalogModel` 把 `Subject.posterURL`/`backdropURL` 的 `lain.*` host 映射到当前线路，切换线路时重写缓存快照；`AppModel` 保存自动/官方/镜像/自建设置，支持 `--bangumi-route`、`DOKI_BANGUMI_ROUTE`、`--bangumi-mirror`、`DOKI_BANGUMI_MIRROR`。
- 图片路径：`ArtworkLoader` 原来逐字节累积响应体，1 MB 海报要数秒 CPU；改为 `session.data(for:)` 一次读取，超时 15→30 秒。`DokiArtworkView` 通过 App 注入的 provider 同时向官方和镜像图床发请求，先解码成功者赢，慢的一方取消；`RootTabView` 在启动任务里注入 `BangumiRoutePolicy.alternateImageURL`。这只用于匿名公开图片，不发送账号凭证。
- 设置页“我的 → 数据服务与配置 → Bangumi 线路”增加自动/官方/镜像/自建选择、自建地址、重新加载；自建地址先编辑草稿再“应用”，避免每次按键重写 126 KB 快照。诊断页增加当前线路和最近耗时。

实际执行的命令与结果：

```sh
swift test --package-path Packages/DokiCore
# 25 tests / 4 suites passed，新增线路、4xx、5xx、HTML、凭证、粘性、图床映射、根校验测试

xcodebuild -project Doki.xcodeproj -scheme DokiTV \
  -destination 'platform=tvOS Simulator,id=A3FD875C-F0DC-4BCE-880D-C4F6680D3C97' \
  -derivedDataPath .local/DerivedData/APP-001 CODE_SIGNING_ALLOWED=NO build
# BUILD SUCCEEDED

xcrun simctl launch <UDID> com.doki.tv --bangumi-route mirror
# 首页 8 张海报实际显示；快照 127 张 lain.bangumi.lat + 30 张 image.tmdb.org
# 诊断：镜像 bangumi.lat，一次请求 2,680 ms

xcrun simctl launch <UDID> com.doki.tv --bangumi-route auto --demo-route diagnostics
# 诊断：官方，一次请求 3,267 ms；快照重新映射回 127 张 lain.bgm.tv
```

证据：`.local/artifacts/NET-001/mirror-home.png`、`mirror-diagnostics.png`、`auto-diagnostics.png`、`route-card.png`。截图只证明该模拟器、该网络、该次启动；不证明真机或大陆裸网。

未覆盖项 / 限制：

- 未在 Apple TV 真机或大陆裸网验证首屏回落耗时；本机透明代理能到官方，自动模式没有触发真实回落，回落分支由单元测试覆盖。
- 内置镜像只有 `bangumi.lat`；它是第三方通配反代，API/图片延迟在本机观测到 1.2–10.7 s / 0.4–15.6 s 的波动，不能当作官方 SLA。`bangumi.vip` 301 到 `.lat`，未加入。
- 未接远端镜像清单、镜像失效切换、自建反代实测；角色/声优头像仍只认官方图床；Hub 已配置时的 Hub 端线路层未做；没有账号请求，带凭证的过滤只由测试验证。

下一步及依赖：真机/大陆网络复测；补自建反代示例；把同一策略独立实现进 Hub `CatalogService`，登录/令牌仍只走官方/自建；再决定公开清单的来源与更新频率。

更新文档：CURRENT_STATE、WORK_LOG、DECISIONS（ADR-018）、INTEGRATIONS_SETUP。

归档复核：`ac746e0`（feat: add Bangumi route fallback for tvOS direct reads）已推送至 `origin/main`；本地 HEAD 与 `git ls-remote origin refs/heads/main` 一致，工作树清洁。未创建 PR、未部署；Apple TV 真机、大陆裸网、真实账号和 Hub 端线路层仍未验收。
