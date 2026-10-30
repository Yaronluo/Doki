# Doki 开发约束

适用范围：整个仓库。用户最新指示优先；不要用历史方案覆盖用户的新要求。

## 开始前阅读

1. `docs/README.md`：文档入口和权威边界。
2. `docs/handoff/CURRENT_STATE.md`：当前真实状态、未验证项和下一步。
3. `docs/Doki-设计方案-v0.4.md`：当前架构与范围。
4. 修改 UI 前读 `docs/design/APPLE_NATIVE_UI.md`；修改弹幕前读 `docs/integrations/DANDANPLAY.md`。
5. 按 `docs/development/ROADMAP.md` 的任务依赖推进；接口、环境、验收分别见同目录的文档。

## 已确定的产品边界

- **当前首版仅做 Apple TV / tvOS + 必要的 Doki Hub。** iPhone、Mac 客户端全部后置，不创建其 target、页面、平台适配或测试门槛。Mac 可以作为开发主机；平台中立模型/协议可保留扩展能力，但不为未来端过度抽象。
- Apple 原生体验为设计基准：当前采用左上角头像与可收起的透色磨砂侧栏，保留 tvOS 原生焦点、搜索和 AVKit 及自己的信息层级，不把 iPhone 底部栏或 Android TV 页面照搬到电视。
- 2026-10-30 用户最新三图纠正：普通背景为蓝灰色和彩色晕染磨砂，不能压成近黑；导航为通透大圆角侧栏与白色胶囊选中条，普通操作继续平面控件。磨砂限于导航面板和普通页面背景，打开菜单不得模糊/遮挡右侧横幅、文字或海报。自绘按钮不得再套 tvOS `.plain` 系统焦点底板，避免重复胶囊、放大遮字。保留系统播放器/输入/面板的原生行为，不以模糊或渐变冒充材质。
- izuko-tv/Animeko 只作问题解决与交互机制的参考，不以相似度、原样页面、Android 尺寸或原动画时序为验收目标；独立设计 Doki 的信息层级与动效。
- 在线源优先适配 MajoSissi/animeko-source 的 `dist/online.json`；规则格式可读取与真实可播放分别记录。先验证 1～2 个源，不批量启用未知源。
- 弹幕纳入 TV 首版，使用弹弹play开放弹幕网络。首版支持观看、匹配修正、开关、密度/字号/透明度和时间偏移；发送功能后置。电视配对/Bangumi 授权用 Hub 的轻量网页和普通手机/电脑浏览器完成，不依赖另一个 Doki 客户端。
- 首版不做 BT/PT、磁力、做种、视频重编码或 ASS 烧录。Bangumi 为条目/章节基准，TMDB 为可失败的图片增强；IMDb 不直接接入。

## 工程与变更要求

- 当前已有 tvOS 原型和 Hub 骨架；不要把目录规划、接口草案、示例环境变量、fixture 或模拟器画面描述为已经部署、真机验收或完整集成。
- 用 XcodeGen 管理工程；先改 `project.yml` 再生成，不手工修改生成的 pbxproj。当前已存在 `project.yml` 与生成的 `Doki.xcodeproj`。
- 业务包不得依赖 SwiftUI 页面实现。平台桥接集中于适配层，网络/解析/同步不写在 View 内；用严格并发检查避免非隔离共享可变状态。
- API 用 TypeScript/Zod 定义并生成 OpenAPI；生成器建立前以 `docs/development/API_CONTRACTS.md` 为草案，不能宣称可调用。
- 数据库 schema 通过迁移管理。稳定章节 ID、外部映射、播放会话、同步 revision 和弹幕时间轴必须分开。
- 主动回看可降低续播位置；旧 epoch、旧异步任务、过期 outbox 不得覆盖新状态。手动已看/未看意图优先。
- 保留已成功展示的图片/内容直到替换成功，后台刷新不清空 UI；图片清理与进度事件分开，缓存修改限定范围。
- 修改依赖或协议前核对官方文档和实际版本；不得将上游首页或规则备注当作运行证据。

## 播放与弹幕

- 使用 AVPlayer/AVKit 公开能力和原生字幕；不能使用私有 header key 或把 Hub 上游 Cookie 发到客户端。
- `SourceEpisode`、临时 `ResolvedAsset`、`PlaybackSession` 分层；切源只有时间轴已验证时才自动继承秒数。
- 弹幕不是字幕。Hub 取数/鉴权/缓存，客户端用媒体时钟渲染；seek、倍速、暂停、切源、切集需正确清理和重建。
- PiP/AirPlay 保留原生视频/字幕路径；自绘弹幕不跟随时明确提供无弹幕播放，不承诺烧录效果。
- 弹幕不可用不阻止视频起播。未获弹弹play凭据时用明确标注的自造 fixture 开发，实际集成状态保持待验证，不移除首版要求。
- 弹幕库与弹幕 ID 在 Hub JSON 中使用十进制字符串，避免 JavaScript int64 精度损失；不要混用 Bangumi episodeId。

## 凭据与访问边界

- Bangumi Client Secret、TMDB token、弹弹play AppSecret、设备 token 和签名密钥只放本地秘密配置/密钥存储；不得放源码、截图、日志、交接文档或真实 fixture。
- 不要求用户将密码/密钥直接贴进聊天。配置模板只列空值和示例地址，不能冒用参考项目 AppId/AppSecret。
- Hub API 对 LAN/VPN 开放；provider 的浏览器、媒体和图片请求都受出站政策约束，重定向和 DNS 解析后复验，阻止私网访问与跨域凭据泄漏。
- 参考仓库代码、规则、字体/图标和图片的来源与许可证分别记录；公开再分发前核对，不能假设聚合库一个许可证覆盖全部条目。
- Git commit/push、PR 发布、外部发信、公开部署不由普通实现请求自动授权；已有明确授权按原范围执行。无需为正常可逆开发反复请求确认。

## 验证与交接

- 每个任务按验收条件完成，使用 `not_started / in_progress / implemented_unverified / verified / blocked` 描述真实状态；文档完成不将功能任务标为 verified。
- 有意义的领域测试优先覆盖同步并发、协议解析、时间轴和失败恢复；不要只为凑覆盖率镜像实现。当前只构建/验证 tvOS；如有并行构建使用独立 DerivedData，避免数据库锁冲突。
- 当前 UI 只验收 tvOS：浅/深色、远距离可读性、焦点/遥控器、减少动态效果/透明度和失败状态；iPhone/Mac 不作为关闭任务的条件。截图证明画面，录屏证明动效；build 成功不证明实播。
- 外部接口回放、真实 API 调用、模拟器播放、真机完整播放分开报告，附时间、设备/系统、网络、命令和结果；日志必须脱敏。
- 每个开发批次结束更新 `docs/handoff/CURRENT_STATE.md` 和 `docs/handoff/WORK_LOG.md`；架构取舍变动追加到 `docs/architecture/DECISIONS.md`，同步受影响的接口、设计和验收。
- 当前文档检查：`python3 scripts/check-docs.py`。该检查不验证编译、真实接口或播放。
- 不引入新的过期平行方案；v0.2/v0.3 是历史，v0.4 的 TV 首发修订是当前基线；引用到的 iPhone/Mac 规划只作后续参考。工作未完成时交接清楚下一步，不虚报完成。
