# 环境与配置交接


本轮真实数据、凭据申请与 `node --env-file` 启动方式见 [INTEGRATIONS_SETUP](INTEGRATIONS_SETUP.md)。正常 TV 浏览公开 Bangumi 资料不需要凭据；TMDB 横幅需 Hub token。
> 当前已有 `project.yml`、单个 tvOS target、Swift 包、`Server/`、迁移和本地运行命令；Compose/生产部署仍未建立。以下命令区分“本轮实际执行”和“尚未验证”。

## 1. 已核对环境

2026-10-30 本机实际结果：

| 项目 | 结果 |
|---|---|
| Xcode / Swift | Xcode 27.1（27A9275）；Swift 6.4 |
| tvOS SDK | AppleTVOS 27.0；AppleTVSimulator 27.0 |
| tvOS Simulator runtime | tvOS 27.0（24J360），已下载安装 |
| XcodeGen | 2.46.0（`/opt/homebrew/bin/xcodegen`） |
| Node / pnpm | Node v24.22.1；pnpm 9.14.4 |
| Postgres | 18.6（Homebrew） |
| 模拟器 | Apple TV 4K 3rd gen (1080p)，UDID `A3FD875C-F0DC-4BCE-880D-C4F6680D3C97` |
| GUI Simulator | 已安装 Device Hub：`/Applications/Xcode.app/Contents/Applications/DeviceHub.app`；旧版 `Simulator.app` 路径不适用于本机 |
| Apple TV 真机 | 未连接；签名资格、型号和系统未知 |
| Hub 部署 | 未建立；本轮只有 `127.0.0.1:18080` 本地 API |

尚需用户补充：Apple TV 型号和系统、签名/开发者账号、Ubuntu/Hub 硬件、LAN/VPN 网段、域名/DNS/TLS、上行和磁盘，以及 Bangumi/TMDB/弹弹play 是否准备好。不要把这些事实写入聊天或文档中的秘密值。

## 2. tvOS 工程与模拟器

在仓库根目录：

```sh
python3 scripts/check-docs.py

xcodegen generate --spec project.yml
xcodebuild -list -project Doki.xcodeproj

xcodebuild \
  -project Doki.xcodeproj \
  -scheme DokiTV \
  -configuration Debug \
  -destination 'generic/platform=tvOS Simulator' \
  -derivedDataPath .local/DerivedData/APP-001 \
  build CODE_SIGNING_ALLOWED=NO
```

本轮实际 scheme 为 `DokiTV`；构建产物：

```text
.local/DerivedData/APP-001/Build/Products/Debug-appletvsimulator/Doki.app
```

启动模拟器并安装（UDID 以本机 `simctl list` 为准）：

```sh
DEVICE=A3FD875C-F0DC-4BCE-880D-C4F6680D3C97
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" \
  .local/DerivedData/APP-001/Build/Products/Debug-appletvsimulator/Doki.app
xcrun simctl launch "$DEVICE" com.doki.tv
open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app \
  --args -CurrentDeviceUDID "$DEVICE"
xcrun simctl io "$DEVICE" screenshot .local/artifacts/UI-001/discover.png
```

Debug 启动参数（仅 DEBUG，用于可复现截图，不替代真实交互）：

```sh
xcrun simctl launch --terminate-running-process "$DEVICE" com.doki.tv \
  --demo-light
xcrun simctl launch --terminate-running-process "$DEVICE" com.doki.tv \
  --demo-route source --demo-dark
xcrun simctl launch --terminate-running-process "$DEVICE" com.doki.tv \
  --demo-hub-url http://127.0.0.1:18080 \
  --demo-route real-source --demo-real-autoplay --demo-dark
```

`--demo-route` 支持 `source`、`danmaku`、`hub`、`auth`、`real-source`、`about`、`diagnostics`、`detail`、`player`；`--demo-subject` 可指定 fixture 条目，`--demo-episode` 可指定集数。真实源预览只有在 Hub 本地运行且环境变量正确时才可用。

### 2.1 tvOS UI 测试

`DokiTVUITests` 保留 `SmokeUITests` 和 `PlayerFlowUITests`。后者验证演示片起播、play/pause、Menu 返回和续播位置变化。

```sh
xcodebuild test \
  -project Doki.xcodeproj \
  -scheme DokiTV \
  -destination "platform=tvOS Simulator,id=$DEVICE" \
  -derivedDataPath .local/DerivedData/UITests \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:DokiTVUITests/PlayerFlowUITests
```

本轮工具链存在一个限制：测试断言通过后，`xcodebuild test` 有时不退出。测试结果可在日志中确认；如需截图，使用测试运行期间的 `simctl io`，不要把该现象当作 CI 通过。真实源 UI 测试需要外部站、本地 Hub 和本地数据库，已从默认测试目标移除。

### 2.2 验证产物的保留与清理

验证产物只写被忽略的 `.local/artifacts/<任务ID>/`，不进 `/private/tmp`，也不提交。每个任务目录保留最新 2 个 `.xcresult`，`.local/artifacts` 预算 3 GB：单个 `.xcresult` 会内嵌约 98 MB 模拟器日志归档，一次密集 UI 验证可产生上百个包、数 GB 占用。

```sh
scripts/local-cleanup.sh           # 干跑：列出超出的 .xcresult 及可回收量
scripts/local-cleanup.sh --check   # 超预算时退出码 1，用于批次收尾
scripts/local-cleanup.sh --apply   # 按保留策略删除
scripts/local-cleanup.sh --apply --derived   # 同时清 DerivedData（下次构建重建）
```

