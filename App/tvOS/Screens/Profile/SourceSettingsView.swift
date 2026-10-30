import SwiftUI
import DokiUI

struct SourceSettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(title: "播放源", subtitle: "番剧资料和视频资源分别接入。", onBack: { dismiss() })
                DokiSurface {
                    VStack(alignment: .leading, spacing: 18) {
                        Label("当前没有可用播放源", systemImage: "antenna.radiowaves.left.and.right").font(DokiType.sectionTitle)
                        Text("已做过一个在线源的解析与模拟器播放验证，但视频内含赌博广告，因此保持禁用。需要验证可接受的源和条目映射后，才会进入普通播放入口。")
                            .font(DokiType.body).foregroundStyle(.secondary)
                        Text("animeko-source 的规则可读取，不代表资源可播。不会批量启用未验证源。")
                            .font(DokiType.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, DokiTheme.pagePadding)
                if model.usesFixtures {
                    ForEach(model.sources) { source in
                        NavigationRow(title: source.name, detail: source.detail + " · 演示线路", systemImage: "testtube.2") { model.selectSource(source) }
                    }.padding(.horizontal, DokiTheme.pagePadding)
                }
            }.padding(.bottom, 64)
        }.background(DokiBackground()).toolbar(.hidden, for: .navigationBar)
    }
}
