# 当前状态

> 更新：2026-10-30，NET-001 / 电视端 Bangumi 线路回落与图片抢跑；REWORK-007 的真实高斯、双向位移动画与明显卡片焦点仍为上一批（REWORK-006/007 本批 GitHub 归档已获用户授权）。当前仅 tvOS + 必要 Hub。真实账号、模拟器、真机、完整播放分别记录；历史批次见 [WORK_LOG](WORK_LOG.md)。

## 1. 当前结论

- 按用户最新截图与圈图纠正：**移除顶部标签，左上角头像展开通透大圆角磨砂侧栏、白色胶囊选中条；移除全部自定义 Liquid Glass，改为平面操作控件**。保留系统焦点、NavigationStack、搜索和 AVKit，发现/详情分开高斯背景与右上清晰封面。
- 发现页保留独立 Bangumi 收藏热度轮播（最多六部、8 秒自动/右键手动切换），首页仅“立即播放”按钮、居中页点与本季推荐；未登录隐藏继续观看。热门经 `/v1/popular` 或无 Hub 官方直读，与评分推荐分开；轮播/菜单/详情的暂停与焦点恢复见本轮证据。全宽横幅、真实标题 Logo、竖版海报货架；详情展示真实收藏人数、评分分布、简介、章节和角色/制作人员。货架 Hero 触发/换卡/返回与无压黑分轨时序先对齐 izuko，SwiftUI 实现独立编写。
- Bangumi 公开资料正常读取，无需密钥。公开 bangumi-tmdb-map 已接入，匹配到的 TMDB 横幅和 Logo **无需 token**，实际 TV 浅深色画面均已显示。缺记录时可选配置 TMDB token 搜索修正；不拿竖图冒充横幅。
- 无 Hub 的公开 Bangumi 读取新增线路层：官方优先，连接失败/5xx/API 返回网页时切到镜像 `bangumi.lat`；匿名请求才允许走镜像，带 `Authorization` 的请求仍只走官方/自建。6 秒探测、30 分钟粘性、4xx 不换线；封面按当前线路映射并在官方/镜像间抢跑。设置页可切自动/官方/镜像/自建，Hub 模式未改。
- 已实现 Hub 浏览器邮箱/密码/验证码登录、自动创建个人令牌、AES-GCM 加密保存；不需要 OAuth 应用密钥，不保存密码或 Cookie。验证码已从官网实际取回；完整登录/账号追番读取尚无真实账号验收。
- 已实现 owner 浏览器登记、TV 六位码批准、一次性领取设备 token、Keychain 保存和账号追番只读导入。DB 并发测试通过；TV 已验证真实 Hub 配对码展示。尚未实现 Bangumi 写回、完整同步、远端令牌撤销或设备管理界面。
- 弹弹play按用户要求**暂缓接入**，没有申请或提交审核；自造弹幕仅开发 fixture，不冒充真实数据。
- 当前没有产品可用视频源。既有 yinghua 技术验证流含赌博广告，继续禁用；本轮未启用新源或扩张实播结论。

## 2. 任务状态

| 任务 | 状态 | 证据 / 剩余条件 |
|---|---|---|
| DOC-001 | verified | 当前批次文档与配置说明通过结构检查 |
| ENV-001 | implemented_unverified | 本机工具/模拟器；缺 TV 真机、签名与 LAN 部署 |
| APP-001 | verified | 单 tvOS XcodeGen 工程构建、安装与模拟器启动 |
| UI-001 | implemented_unverified | 真实高斯背景、连续展开/收起、上下行焦点与整卡 1.15 倍放大已实现；模拟器专项证据见 REWORK-007；缺真机完整辅助功能/性能验收 |
| HUB-001 | verified | 本地 API、迁移、Worker、PG 测试；不是部署验收 |
| AUTH-001 | implemented_unverified | owner/配对/加密网页登录/账号只读实现；fixture 和 PG 并发通过，真实验证码成功，缺真实账号登录、撤销和恢复验收 |
| SYNC-001 | not_started | 收藏/已看修改仍在本机，不是远端写回/outbox/epoch 同步 |
| META-001 | implemented_unverified | Bangumi 和无 token 横幅实际读取；可选 token 搜索没有真实凭据验收，真实账号追番尚未验证 |
| NET-001 | implemented_unverified | 电视端公开 Bangumi 线路回落、图床映射和图片抢跑已实现；DokiCore 25 项测试与模拟器强制镜像/自动诊断画面通过。未在真机/大陆网络验收，未接远端镜像清单，Hub 端线路层未做。 |
| SRC-001 / PLAY-001 | implemented_unverified | 仅历史单源模拟器技术证据，内容安全阻断产品启用 |
| SRC-002 | not_started | 没有启用第二源 |
| DAN-001 | not_started | 用户要求暂缓，未配置自有凭据 |
| DAN-002 | implemented_unverified | 历史自造媒体时钟弹幕；本轮未改 |
| DAN-003 | blocked | 真实凭据/匹配集成未完成；当前按用户要求暂缓 |
| OPS-001 / QA-001 | not_started | 无公开部署、备份恢复、真机综合验收 |

