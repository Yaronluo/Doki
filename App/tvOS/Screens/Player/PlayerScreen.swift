import AVKit
import SwiftUI
import DokiCore
import DokiDanmaku
import DokiUI

struct PlayerScreen: View {
    @Bindable var model: AppModel
    let route: PlaybackRoute
    @Environment(\.dismiss) private var dismiss
    @State private var playerModel = PlayerViewModel()
    @State private var showDanmakuSettings = false
    @State private var showMapping = false
    @State private var showSourcePicker = false
    @State private var didLoad = false
    @Environment(\.dokiReduceMotion) private var reduceMotion
    @Environment(\.dokiReduceTransparency) private var reduceTransparency

    private var episode: Episode? {
        model.episode(id: route.episodeID)
    }

    private var subject: Subject? {
        model.subject(id: route.subjectID)
    }

    private var sourceName: String {
        if route.isRealSourcePreview {
            return route.sourceDisplayName
        }
        return model.sources.first { $0.id == route.sourceID }?.name
            ?? model.selectedSource?.name
            ?? route.sourceDisplayName
    }

    private var playbackURL: URL? {
        route.mediaURL ?? model.demoMediaURL
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if playbackURL != nil {
                PlayerViewControllerRepresentable(player: playerModel.player)
                    .ignoresSafeArea()

                if shouldShowDanmaku, let episode, let timeline = model.timeline(for: episode) {
                    DanmakuOverlayRepresentable(
                        timeline: timeline,
                        preferences: model.danmakuPreferences,
                        mediaTime: { playerModel.player.currentTime().seconds }
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                playerScrims

                chrome
                    .opacity(playerModel.phase == .failed || playerModel.phase == .ended ? 0.25 : 1)

                if playerModel.phase == .failed {
                    failureOverlay
                }

                if playerModel.phase == .ended {
                    endedOverlay
                }
            } else {
                missingMedia
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            loadMedia()
        }
        .onDisappear {
            playerModel.stop()
        }
        .onExitCommand {
            close()
        }
        .sheet(isPresented: $showDanmakuSettings) {
            DanmakuSettingsView(
                model: model,
                presentation: .playerSheet,
                episode: episode,
                onRequestMapping: {
                    showDanmakuSettings = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(320))
                        showMapping = true
                    }
                }
            )
        }
        .sheet(isPresented: $showMapping) {
            if let episode {
                DanmakuMappingSheet(model: model, episode: episode)
            }
        }
        .sheet(isPresented: $showSourcePicker) {
            SourcePickerSheet(model: model)
        }
    }

