import SwiftUI
import UIKit
import DokiCore

public struct DokiHeroBackdrop: View {
    public let subject: Subject?
    @Environment(\.colorScheme) private var scheme
    public init(subject: Subject?) { self.subject = subject }
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                DokiTheme.pageBackground(for: scheme)
                if let subject, subject.backdropURL != nil || subject.backdropAsset != nil {
                    DokiArtworkView(assetName: subject.backdropAsset, title: subject.title, accentHex: subject.accentHex, remoteURL: subject.backdropURL, retainWhileLoading: true)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    LinearGradient(stops: [.init(color: DokiTheme.pageBackground(for: scheme).opacity(0.97), location: 0), .init(color: DokiTheme.pageBackground(for: scheme).opacity(0.80), location: 0.23), .init(color: DokiTheme.pageBackground(for: scheme).opacity(0.18), location: 0.52), .init(color: .clear, location: 0.76)], startPoint: .leading, endPoint: .trailing)
                    LinearGradient(stops: [.init(color: .clear, location: 0.30), .init(color: DokiTheme.pageBackground(for: scheme).opacity(0.2), location: 0.49), .init(color: DokiTheme.pageBackground(for: scheme), location: 0.76)], startPoint: .top, endPoint: .bottom)
                }
            }
        }.accessibilityHidden(true)
    }
}

public struct DokiTitleArtwork: View {
    public let subject: Subject
    public var width: CGFloat
    public var height: CGFloat
    @State private var image: UIImage?
    @State private var loadedURL: URL?
    public init(subject: Subject, width: CGFloat = 550, height: CGFloat = 145) { self.subject = subject; self.width = width; self.height = height }
    public var body: some View {
        Group {
            if let image, loadedURL == subject.titleLogoURL {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: width, maxHeight: height, alignment: .leading)
            } else {
                Text(subject.title).font(.system(size: 58, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.7)
            }
        }.frame(width: width, height: height, alignment: .leading)
            .task(id: subject.titleLogoURL) {
                guard let url = subject.titleLogoURL else { return }
                do { let bitmap = try await ArtworkLoader.shared.image(at: url); try Task.checkCancellation(); image = bitmap; loadedURL = url } catch { }
            }
            .accessibilityLabel(subject.title)
    }
}
