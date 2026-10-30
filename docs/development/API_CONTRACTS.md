# 内部 API 契约草案

> Hub 已有本地可运行的 Fastify/Zod 骨架，但尚未部署；现有 system、匿名 Bangumi 元数据、可选 TMDB 横幅、开发真实源预览与签名 relay 路由。本文固定跨模块语义与新增弹幕 DTO；未实现路由仍不能宣称可调用。已完成 Zod → OpenAPI 生成，并保存脱敏契约样本。

## 1. 通用规则

- JSON camelCase；时间戳用 UTC ISO8601；仅含年月日的放送日期保留 YYYY-MM-DD，不混为时间戳。位置/偏移使用有限数值的秒，拒绝 NaN、Infinity 和无意义负进度。
- Bangumi 标识明确命名 `bgmSubjectId` / `bgmEpisodeId`；`/v1/episodes/{id}` 中的 id 指 Bangumi 章节。
- 设备、会话、事件、provider、media 使用稳定字符串；弹弹play的 int64 库 ID / cid 在 Hub API 中必须是十进制字符串，不能先以 JS Number 解码再转回字符串。
- 所有用户接口按已配对设备校验所有者。客户端 deviceId/userId 不能替代服务端鉴权。
- 写入使用独立 `Idempotency-Key` 或不可重复的 eventId；版本化修改带 expectedRevision；409 返回当前版本与可恢复选择。
- GET 不隐式创建无界搜索/浏览器任务；异步操作 202 返回任务与 statusUrl，限制轮询、总时长和重试。
- 分页返回 nextCursor / hasMore，游标与用户、查询、快照绑定；有界列表和内容响应不能省略截断状态。

统一错误：

```json
{
  "code": "DEPENDENCY_NOT_CONFIGURED",
  "message": "弹幕服务尚未配置",
  "retryable": false,
  "requestId": "req_example",
  "details": { "dependency": "dandanplay" }
}
```

网络不可达、配置缺失、没有候选、上游业务失败、额度限制、内容过期和映射冲突分别编码。服务器保留脱敏诊断，用户消息不包含 Secret、请求签名或原始上游带 token URL。

## 2. 启动能力

当前仅 TV + Hub。已实现 `GET /`、`POST /setup`、`POST /pair`、`GET /auth/bgm/captcha`、`POST /auth/bgm/login`、`POST /auth/bgm/unlink` 浏览器表单。owner 用 HttpOnly/SameSite 会话、CSRF/同源校验和一次性 setup nonce；本机登记或配置 HUB_SETUP_SECRET 后登记。网页登录不依赖 OAuth 应用密钥，密码/Cookie 不持久化。OAuth start/callback 尚未实现。

设备 JSON 接口已生成于 Server/openapi.json：`POST /v1/devices/pairings` 返回 id/code/secret/有效期；`GET /v1/devices/pairings/{id}` 和 `POST .../{id}/claim` 使用 `Authorization: Pairing <secret>`，领取一次性；`GET /v1/account`、`GET /v1/account/collections?offset=0` 使用设备 Bearer token，不返回上游 token。账号收藏只读，未实现写回。

`GET /v1/bootstrap` 的能力表示可用状态，不把“界面存在”当作服务可用：

```json
{
  "apiVersion": "1",
  "capabilities": {
    "bangumi": { "state": "notConfigured" },
    "tmdb": { "state": "notConfigured" },
    "danmaku": { "state": "notConfigured", "provider": "dandanplay" }
  }
}
```

依赖状态为 `ready / notConfigured / unavailable`，与单次加载状态分开。端点实现前该 JSON 只是契约样本，不是当前响应。

## 3. 播放与进度

