import SwiftUI
import DokiUI

struct HubSettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draftURL: String = ""

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(
                    title: "Doki Hub",
                    subtitle: "公开番剧资料无需 Hub；TMDB 横幅与后续播放、弹幕由 Hub 提供。",
                    badge: "连接状态",
                    onBack: { dismiss() }
                )

                HStack(alignment: .top, spacing: 26) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Hub 地址")
                            .font(DokiType.sectionTitle)
                        TextField("例如 https://hub.example.com", text: $draftURL)
                            .textFieldStyle(.plain)
                            .font(.system(size: 22, weight: .medium, design: .monospaced))
                            .padding(18)
                            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                            }
                        Text("检查会真实请求 Hub 的 /health。地址可能因 ATS、VPN、证书或局域网隔离而不可达；失败不会被伪装成演示成功。")
                            .font(DokiType.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 14) {
                            DokiControlButton("保存并检查", systemImage: "arrow.clockwise") {
                                model.hubURLString = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
                                Task { await model.checkHubConnection() }
                            }
                            if model.hubState.isBusy {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .frame(maxWidth: 780, alignment: .leading)

                    DokiSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("当前状态")
                                .font(DokiType.sectionTitle)
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 10, height: 10)
                                Text(model.hubState.title)
                                    .font(DokiType.cardTitle)
                            }
                            Text(model.hubState.detail)
                                .font(DokiType.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Divider().opacity(0.25)
                            Text("已保存地址")
                                .font(DokiType.micro)
                                .foregroundStyle(.secondary)
                            Text(model.hubURLString.isEmpty ? "未填写" : sanitizedURL)
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary)
                            Text("不会显示 query、token 或上游 Cookie。")
                                .font(DokiType.micro)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: 420)
                }
                .padding(.horizontal, DokiTheme.pagePadding)

                DokiSurface {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("电视端不做什么")
                            .font(DokiType.sectionTitle)
                        Label("不打开 WebKit，不执行源站脚本或 iframe", systemImage: "xmark.app")
                        Label("不接收 Bangumi Client Secret、弹弹play AppSecret 或上游 Cookie", systemImage: "key.slash")
                        Label("不在电视上显示 Hub owner 管理密钥", systemImage: "person.badge.shield.checkmark")
                        Label("Hub 不可达时保留已展示资料与本机收藏", systemImage: "externaldrive.badge.exclamationmark")
                    }
                    .font(DokiType.caption)
                }
                .padding(.horizontal, DokiTheme.pagePadding)

                HStack {
                    DemoNotice(text: "保存 Hub 地址后会刷新真实目录；无需凭据的番剧浏览可直接使用。")
                    Spacer()
                }
                .padding(.horizontal, DokiTheme.pagePadding)
            }
            .padding(.bottom, 64)
        }
        .background(DokiBackground())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            draftURL = model.hubURLString
        }
    }

    private var statusColor: Color {
        switch model.hubState {
        case .connected: DokiTheme.accent
        case .failed: .orange
        case .checking: .yellow
        case .demo, .notChecked, .notConfigured: .secondary
        }
    }

    private var sanitizedURL: String {
        guard let components = URLComponents(string: model.hubURLString) else { return model.hubURLString }
        return "\(components.scheme ?? "")://\(components.host ?? "")\(components.port.map { ":\($0)" } ?? "")"
    }
}