    private var shouldShowDanmaku: Bool {
        guard model.danmakuPreferences.enabled, let episode else { return false }
        return model.isDanmakuMapped(episode)
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                DokiControlIconButton("chevron.backward", accessibilityLabel: "返回") {
                    close()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(route.subjectTitle)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("第 \(route.episodeNumber) 话 · \(route.episodeTitle)")
                        .font(DokiType.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }
                .padding(.leading, 34)
                .shadow(color: .black.opacity(0.7), radius: 4, y: 2)

                Spacer(minLength: 20)

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        playerBadge(sourceName, symbol: "antenna.radiowaves.left.and.right")
                        if route.isRealSourcePreview {
                            playerBadge("弹幕未接入", symbol: "text.bubble")
                        } else if model.danmakuPreferences.enabled {
                            playerBadge(
                                episode.map(model.isDanmakuMapped) == true ? "弹幕开启" : "弹幕未匹配",
                                symbol: "text.bubble"
                            )
                        } else {
                            playerBadge("弹幕关闭", symbol: "text.bubble")
                        }
                    }
                    HStack(spacing: 12) {
                        DokiControlButton("弹幕", systemImage: "text.bubble") {
                            showDanmakuSettings = true
                        }
                        if !route.isRealSourcePreview {
                            DokiControlButton("换源", systemImage: "antenna.radiowaves.left.and.right") {
                                showSourcePicker = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 44)
            .padding(.top, 28)

            Spacer()

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(route.isRealSourcePreview ? "Hub relay · 真实源预览" : "本地样片 · 非真实源")
                        Text("·")
                        Text("\(PlaybackProgressPolicy.displayTime(playerModel.currentTime)) / \(PlaybackProgressPolicy.displayTime(playerModel.duration))")
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .font(DokiType.micro)
                    .foregroundStyle(.white.opacity(0.52))
                    Text(playbackStateText)
                        .font(DokiType.caption)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.36), in: Capsule())
                Spacer()
                Text("按方向键访问系统播放控制 · 返回键关闭")
                    .font(DokiType.micro)
                    .foregroundStyle(.white.opacity(0.42))
            }
            .padding(.horizontal, 44)
            .padding(.bottom, 26)
        }
        .allowsHitTesting(playerModel.phase != .failed)
        .opacity(playerModel.phase == .ended ? 0 : 1)
    }

    private var playbackStateText: String {
        switch playerModel.phase {
        case .preparing: route.isRealSourcePreview ? "正在准备 Hub relay 流" : "正在准备本地样片"
        case .buffering: "缓冲中"
        case .playing: route.isRealSourcePreview
            ? "播放中 · Hub relay"
            : "播放中 · 弹幕按媒体时钟定位"
        case .paused: "已暂停"
        case .seeking: "正在定位"
        case .ended: "播放完毕"
        case .failed: "播放失败"
        case .cancelled, .idle: "尚未开始"
        }
    }

    private var endedOverlay: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DokiTheme.accent)
            Text(route.isRealSourcePreview ? "真实源样片播放完毕" : "本集样片播放完毕")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(route.isRealSourcePreview
                 ? "这是真实源第 1 集的开发预览。续播位置保存在本机，Bangumi 写回与正式播放会话尚未接入。"
                 : "续播位置已保存到本机。真实 Bangumi 已看回写与 Hub 同步尚未接入。")
                .font(DokiType.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 14) {
                DokiControlButton("重新播放", systemImage: "arrow.counterclockwise") {
                    playerModel.replay()
                }
                DokiControlButton("返回详情", systemImage: "chevron.backward") {
                    close()
                }
            }
        }
        .padding(34)
        .frame(maxWidth: 640)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .transition(.opacity)
    }

    private var failureOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(playerModel.failure?.stage.title ?? "播放失败")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(playerModel.failure?.message ?? "视频暂时无法播放。")
                .font(DokiType.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 14) {
                DokiControlButton("重试", systemImage: "arrow.clockwise") {
                    loadMedia()
                }
                DokiControlButton("返回", systemImage: "chevron.backward") {
                    close()
                }
            }
        }
        .padding(32)
        .frame(maxWidth: 620)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var playerScrims: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0.62), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 210)
            Spacer(minLength: 0)
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func playerBadge(_ title: String, symbol: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(title)
                .font(DokiType.micro)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.62), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
    }

    private var missingMedia: some View {
        VStack(spacing: 18) {
            Image(systemName: "film.stack")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DokiTheme.accent)
            Text(route.isRealSourcePreview ? "Hub relay 地址缺失" : "演示样片没有打包")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(route.isRealSourcePreview
                 ? "真实源计划没有有效媒体地址。请检查 Hub 日志与开发预览响应，此状态不会被伪装成可播放。"
                 : "请检查 App/tvOS/Resources/DemoMedia/doki-demo-24min.mp4，重新执行 xcodegen 与构建。此状态不会被伪装成可播放。")
                .font(DokiType.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 680)
            DokiControlButton("返回", systemImage: "chevron.backward") {
                close()
            }
        }
        .padding(DokiTheme.pagePadding)
    }

    private func loadMedia() {
        guard let url = playbackURL else { return }
        playerModel.load(
            url: url,
            startAt: route.startAtSeconds,
            durationHint: route.durationSeconds,
            onCheckpoint: { position, duration in
                model.recordPlayback(route: route, position: position, duration: duration)
            }
        )
    }

    private func close() {
        playerModel.checkpointNow(force: true)
        playerModel.stop()
        dismiss()
    }
}

struct PlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}