## 3. 已修复与边界

- 根层保留五个独立 NavigationStack，去掉 TabView 顶部栏。头像上/左边缘呼出，侧栏右侧离开/下方离开收起；菜单内上下用于选择，菜单打开时内容禁用焦点。普通卡片保留竖版比例。
- 自定义控件无 `glassEffect`、glass 按钮或玻璃容器；导航用透色系统 Material 和克制烟色遮罩维持文字对比，减少透明度时蓝灰实色。系统 AVKit/输入/面板保持原生。
- 热门请求独立失败/缓存，旧快照兼容，失败不清空旧目录；热门图片预热后再一起切换标题与背景，过期任务不得覆盖手动预览。导航/详情/播放/后台/横幅滚离时暂停；减少动态效果与 VoiceOver 时不自动轮播。
- 首页海报首次选择进入屏幕上方固定 Hero，聚焦行停在简介下方，上方行及卡片番名淡出；Hero 内方向换卡直接更新预览，再确认进入详情，详情返回仍在 Hero，菜单键再收起。首页/货架统一真实 Logo/文字回退，普通海报下方只有番名。
- 章节选择先打开操作确认，不再直接改变已看状态；手动标记才修改本机状态。切换手动横幅时清除旧标题 Logo，避免错误搭配。
- 保留已显示图片和目录直到替换成功；Hub 断连不清空缓存。没有清理观看记录或扩大缓存操作范围。
- 账号网页同源/CSRF/一次性登记 nonce，登录响应不跟随跨域重定向；个人令牌只发固定官方 API。设备和浏览器会话只存哈希，数据库令牌密文带独立随机 nonce；旧登录完成不能覆盖显式解除绑定。
- 网页“解除本机绑定”只删 Hub 凭据，不声称已撤销 Bangumi 上游令牌。个人令牌申请 365 天，不把申请值当作官网实际到期证明；失效后需重新登录。OAuth 回调、refresh token 流程仍未实现。
- 账号读取不等于完整同步；离线账号列表恢复、切换账号的本地缓存边界仍待专项完善。当前不可宣称多账号完整支持。
- 无 Hub 的 Bangumi 公开读取只走匿名线路：镜像不接收 `Authorization`，官方/自建才可带凭证；图片同时向官方与镜像发起、先成功者赢，失败保留旧图。`bangumi.lat` 是第三方反代，速度和可用性会波动；不能把它当成官方 SLA 或账号通道。

## 4. 本机环境与证据

### NET-001（当前批次）

2026-10-30 19:06–19:24，同一 Mac 开发主机、Xcode 27.1、Apple TV 4K (3rd generation, 1080p) 模拟器 `A3FD875C-F0DC-4BCE-880D-C4F6680D3C97` / tvOS 27.0，沿用主机网络（公网域名解析到 198.18/15 透明代理）。本批只改 tvOS/DokiCore/DokiUI 与本机验证；无 Hub、数据库迁移、依赖版本或播放源变化；用户随后明确授权本批提交并推送至既有 origin/main（`ac746e0`），本地与远端一致。

