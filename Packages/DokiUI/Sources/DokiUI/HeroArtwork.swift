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
                    if let subject {
                        // A poster may supply diffuse colors when no backdrop exists; it is never shown as a sharp banner.
                        DokiArtworkView(assetName: subject.backdropAsset ?? subject.posterAsset, title: subject.title, accentHex: subject.accentHex, remoteURL: subject.backdropURL ?? subject.posterURL, retainWhileLoading: true)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(1.12).blur(radius: 48, opaque: true)
                            .saturation(0.95)
                            .blendMode(scheme == .dark ? .screen : .normal)
                            .opacity(scheme == .dark ? 0.78 : 0.72)
                    }
                    // Preserve the image’s diffuse shapes and colors instead of washing them out in gray.
                    DokiTheme.pageBackground(for: scheme).opacity(scheme == .dark ? 0.12 : 0.22)
                }
            }.clipped()
        }.accessibilityHidden(true)
    }
}

public struct DokiHeroBackdrop: View {
    public let subject: Subject?
    public var frosted: Bool
    public var contentOpacity: Double
    public var clearHeight: CGFloat
    @Environment(\.colorScheme) private var scheme
    public init(subject: Subject?, frosted: Bool = false, contentOpacity: Double = 1, clearHeight: CGFloat = 740) {
        self.subject = subject; self.frosted = frosted; self.contentOpacity = contentOpacity; self.clearHeight = clearHeight
    }
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // The material floor never depends on focus, menus or hero visibility.
                DokiAmbientBackground(subject: subject)
                if !frosted, let subject, subject.backdropURL != nil || subject.backdropAsset != nil {
                    DokiArtworkView(assetName: subject.backdropAsset, title: subject.title, accentHex: subject.accentHex, remoteURL: subject.backdropURL, retainWhileLoading: true)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .mask {
                            // Only the cover at the upper right is sharp. Text never sits over a dim sharp duplicate.
                            LinearGradient(stops: [.init(color: .clear, location: 0.44), .init(color: .black, location: 0.72)], startPoint: .leading, endPoint: .trailing)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .mask(alignment: .top) {
                            LinearGradient(stops: [.init(color: .black, location: 0.48), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                                .frame(height: min(clearHeight, geometry.size.height))
                        }
                        .scaleEffect(1 + (1 - contentOpacity) * 0.035, anchor: .topTrailing)
                        .offset(x: (1 - contentOpacity) * 24)
                        .opacity(contentOpacity)
                }
            }.clipped()
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
