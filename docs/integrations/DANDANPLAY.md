# 弹弹play弹幕接入设计

> 首版功能：观看弹幕、匹配修正和显示设置，当前仅覆盖 Apple TV / tvOS，其他客户端后置。发送弹幕后置。
> 查阅日期：2026-10-29。已核对官方指南和 Swagger，尚未获得 Doki 凭据、调用受应用鉴权保护的接口或真实渲染弹幕。

## 1. 已确认的接入事实

使用[弹弹play开放弹幕网络](https://doc.dandanplay.com/open/)，在[开发者中心](https://dev.dandanplay.com/)申请 Doki 自己的 AppId/AppSecret。官方允许服务端保存秘密并转发客户端请求；应用认证与用户登录是不同概念。存在应用层级/额度管理，不能理解为无限调用；按需请求、缓存，并在 README/关于页标明服务来源。[指南](https://doc.dandanplay.com/open/)、[变动日志](https://doc.dandanplay.com/open/changelog.html)。

Hub 采用签名模式，按官方定义构造：

```text
X-AppId: 应用编号
X-Timestamp: UTC Unix 秒
X-Signature: Base64(SHA256(UTF8(AppId + Timestamp + Path + AppSecret)))
```

Path 不包含域名或 query，Base64 编码 SHA256 的二进制结果；这不是 HMAC 或十六进制摘要。Secret 不进入 App 包和日志。应用未配置时准确返回 notConfigured，不伪装成空弹幕。

## 2. 上游协议与匹配

本次核对的[官方 Swagger](https://api.dandanplay.net/swagger/v2/swagger.json)包括：

| 接口 | Doki 使用方式 |
|---|---|
| `GET /api/v2/bangumi/bgmtv/{bgmtvSubjectId}` | 先用 Bangumi 条目找弹幕作品；上游人工映射可能缺失/错误，仍需章节校验 |
| `GET /api/v2/search/episodes` | 条目映射失败后用标题/集号或 TMDB ID 寻找候选，留手动确认 |
| `GET /api/v2/comment/{episodeId}` | 取得弹幕；处理 302 到加速服务、withRelated、简繁参数和实际响应 |

评论数据使用 `cid`、`p`、`m`；`p` 的四段是出现秒数、模式、颜色、用户标识。首版支持模式 1 滚动、4 底部、5 顶部，未知模式跳过。弹幕库编号和 cid 为 int64，内部 API 用十进制字符串表达。[Swagger](https://api.dandanplay.net/swagger/v2/swagger.json)。

上游 `bangumi` 路径不意味着 Bangumi API；所有字段使用明确的 `bgmEpisodeId`、`danmakuEpisodeId` 名称。在线 HLS 不天然具有完整文件 Hash，不用 m3u8 文本或第一分片伪造文件匹配。

## 3. Doki 数据流

```text
播放会话 / Bangumi 章节
  → Hub 查已确认 episode_danmaku_mapping
  → 没有映射：Bangumi 条目映射 + 章节候选校验
  → 仍有歧义：标题/TMDB 搜索 + 用户手动确认
  → 用户开启弹幕时按需获取 / 命中缓存
  → Hub 验签、受控重定向、校验/规范化
  → 客户端按 AVPlayer 媒体时间调度与渲染
```

弹幕是播放旁路。视频起播不等待匹配或弹幕取数；没有正确映射时显示待选择，不自动把第一条候选画在视频上。

### 3.1 持久状态

| 实体 | 必要字段与约束 |
|---|---|
| episode_danmaku_mapping | userId、bgmEpisodeId、danmakuEpisodeId、来源、verified、revision；人工修正优先 |
| danmaku_timing | userId、bgmEpisodeId、mediaId/剪辑版本、offsetSeconds、revision；不同源不共享未经验证的偏移 |
| danmaku_preferences | 用户/设备、enabled、density、fontScale、opacity、area、modes；服务端存偏好，本地即时生效 |
| danmaku_cache | 弹幕库 ID、withRelated、简繁参数、内容版本、抓取时间和有效期；不保存上游鉴权头 |

TMDB season 或 Bangumi sort 不能直接当作弹幕库 ID。特别篇、总集篇、跨季等沿用显式映射规则；改弹幕映射不改变视频章节和已看记录。

### 3.2 请求与缓存策略（Doki 初始值）

- 仅在用户开启或明确预览该集弹幕时请求；关闭时不遍历整季获取。
- 同键请求合并；当季热门初始 TTL 1h、普通条目 6h、完结旧作 24h，按真实配额和更新规律调整。
- 获取失败可使用已缓存且明确标注的版本，后台复验；不能因暂时错误清空已有弹幕。
- 解析前限制响应体、条数、文本长度与时间范围；规范化后按时间/cid 排序并去重。
- 请求前检查 HTTP 与业务成功字段，区分 401/403、额度、429、timeout 和空库，不对永久鉴权错误无限重试。
- 302 只跟随已批准的官方加速域名，限制跳数；不向不同 origin 盲目转发 AppSecret/Authorization/签名头。
- Hub 面向已配对设备提供有限用途 API，不暴露任意 URL 代理或批量数据库下载功能。

## 4. 客户端渲染架构（Doki 决策）

新增 `DokiDanmaku` 包。模型、文本过滤与时间索引可共享；当前只实现 tvOS UIKit 绘制宿主，不实现 AppKit/iPhone 专属适配。调度不为每条弹幕创建长期 SwiftUI timer，不在每帧刷新整页 View。

建议实现：时间索引 + 有界轨道调度 + 复用文本图层/纹理 + 平台绘制宿主。先用可测的轻量 CALayer/绘制方案验证，实测瓶颈再考虑更复杂渲染器，不预先承诺 Metal 或引用不明许可证引擎。

### 4.1 时间轴定义

以 AVPlayer 的实际媒体时间为唯一播放时钟，墙钟只用于帧节奏。时间偏移定义为：

```text
videoDisplayTime = commentTime + offsetSeconds
正偏移：弹幕更晚出现。
查当前应显示弹幕时：commentTime = playerTime - offsetSeconds。
```

- 暂停时所有弹幕冻结；继续时从当前媒体时间恢复，不按暂停经过的墙钟补跑。
- 倍速改变时与媒体时间一致，不将 elapsed wall time 当作视频进度。
- seek、切集、切映射先提升 generation、清空在屏轨道、二分定位新的时间窗口；旧请求返回不能重新绘制。
- 切源后重新读取该 mediaId 的偏移；时间轴不兼容时提示调整，不自动继承上一源偏移。
- 从后台或系统播放器模式恢复时重新定位，不能把离开期间的弹幕全部一次性发射。

### 4.2 可读性与边界

- 渲染区域跟随实际视频可见矩形，扣除黑边、原生控件和字幕保留区；旋转、窗口缩放与视频比例改变时重新排轨。
- 初始默认上部约三分之一、适中密度、可调字号和透明度；轨道数/在屏数量有上限，超载按确定性采样降密度。
- 默认不碰撞追尾；顶部/底部固定弹幕有独立轨道和展示时长。用户禁用的模式不占轨道。
- 弹幕是纯文本，不执行 HTML/脚本；不显示不可控超长文本，也不向日志输出用户弹幕正文。
- 原生 VTT 字幕继续由播放器负责，弹幕不能挤占字幕轨道或把字幕转换为弹幕。
- 开关、密度、字号、透明度、区域和时间偏移通过平台原生设置面板操作，避免大面积玻璃覆盖视频。

### 4.3 PiP / AirPlay

首版自绘弹幕只在 Doki 的正常播放宿主显示。PiP 或远端 AirPlay 不承诺携带弹幕，仍保留视频与支持的原生字幕；回到 App 后重新按媒体时钟定位。不为弹幕引入视频烧录或重编码。

这是一项明确能力边界，不影响“首版含观看弹幕”的交付要求。界面只在相关模式中说明，普通播放不反复提示限制。

## 5. 内部接口草案

规范及示例位于 [API_CONTRACTS](../development/API_CONTRACTS.md)，路由计划为：

- `GET /v1/episodes/{id}/danmaku/mapping`：获取映射状态，读取不触发无界搜索。
- `POST /v1/episodes/{id}/danmaku/searches`、`GET /v1/danmaku/searches/{id}`：用户发起候选搜索，任务有界且可复用。
- `PUT /v1/episodes/{id}/danmaku/mapping`：带 expectedRevision 保存选择。
- `POST /v1/playback/sessions/{id}/danmaku/loads`、`GET /v1/danmaku/loads/{id}`：按需取数/缓存，返回规范化数据或受控内容资源。
- `PUT /v1/episodes/{id}/danmaku/timing`：按 mediaId 保存时间偏移；设置型写入幂等。
- `PATCH /v1/preferences/danmaku`：显示偏好，版本化更新。

用户首次开启时允许先显示“正在准备弹幕”，视频继续播放；配置未完成或候选错误时入口能恢复操作。

## 6. 验收与凭据准备

先用自造 fixture 完成渲染：0s/长集、密集文本、滚动/顶/底、未知模式、非法 p、超大 ID、重复 cid、极端文本、倒序数据。随后用 Doki 自己的应用凭据验证真实请求和 TV 播放。

必测：签名固定向量、query 不参与签名、302 与跨域头处理、配额/业务错误、Bangumi 映射缺失、手动修正、暂停/seek/倍速/切源/切集/后台恢复、字幕保留、PiP/AirPlay 降级、无凭据状态。

配置项为 `DANDANPLAY_APP_ID`、`DANDANPLAY_APP_SECRET`，见根目录 [.env.example](../../.env.example)。凭据未配置时相关真实接口验收保持待验证；文档和 fixture 开发可以继续，不借用其他项目凭据。

## 7. 官方参考与证据边界

- [官网](https://www.dandanplay.com/)：服务身份与对外署名。
- [开放网络指南](https://doc.dandanplay.com/open/)：应用认证、调用约定和缓存。
- [Swagger JSON](https://api.dandanplay.net/swagger/v2/swagger.json)：当次请求字段、响应与精度。
- [变动日志](https://doc.dandanplay.com/open/changelog.html)：额度机制与接口更新。

本方案使用只读弹幕能力；发送、账号体系和收费商业使用不自动进入范围。以后扩展前单独核对当时权限和额度。当前没有真实 API 请求成功、实播或性能达标证据。

## 8. 当前实现状态（2026-10-30）

DAN-002 的 TV 自造 fixture 渲染已在模拟器落地：`DokiDanmaku` 提供时间索引/确定性密度采样/偏移语义，tvOS 宿主用 `CADisplayLink` 读取 AVPlayer 媒体时间，暂停冻结、seek 后重新定位；播放器设置使用 tvOS 原生 Toggle/Picker/自定义 ChoiceChip（tvOS 没有 SwiftUI Slider），支持开关、密度、字号、透明度、区域、模式和时间偏移。fixture 明确标注自造，不冒充弹弹play数据。

仍未完成：DAN-001 真实签名/302/额度/候选映射、DAN-003 真实取数与 TV 录屏、真实 int64 fixture、字幕避让的真机验证，以及 PiP/AirPlay 边界测试。本轮没有 Doki AppId/AppSecret，真实接口状态保持未验证；真实源视频画面因内容安全原因未保留。真实渲染能力不能由本轮 fixture 截图替代验收。