- 新增 `BangumiRoute`/`BangumiRoutePolicy`：官方、镜像、自建通配反代；按顺序尝试，连接失败/3xx/5xx/API 返回 HTML 才换线，4xx 原样返回；官方不是最后一站时 6 秒探测、最后一站 18 秒；非官方成功后粘 30 分钟，官方连接失败后 60 秒内不再先试官方。
- 带 `Authorization` 的请求过滤掉第三方镜像；当前没有账号请求，但边界先写死。设置默认“自动”（官方优先，失败切 `bangumi.lat`），可手动选官方/镜像/自建；`--bangumi-route` 与 `DOKI_BANGUMI_ROUTE` 可覆盖本机启动，`--bangumi-mirror`/`DOKI_BANGUMI_MIRROR` 填自建根。
- 图片按当前线路映射 `lain.*` host；切换线路时重写模型和快照里的图床地址。`ArtworkLoader` 改为一次性读取响应体（原逐字节循环会让 1 MB 海报像卡死），并让官方/镜像两个图床抢跑，先解码成功者赢；超时从 15 秒放宽到 30 秒。
- 设置页“我的 → 数据服务与配置 → Bangumi 线路”有自动/官方/镜像/自建与“重新加载”；诊断页显示当前线路和最近耗时。Hub 模式仍走 Hub，未在本批加入 Hub 端线路层。

验证与证据（`.local/artifacts/NET-001/`）：

- `swift test --package-path Packages/DokiCore`：25 tests / 4 suites 全部通过，新增 9 项线路/图床/凭证/粘性测试。
- `xcodebuild ... DokiTV ... build`：BUILD SUCCEEDED。
- 强制镜像：启动参数 `--bangumi-route mirror`，首页真实目录 128 条；快照 127 张 `lain.bangumi.lat` 海报 + 30 张 TMDB 图；诊断显示“镜像 bangumi.lat”，一次请求 2,680 ms；首页 8 张海报实际显示，截图 `mirror-home.png`、`mirror-diagnostics.png`、`route-card.png`。
- 自动：`--bangumi-route auto`，诊断显示“官方”，一次请求 3,267 ms；快照重新映射回 127 张 `lain.bgm.tv`，截图 `auto-diagnostics.png`。本机透明代理能到官方，所以自动模式没有触发回落；回落分支由单元测试覆盖。
- 镜像可达性：`api.bangumi.lat/calendar`、`/v0/subjects/554779`、搜索 POST 和 `lain.bangumi.lat` 图片均返回 200；`bangumi.lat` 主站是反爬挑战页，不能用于登录。观测到镜像 API 1.2–10.7 s、图片 0.4–15.6 s 的波动，不能把本机数值当作大陆速度。
- 未覆盖：Apple TV 真机、大陆裸网、真实账号、远端镜像清单、镜像失效切换、角色/声优头像（仍只认官方 `lain.bgm.tv`/`lain.bangumi.tv`）、Hub 已配置时的同线路层。`bangumi.vip` 会 301 到 `bangumi.lat`，未加入内置清单。

下一步：真机/大陆网络复测首屏回落耗时；提供自建反代示例；把同一策略加到 Hub `CatalogService`（登录/令牌仍只走官方/自建）；再决定是否接公开镜像清单。

### REWORK-007（上一批）

2026-10-30，同一 Mac 开发主机、Xcode 27.1、Apple TV 4K (3rd generation, 1080p) 模拟器 `A3FD875C-F0DC-4BCE-880D-C4F6680D3C97` / tvOS 27.0，沿用主机网络。仅 tvOS/DokiUI 与对应 UI 测试/文档；无 Hub、依赖、协议或迁移变化；实现交接时未 commit/push，随后用户授权归档见本文末尾。

- 按用户追加两图修正上一批：模糊图片持续铺底，去掉洗灰材质叠层，保留内容色与蓝灰亮度；清晰封面只在右上，文字区/货架后方不叠清晰副本。缺独立横幅时海报仅作为模糊色源，不作为清晰横幅；减少透明度仍为蓝灰实色。
- 共享展开占位保持节点身份，动画覆盖父层并双向弹簧改变高度，按稳定内容坐标滚动且保证整卡可见；文字增加进入/退出位移，横幅轻微位移/缩放。Hero 内上下命令改在滚动容器统一处理，按行/列切换，左右由原生焦点一次移动一张卡；第一行向上收起 Hero 并回播放入口，使用原生焦点范围和绝对顶部滚动，头部重新可见后更新播放按钮的焦点身份，交接时旧卡片暂不抢焦点。
- 发现、追番、搜索和日历共用卡片整卡放大到 1.15 倍、10pt 抬升、白色 3.5pt 海报描边。详情转场来源移到缩放层内，解决放大被原始来源边界裁掉的问题；海报下方仍只留番名。
- tvOS 构建通过；最终 `ui-final-adjacent.log / xcresult` 五项全部通过，TEST SUCCEEDED（含一次右键仅移动相邻卡）：动画中取消/换卡/详情返回、真实资料与菜单、浅色减少动态/透明度、上下行/第一行回首页/尺寸与整卡边界、导航与追番。最终截图和录屏见 WORK_LOG。UI-001 仍 `implemented_unverified`，真机观看距离、完整辅助功能与帧率没有完成，不宣称 Apple TV/Android 性能对比或逐帧复刻。
- 证据在 `.local/artifacts/REWORK-007/`。旧 REWORK-006 的通过记录只证明旧场景，不代替本轮新增的高斯、位移与跨行验收。

