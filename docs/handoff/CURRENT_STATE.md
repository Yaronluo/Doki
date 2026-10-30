# 当前状态

> 更新：2026-10-30，REWORK-005 / 首页单播放入口、货架内预览与账号胶囊（本批 GitHub 归档已获用户授权）。当前仅 tvOS + 必要 Hub。真实账号、模拟器、真机、完整播放分别记录；历史批次见 [WORK_LOG](WORK_LOG.md)。

## 1. 当前结论

- 按用户最新截图与圈图纠正：**移除顶部标签，左上角头像展开通透大圆角磨砂侧栏、白色胶囊选中条；移除全部自定义 Liquid Glass，改为平面操作控件**。保留系统焦点、NavigationStack、搜索和 AVKit，发现/详情保留全宽真实横幅。
- 发现页保留独立 Bangumi 收藏热度轮播（最多六部、8 秒自动/右键手动切换），首页仅“立即播放”按钮、居中页点与本季推荐；未登录隐藏继续观看。热门经 `/v1/popular` 或无 Hub 官方直读，与评分推荐分开；轮播/菜单/详情的暂停与焦点恢复见本轮证据。全宽横幅、真实标题 Logo、竖版海报货架；详情展示真实收藏人数、评分分布、简介、章节和角色/制作人员。参考 izuko 的视觉层级，SwiftUI 实现独立编写。
- Bangumi 公开资料正常读取，无需密钥。公开 bangumi-tmdb-map 已接入，匹配到的 TMDB 横幅和 Logo **无需 token**，实际 TV 浅深色画面均已显示。缺记录时可选配置 TMDB token 搜索修正；不拿竖图冒充横幅。
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
| UI-001 | implemented_unverified | 彩色蓝灰磨砂背景、胶囊原位展开导航、单播放入口与货架内预览已实现；模拟器专项证据见 REWORK-005；缺真机完整辅助功能/性能验收 |
| HUB-001 | verified | 本地 API、迁移、Worker、PG 测试；不是部署验收 |
| AUTH-001 | implemented_unverified | owner/配对/加密网页登录/账号只读实现；fixture 和 PG 并发通过，真实验证码成功，缺真实账号登录、撤销和恢复验收 |
| SYNC-001 | not_started | 收藏/已看修改仍在本机，不是远端写回/outbox/epoch 同步 |
| META-001 | implemented_unverified | Bangumi 和无 token 横幅实际读取；可选 token 搜索没有真实凭据验收，真实账号追番尚未验证 |
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
- 首页海报首次选择在原货架上方展开预览，保留海报焦点，不改变热门条目或滚回首页顶端；重复选择进入详情，菜单键收起预览。详情转场固定入口身份，返回焦点有实际测试。
- 章节选择先打开操作确认，不再直接改变已看状态；手动标记才修改本机状态。切换手动横幅时清除旧标题 Logo，避免错误搭配。
- 保留已显示图片和目录直到替换成功；Hub 断连不清空缓存。没有清理观看记录或扩大缓存操作范围。
- 账号网页同源/CSRF/一次性登记 nonce，登录响应不跟随跨域重定向；个人令牌只发固定官方 API。设备和浏览器会话只存哈希，数据库令牌密文带独立随机 nonce；旧登录完成不能覆盖显式解除绑定。
- 网页“解除本机绑定”只删 Hub 凭据，不声称已撤销 Bangumi 上游令牌。个人令牌申请 365 天，不把申请值当作官网实际到期证明；失效后需重新登录。OAuth 回调、refresh token 流程仍未实现。
- 账号读取不等于完整同步；离线账号列表恢复、切换账号的本地缓存边界仍待专项完善。当前不可宣称多账号完整支持。

## 4. 本机环境与证据

### REWORK-005（本轮）

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
