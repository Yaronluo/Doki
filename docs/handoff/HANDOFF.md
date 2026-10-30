# 开发交接指南

## 1. 用十分钟接上项目

1. 读根目录 [AGENTS](../../AGENTS.md)，知道 TV 首发、原生 Liquid Glass、引用边界、弹幕和验证要求。
2. 读 [CURRENT_STATE](CURRENT_STATE.md)，区分已有文档与不存在的实现。
3. 读 [v0.4](../Doki-设计方案-v0.4.md) 的产品决策/范围/架构，以及与你当前任务相关的章节。
4. UI 任务读 [APPLE_NATIVE_UI](../design/APPLE_NATIVE_UI.md)；弹幕任务读 [DANDANPLAY](../integrations/DANDANPLAY.md)；源任务读[参考与接入记录](../参考实现与数据源接入.md)。
5. 按 [ROADMAP](../development/ROADMAP.md) 选实际未完成任务，核对 [API_CONTRACTS](../development/API_CONTRACTS.md) / [SETUP](../development/SETUP.md) / [ACCEPTANCE](../development/ACCEPTANCE.md)。

不需要先遍历历史方案或复制上游仓库。v0.2/v0.3 保留背景，但当前需求不从它们恢复。

## 2. 关键上下文

用户喜欢 izuko-tv 的界面与动画，但明确要求**参考而不是照搬**，要有独立想法，适合 iOS，有真实 Liquid Glass 和 Apple 原生样式。Doki 的主线是继续观看、今日更新和个人追番记录。当前用户已收敛为仅 TV/tvOS + 必要 Hub，iPhone/Mac 客户端后置。

在线源候选来自 MajoSissi/animeko-source 的 online.json；不接 BT。Bangumi 管条目/章节/收藏，TMDB 增强图片，弹弹play提供弹幕。Hub 统一解析和保管秘密，客户端负责交互、播放、检查点和弹幕绘制。

用户要求完整交接资料，以便下一位开发者继续；文档仍应与真实状态分开。当前已有可运行原型，但不要把局部模拟器证据或单源技术验证当作完整程序/真机验收。

## 3. 不要重新踩的坑

- 参考库的图形布局、动画毫秒值不是 Doki 的必选样式；不要照搬 Android TV，也不要机械套用 iPhone 底部栏；当前不实施其他客户端。
- 导入 online.json 不等于源可播；63 条是配置数量，不是通过验收的数量。
- 按最大 position 合并会破坏回看；旧会话/旧任务不能覆盖新状态。
- remux 不修复不支持的 codec；自绘弹幕不天然跟随 PiP/AirPlay，也不能替代原生字幕。
- 弹弹play“无需用户登录”不表示不需要 AppId/AppSecret；ID 为 int64，302 不能丢失或泄漏上下文。
- 旧文件中“不做弹幕”“主要复现 izuko-tv”等定位已失效；以 v0.4 为准。
- 构建、截图、fixture、真实接口和完整真机实播是不同证据，不混报。

## 4. 当前批次可交接结果

第一批已经执行：单个 tvOS 工程、完整页面/播放器壳、Hub 骨架、真实源 adapter/relay 与模拟器实播都有本地证据；但 Apple TV 真机、正式账号/同步、真实弹幕、部署和内容安全仍未完成。实时状态、证据和限制只看 [CURRENT_STATE](CURRENT_STATE.md)。

下一批先处理可接受授权的在线源、真机 PLAY-001 和 AUTH-001；不要默认启用当前含第三方赌博广告的真实源。

若 TV 无法构建或真机不可用，写出具体命令、错误和所需输入，继续其他独立任务；只用模拟器验证不能报告真机完成，也不因此增加其他客户端。真实播放和弹幕验收保持明确未完成。

## 5. 每批结束要更新

| 文件 | 更新内容 |
|---|---|
| CURRENT_STATE | 任务状态、当前版本、实际运行结果、阻塞/限制、下一步 |
| WORK_LOG | 日期、任务 ID、改动/命令/证据、未覆盖范围 |
| ROADMAP | 依赖或验收条件发生变化才改任务定义；实际状态仍放 CURRENT_STATE |
| DECISIONS | 架构/设计取舍改变时追加或标记取代关系 |
| API/设计/接入/环境文档 | 与实际契约和命令同步；不留下相反的有效描述 |

不要将 token、真实签名链接、用户账户信息、私网秘密配置写入交接。证据原始文件放被忽略的本地目录，文档保留安全摘要。

## 6. 可复制的启动上下文

```text
项目：Doki，目录 /Users/yaron/Doki。
先读 AGENTS.md、docs/README.md、docs/handoff/CURRENT_STATE.md。
当前架构基线 v0.4 TV 首发修订；Apple 原生 UI + Liquid Glass；首版仅 tvOS + Hub。
iPhone/Mac 客户端全部后置，不创建其 target/UI/测试；Mac 仅作为开发主机。
参考 izuko-tv/Animeko 的机制，不复刻页面/尺寸/时序。
在线源优先 animeko-source/online.json；弹幕用弹弹play，Hub 持有秘密。
电视配对/Bangumi 授权用 Hub 网页与普通浏览器，不依赖 Doki 手机 App。
按 ROADMAP 推进，缺真实凭据可先做自造 fixture，不得把真实验收标完成。
完成当前批次后更新 CURRENT_STATE 与 WORK_LOG，记录命令、证据和下一步。
不要自行 commit/push 或公开部署；当前用户普通开发授权不包含这些操作。
```

上述摘要不能替代文件中的实际状态；恢复工作时先检查工作区与文档是否已变化。

面向 DeepSeek 的完整执行版见 [DEEPSEEK_TV_PROMPT](DEEPSEEK_TV_PROMPT.md)，复制后从实际 CURRENT_STATE 接续，不重新启动旧三端范围。