### REWORK-006（上一批）

2026-10-30，Mac 开发主机、Xcode 27.1、Apple TV 4K (3rd generation, 1080p) 模拟器 `A3FD875C-F0DC-4BCE-880D-C4F6680D3C97` / tvOS 27.0，沿用主机网络。真实资料匿名直读 Bangumi/公开 TMDB 图片；无真实账号、视频播放、真机或部署验收。无 Hub、API、依赖或迁移变更；当前批次未 commit/push。

- 磨砂底层持续存在，文字区和海报货架背景不随菜单或预览被清晰图覆盖；清晰图仅在右上横幅羽化显示，前景海报不磨砂。保留系统减少透明度的实色回退。
- 修复货架另写 Text 导致标题样式不一致，首页/货架复用 DokiTitleArtwork；真实“学生会也有洞！”Logo 和横幅均在模拟器显示。普通卡片下方只留番名。
- 重新读取固定 izuko 版本的 HeroTimeline/Stage/RowWall/WallFocus/WallBackdrop，按无压黑磨砂模式分轨实现可中断的进入/退出；Hero 内焦点换卡直接换预览，上方行淡出；二次确认卡片/简介 200ms 淡出，400ms 交接到系统详情转场，返回倒放并在淡入后恢复焦点。持续保留磨砂，不采用整屏去磨砂对焦；tvOS 滚动/系统转场未与 Android 做逐帧对照。
- XcodeGen 生成工程，build-for-testing/build 通过。初始两项 fixture、后续动画与真实目录各两项通过；全屏源修正后的真实目录和浅色减少动态/透明度通过。新增详情淡出后的焦点恢复曾两次失败，原始日志保留；显式清除/恢复 FocusState 后，最终 ui-delivery 两项（动画完整返回与真实目录/菜单）均通过，TEST EXECUTE SUCCEEDED。UI-001 继续 `implemented_unverified`，真机/完整辅助功能/帧率未完成。
- 证据目录 `.local/artifacts/REWORK-006/`：构建日志、UI xcresult/截图、模拟器交互录屏。检查只证明对应场景；文档检查不证明实播。

### REWORK-005（上一批）

2026-10-30，同一下述 tvOS 27.0 模拟器与 Mac 开发主机网络；只改 tvOS/DokiUI 首页、导航、浏览文案与 UI 测试，没有新接口、依赖、数据库迁移或播放源。工作树起始干净，原暂停对话未留下改动。用户随后明确授权本批提交并推送至既有 GitHub origin/main；归档不扩大功能验收结论。

- 首页单一“立即播放”平面胶囊，居中轮播页点；移除来源标签、数量、左右箭头与普通浏览操作教学。未登录不显示继续观看，fixture 仍明确标注。真实条目没有可用源时只反馈“暂无可用播放源”，不会播放演示片。
- 海报货架首次选择在当前行上方展开文本/横幅预览，顶部轮播身份保留；预览可见时使用全宽页面背景，避免矩形边界；重复选择详情，返回原海报，菜单键收起。图片仍由现有图片层保留成功结果与异步加载。
- 头像昵称胶囊原位扩展为磨砂面板，同一尺寸动画双向可中断；下方焦点隐藏胶囊，左边缘呼出独立于可见性。收起胶囊用系统 Material，展开侧栏沿用公开 UIKit 轻磨砂；右侧横幅无全屏模糊。
- tvOS build 与三项 fixture 交互通过；最终全宽背景后的货架复测通过，真实目录/菜单与浅色减少动态透明度两项通过且 TEST SUCCEEDED。真实首页横幅显示；该轮部分海报/Logo/选中条目横幅仍为缺图回退，网络探测成功不代替 App 图片成功。截图/录屏与命令见 WORK_LOG 和 `.local/artifacts/REWORK-005/`；UI-001 继续保持 implemented_unverified，真机完整辅助功能/帧率、真实账号与实播不在本批验收事实中。

