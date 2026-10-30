import SwiftUI
import DokiUI

struct IntegrationSettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(title: "数据服务", subtitle: "秘密配置只填写在 Hub 本机，不填写在电视或聊天里。", onBack: { dismiss() })
                VStack(spacing: 24) {
                    service("Bangumi 番剧资料", state: "无需凭据", text: "首页、本季条目、搜索、周放送表、简介、竖版封面与章节可直接读取。支持读取已登录账号的追番；收藏修改和已看标记暂存本机，尚未写回账号。", website: "bangumi.github.io/api", fields: nil)
                    service("TMDB 横幅", state: "匹配横幅无需密钥", text: "优先从公开对应表读取横幅和标题 Logo。未命中或需要搜索修正时，可为 Hub 配置自己的 TMDB API Read Access Token。", website: "themoviedb.org/settings/api", fields: "TMDB_READ_ACCESS_TOKEN")
                    service("弹弹play", state: "暂缓接入", text: "在开发者中心为 Doki 申请自己的应用。获得 AppId 与 AppSecret 后填写 Hub；真实弹幕协议、匹配与取数仍需下一批集成和实测。", website: "dev.dandanplay.com", fields: "DANDANPLAY_APP_ID · DANDANPLAY_APP_SECRET")
                    service("Bangumi 账号", state: "网页登录无需密钥", text: "在“我的 → Bangumi 账号”配对 Hub，然后用浏览器输入邮箱、密码和验证码。Hub 加密保存个人令牌，密码不保存。当前支持读取账号追番，写回尚未接入。", website: "bgm.tv/login", fields: nil)
                    Text("配置位置：仓库根目录 .env（从 .env.example 复制），启动 Hub 时显式加载。配置完成后在“我的 → Doki Hub”填写电视可访问的 Hub 地址。完整步骤见 docs/development/INTEGRATIONS_SETUP.md。")
                        .font(DokiType.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, DokiTheme.pagePadding)
            }.padding(.bottom, 64)
        }.background(DokiBackground()).toolbar(.hidden, for: .navigationBar)
    }
    private func service(_ title: String, state: String, text: String, website: String, fields: String?) -> some View {
        DokiSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text(title).font(DokiType.sectionTitle); Spacer(); DokiBadge(state, tone: .neutral) }
                Text(text).font(DokiType.body).foregroundStyle(.secondary)
                Text(website).font(DokiType.caption).foregroundStyle(DokiTheme.accent)
                if let fields { Text(fields).font(.system(size: 18, design: .monospaced)).foregroundStyle(.secondary) }
            }
        }
    }
}
