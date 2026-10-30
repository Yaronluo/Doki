import SwiftUI
import DokiCore
import DokiUI

private enum RealSourcePreviewState: Equatable {
    case idle
    case loading
    case ready
    case failed(String)
}

struct RealSourcePreviewView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = "葬送的芙莉莲"
    @State private var plan: RealSourcePreviewPlan?
    @State private var state: RealSourcePreviewState = .idle
    @State private var requestTask: Task<Void, Never>?
    @State private var didAutoStart = false

    private var hubURL: URL? {
        guard let url = URL(string: model.hubURLString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }

    private var savedProgress: PlaybackPosition? {
        guard let plan else { return nil }
        return model.progress.position(for: plan.episode.mediaId)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "真实源预览",
                    subtitle: "Hub 执行源站搜索/详情/解析与 relay；TV 只拿短期签名播放计划。",
                    badge: "技术验证 · 内容未通过",
                    onBack: { dismiss() }
                )

                DokiSurface {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("内容安全限制：此源不能作为产品源")
                                .font(DokiType.cardTitle)
                            Text("2026-10-30 本地验证发现该真实源的流内含第三方赌博广告。樱花动漫仅用于验证 adapter / relay 技术链路；不得设为默认源、公开部署或作为内容交付。")
                                .font(DokiType.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, DokiTheme.pagePadding)

                HStack(alignment: .top, spacing: 18) {
                    DokiSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("链路")
                                .font(DokiType.sectionTitle)
                            flowStep("1", "Hub 固定 online.json 快照，选择樱花动漫规则")
                            flowStep("2", "搜索 → 详情 → 第 1 集播放页")
                            flowStep("3", "校验 m3u8 → 签名 relay → AVPlayer")
                            flowStep("4", "本机续播；不写回 Bangumi")
                        }
                    }
                    .frame(maxWidth: 720)

                    DokiSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hub")
                                .font(DokiType.sectionTitle)
                            if let hubURL {
                                Text("\(hubURL.scheme ?? "")://\(hubURL.host ?? "")\(hubURL.port.map { ":\($0)" } ?? "")")
                                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                                    .foregroundStyle(DokiTheme.accent)
                            } else {
                                DokiBadge("未配置", tone: .scheduled)
                                Text("真实源需要 Doki Hub 在局域网可达。")
                                    .font(DokiType.caption)
                                    .foregroundStyle(.secondary)
                            }
                            DokiBadge("NODE_ENV != production", tone: .demo)
                            Text("开发路由在 production 不注册；未暴露任意 URL 代理。")
                                .font(DokiType.micro)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, DokiTheme.pagePadding)

                DokiSurface {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("预览参数")
                                    .font(DokiType.sectionTitle)
                                Text("首版只验证第 1 集。输入只用于源站搜索，不会写入 Bangumi。")
                                    .font(DokiType.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            DokiBadge("樱花动漫 · relay", tone: .demo)
                        }

                        HStack(spacing: 14) {
                            TextField("搜索标题，例如 葬送的芙莉莲", text: $query)
                                .textFieldStyle(.plain)
                                .font(DokiType.body)
                                .padding(16)
                                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                                }
                                .frame(maxWidth: 680)
                            DokiBadge("第 1 集", tone: .neutral)
                        }

                        HStack(spacing: 14) {
                            DokiControlButton("解析并播放", systemImage: "play.circle.fill") {
                                startPreview()
                            }
                            .disabled(state == .loading)

                            if state == .loading {
                                ProgressView()
                                    .controlSize(.small)
                                Text("真实请求中；受源站 requestInterval 限制，通常 5～15 秒")
                                    .font(DokiType.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if plan != nil {
                                DokiControlButton("重新解析", systemImage: "arrow.clockwise") {
                                    startPreview()
                                }
                            }
                            if hubURL == nil {
                                DokiControlButton("配置 Hub", systemImage: "network") {
                                    model.profilePath.append(.hubSettings)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, DokiTheme.pagePadding)

                statusSection
                    .padding(.horizontal, DokiTheme.pagePadding)

                HStack {
                    DemoNotice(text: "真实源内容只用于本地技术验证；不公开部署、不写回 Bangumi、不缓存整集。")
                    Spacer()
                }
                .padding(.horizontal, DokiTheme.pagePadding)
            }
            .padding(.bottom, 64)
        }
        .background(DokiBackground())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if !didAutoStart,
               ProcessInfo.processInfo.arguments.contains("--demo-real-autoplay"),
               hubURL != nil {
                didAutoStart = true
                startPreview()
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch state {
        case .idle:
            EmptyView()
        case .loading:
            DokiSurface {
                HStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.regular)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("正在解析真实源")
                            .font(DokiType.cardTitle)
                        Text("Hub 正在搜索源站、读取章节、解析播放页并校验 HLS；不会把上游 URL 暴露给 TV。")
                            .font(DokiType.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        case .failed(let message):
            DokiSurface {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("真实源解析失败")
                            .font(DokiType.sectionTitle)
                    }
                    Text(message)
                        .font(DokiType.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("失败阶段在 Hub 日志中区分搜索、详情、播放页与媒体校验；不会伪装成可播放。")
                        .font(DokiType.micro)
                        .foregroundStyle(.tertiary)
                    DokiControlButton("重试", systemImage: "arrow.clockwise") {
                        startPreview()
                    }
                }
            }
        case .ready:
            if let plan {
                DokiSurface {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(plan.subject.name)
                                    .font(DokiType.sectionTitle)
                                Text("第 \(plan.episode.number) 集 · \(plan.episode.channel) · \(plan.provider.name)")
                                    .font(DokiType.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            DokiBadge("relay 已就绪", tone: .available, symbol: "checkmark")
                        }
                        HStack(spacing: 18) {
                            keyValue("会话", plan.sessionId)
                            keyValue("规则快照", String(plan.provenance.snapshotSha256.prefix(12)))
                            keyValue("解析时间", plan.provenance.verifiedAt)
                        }
                        if let savedProgress, savedProgress.positionSeconds > 0 {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(DokiTheme.accent)
                                Text("上次看到 \(PlaybackProgressPolicy.displayTime(savedProgress.positionSeconds)) / \(PlaybackProgressPolicy.displayTime(savedProgress.durationSeconds))")
                                    .font(DokiType.caption)
                                    .monospacedDigit()
                            }
                        }
                        HStack(spacing: 14) {
                            DokiControlButton(
                                savedProgress == nil ? "开始播放" : "继续播放",
                                systemImage: "play.fill"
                            ) {
                                model.presentRealSource(plan)
                            }
                            DokiControlButton("返回", systemImage: "chevron.backward") {
                                dismiss()
                            }
                            DemoNotice(text: "真实源 · 未绑定 Bangumi")
                        }
                    }
                }
            }
        }
    }

    private func flowStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .frame(width: 22, height: 22)
                .background(DokiTheme.accent.opacity(0.16), in: Circle())
                .foregroundStyle(DokiTheme.accent)
            Text(text)
                .font(DokiType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(DokiType.micro)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startPreview() {
        requestTask?.cancel()
        guard let hubURL else {
            state = .failed("Hub 地址未配置。请先在「我的 > Doki Hub」填写局域网或本机地址。")
            return
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .failed("请输入搜索标题。")
            return
        }
        state = .loading
        plan = nil
        requestTask = Task { @MainActor in
            do {
                let result = try await RealSourceClient.preview(
                    hubBaseURL: hubURL,
                    query: trimmed,
                    episodeNumber: 1
                )
                guard !Task.isCancelled else { return }
                plan = result
                state = .ready
                model.presentRealSource(result)
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .failed(
                    (error as? any LocalizedError)?.errorDescription
                        ?? "无法解析真实源"
                )
            }
        }
    }
}