### REWORK-004（上一批）

2026-10-30，同一下述 tvOS 27.0 模拟器与 Mac 开发主机网络；只改 tvOS/DokiUI 视觉与 UI 专项测试，没有新 API、依赖或数据库迁移。正常浏览仍使用真实 Bangumi，焦点几何测试使用明确自造 fixture。

- 修复根因：部分自绘控件仍用 tvOS `.plain`，聚焦时额外产生系统白色底板。筛选/日期/设置行/弹幕选项/源选择统一改为自有 ButtonStyle 与公开 focusEffectDisabled；筛选使用固定高度和单一填充，不再两层胶囊遮字。
- 普通背景改为蓝灰基底与原始内容色扩散，移除磨砂前的近黑压暗渐变；发现页滚到货架后切为彩色磨砂。菜单 420pt 宽、44pt 圆角、白色胶囊焦点条，采用半透明轻磨砂，保留背景颜色与轮廓；磨砂只在侧栏内，右侧横幅/文字/海报保持清晰，无全屏 blur 或遮挡。减少透明度使用实体蓝灰底。
- tvOS build-for-testing 通过（build.log）。ui-colored.log / ui-colored.xcresult 三项通过：筛选焦点与不重叠几何、导航、浅色减少动态透明度手动轮播。ui-controls-live.log / ui-controls-live.xcresult 两项通过：真实热门/菜单暂停/详情返回、日期与浅色设置行焦点。导航色调/发现货架最终回归通过（ui-shelf-navigation-2.log）；用户圈图纠正后右侧内容清晰回归通过（ui-clear-content.log）；轻磨砂采用公开 UIKit blur 强度插值，避免清晰文字与磨砂副本混叠；最终真实回归通过（ui-light-frost-native.log，TEST SUCCEEDED）。
- 证据：`.local/artifacts/REWORK-004/screens/` 聚焦按钮、日期、浅色设置行、彩色背景与透色导航截图；测试命令见 WORK_LOG。截图仅证明对应模拟器状态，完整 VoiceOver、真机帧率/遥控器和实播仍未验收。



### REWORK-003（上一批；旧背景/导航视觉已由 REWORK-004 修正）

2026-10-30，同一下述 Mac/tvOS 27.0 模拟器、开发主机网络；本地 Hub 127.0.0.1:18080 为验证临时启动，非 LAN/公开部署。真实 Bangumi 热门响应 12 条，前六 ID：10380、328609、400602、9717、27364、265。未登录，没有真实账号头像或视频播放验收。

- `xcodegen generate --spec project.yml --project .` 后 tvOS build-for-testing 通过；修正 project.yml 注释中会生成嵌套工程的旧命令，没有手改 pbxproj。
- `DOKI_LIVE_METADATA=1 swift test --package-path Packages/DokiCore`：16 项通过（core-tests-2.log），含真实热门/公开资料/横幅；首次上游超时失败保留在 core-tests.log。
- `cd Server && pnpm typecheck && pnpm openapi && pnpm test -- test/catalog.test.ts test/openapi.test.ts && pnpm build`：通过，12 项测试；无依赖、数据库迁移或源变更。
- tvOS 三项界面测试全部通过（ui-matte-2.log，TEST SUCCEEDED）：导航、真实热门自动轮播/菜单暂停/详情返回，以及浅色减少动态透明度/手动轮播。之前的焦点时序失败已保留；导航容器覆盖子控件 accessibilityIdentifier 的问题已修复。
- 证据在 `.local/artifacts/REWORK-003/`：原始构建/测试日志、截图与 navigation-matte.mp4。截图证明对应模拟器画面，录屏只证明对应交互，不证明真机帧率或实播。

### REWORK-002（上一批，以下证据不证明本轮样式）

2026-10-30；Mac 开发主机原有网络，Xcode 27.1 / Swift 6.4 / tvOS 27.0；Apple TV 4K (3rd generation, 1080p) 模拟器 `A3FD875C-F0DC-4BCE-880D-C4F6680D3C97`。Node 24.22.1、pnpm 9.14.4、PostgreSQL 18.6。

