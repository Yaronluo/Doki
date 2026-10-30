import SwiftUI
import UIKit
import DokiCore

/// A colored, diffuse content backdrop. This is independent of button chrome.
public struct DokiAmbientBackground: View {
    public let subject: Subject?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dokiReduceTransparency) private var reduceTransparency
    public init(subject: Subject?) { self.subject = subject }
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                DokiTheme.pageBackground(for: scheme)
                if !reduceTransparency {
                    if let subject, subject.backdropURL != nil || subject.backdropAsset != nil {
                        DokiArtworkView(assetName: subject.backdropAsset, title: subject.title, accentHex: subject.accentHex, remoteURL: subject.backdropURL, retainWhileLoading: true)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(1.2).blur(radius: 100, opaque: true)
                            .saturation(0.65).opacity(scheme == .dark ? 0.48 : 0.25)
                    }
                    Rectangle().fill(.ultraThinMaterial).opacity(0.22)
                    DokiTheme.pageBackground(for: scheme).opacity(0.2)
                }
            }.clipped()
        }.accessibilityHidden(true)
    }
}

public struct DokiHeroBackdrop: View {
    public let subject: Subject?
    public var frosted: Bool
    public var navigationExpanded: Bool
    public var diffuseLeading: Bool
    @Environment(\.colorScheme) private var scheme
    public init(subject: Subject?, frosted: Bool = false, navigationExpanded: Bool = false, diffuseLeading: Bool = false) {
        self.subject = subject; self.frosted = frosted; self.navigationExpanded = navigationExpanded; self.diffuseLeading = diffuseLeading
    }
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                DokiAmbientBackground(subject: subject)
                if !frosted, let subject, subject.backdropURL != nil || subject.backdropAsset != nil {
                    DokiArtworkView(assetName: subject.backdropAsset, title: subject.title, accentHex: subject.accentHex, remoteURL: subject.backdropURL, retainWhileLoading: true)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    if diffuseLeading {
                        DokiAmbientBackground(subject: subject)
                            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.26), .init(color: .clear, location: 0.65)], startPoint: .leading, endPoint: .trailing))
                    }
                    if !navigationExpanded {
                        LinearGradient(stops: [.init(color: DokiTheme.pageBackground(for: scheme).opacity(0.94), location: 0), .init(color: DokiTheme.pageBackground(for: scheme).opacity(0.76), location: 0.23), .init(color: DokiTheme.pageBackground(for: scheme).opacity(0.12), location: 0.54), .init(color: .clear, location: 0.8)], startPoint: .leading, endPoint: .trailing)
                        LinearGradient(stops: [.init(color: .clear, location: 0.32), .init(color: DokiTheme.pageBackground(for: scheme).opacity(0.3), location: 0.55), .init(color: DokiTheme.pageBackground(for: scheme), location: 0.83)], startPoint: .top, endPoint: .bottom)
                    }
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
