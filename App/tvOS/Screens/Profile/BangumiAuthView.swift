import SwiftUI
import CoreImage.CIFilterBuiltins
import DokiCore
import DokiUI

struct BangumiAuthView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var pairing: HubPairing?
    @State private var error: String?
    @State private var attempt = 0
    @State private var busy = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 35) {
                PageHeader(title: "连接 Bangumi", subtitle: "用自己的账号登录，无需申请 API 密钥。", onBack: { dismiss() })
                HStack(alignment: .top, spacing: 65) {
                    VStack(alignment: .leading, spacing: 22) {
                        if let account = model.accountStatus?.bangumi {
                            Text(account.nickname.isEmpty ? account.username : account.nickname).font(.system(size: 38, weight: .semibold))
                            Label("Bangumi 已连接", systemImage: "checkmark.seal.fill").foregroundStyle(DokiTheme.accent)
                            Text("真实追番列表已可读取。网页登录与个人令牌保存在 Hub，密码不会保存在电视。").font(DokiType.body).foregroundStyle(.secondary)
                            DokiGlassButton("刷新追番", systemImage: "arrow.clockwise") { Task { await model.refreshAccount() } }
                        } else {
                            Text(model.accountStatus?.paired == true ? "电视已配对，在 Hub 完成登录" : "用浏览器连接这台电视").font(DokiType.sectionTitle)
                            Text("1. 在运行 Hub 的电脑浏览器打开右侧地址。\n2. 登记 Hub，并批准电视上的配对码。\n3. 在网页输入 Bangumi 邮箱、密码和验证码。").font(DokiType.body).lineSpacing(12)
                            Text("登录成功后自动创建个人令牌，追番列表会出现在电视上。").font(DokiType.caption).foregroundStyle(.secondary)
                            if let pairing { Text(pairing.code).font(.system(size: 68, weight: .semibold, design: .monospaced)).tracking(12).accessibilityIdentifier("pairing-code") }
                            if busy { ProgressView(pairing == nil ? "正在连接 Hub…" : "等待浏览器批准…") }
                            if let error { Text(error).font(DokiType.caption).foregroundStyle(.orange) }
                            if model.configuredHubURL != nil { DokiGlassButton("重新连接", systemImage: "arrow.clockwise") { attempt += 1 } }
                            else { DokiGlassButton("设置 Hub 地址", systemImage: "network") { model.profilePath.append(.hubSettings) } }
                        }
                    }.frame(maxWidth: 850, alignment: .leading)
                    if let url = model.configuredHubURL {
                        VStack(spacing: 20) {
                            if ["127.0.0.1", "localhost", "::1", "[::1]"].contains(url.host ?? "") {
                                Image(systemName: "desktopcomputer").font(.system(size: 100, weight: .light)).frame(width: 280, height: 240)
                                Text("在运行 Hub 的电脑打开").font(DokiType.caption).foregroundStyle(.secondary)
                            } else if let image = qr(url.absoluteString) { Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 280, height: 280).padding(22).background(.white, in: RoundedRectangle(cornerRadius: 20)) }
                            Text(url.absoluteString).font(.system(size: 22, design: .monospaced))
                        }
                    }
                }.padding(.horizontal, DokiTheme.pagePadding)
                if let error = model.accountError { Text(error).foregroundStyle(.secondary).padding(.horizontal, DokiTheme.pagePadding) }
            }.padding(.bottom, 65)
        }.background(DokiBackground()).toolbar(.hidden, for: .navigationBar)
        .task(id: [String(attempt), model.hubURLString]) { await connect() }
    }
    private func connect() async {
        guard let hub = model.configuredHubURL else { return }
        busy = true; error = nil
        defer { busy = false }
        let client = HubAccountClient(hub: hub)
        do {
            if DeviceCredentialStore.token(for: hub) != nil {
                await model.refreshAccount()
                while !Task.isCancelled && model.accountStatus?.bangumi == nil && model.accountStatus?.paired == true {
                    try await Task.sleep(for: .seconds(3)); await model.refreshAccount()
                }
                if model.accountStatus != nil { return }
            }
            let fresh = try await client.createPairing(); try Task.checkCancellation(); pairing = fresh
            let expires = Date().addingTimeInterval(Double(fresh.expiresIn))
            while Date() < expires {
                try Task.checkCancellation()
                let state = try await client.pairingStatus(fresh)
                if state == "approved" {
                    let claim = try await client.claim(fresh); try Task.checkCancellation()
                    try DeviceCredentialStore.save(claim.token, for: hub); pairing = nil
                    await model.refreshAccount()
                    while !Task.isCancelled && model.accountStatus?.bangumi == nil { try await Task.sleep(for: .seconds(3)); await model.refreshAccount() }
                    return
                }
                try await Task.sleep(for: .seconds(2))
            }
            error = "配对码已过期，请重新连接。"
        } catch is CancellationError { } catch { self.error = (error as? any LocalizedError)?.errorDescription ?? "无法连接 Hub" }
    }
    private func qr(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(text.utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        guard let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
