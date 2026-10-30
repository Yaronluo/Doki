import SwiftUI
import DokiUI

struct ProfileView: View {
    @Bindable var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                PageHeader(title: "我的 Doki")
                HStack(spacing: 24) {
                    summary("追看中", value: "\(model.watchingCount)")
                    summary("资料来源", value: model.usesFixtures ? "演示素材" : "Bangumi")
                    summary("收藏保存", value: "本机")
                }.padding(.horizontal, DokiTheme.pagePadding)
                VStack(spacing: 28) {
                    SettingsSection("内容与连接") {
                        NavigationRow(title: "Doki Hub", detail: model.hubURLString.isEmpty ? "公开资料和匹配横幅可直接浏览；Hub 用于账号配对。" : model.hubState.detail, systemImage: "network", badge: DokiBadge(model.hubState.title, tone: .neutral)) { model.profilePath.append(.hubSettings) }
                        NavigationRow(title: "数据服务与配置", detail: "查看 Bangumi、TMDB、弹弹play的接入状态、申请位置与配置方式。", systemImage: "slider.horizontal.3") { model.profilePath.append(.integrationSettings) }
                        NavigationRow(title: "Bangumi 账号", detail: model.accountStatus?.bangumi.map { "已登录 \($0.nickname) · 读取真实追番列表" } ?? "在 Hub 网页用邮箱、密码、验证码登录，无需 API 密钥。", systemImage: "person.badge.key", badge: DokiBadge(model.accountStatus?.bangumi == nil ? "未连接" : "已登录", tone: .neutral)) { model.profilePath.append(.bangumiAuth) }
                    }
                    SettingsSection("播放偏好") {
                        NavigationRow(title: "播放源", detail: "当前没有已启用的产品播放源。", systemImage: "antenna.radiowaves.left.and.right", badge: DokiBadge("未接通", tone: .scheduled)) { model.profilePath.append(.sourceSettings) }
                        NavigationRow(title: "弹幕", detail: "偏好可调整；弹弹play按当前要求暂缓接入。", systemImage: "text.bubble", badge: DokiBadge("待配置", tone: .neutral)) { model.profilePath.append(.danmakuSettings) }
                        HStack {
                            Label("外观", systemImage: "circle.lefthalf.filled").font(DokiType.cardTitle)
                            Spacer()
                            Picker("外观", selection: $model.appearanceMode) { ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) } }.frame(width: 560)
                        }.padding(20)
                    }
                    SettingsSection("关于") {
                        NavigationRow(title: "关于 Doki", detail: "版本、数据来源与第三方署名", systemImage: "info.circle") { model.profilePath.append(.about) }
                        NavigationRow(title: "诊断", detail: "连接状态与验证范围", systemImage: "stethoscope") { model.profilePath.append(.diagnostics) }
                    }
                }.padding(.horizontal, DokiTheme.pagePadding)
            }.padding(.bottom, 64)
        }.background(DokiBackground()).toolbar(.hidden, for: .navigationBar)
    }
    private func summary(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(value).font(.system(size: 34, weight: .semibold))
            Text(title).font(DokiType.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
    }
}