REWORK-002 命令与结果：

- `DOKI_LIVE_METADATA=1 swift test --package-path Packages/DokiCore`：16 项通过，含真实 Bangumi 首页/详情/章节/角色/人员/搜索和无密钥横幅/Logo。
- `cd Server && pnpm typecheck && pnpm openapi && pnpm build`：通过；无依赖版本变更，新增迁移 0002。
- `TEST_DATABASE_URL=postgres://postgres@127.0.0.1:55432/doki_hub_test pnpm test`：65 项通过，含真实 PG 并发领取/撤销鉴权；账号协议使用明确自造 fixture，无真实账号秘密。
- tvOS CatalogUITests 三项真实网络测试通过：详情/返回、浅色日历/搜索/减少透明度与动态效果、Hub 失败保留目录。追加顶部布局与真实 Hub 配对页面测试的最终结果见 WORK_LOG。
- HTTP `/health`、`/ready`、`/`、条目横幅均 200，横幅 state=ready；未配对 `/v1/account` 为 401。
- 官网只读登录探测成功返回 3470 字节 GIF 验证码，没有提交账号密码或创建真实上游令牌。

证据：`.local/artifacts/REWORK-002/`，构建/测试日志、浅深色顶部全宽图、详情/日历/搜索附件与导航录屏。截图证明该画面，录屏仅证明对应模拟器交互；不证明真机帧率或实播。此前数据库端口与迁移测试预期错误已修正后重跑通过，失败记录没有删除。

根目录 `.env` 已用初始化脚本创建（0600），只含本机随机加密/签名密钥，第三方项为空。当前开发 Hub 绑定 `127.0.0.1:18080`，数据库 55432；为本机透明代理显式启用 benchmark 出站开关，仅本地开发，不是 LAN 部署。真实账号尚未登记/登录。

## 5. 使用与下一步

1. 普通浏览与命中横幅无需配置。TV“我的 → Bangumi 账号”配置 Hub 后显示配对码；在运行 Hub 的 Mac 浏览器打开 `http://127.0.0.1:18080`，登记、批准并用自己的 Bangumi 邮箱/密码/验证码登录。秘密不发聊天。完整步骤见 [配置指南](../development/INTEGRATIONS_SETUP.md)。
2. 可选 TMDB 在线搜索：在 [账户 API 设置](https://www.themoviedb.org/settings/api) 获取 Read Access Token，填本机 `.env` 的 `TMDB_READ_ACCESS_TOKEN`；不是显示现有横幅的前提。
3. 弹弹play暂缓。将来恢复时需在 [开发者中心](https://dev.dandanplay.com/) 为 Doki 申请自己的 AppId/AppSecret，之后仍要集成和验收。
4. 视频源、完整同步、真实账号/真机、LAN HTTPS、备份恢复分别推进。当前没有用密钥就能解除的通用播放限制。

用户已在本轮明确授权将 REWORK-003/004 提交并推送至 GitHub origin/main；归档以远端 main 与本地 HEAD 一致为交付核验。未发布 PR 或部署。代码版本管理已初始化，远端为 GitHub 私有仓库 [Yaronluo/Doki](https://github.com/Yaronluo/Doki)，主分支 `main`。用户已明确授权本批次初始 commit/push；未发布 PR 或公开部署，未创建 iPhone/Mac 客户端。`.env`、`.local/`、依赖、构建产物和 Xcode 用户状态不纳入版本控制；`.env.example` 保留空凭据模板。生产出站 IP 固定和强制代理仍待 OPS-001；本批次归档不扩大现有功能验收结论。


## 2026-10-30 · REWORK-006/007 GitHub 归档

用户明确要求“提交到 github”，授权将当前高斯背景、统一 Logo/卡片标题、货架双向动画、上下行与相邻卡焦点、对应 UI 测试和文档提交并推送到既有私有仓库 Yaronluo/Doki 的 origin/main。归档前 fetch 确认 HEAD 与 origin/main 无分歧；21 个变更文件均属于本批。已核对最终五项模拟器回归成功记录，文档检查和差异空白检查通过；本地秘密配置、截图/录屏、xcresult、构建缓存均保持忽略。归档以远端 main 与本地 HEAD 一致及工作树清洁为交付核验；不发布 PR 或部署，不扩大真机、账号或实播验证结论。
