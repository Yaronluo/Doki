# Doki 文档入口

当前基线：**v0.4 · TV 首发修订：仅 tvOS + 必要 Hub，Apple 原生设计 + Liquid Glass + 弹弹play弹幕**。iPhone/Mac 客户端不在首版任务或验收范围。项目已进入实现阶段：tvOS 原型、Hub 骨架和单源技术验证均已出现；真实源内容安全、真机与正式集成仍未完成，详见 [CURRENT_STATE](handoff/CURRENT_STATE.md)。

真实数据申请与本地启动：[配置指南](development/INTEGRATIONS_SETUP.md)。当前正常浏览已接入 Bangumi 公开资料；TMDB/账号/弹幕与视频的不同边界见当前状态。

[DeepSeek TV 开发提示词](handoff/DEEPSEEK_TV_PROMPT.md)可直接复制给能访问本仓库的编码工具。

## 阅读顺序

| 顺序 | 文件 | 作用 |
|---|---|---|
| 1 | [开发约束](../AGENTS.md) | 仓库内工作方式、不可丢失的产品要求与验证规则 |
| 2 | [当前状态](handoff/CURRENT_STATE.md) | 已有内容、缺少的凭据/设备信息、下一步任务 |
| 3 | [实施方案 v0.4](Doki-设计方案-v0.4.md) | 架构、范围、源、播放、映射、同步与部署 |
| 4 | [Apple 原生设计规范](design/APPLE_NATIVE_UI.md) | Doki 自己的信息架构、tvOS 页面、Liquid Glass 和动效；其他平台仅作后续参考 |
| 5 | [弹弹play接入](integrations/DANDANPLAY.md) | 取数、ID 匹配、媒体时钟、客户端渲染、申请凭据和失效恢复 |
| 6 | [架构决策](architecture/DECISIONS.md) | 已定取舍、依据、影响和改动记录 |
| 7 | [开发任务](development/ROADMAP.md) | 可执行任务 ID、依赖、完成条件与交付物 |
| 8 | [接口契约草案](development/API_CONTRACTS.md) | ID、错误、幂等、版本、弹幕 DTO 与会话接口约束 |
| 9 | [环境与配置](development/SETUP.md) | 环境调查、配置模板、未来构建入口和部署步骤 |
| 10 | [验收清单](development/ACCEPTANCE.md) | 功能、交互、实播和可追溯证据 |
| 11 | [交接指南](handoff/HANDOFF.md) / [工作记录](handoff/WORK_LOG.md) | 下一位开发者的启动步骤、更新义务和历史批次 |

## 权威边界

用户最新要求优先。AGENTS.md 定义工作约束；产品架构在 v0.4 的 TV 首发修订；UI 细节在设计规范；弹幕协议和时间轴在接入文档；项目“做到了什么”只看当前状态和证据。任务路线不把规划日期变成已完成状态。

出现冲突时先按用户明确要求处理，并同步受影响文件；跨文档设计变更记录决策 ID。不要只改一份说明，让另一个文件继续发出相反约束。

## 历史与参考

- [v0.3 历史方案](Doki-设计方案-v0.3.md)、[v0.2 历史方案](Doki-设计方案-v0.2.md)：保留讨论过程，不作为新实现要求。
- [参考实现与数据源接入](参考实现与数据源接入.md)：保留已核对源码、版本和源格式事实；参考行为不直接成为 Doki 设计规格。
- [旧 tvOS 概念图](assets/preview-tvos-home.png)：历史视觉探索，不是当前 UI 验收图。

## 维护规则

每次开发交接更新当前状态、任务证据和工作记录；不要修改用户的历史原话或伪造验证记录。秘密配置使用根目录 [.env.example](../.env.example) 的键名，真实值不进入仓库。

运行 `python3 scripts/check-docs.py` 校验仓库文档内部链接、表格、代码块和示例 JSON；更改后再检查真实实现。
