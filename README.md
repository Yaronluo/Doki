# Doki

Apple 原生追番项目，**首版只做 Apple TV / tvOS 与必要的家庭 Doki Hub**。iPhone、Mac 客户端留待后续，不属于当前开发和验收范围；Mac 只作为开发主机。

当前已有一个可构建/启动的 tvOS 原型、Hub 骨架、自造 fixture、真实在线源 adapter 与签名 HLS relay。完整状态、证据和限制以 [docs/handoff/CURRENT_STATE.md](docs/handoff/CURRENT_STATE.md) 为准；不要把模拟器画面、build 或单源技术验证当作真机验收或可部署版本。

**Doki 独立设计 Apple 原生界面与克制的系统材质。** izuko-tv/Animeko 只作机制参考；当前按 tvOS 的收起式侧栏、焦点、遥控器和播放器独立设计。在线源优先适配 MajoSissi/animeko-source 的 online.json。

TV 首版包含弹幕观看、匹配修正与显示设置，使用[弹弹play开放弹幕网络](https://www.dandanplay.com/)。当前只有自造弹幕 fixture，真实凭据与电视渲染尚未联调；弹幕失败不阻塞视频。

## 当前入口

- [DeepSeek 开发提示词](docs/handoff/DEEPSEEK_TV_PROMPT.md)
- [开发约束 AGENTS.md](AGENTS.md)
- [文档目录与阅读顺序](docs/README.md)
- [当前状态与下一步](docs/handoff/CURRENT_STATE.md)
- [实施方案 v0.4](docs/Doki-设计方案-v0.4.md)
- [Apple 原生设计规范](docs/design/APPLE_NATIVE_UI.md)
- [弹弹play接入设计](docs/integrations/DANDANPLAY.md)
- [开发任务](docs/development/ROADMAP.md)、[环境/命令](docs/development/SETUP.md)与[交接指南](docs/handoff/HANDOFF.md)

## 可直接运行的检查

```sh
# 文档结构检查（不证明编译/接口/播放）
python3 scripts/check-docs.py

# 生成并构建 tvOS 工程（scheme: DokiTV）
xcodegen generate --spec project.yml
xcodebuild -project Doki.xcodeproj -scheme DokiTV -configuration Debug \
  -destination 'generic/platform=tvOS Simulator' \
  -derivedDataPath .local/DerivedData/APP-001 \
  build CODE_SIGNING_ALLOWED=NO

# Hub
cd Server
pnpm install --frozen-lockfile
pnpm typecheck
pnpm test
```

## 内容安全与凭据

真实源开发预览目前只验证了一条 online.json 规则。2026-10-30 的本地实播发现该源视频流含第三方赌博广告，因此**不得默认启用、公开部署或作为内容交付**；详见 CURRENT_STATE。含该源画面/原始媒体的证据未保留。

Bangumi/TMDB/弹弹play 真实凭据均未配置，不得借用参考项目凭据。秘密键名见 [.env.example](.env.example)，真实值保留在本地配置。源码实现、真实 API、tvOS 模拟器播放与真机验收状态分别记录。