脚本只删 `.xcresult`，不动 `.local/postgres-hub`、`.local/logs`、截图、录屏和日志；删除前会确认 `.local` 解析后仍在仓库内。

录屏必须走带硬超时的包装脚本，不能直接调无上限的 `simctl io recordVideo`：

```sh
scripts/tv-record.sh FOCUS-002 focus-motion 45   # 任务ID、文件名、最长秒数（默认 60，上限 600）
```

2026-10-31 清理时发现一个中断后无人回收的 `simctl` 录屏残留，单文件 19.9 GB（`/private/tmp/doki-focus-probe.mp4.sb-*`），并一直被模拟器渲染进程持有句柄。包装脚本的时长上限和固定输出目录就是为了不再产生这类孤儿文件。

## 3. Hub 本地运行

```sh
cd Server
pnpm install --frozen-lockfile
pnpm typecheck
pnpm openapi
pnpm build

# 本地 Postgres 测试集群（路径已忽略）
pg_ctl -D ../.local/postgres-hub -o "-p 55432" -l ../.local/postgres-hub.log start
createdb -p 55432 -U postgres doki_hub_test 2>/dev/null || true

TEST_DATABASE_URL='postgres://postgres@127.0.0.1:55432/doki_hub_test' pnpm test
```

启动 API（不要把这些值写进仓库；`CREDENTIAL_ENCRYPTION_KEY` 与 `STREAM_SIGNING_KEY` 必须各自为 32 字节 base64）：

```sh
export NODE_ENV=development
export HUB_HOST=127.0.0.1
export HUB_PORT=18080
export HUB_BASE_URL=http://127.0.0.1:18080
export DATABASE_URL='postgres://postgres@127.0.0.1:55432/doki_hub_test'
export CREDENTIAL_ENCRYPTION_KEY="$(openssl rand -base64 32)"
export STREAM_SIGNING_KEY="$(openssl rand -base64 32)"

node dist/db/migrate-cli.js
node dist/api/server.js
```

健康检查：

```sh
curl -sS http://127.0.0.1:18080/health
curl -sS http://127.0.0.1:18080/ready
curl -sS http://127.0.0.1:18080/v1/bootstrap
curl -sS http://127.0.0.1:18080/v1/openapi.json
```

本轮结果：health/ready/bootstrap/openapi 均 200；迁移前 ready 503，迁移后 200；真实 Postgres 测试 49 项通过。未验证生产部署、TLS、鉴权、Redis/BullMQ、备份恢复或公网访问。

## 4. 真实源开发预览

Hub 的运行环境还需要：

```sh
export NODE_ENV=development
export OUTBOUND_ALLOW_BENCHMARK_NETWORK=1
```

> 本机 DNS 把公网域名解析到 `198.18.0.0/15` 的透明代理。`OUTBOUND_ALLOW_BENCHMARK_NETWORK=1` 只用于这个本地验证环境；普通 LAN/生产必须删除该开关，否则出站政策不能按默认拒绝所有 benchmark 网段。该开关不是凭据。

请求：

```sh
curl -sS -X POST http://127.0.0.1:18080/v1/dev/source-preview \
  -H 'Content-Type: application/json' \
  -d '{"query":"葬送的芙莉莲","episodeNumber":1}'
```

本轮真实结果：preview 200（约 4.94 秒）；relay master/variant/segment 200/200/206；Range 206；坏签名 403。**该真实源视频含第三方赌博广告**，只能用于 adapter/relay 技术验证；不得把该源设为产品默认源、公开部署或作为内容交付。含广告/受版权画面的截图已删除。

## 5. 秘密配置

根目录 `.env.example` 是键名契约；实际代码读取环境变量。真实值放本地 `.env` 或进程环境，不进入源码、fixture、日志、截图或交接文档。应用读取和字段校验已在 `Server/src/config/config.ts` 实现；空凭据返回 `notConfigured`，配置但未验证返回 `unavailable`。

| 配置组 | 准备方式 | 未配置时 |
|---|---|---|
| Hub/数据库/签名 | 本地生成独立高熵秘密；签名与加密键分离 | 启动拒绝或 readiness 失败，不退化为默认值 |
| Bangumi Client ID/Secret/回调 | 注册自己的 OAuth 应用，回调与 Hub 地址精确一致 | 授权/写回未配置 |
| TMDB Read Access Token | 自己申请 API 访问 | 图片回退到 Bangumi/稳定底色 |
| 弹弹play AppId/AppSecret | 在 DevCenter 注册、审核应用 | 弹幕 fixture 可继续，真实接口待验证 |

本轮没有配置任何真实 Bangumi/TMDB/弹弹play凭据，也没有借用参考项目凭据。

## 6. 尚未验证与用户需补充

- Apple TV 真机、型号/系统、签名安装、遥控器手感和 PiP/AirPlay。
- 家庭 Hub 机器、LAN/VPN、域名/DNS/TLS、上行和磁盘。
- 真实账号和弹幕应用凭据；只能记录“是否具备”，不要把秘密发给模型或写入文档。
- 生产部署、备份恢复、鉴权和出站强制代理。

Mac 只是开发主机；没有创建 iPhone/Mac 客户端 target。模拟器截图和 build 成功不等于真机安装或完整集实播。
