import SwiftUI
import DokiCore
import DokiUI

struct AboutView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(
                    title: "关于 Doki",
                    subtitle: "Apple TV 首版原型 · 原生 SwiftUI / AVKit · 自造数据",
                    badge: "v0.4 · TV 首发",
                    onBack: { dismiss() }
                )

                HStack(alignment: .top, spacing: 22) {
                    DokiSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Doki")
                                .font(.system(size: 52, weight: .black, design: .rounded))
                            Text("把“今天看什么、上次看到哪、这一集是否看过”放在同一个电视界面里。")
                                .font(DokiType.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Divider().opacity(0.25)
                            keyValue("版本", model.appVersion)
                            keyValue("平台", "tvOS 26+ · 单 tvOS target")
                            keyValue("播放器", "AVPlayerViewController · 本地 24 分钟样片")
                            keyValue("数据", model.usesFixtures ? "自造演示资料" : "Bangumi 实时公开资料")
                        }
                    }
                    .frame(maxWidth: 620)

                    DokiSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("当前边界")
                                .font(DokiType.sectionTitle)
                            boundary("仅 tvOS + 必要的 Doki Hub；iPhone/Mac 客户端后置。")
                            boundary("演示源、演示弹幕候选和本地样片是明确自造数据，不是真实源站或弹弹play响应。")
                            boundary("Bangumi 公开资料无需凭据；TMDB 可在 Hub 配置；账号授权与真实弹幕尚未实现。")
                            boundary("tvOS 真机、签名安装、真实源完整集播放与真实弹幕都未完成。")
                        }
                    }
                }
                .padding(.horizontal, DokiTheme.pagePadding)

                DokiSurface {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("第三方服务与署名")
                            .font(DokiType.sectionTitle)
                        Text("弹幕设计使用弹弹play开放弹幕网络（https://www.dandanplay.com/）。当前没有 Doki 凭据、没有发起真实鉴权请求，也没有把参考项目凭据带入 App。")
                            .font(DokiType.caption)
                            .foregroundStyle(.secondary)
                        Image("tmdb-logo").resizable().scaledToFit().frame(width: 231, height: 30).accessibilityLabel("The Movie Database")
                        Text("This product uses the TMDB API but is not endorsed or certified by TMDB.").font(DokiType.caption).foregroundStyle(.secondary)
                        Text("Bangumi 提供真实条目、竖版封面、章节、角色与制作人员。TMDB 为可选横幅增强，由 Hub 持有 token。")
                            .font(DokiType.caption)
                            .foregroundStyle(.secondary)
                        Text("参考研究：izuko-tv（交互机制）、Animeko（源与资源身份语义）、MajoSissi/animeko-source（在线规则集合）。Doki 独立实现界面与代码，未复制参考项目页面、素材或动画时序。")
                            .font(DokiType.caption)
                            .foregroundStyle(.secondary)
                        Text("正常浏览的封面来自 Bangumi，版权归各权利人；不打包进 App。测试模式的自造海报和样片由本仓库生成。")
                            .font(DokiType.micro)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, DokiTheme.pagePadding)

                DokiSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("验证证据边界")
                            .font(DokiType.sectionTitle)
                        evidence("Build / Swift 包测试", "证明当前源码在对应工具链下通过；不证明真实播放或账号集成。")
                        evidence("模拟器截图 / 录屏", "证明当前模拟器画面与交互；不证明真机安装、性能或 PiP。")
                        evidence("真实 Hub /health", "只证明这次网络请求的响应；不证明 OAuth、源解析或媒体链路。")
                        evidence("真实完整集播放", "需要真机、已配置 Hub、已验证源与网络；当前尚未完成。")
                    }
                }
                .padding(.horizontal, DokiTheme.pagePadding)

                HStack {
                    DemoNotice(text: "详细证据、命令和限制以 docs/handoff/CURRENT_STATE.md 为准。")
                    Spacer()
                }
                .padding(.horizontal, DokiTheme.pagePadding)
            }
            .padding(.bottom, 64)
        }
        .background(DokiBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(key)
                .font(DokiType.caption)
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            Text(value)
                .font(DokiType.caption)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private func boundary(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(DokiTheme.accent)
                .padding(.top, 7)
            Text(text)
                .font(DokiType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func evidence(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(DokiType.micro)
                .foregroundStyle(DokiTheme.accent)
                .frame(width: 180, alignment: .leading)
            Text(detail)
                .font(DokiType.micro)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DiagnosticsView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "诊断",
                    subtitle: "只展示可安全显示的本地状态；不包含秘密、上游 Cookie 或签名 URL。",
                    badge: "本地证据",
                    onBack: { dismiss() }
                )

                HStack(alignment: .top, spacing: 22) {
                    DokiSurface {
                        VStack(alignment: .leading, spacing: 11) {
                            Text("运行状态")
                                .font(DokiType.sectionTitle)
                            status("App 版本", model.appVersion)
                            status("系统", ProcessInfo.processInfo.operatingSystemVersionString)
                            status("目标", targetName)
                            status("Hub 状态", model.hubState.title)
                            status("Hub 地址", sanitizedHubURL)
                            status("样片", model.demoMediaURL == nil ? "缺失（播放器会失败）" : "doki-demo-24min.mp4 已打包")
                            status("最后刷新", model.lastRefresh.map { DokiDate.relativeUpdate($0) } ?? "尚未刷新")
                        }
                    }
                    .frame(maxWidth: 680)

                    DokiSurface {
                        VStack(alignment: .leading, spacing: 11) {
                            Text("内容快照")
                                .font(DokiType.sectionTitle)
                            status("条目", "\(model.usesFixtures ? model.library.subjects.count : model.catalogSubjects.count)")
                            status("章节", "\(model.usesFixtures ? model.library.allEpisodes.count : model.catalogEpisodes.values.flatMap { $0 }.count)")
                            status("续播记录", "\(model.progress.positions.count) 集")
                            status("今日可播", "\(model.todayAvailable.count)")
                            status("今日计划", "\(model.usesFixtures ? model.todayScheduled.count : model.todayCatalog.count)")
                            status("产品播放源", "0 · 尚未接通")
                            status("弹幕偏好", "\(model.danmakuPreferences.enabled ? "开启" : "关闭") · \(model.danmakuPreferences.density.title) · \(String(format: "%+.1f", model.danmakuPreferences.offsetSeconds))s")
                            status("弹幕映射", "\(model.danmakuMappings.values.filter(\.confirmed).count) 集已确认")
                        }
                    }
                }
                .padding(.horizontal, DokiTheme.pagePadding)

                DokiSurface {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("任务验证状态")
                            .font(DokiType.sectionTitle)
                        status("APP-001 工程", "本机 tvOS 构建结果见交接记录；此页面不读取构建日志。")
                        status("UI-001", "需要浅/深色截图、遥控器导航录屏与焦点返回证据。")
                        status("HUB-001", "API/迁移/契约在 Server/；独立于该电视页面。")
                        status("SRC-001 / PLAY-001", "真实 source 与完整集播放尚未完成。")
                        status("AUTH-001 / SYNC-001 / META-001", "未接入真实账号或跨端同步。")
                        status("DAN-001/002/003", "fixture 渲染就绪；真实弹弹play鉴权未完成。")
                    }
                    .font(DokiType.caption)
                }
                .padding(.horizontal, DokiTheme.pagePadding)

                HStack(spacing: 14) {
                    DokiControlButton("重新检查 Hub", systemImage: "network") {
                        Task { await model.checkHubConnection() }
                    }
                    DemoTip()
                    Spacer()
                }
                .padding(.horizontal, DokiTheme.pagePadding)
            }
            .padding(.bottom, 64)
        }
        .background(DokiBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var targetName: String {
        #if targetEnvironment(simulator)
        "tvOS Simulator"
        #else
        "Apple TV device"
        #endif
    }

    private var sanitizedHubURL: String {
        guard !model.hubURLString.isEmpty else { return "未填写" }
        guard let components = URLComponents(string: model.hubURLString) else { return "无法解析" }
        return "\(components.scheme ?? "")://\(components.host ?? "")\(components.port.map { ":\($0)" } ?? "")"
    }

    private func status(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(key)
                .font(DokiType.micro)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(DokiType.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct DemoTip: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
            Text("诊断页不发起 Bangumi、TMDB 或弹弹play请求")
        }
        .font(DokiType.micro)
        .foregroundStyle(.secondary)
    }
}
