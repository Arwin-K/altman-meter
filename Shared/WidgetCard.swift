import SwiftUI
import WidgetKit

/// Background used by the desktop widget and the menu bar panel's card:
/// the system window color with a faint wash of the mood color.
struct CardBackground: View {
    let mood: Mood

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [mood.tint.opacity(0.22), mood.tint.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

/// "FURIOUS" / "ANNOYED" / "CONFUSED" pill.
struct MoodBadge: View {
    let mood: Mood
    var fontSize: CGFloat = 10

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let color = renderingMode == .fullColor ? mood.tint : Color.primary
        Text(mood.word.uppercased())
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, fontSize * 0.6)
            .padding(.vertical, fontSize * 0.2)
            .background(color.opacity(0.15), in: Capsule())
            .lineLimit(1)
            .fixedSize()
    }
}

/// Sam Altman's current line.
struct QuoteText: View {
    let text: String
    var size: CGFloat = 12
    var lineLimit = 3

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.7)
    }
}

/// Which side of the speech bubble the tail sticks out of.
enum BubbleTail { case top, leading }

/// A comic speech bubble whose tail points at Sam Altman.
struct SpeechBubble<Content: View>: View {
    typealias Tail = BubbleTail

    var tail: Tail = .top
    /// Where the tail sits, measured from the bubble's leading edge (`.top`) or top edge (`.leading`).
    var tailPosition: CGFloat = 24
    @ViewBuilder var content: Content

    private let tailSize: CGFloat = 7

    var body: some View {
        let shape = BubbleShape(tail: tail, tailPosition: tailPosition, tailSize: tailSize)
        content
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .padding(tail == .top ? .top : .leading, tailSize)
            .background {
                shape.fill(Color(nsColor: .textBackgroundColor).opacity(0.92))
                shape.stroke(Color.primary.opacity(0.22), lineWidth: 1)
            }
    }
}

private struct BubbleShape: Shape {
    let tail: BubbleTail
    let tailPosition: CGFloat
    let tailSize: CGFloat

    func path(in rect: CGRect) -> Path {
        let body = CGRect(
            x: rect.minX + (tail == .leading ? tailSize : 0),
            y: rect.minY + (tail == .top ? tailSize : 0),
            width: rect.width - (tail == .leading ? tailSize : 0),
            height: rect.height - (tail == .top ? tailSize : 0)
        )
        let r = min(10, body.height / 2, body.width / 2)
        var p = Path()
        switch tail {
        case .top:
            let x = min(max(rect.minX + tailPosition, body.minX + r + tailSize), body.maxX - r - tailSize)
            p.move(to: CGPoint(x: body.minX + r, y: body.minY))
            p.addLine(to: CGPoint(x: x - tailSize, y: body.minY))
            p.addLine(to: CGPoint(x: x - tailSize * 0.4, y: rect.minY))
            p.addLine(to: CGPoint(x: x + tailSize * 0.6, y: body.minY))
            p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.maxY), radius: r)
            p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY), radius: r)
            p.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.minY), radius: r)
            p.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY), radius: r)
        case .leading:
            let y = min(max(rect.minY + tailPosition, body.minY + r + tailSize), body.maxY - r - tailSize)
            p.move(to: CGPoint(x: body.minX, y: body.minY + r))
            p.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY), radius: r)
            p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.maxY), radius: r)
            p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY), radius: r)
            p.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.minY), radius: r)
            p.addLine(to: CGPoint(x: body.minX, y: y + tailSize * 0.6))
            p.addLine(to: CGPoint(x: rect.minX, y: y - tailSize * 0.2))
            p.addLine(to: CGPoint(x: body.minX, y: y - tailSize))
        }
        p.closeSubpath()
        return p
    }
}

/// The medium-size card: Sam Altman's head with a speech bubble on the left, stats
/// on the right. Used by the medium desktop widget and, unchanged, by the menu
/// bar panel so both look the same.
struct WidgetCard: View {
    let stats: SystemStats
    var pokes = 0
    var poke: PokeableAltmanFace.Action = .none
    /// Panel only: idle animations, and a "Live" time with seconds.
    var live = false

    var body: some View {
        // Sizes follow the space macOS actually gives the widget, which varies by
        // display and macOS version, so nothing gets clipped.
        GeometryReader { proxy in
            let mood = Mood(stats: stats)
            let face = min(66, proxy.size.height * 0.42)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .center, spacing: 6) {
                        PokeableAltmanFace(mood: mood, size: face, animated: live, pokes: pokes, action: poke)
                        VStack(alignment: .leading, spacing: 3) {
                            MoodBadge(mood: mood)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(live ? "Live" : "Sampled")
                                Text(live ? stats.sampledAt.formatted(date: .omitted, time: .standard) : StatFormat.time(stats.sampledAt))
                            }
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    SpeechBubble(tail: .top, tailPosition: face * 0.45) {
                        QuoteText(text: mood.quote(at: stats.sampledAt, pokes: pokes), size: 11, lineLimit: 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .layoutPriority(-1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 0) {
                    StatRow.ram(stats, mood: mood)
                    Spacer(minLength: 4)
                    StatRow.disk(stats)
                    Spacer(minLength: 4)
                    StatRow.battery(stats)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

#Preview("Card") {
    WidgetCard(stats: .previewFurious, live: true)
        .padding(16)
        .frame(width: 340, height: 170)
        .background(CardBackground(mood: .furious))
}
