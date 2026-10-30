# DeepSeek 执行提示词：Doki TV 首版

适用于能读写 `/Users/yaron/Doki` 并执行开发工具的编码环境。复制下方整段；如果使用不具备本地文件访问的环境，应同时提供当前交接资料，不要假设模型看得到路径内容。

```text
你是 Doki 项目的实现工程师。请直接在 /Users/yaron/Doki 工作，先检查当前仓库，再根据实际状态持续实现；不要只输出方案或重新评审需求。

一、最新范围（优先于任何历史三端要求）
1. 首版只开发 Apple TV / tvOS 客户端和必要的 Doki Hub。
2. iPhone、Mac 客户端全部后置：不创建 target、页面、播放器适配层或测试门槛。Mac 可以作为 Xcode 开发主机；普通手机/电脑浏览器可以辅助 Hub 设置与授权。
3. 保留平台中立模型和接口的自然扩展能力，不为未来客户端建设额外框架。
4. 原生 Apple/tvOS 风格与真实 Liquid Glass 是要求。用户喜欢 izuko-tv 的体验，但明确只参考机制、不要照搬页面、尺寸和动画时序；Doki 要有自己的信息层级与交互。
5. 弹弹play弹幕仍在 TV 首版范围，不能因缩小平台而删去。

二、先读这些文件
- AGENTS.md
- docs/README.md
- docs/handoff/CURRENT_STATE.md
- docs/handoff/HANDOFF.md
- docs/development/ROADMAP.md
- docs/design/APPLE_NATIVE_UI.md
- docs/Doki-设计方案-v0.4.md（优先看当前范围、架构、播放、授权、同步和任务章节）
- 按任务继续读 docs/development/API_CONTRACTS.md、SETUP.md、ACCEPTANCE.md 和 docs/integrations/DANDANPLAY.md。
v0.2/v0.3 是历史，不作为实现要求。当前描述可能尚无工程；以实际文件为准，不把规划目录、路由或已通过文档检查当作已有实现。

三、TV 产品与设计
- 首版页面：发现、追番、日历、搜索、我的/设置、详情/选集、播放器，以及源和弹幕设置。
- 发现按“继续观看 → 今日放送/确认可播更新 → 本季精选”组织；计划放送与实际资源更新分开。
- 使用 tvOS 原生 TabView 标签导航、系统搜索、焦点、遥控器交互和 AVPlayerViewController。不要照搬 iPhone 底部栏或 Android 左图标栏。
- 系统组件优先使用其原生材质；必要自定义操作层用公开 glassEffect/glass 按钮。海报、章节和正文不全部玻璃化，不用 blur/渐变图假装 Liquid Glass，不叠加重复焦点放大。
- 自己设计内容比例、间距和动效；输入立即反馈、导航可取消、旧图保持到新图成功，返回恢复原焦点和滚动位置。不能等背景图或服务端请求完成才允许进入详情。
- 所有日常浏览、选集、换源、弹幕设置和失败重试可用遥控器完成。浅/深色、减少动态效果/透明度、缺图与长标题都要可用。

四、数据、Hub 与授权
- Bangumi 管条目/章节/收藏/已看；TMDB 只做可失败的图片增强，支持 TV/movie，缺图不阻塞浏览；不直接接 IMDb。
- 在线规则优先来自 https://github.com/MajoSissi/animeko-source 的 dist/online.json。只读在线集合，先验证 1～2 个源，不接 all.json/bt.json、磁力、BT 或做种。
- 核对规则实际结构和执行语义，处理选择器、正则、线路/集号、请求节流、嵌套页面、Referer/Cookie/UA；规则导入成功不等于可播。
- Hub 保管上游秘密，执行解析与 relay；客户端只拿安全的资源/播放计划。稳定资源、短期地址、播放会话分层，过期可复验。
- TV 无 WebKit，不在电视上执行网页 JS。需要浏览器解析时在受控 Worker 执行，所有子资源/重定向/媒体请求都受出站策略约束。
- 首版配对与 Bangumi OAuth 由 Hub 轻量网页和普通浏览器辅助，不依赖 Doki 手机 App。首次 owner 使用服务器本地一次性 setup secret；配对短码不能独立授予权限，TV 持秘密领取 token。
- 不把 Client Secret、AppSecret、Cookie、长期设备 token 放 App 源码、日志、截图或交接文件，不借用其他项目凭据。缺凭据时准确返回 notConfigured，不伪装无数据或成功。

五、播放、续播和弹幕
- 使用 AVPlayer/AVKit 公开能力与原生字幕，direct/relay 按实际依赖判断，不能认为服务端探测成功就保证客户端 direct。
- 完成起播、首/中/尾 seek、暂停/恢复、退出重开续播和错误恢复。remux 不改变 codec；首版不建设视频转码或 ASS 烧录。
- 续播按有效会话 epoch、事件序号和 revision 更新；主动回看允许位置变小。旧事件、旧回调和旧 outbox 不覆盖新意图；手动已看/未看优先。
- 弹幕使用弹弹play开放弹幕网络，由 Hub 使用 Doki 自己的 AppId/AppSecret 鉴权、匹配和缓存，TV 按 AVPlayer 媒体时间渲染。
- 支持滚动/顶部/底部、开关、密度、字号、透明度、区域和时间偏移；匹配错误可手动修正。发送弹幕后置。
- 核对 int64 ID 的字符串表达、签名、302、额度和业务错误。Bangumi 章节、源站资源和弹幕库三种 ID 分开，偏移按资源剪辑保存。
- pause/seek/倍速/切集/切源/后台恢复后重新定位，限制轨道和在屏数量，避让字幕和控件。弹幕失败不阻塞视频。
- 自绘弹幕不承诺进入 PiP/AirPlay；保留系统视频/原生字幕路径，不为此引入烧录。

六、实现顺序与第一批交付
先用不超过 10 行说明当前状态和本批目标，然后立即执行。
1. ENV-001：检查现有 Xcode、tvOS SDK、XcodeGen、模拟器及 Hub 工具；记录实际结果，不假设设备/账号已准备好。
2. APP-001：创建 project.yml、单个 tvOS app target 和必要包，最低 tvOS 暂定 26。改 project.yml 后生成工程，不手改 pbxproj；记录真实 scheme 和构建命令。
3. UI-001：用明确标注的自造数据，实现可运行的 TV 导航、发现/追番/详情/选集/播放器壳，再补日历/搜索/设置。按钮要有实际导航或可解释动作，不能只有静态占位。
4. HUB-001：建立 TypeScript API/Worker、配置 schema、必要迁移与 health/readiness、错误/requestId、契约样本。依赖版本实际核对并锁定；不预先拆微服务。
5. SRC-001 → PLAY-001：实现一个在线源的正确映射、解析、relay 与 TV 实播闭环。
6. AUTH-001/SYNC-001/META-001：Hub 网页授权、TV 续播、Bangumi 写回、个人浏览与 TMDB 增强。
7. DAN-001/002/003：先协议和渲染 fixture，再用自有凭据真实接通 TV 弹幕。
8. SRC-002/OPS-001/QA-001：第二源恢复、备份/部署、TV 综合验收。
按依赖持续推进，不停在“工程骨架已创建”或“计划已写好”；也不要为一次完成全功能而省略中间构建和证据。

七、验证与交接
- 先确认实际 scheme/destination，再执行 tvOS 构建、安装、启动和遥控器交互检查；不要伪造尚未存在的命令输出。
- 缺真机时继续模拟器/领域测试，并保持真机验收未完成。缺 API 凭据时先做自造 fixture、界面和协议实现，准确记录真实联调未完成。
- 文档检查、fixture、build、真实 API、模拟器播放和真机完整集播放分别报告；截图证明画面，录屏证明动效，不能相互替代。
- 依任务验收处理真实问题，不用大量镜像实现的测试代替验证，不降低检查来掩盖失败。
- 每批更新 CURRENT_STATE.md 和 WORK_LOG.md；架构/设计变化同步 DECISIONS.md、契约与验收。记录任务 ID、改动、实际命令、设备/网络、证据、限制、下一步。
- 运行 python3 scripts/check-docs.py。不要自行 commit/push、公开部署或对外发消息。
- 最终报告写清本批实现、验证结果、尚未完成项和可直接接续的下一任务。不要将本提示词再改写一遍作为交付。

现在开始读取仓库并实现 TV 首版。
```
