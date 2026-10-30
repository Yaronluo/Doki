import SwiftUI
import DokiCore

public struct DokiPosterTile: View {
    public let subject: Subject
    public let fraction: Double?
    public let watched: Bool
    public let badge: DokiBadge?
    public var width: CGFloat?
    @Environment(\.isFocused) private var isFocused

    public init(
        subject: Subject,
        fraction: Double? = nil,
        watched: Bool = false,
        badge: DokiBadge? = nil,
        width: CGFloat? = nil
    ) {
        self.subject = subject
        self.fraction = fraction
        self.watched = watched
        self.badge = badge
        self.width = width
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DokiArtworkView(
                assetName: subject.posterAsset,
                title: subject.title,
                accentHex: subject.accentHex,
                remoteURL: subject.posterURL
            )
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: DokiTheme.cardRadius, style: .continuous))
            .overlay(alignment: .bottom) {
                if let fraction {
                    DokiProgressBar(fraction: fraction, tint: DokiTheme.accent(hex: subject.accentHex))
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                }
            }
            .overlay(alignment: .topTrailing) {
                if watched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white, DokiTheme.accent)
                        .padding(10)
                        .accessibilityLabel("已看完")
                } else if let badge {
                    badge.padding(10)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: DokiTheme.cardRadius, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.white.opacity(0.78) : Color.white.opacity(0.08),
                        lineWidth: isFocused ? 2.5 : 1
                    )
            }
            .shadow(
                color: isFocused ? DokiTheme.accent(hex: subject.accentHex).opacity(0.24) : .clear,
                radius: isFocused ? 22 : 0,
                y: 8
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(subject.title)
                    .font(DokiType.cardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 56, alignment: .topLeading)
                HStack(spacing: 7) {
                    if let rating = subject.rating {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.yellow.opacity(0.9))
                        Text(String(format: "%.1f", rating))
                    }
                    if subject.rating != nil && !subject.genres.isEmpty { Text("·") }
                    if !subject.genres.isEmpty { Text(subject.genres.prefix(2).joined(separator: " / ")) }
                    else if subject.year > 0 { Text(String(subject.year)) }
                }
                .font(DokiType.micro)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .frame(width: width.map { $0 - 2 }, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(subject.title)，\(subject.followState.title)"))
    }
}

public struct DokiContinueCard: View {
    public let item: ContinueWatchingItem
    public var width: CGFloat = 560
    @Environment(\.isFocused) private var isFocused

    public init(item: ContinueWatchingItem, width: CGFloat = 560) {
        self.item = item
        self.width = width
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            DokiArtworkView(
                assetName: item.subject.backdropAsset,
                title: item.subject.title,
                accentHex: item.subject.accentHex,
                remoteURL: item.subject.backdropURL
            )
            .aspectRatio(16.0 / 9.0, contentMode: .fill)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.20),
                    .init(color: .black.opacity(0.28), location: 0.52),
                    .init(color: .black.opacity(0.88), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    DokiBadge("继续观看", tone: .accent, symbol: "play.fill")
                    if let rating = item.subject.rating {
                        DokiBadge(String(format: "★ %.1f", rating), tone: .neutral)
                    }
                }
                Spacer(minLength: 0)
                Text(item.subject.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("第 \(item.episode.number) 话 · \(item.episode.title)")
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Text("\(PlaybackProgressPolicy.displayTime(item.positionSeconds)) / \(PlaybackProgressPolicy.displayTime(item.episode.durationSeconds))")
                        .foregroundStyle(.white.opacity(0.70))
                        .monospacedDigit()
                }
                .font(DokiType.caption)
                DokiProgressBar(fraction: item.fraction, tint: DokiTheme.accent(hex: item.subject.accentHex), height: 4)
            }
            .padding(20)
        }
        .frame(width: width)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DokiTheme.heroRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DokiTheme.heroRadius, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.white.opacity(0.82) : Color.white.opacity(0.09),
                    lineWidth: isFocused ? 3 : 1
                )
        }
        .shadow(
            color: isFocused ? DokiTheme.accent(hex: item.subject.accentHex).opacity(0.28) : .clear,
            radius: 26,
            y: 10
        )
        .contentShape(RoundedRectangle(cornerRadius: DokiTheme.heroRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("继续观看 \(item.subject.title) 第 \(item.episode.number) 话"))
        .accessibilityValue(Text("已观看 \(Int(item.fraction * 100))%"))
    }
}

public struct DokiUpdateCard: View {
    public let entry: AiringEntry
    public var width: CGFloat = 220
    public init(entry: AiringEntry, width: CGFloat = 220) { self.entry = entry; self.width = width }
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DokiPosterTile(subject: entry.subject, badge: DokiBadge(entry.availability == .available ? "可播" : "计划", tone: .neutral), width: width)
            Text("第 \(entry.episode.number) 话 · \(DokiDate.time(entry.airDate))")
                .font(DokiType.caption).foregroundStyle(.secondary).lineLimit(1)
        }.frame(width: width)
    }
}

public struct DokiEpisodeChip: View {
    public let episode: Episode
    public let watched: Bool
    public let fraction: Double?
    public var isCurrent: Bool
    @Environment(\.isFocused) private var isFocused

    public init(
        episode: Episode,
        watched: Bool,
        fraction: Double? = nil,
        isCurrent: Bool = false
    ) {
        self.episode = episode
        self.watched = watched
        self.fraction = fraction
        self.isCurrent = isCurrent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(episode.sort.rounded() == episode.sort ? String(format: "%02d", episode.number) : episode.sort.formatted())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                if watched {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DokiTheme.accent)
                } else if isCurrent {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DokiTheme.accent)
                }
            }
            Text(episode.title)
                .font(DokiType.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let fraction, fraction > 0, fraction < 1 {
                DokiProgressBar(fraction: fraction, height: 3)
            } else if episode.availability != .available {
                Text(episode.availability.title)
                    .font(DokiType.micro)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(minWidth: 176, maxWidth: .infinity, alignment: .leading)
        .background(
            isFocused
                ? Color.white.opacity(0.14)
                : Color.primary.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    isFocused ? DokiTheme.accent.opacity(0.9) : Color.primary.opacity(0.09),
                    lineWidth: isFocused ? 2 : 1
                )
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("第 \(episode.number) 话 \(episode.title)\(watched ? "，已看完" : "")"))
    }
}
