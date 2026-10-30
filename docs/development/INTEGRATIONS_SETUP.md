# 真实数据与本地配置

> 2026-10-30 · REWORK-002。仅 tvOS + 必要 Hub。所有秘密在本机填写，不发聊天；当前真实状态见 [CURRENT_STATE](../handoff/CURRENT_STATE.md)。

## 哪些功能需要密钥

| 功能 | 当前方式 | 用户需要提供什么 |
|---|---|---|
| Bangumi 资料/搜索/日历/章节/人员 | 官方公开 API | 无 |
| 已匹配 TMDB 横幅/标题 Logo | 公开 bangumi-tmdb-map + 官方图片 CDN | 无 |
| Bangumi 账号 | Hub 网页邮箱、密码、验证码登录，自动创建个人令牌 | 在浏览器自行登录；无需 Client ID/Secret，不把密码填进配置文件 |
| TMDB 搜索补图/手动修正 | 可选官方 API Bearer token | 从 [TMDB 账户 API 设置](https://www.themoviedb.org/settings/api) 取得 Read Access Token，填写 `TMDB_READ_ACCESS_TOKEN` |
| 弹弹play | 当前按用户要求暂缓 | 现在不填；将来从 [开发者中心](https://dev.dandanplay.com/) 申请 Doki 的 AppId/AppSecret |
| 视频源 | 仍无产品可用源 | 不是补一个通用 key 就能完成；需验证源与章节映射 |

Bangumi OAuth 的 `BGM_CLIENT_ID`、`BGM_CLIENT_SECRET`、`BGM_REDIRECT_URI` 保留为可选规划，**当前网页登录不使用，全部留空即可**。没有实现 OAuth callback 或 refresh token。公开资料与匹配图片不依赖 Hub；账号由 Hub 承担会话和令牌。

## 配置放在哪里

本机实际路径：`/Users/yaron/Doki/.env`，已用 `scripts/init-local-config.py` 创建，权限 0600。第三方字段目前为空；`CREDENTIAL_ENCRYPTION_KEY` 和 `STREAM_SIGNING_KEY` 已独立随机生成，不向服务商申请，不要每次启动重新生成。丢失加密密钥将无法解密已有令牌。

模板：[.env.example](../../.env.example)。已有 `.env` 时直接用本机编辑器编辑，不覆盖；初始化脚本只适用于尚无文件的环境。密码不进 `.env`、截图、日志或聊天。

## 当前 Mac 上启动与登录

已有本地 PostgreSQL 集群与 `doki_hub` 数据库，端口 55432。若集群停止，从仓库根目录启动：

```sh
pg_ctl -D /Users/yaron/Doki/.local/postgres-hub -o '-p 55432' \
  -l /Users/yaron/Doki/.local/postgres-hub/server.log start
cd /Users/yaron/Doki/Server
pnpm install --frozen-lockfile
node --env-file=../.env --import tsx src/db/migrate-cli.ts
pnpm build
OUTBOUND_ALLOW_BENCHMARK_NETWORK=1 node --env-file=../.env dist/api/server.js
```

最后一行的 benchmark 开关仅因当前 Mac 的透明代理把公网域名解析到 198.18/15；其他网络去掉前缀，生产禁止开启。已运行 Hub 时不要重复启动；`/ready` 返回 200 才说明数据库与迁移准备完毕。其他机器按 [SETUP](SETUP.md) 和 [Server README](../../Server/README.md) 初始化自己的环境。

1. TV“我的 → Doki Hub”保存 `http://127.0.0.1:18080`（仅模拟器），再进“Bangumi 账号”获得六位配对码。
2. 在运行 Hub 的 Mac 浏览器打开 [Doki Hub 本机页面](http://127.0.0.1:18080)，点击登记。已有 owner 时本机可恢复管理会话，旧浏览器会话失效。
3. 输入电视的六位码批准；TV 用独立隐藏凭证一次性领取设备 token 并存 Keychain，六位码本身不能读取账号。
4. 网页输入自己的 Bangumi 邮箱、密码和验证码。成功后自动申请个人令牌，Hub 加密保存，TV 自动读取追番。密码和官网 Cookie 不持久化。

**当前完整登录仅通过自造协议测试；真实官网验证码已成功取回，但没有用真实账号验收最终令牌创建/追番。** 失败时刷新验证码重试；网站表单变化需更新适配。令牌申请 365 天，实际失效后重新登录。网页解除本机绑定仅删除 Hub 保存的令牌，不撤销官网令牌；需要时到 Bangumi 官网个人令牌页手动撤销。当前收藏/已看修改仍在本机，不写回账号。

真实 Apple TV 不能使用 Mac loopback 地址。LAN/VPN 需可达 HTTPS、证书、反向代理/访问控制和 `HUB_SETUP_SECRET`；不依赖另一个 Doki App。目前仅本机开发运行，没有完成这部分部署。扫码 loopback 地址也只能在 Hub 主机使用；手机端需 LAN 配置后再使用。

## Bangumi 线路（无 Hub 直读）

无 Hub 时，电视默认“自动”：官方优先，连接失败、5xx 或 API 返回网页时切到公开镜像 `bangumi.lat`。这条通道只用于公开资料，请求不带 Bangumi 账号令牌；登录、追番读取和后续写回仍必须走 Hub。

- 设置位置：“我的 → 数据服务与配置 → Bangumi 线路”。可选自动 / 官方 / 镜像 / 自建。
- “自建”填整族通配反代根，例如 `bgm.example.com`；需要同时把 `api.bgm.example.com`、`lain.bgm.example.com` 指向 `*.bgm.tv`。自建被视为可信线路，可带账号请求；镜像默认不带。
- 诊断页显示当前线路和最近一次请求耗时；设置页“重新加载”会重新请求首页和热门。
- 镜像 `bangumi.lat` 的主站是反爬挑战页，不能用于登录；只用它的 API 和图床。第三方镜像能看到公开请求和 IP，也能改写返回内容，不要把它当作官方 SLA。

本机验证可通过启动参数或环境变量覆盖，不需要改代码：

```sh
# 强制镜像
xcrun simctl launch <UDID> com.doki.tv --bangumi-route mirror

# 官方优先（默认）
xcrun simctl launch <UDID> com.doki.tv --bangumi-route auto

# 自建反代：直接用启动参数，避免 simctl 环境变量需要 SIMCTL_CHILD_ 前缀
xcrun simctl launch <UDID> com.doki.tv \
  --bangumi-route custom --bangumi-mirror bgm.example.com
```

用环境变量时，`simctl` 需要 `SIMCTL_CHILD_` 前缀；Xcode Run 的环境变量则直接生效。

`--demo-route integration` 与 `--demo-route diagnostics` 是 DEBUG 启动参数，用于直接打开设置/诊断页。未配置 Hub 时公开资料直读；配置 Hub 后电视走 Hub，Hub 端尚未实现同一线路层。

## 验证

```sh
DOKI_LIVE_METADATA=1 swift test --package-path Packages/DokiCore
cd Server
pnpm typecheck
pnpm openapi
TEST_DATABASE_URL=postgres://postgres@127.0.0.1:55432/doki_hub_test pnpm test
pnpm build
```

DB 测试会删除指定测试数据库的 public schema，只允许用可丢弃的 `doki_hub_test`，不能指向实际 `doki_hub`。TV 真实网络测试显式启用：

```sh
xcodebuild -project Doki.xcodeproj -scheme DokiTV \
  -destination 'platform=tvOS Simulator,id=A3FD875C-F0DC-4BCE-880D-C4F6680D3C97' \
  -derivedDataPath .local/DerivedData/APP-001 CODE_SIGNING_ALLOWED=NO \
  DOKI_LIVE_UI=1 -only-testing:DokiTVUITests/CatalogUITests test
```

`testNativeTopTabsAndHubPairing` 需要 loopback Hub/数据库运行；默认 `DOKI_LIVE_UI=0` 不执行真实网络测试。fixture 只通过 `--demo-fixtures` 启用。

## 来源与使用边界

- [Bangumi OpenAPI](https://bangumi.github.io/api/) 提供资料；封面与内容权利属于各权利人，不把远程番剧图片打包进 App。
- 网页流程参考 izuko 固定提交 `9d9cba2ad0ef7e443ffa3542cee91fba345edafa` 的 [BangumiWebLogin.kt](https://github.com/GrahamZen/izuko-tv/blob/9d9cba2ad0ef7e443ffa3542cee91fba345edafa/app/shared/app-data/src/commonMain/kotlin/domain/session/auth/BangumiWebLogin.kt)。研究协议后用 TypeScript 独立实现；没有复制 Kotlin、复用其密钥或发行包配置。
- [bangumi-tmdb-map](https://github.com/GrahamZen/bangumi-tmdb-map) 运行时在线获取 TSV；严格检查 image path，6 小时缓存，失败保留旧表。未发现仓库根 LICENSE，不声称开放许可证已授权再分发；没有把表或参考截图打包进产品，公开再分发前需单独确认条件。数据维护者不代表拥有图片版权。
- TMDB [图片说明](https://developer.themoviedb.org/docs/image-basics)、[认证](https://developer.themoviedb.org/docs/authentication-application)与[署名](https://developer.themoviedb.org/docs/faq)：token 只送官方 API，不送图片 CDN。About 保留官方蓝色 Logo 与声明，原素材来自[官方标志页](https://www.themoviedb.org/about/logos-attribution)。
- izuko 参考截图只在本机证据目录用于对照，未加入资源；SwiftUI 界面独立实现，保留用户指定的顶部原生标签与系统元素，不移植 Android 布局尺寸/时序。
