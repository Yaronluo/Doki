# 当前状态

> 更新：2026-10-30，REWORK-002 / GitHub 初始归档。当前仅 tvOS + 必要 Hub。真实账号、模拟器、真机、完整播放分别记录；历史批次见 [WORK_LOG](WORK_LOG.md)。

## 1. 当前结论

- 按用户最新要求：**顶部原生 TabView，移除侧栏，大横幅铺满屏幕顶部并延伸到标签栏背后**。保留系统焦点、Liquid Glass 按钮/标签、NavigationStack 和 AVKit。
- 发现页改为全宽横幅、真实标题 Logo、六列竖版海报；详情展示真实收藏人数、评分分布、简介、章节和角色/制作人员。参考 izuko 的视觉层级，SwiftUI 实现独立编写。
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
| UI-001 | implemented_unverified | 顶部原生标签/全宽横幅、浅深色、返回和失败状态有模拟器证据；缺真机完整辅助功能/性能验收 |
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

- 消除侧栏和顶部导航并存；背景提升到 TabView 外层，避免安全区使横幅出现四周留白。普通卡片保留竖版比例。
- 首页海报首次选择预览，重复选择进入详情；详情转场固定入口身份，避免之后的导航覆盖旧页面转场源。返回焦点有实际测试。
- 章节选择先打开操作确认，不再直接改变已看状态；手动标记才修改本机状态。切换手动横幅时清除旧标题 Logo，避免错误搭配。
- 保留已显示图片和目录直到替换成功；Hub 断连不清空缓存。没有清理观看记录或扩大缓存操作范围。
- 账号网页同源/CSRF/一次性登记 nonce，登录响应不跟随跨域重定向；个人令牌只发固定官方 API。设备和浏览器会话只存哈希，数据库令牌密文带独立随机 nonce；旧登录完成不能覆盖显式解除绑定。
- 网页“解除本机绑定”只删 Hub 凭据，不声称已撤销 Bangumi 上游令牌。个人令牌申请 365 天，不把申请值当作官网实际到期证明；失效后需重新登录。OAuth 回调、refresh token 流程仍未实现。
- 账号读取不等于完整同步；离线账号列表恢复、切换账号的本地缓存边界仍待专项完善。当前不可宣称多账号完整支持。

## 4. 本机环境与证据

2026-10-30；Mac 开发主机原有网络，Xcode 27.1 / Swift 6.4 / tvOS 27.0；Apple TV 4K (3rd generation, 1080p) 模拟器 `A3FD875C-F0DC-4BCE-880D-C4F6680D3C97`。Node 24.22.1、pnpm 9.14.4、PostgreSQL 18.6。

本轮命令与结果：

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

代码版本管理已初始化，远端为 GitHub 私有仓库 [Yaronluo/Doki](https://github.com/Yaronluo/Doki)，主分支 `main`。用户已明确授权本批次初始 commit/push；未发布 PR 或公开部署，未创建 iPhone/Mac 客户端。`.env`、`.local/`、依赖、构建产物和 Xcode 用户状态不纳入版本控制；`.env.example` 保留空凭据模板。生产出站 IP 固定和强制代理仍待 OPS-001；本批次归档不扩大现有功能验收结论。
