import SwiftUI
import UIKit

public struct DokiArtworkView: View {
    public let assetName: String?
    public let title: String
    public let accentHex: String
    public var contentMode: ContentMode
    public var remoteURL: URL?
    public var retainWhileLoading: Bool
    @State private var image: UIImage?
    @State private var displayedURL: URL?
    @Environment(\.dokiReduceMotion) private var reduceMotion

    public init(assetName: String?, title: String, accentHex: String, contentMode: ContentMode = .fill, remoteURL: URL? = nil, retainWhileLoading: Bool = false) {
        self.assetName = assetName; self.title = title; self.accentHex = accentHex
        self.contentMode = contentMode; self.remoteURL = remoteURL; self.retainWhileLoading = retainWhileLoading
    }
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(dokiHex: accentHex).opacity(0.12)
                if let bitmap = bitmap {
                    Image(uiImage: bitmap).resizable().aspectRatio(contentMode: contentMode)
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .transition(.opacity)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo").font(.system(size: 30, weight: .light))
                        Text(title).font(.system(size: 20, weight: .medium)).lineLimit(3).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary).padding(20)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .clipped()
        .task(id: remoteURL) {
            guard let remoteURL else { return }
            do {
                let replacement = try await ArtworkLoader.shared.image(at: remoteURL)
                try Task.checkCancellation()
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                    image = replacement; displayedURL = remoteURL
                }
            } catch { /* Keep a successfully displayed image when refresh fails. */ }
        }
        .accessibilityLabel(Text(title))
    }
    private var bitmap: UIImage? {
        if let image, displayedURL == remoteURL || retainWhileLoading { return image }
        if let assetName { return UIImage(named: assetName) }
        return nil
    }
}