播放会话按稳定 Bangumi 章节创建。所有变更验证 sessionId、generation 和设备权限；SourceEpisode 定位不含临时 CDN URL。返回写入 epoch、resumeRevision、原生轨道能力和当前播放入口，参见 [主方案 §5](../Doki-设计方案-v0.4.md#5-播放闭环)。

进度事件使用 eventId、sessionId、deviceSeq、writeEpoch、baseRevision、kind、positionSeconds、durationSeconds；服务器裁决 accepted/duplicate/conflict。客户端发生 seekCompleted 可以更新更小的位置，不能被“取最大值”合并掉。

映射/收藏/已看更新与 outbox 使用各自版本；未经确认的低置信度匹配不能直接播放。所有反复可重试动作都规定幂等键生命周期，不按整个账号永久去重。

## 4. 弹幕接口

| 方法 | 路径 | 输入/返回约束 |
|---|---|---|
| GET | `/v1/episodes/{id}/danmaku/mapping` | 返回 unbound/candidate/confirmed 和 revision；不默认触发上游搜索 |
| POST | `/v1/episodes/{id}/danmaku/searches` | 用户发起搜索；202 或复用结果，带 Idempotency-Key |
| GET | `/v1/danmaku/searches/{id}` | running/ready/failed，候选带作品与章节依据，不默认选择第一项 |
| PUT | `/v1/episodes/{id}/danmaku/mapping` | `danmakuEpisodeId, expectedRevision`；校验候选身份，保存人工确认来源 |
| POST | `/v1/playback/sessions/{id}/danmaku/loads` | 用当前章节/映射版本和 withRelated/chConvert 创建有界加载，202 或已就绪结果 |
| GET | `/v1/danmaku/loads/{id}` | 状态或规范化内容；带 contentRevision、映射/时间轴身份和截断标志 |
| PUT | `/v1/episodes/{id}/danmaku/timing` | `mediaId, offsetSeconds, expectedRevision`，校验归属和有限范围 |
| PATCH | `/v1/preferences/danmaku` | 设备偏好与 expectedRevision；本地可即时应用，服务端确认后同步 |

候选确认示例：

```json
{
  "danmakuEpisodeId": "123450001",
  "expectedRevision": 0
}
```

规范化内容示例，数值与文本均为自造数据：

```json
{
  "loadId": "dl_example",
  "status": "ready",
  "bgmEpisodeId": 1024,
  "danmakuEpisodeId": "123450001",
  "mappingRevision": 1,
  "contentRevision": "dc_example",
  "mediaId": "media_example",
  "offsetSeconds": 0.5,
  "truncated": false,
  "items": [
    {
      "id": "9223372036854775806",
      "timeSeconds": 12.34,
      "mode": "scroll",
      "colorRgb": 16777215,
      "text": "这是一条自造的测试弹幕"
    }
  ]
}
```

客户端 generation 属于当前本地播放器实例。响应回来时先检查 session/episode/mapping/media 身份，再插入时间索引；不同身份的旧结果可入缓存，但不能绘制。偏移正值表示晚显示。

Hub 对响应体解压前后大小、规范化条数和文本长度设上限；触发限制时返回可解释的 truncated/失败状态，而不是无声截断后报告全量成功。首版不要求跨窗口实时直播式弹幕增量推送。

## 5. 契约建立顺序

HUB-001 先落地错误、鉴权上下文、幂等和配置 schema；PLAY-001 落会话/资源；SYNC-001 落 revision 与事件；DAN-001 落弹幕 DTO。每次生成 OpenAPI 后用 fixture 核对 Swift 解码和未识别字段策略。

实际字段变更先改 schema，再更新本文/主方案和样本，不能为保持旧草案字面不变而让实现错误。生效的契约版本和迁移需要进入 [DECISIONS](../architecture/DECISIONS.md) 与交接记录。

## 6. 开发真实源预览与签名 relay（2026-10-30）

> 只在本机 `NODE_ENV != production` 注册。它不是 Bangumi 绑定的 `PlaybackSession`，没有 `bgmEpisodeId`、epoch、revision 或 outbox 语义；不得作为首版正式接口或生产源开关。真实源内容当前还有单独的内容安全阻断（见 CURRENT_STATE）。

### 6.1 `POST /v1/dev/source-preview`

请求：

```json
{
  "query": "示例标题",
  "episodeNumber": 1,
  "channel": "线路1"
}
```

`channel` 与 `episodeNumber` 可选；实现只启用固定的 `yinghua` provider，不接受任意 URL。响应为短期 Hub relay 计划，`source.url` 是 Hub 签名地址，不是上游 URL：

```json
{
  "sessionId": "ps_example",
  "status": "ready",
  "provider": { "id": "yinghua", "name": "樱花动漫" },
  "subject": { "name": "示例标题", "sourceSubjectKey": "yinghua:subject:example" },
  "episode": {
    "number": 1,
    "title": "第1集",
    "channel": "线路1",
    "mediaId": "yinghua:subject:example:channel:0:episode:1:example"
  },
  "source": {
    "mode": "relay",
    "url": "https://hub.example.com/s/ps_example/resource_example?exp=1893456000&sig=example-only",
    "expiresAt": "2026-10-30T12:00:00.000Z"
  },
  "tracks": { "subtitleLanguages": [], "hasAlternateAudio": false },
  "capabilities": { "canSeek": true, "canAutoFailover": false },
  "durationHintSeconds": 1440,
  "provenance": {
    "ruleCommit": "d2f58217e6614c2e279d6f461e278d665c2b234b",
    "snapshotSha256": "7e54969e4d8de3535242927af3c27e09a8e8d47f65ab9649a84a2163c975535c",
    "verifiedAt": "2026-10-30T10:00:00.000Z"
  }
}
```

错误沿用统一错误体：无匹配条目/章节 404，规则或媒体地址不支持 422，出站阻断或上游失败 502；不把上游带签名 URL、Cookie 或凭据写入日志/响应。

### 6.2 `GET|HEAD /s/{sessionId}/{resourceId}`

- `exp` 为 Unix 秒，`sig` 为 `HMAC-SHA256(sessionId:resourceId:exp:method)` 的 base64url；不匹配/过期返回 403，未知资源 404。
- master/media playlist 返回 `application/vnd.apple.mpegurl` 并重写子资源 URI；分片支持 Range/HEAD、206 与 `Content-Range`。
- 资源只能由已创建 session 注册，客户端不能传任意上游 URL；当前 session 在内存，TTL 2 小时，重启即失效。
- Hub 的 SafeFetcher 对每次请求/重定向重新检查 scheme、端口、凭据、DNS/IP 和跨域敏感头；本机 198.18/15 透明代理只能通过本地 `OUTBOUND_ALLOW_BENCHMARK_NETWORK=1` 放行，生产禁止。
- 真实请求证据：preview 200（约 4.94s）；master/variant/segment 200/200/206；坏签名 403；见 CURRENT_STATE/WORK_LOG。该技术链路通过不解除真实源内容安全阻断。

`Server/openapi.json` 已生成并登记 `/v1/dev/source-preview` 与 `/s/{sessionId}/{resourceId}`，标签为 `development`；正式播放、进度和弹幕路由仍只有 schema，没有可调用路径。

## 8. REWORK-001 已实现的匿名目录接口

以下接口已实现并本地真实 HTTP 探测；不依赖账号，不授予用户状态或源执行权限：

| 方法 | 路径 | 返回 |
|---|---|---|
| GET | `/v1/home` | `calendar, picks, updatedAt`；更新时间是 Hub 响应时间，不冒充上游更新时间 |
| GET | `/v1/calendar` | Bangumi 周放送计划，星期 1～7 为周一～周日 |
| GET | `/v1/subjects/{id}` | 公开条目资料 |
| GET | `/v1/subjects/{id}/episodes?offset=0` | `total, data, limit, offset`；100/页，type=0 |
| GET | `/v1/subjects/{id}/characters` | 角色与声优记录 |
| GET | `/v1/subjects/{id}/persons` | 制作人员与职务记录，可有同人员多个职务 |
| POST | `/v1/search` | 输入 `keyword, offset`；24/页动画搜索，排除 nsfw |
| GET | `/v1/subjects/{id}/artwork` | `state, candidates, selected`；TMDB 未配返回 `notConfigured` |
| GET | `/v1/artwork/tmdb/{filename}` | 固定官方图片 origin 的有界横幅代理，不接收任意 URL 或客户端 Authorization |

目录内容作为 Bangumi 公共字段的受校验透传，**这一小组是 camelCase 规则的显式例外**：保留 `name_cn / total_episodes / air_date` 等上游拼写，以便匿名直读与 Hub 模式使用同一平台中立 decoder。图像字段允许实际观察到的 null；有值时仍由客户端批准图片 origin。`artwork` 则是 Doki 自己的 camelCase DTO，movie 与 TV ID 必须携带 `mediaType` 区分。

只有标题/年份匹配且候选唯一时才给自动 `selected`；未知/多义候选需 TV 手动选择。手选绑定暂存本机，不能当作正式 revision 化 Hub 映射。TMDB 凭据只送固定官方 API origin，图片不带 Bearer，API 不允许重定向。上游失败/畸形返回可重试 502；搜索输入校验为 400。缓存上限 256 条，公开目录调用有每 IP 速率限制。

`bootstrap.capabilities.bangumi` 保持原有账号能力语义，不能用它否定匿名读取；TMDB 静态配置状态也不等于成功取图，应读取 artwork 的单次状态。生产身份/写接口依然未实现，不能把这些只读接口看成已完成 AUTH/META 全部任务。
