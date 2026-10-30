import SwiftUI
import DokiUI

@main
struct DokiTVApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootTabView(model: model)
                .preferredColorScheme(model.appearanceMode.colorScheme)
                .overlay(alignment: .bottom) {
                    if let toast = model.toast {
                        ToastBanner(message: toast.message)
                            .padding(.bottom, 36)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
                .animation(.easeOut(duration: 0.22), value: model.toast?.id)
        }
    }
}
