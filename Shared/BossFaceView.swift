import SwiftUI
import AppKit

/// The boss's head as a die-cut sticker.
///
/// It uses cut-out PNGs named `boss-furious`, `boss-annoyed` and `boss-confused`
/// from `Shared/Photos/` when they're in the bundle (make them with
/// `Tools/MakeSticker.swift`), and draws an original cartoon boss when they aren't.
/// Either way the mood gets cartoon extras: angry brows, gritted teeth and steam
/// when furious, a throbbing anger mark when annoyed, a question mark when confused.
///
/// `animated` (menu bar panel only) makes him shake, sway or tilt. Widgets are
/// static snapshots, so they leave it off. Changing `pokes` plays a squish.
struct BossFaceView: View {
    let mood: Mood
    var size: CGFloat = 64
    var animated = false
    var pokes = 0

    var body: some View {
        let face = ZStack {
            Group {
                if let photo = BossPhotos.image(for: mood) {
                    PhotoFace(photo: photo, mood: mood, size: size)
                } else {
                    CartoonFace(mood: mood, size: size)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: max(2, size * 0.045)))
                }
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.3), radius: size * 0.035, x: 0, y: size * 0.025)

            MoodDecoration(mood: mood, size: size, animated: animated)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(mood.stickerTilt))

        Group {
            if animated {
                face.modifier(LivelyFace(mood: mood, pokes: pokes))
            } else {
                face
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The boss looks \(mood.word.lowercased())")
    }
}

/// The boss's face as a button: clicking it pokes him (new line + squish).
struct PokeableFace: View {
    enum Action {
        /// Inside a desktop widget: runs `PokeBossIntent` in the widget extension.
        case widgetIntent
        /// In the app: runs a closure.
        case perform(() -> Void)
        case none
    }

    let mood: Mood
    var size: CGFloat
    var animated = false
    var pokes = 0
    var action: Action = .none

    var body: some View {
        let face = BossFaceView(mood: mood, size: size, animated: animated, pokes: pokes)
        switch action {
        case .widgetIntent:
            Button(intent: PokeBossIntent()) { face }
                .buttonStyle(.plain)
        case let .perform(poke):
            Button(action: poke) { face }
                .buttonStyle(.plain)
                .help("Poke him")
        case .none:
            face
        }
    }
}

extension Mood {
    /// A slight sticker-on-a-laptop tilt.
    var stickerTilt: Double {
        switch self {
        case .furious: return -3
        case .annoyed: return 4
        case .confused: return -5
        }
    }
}

// MARK: - Panel animations

private struct Squish {
    var x = 1.0
    var y = 1.0
}

/// Idle animation per mood, plus a squash-and-stretch when poked.
private struct LivelyFace: ViewModifier {
    let mood: Mood
    let pokes: Int

    func body(content: Content) -> some View {
        content
            .phaseAnimator(phases) { view, angle in
                view.rotationEffect(.degrees(angle), anchor: .bottom)
            } animation: { angle in
                switch mood {
                // Shake in short bursts, then hold still for a moment.
                case .furious: return angle == 0 ? .easeInOut(duration: 0.08).delay(1.1) : .easeInOut(duration: 0.07)
                case .annoyed: return .easeInOut(duration: 1.4)
                case .confused: return .easeInOut(duration: 1.1)
                }
            }
            .keyframeAnimator(initialValue: Squish(), trigger: pokes) { view, squish in
                view.scaleEffect(x: squish.x, y: squish.y, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.x) {
                    CubicKeyframe(1.18, duration: 0.08)
                    CubicKeyframe(0.9, duration: 0.12)
                    SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
                }
                KeyframeTrack(\.y) {
                    CubicKeyframe(0.78, duration: 0.08)
                    CubicKeyframe(1.12, duration: 0.12)
                    SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
                }
            }
    }

    private var phases: [Double] {
        switch mood {
        case .furious: return [0, -4, 4, -4, 4, -2]
        case .annoyed: return [-2, 2]
        case .confused: return [-7, 5]
        }
    }
}

/// Gentle pulse/bob for the cartoon extras while the panel is open.
private struct Bob: ViewModifier {
    let active: Bool
    var scale: CGFloat = 0.08
    var lift: CGFloat = 0
    var duration: Double = 0.6

    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([false, true]) { view, up in
                view.scaleEffect(up ? 1 + scale : 1 - scale).offset(y: up ? -lift : lift)
            } animation: { _ in .easeInOut(duration: duration) }
        } else {
            content
        }
    }
}

// MARK: - Photos

/// Loads (and caches) the optional cut-out photos from the current bundle. In the
/// widget extension that's the widget's own bundle, which gets its own copy.
enum BossPhotos {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for mood: Mood) -> NSImage? {
        let name = "boss-\(mood.rawValue)"
        if let cached = cache.object(forKey: name as NSString) { return cached }
        for ext in ["png", "jpg", "jpeg"] {
            let url = Bundle.main.url(forResource: name, withExtension: ext)
                ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Photos")
            if let url, let image = NSImage(contentsOf: url) {
                cache.setObject(image, forKey: name as NSString)
                return image
            }
        }
        return nil
    }
}

/// Where the brows and mouth sit on a face, in 0...1 coordinates of the square image.
private struct FaceGeometry {
    var leftBrow: (CGPoint, CGPoint)
    var rightBrow: (CGPoint, CGPoint)
    var mouthCenter: CGPoint
    var mouthSize: CGSize

    /// Measured on `Shared/Photos/boss-furious.png` with Apple's Vision face landmarks
    /// (`Tools/MakeSticker.swift` prints them). Brows tilt down toward the nose.
    static let furiousPhoto = FaceGeometry(
        leftBrow: (CGPoint(x: 0.23, y: 0.39), CGPoint(x: 0.41, y: 0.465)),
        rightBrow: (CGPoint(x: 0.48, y: 0.465), CGPoint(x: 0.67, y: 0.39)),
        mouthCenter: CGPoint(x: 0.456, y: 0.80),
        mouthSize: CGSize(width: 0.25, height: 0.09)
    )

    static let cartoonFurious = FaceGeometry(
        leftBrow: (CGPoint(x: 0.24, y: 0.35), CGPoint(x: 0.45, y: 0.44)),
        rightBrow: (CGPoint(x: 0.55, y: 0.44), CGPoint(x: 0.76, y: 0.35)),
        mouthCenter: CGPoint(x: 0.5, y: 0.73),
        mouthSize: CGSize(width: 0.36, height: 0.13)
    )
}

private struct PhotoFace: View {
    let photo: NSImage
    let mood: Mood
    let size: CGFloat

    var body: some View {
        ZStack {
            Image(nsImage: photo)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)

            if mood == .furious {
                AngryFeatures(geometry: .furiousPhoto, size: size)
            }
        }
    }
}

// MARK: - Cartoon fallback (original drawing, used when there are no photos)

private struct CartoonFace: View {
    let mood: Mood
    let size: CGFloat

    private var skin: Color {
        mood == .furious ? Color(red: 0.92, green: 0.38, blue: 0.32) : Color(red: 0.97, green: 0.83, blue: 0.70)
    }
    private let hair = Color(red: 0.30, green: 0.24, blue: 0.20)
    private let ink = Color(white: 0.12)

    var body: some View {
        let s = size
        ZStack {
            skin
            // Messy hair cap.
            Ellipse().fill(hair)
                .frame(width: s * 1.1, height: s * 0.62)
                .position(x: s * 0.5, y: s * 0.06)
            // Eyes.
            ForEach([0.37, 0.63], id: \.self) { x in
                Ellipse().fill(ink)
                    .frame(width: s * 0.075, height: mood == .annoyed ? s * 0.045 : s * 0.09)
                    .position(x: s * x, y: s * 0.52)
            }
            switch mood {
            case .furious:
                AngryFeatures(geometry: .cartoonFurious, size: s)
            case .annoyed:
                Segment(from: CGPoint(x: 0.26, y: 0.41), to: CGPoint(x: 0.45, y: 0.44))
                    .stroke(ink, style: StrokeStyle(lineWidth: s * 0.05, lineCap: .round))
                Segment(from: CGPoint(x: 0.55, y: 0.44), to: CGPoint(x: 0.74, y: 0.41))
                    .stroke(ink, style: StrokeStyle(lineWidth: s * 0.05, lineCap: .round))
                Segment(from: CGPoint(x: 0.38, y: 0.75), to: CGPoint(x: 0.63, y: 0.72))
                    .stroke(ink, style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))
            case .confused:
                Segment(from: CGPoint(x: 0.27, y: 0.36), to: CGPoint(x: 0.45, y: 0.38))
                    .stroke(ink, style: StrokeStyle(lineWidth: s * 0.05, lineCap: .round))
                Segment(from: CGPoint(x: 0.56, y: 0.44), to: CGPoint(x: 0.74, y: 0.44))
                    .stroke(ink, style: StrokeStyle(lineWidth: s * 0.05, lineCap: .round))
                WavyMouth()
                    .stroke(ink, style: StrokeStyle(lineWidth: s * 0.04, lineCap: .round, lineJoin: .round))
                    .frame(width: s * 0.3, height: s * 0.07)
                    .position(x: s * 0.5, y: s * 0.74)
            }
        }
        .frame(width: s, height: s)
    }
}

// MARK: - Cartoon pieces

/// Angry brows and gritted teeth, placed using a `FaceGeometry`.
private struct AngryFeatures: View {
    let geometry: FaceGeometry
    let size: CGFloat

    var body: some View {
        let s = size
        let brow = StrokeStyle(lineWidth: max(2, s * 0.06), lineCap: .round)
        ZStack {
            Segment(from: geometry.leftBrow.0, to: geometry.leftBrow.1)
                .stroke(Color(white: 0.08), style: brow)
            Segment(from: geometry.rightBrow.0, to: geometry.rightBrow.1)
                .stroke(Color(white: 0.08), style: brow)
            GrittedTeeth()
                .frame(width: s * geometry.mouthSize.width, height: s * geometry.mouthSize.height)
                .position(x: s * geometry.mouthCenter.x, y: s * geometry.mouthCenter.y)
        }
        .frame(width: s, height: s)
    }
}

private struct GrittedTeeth: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let shape = RoundedRectangle(cornerRadius: h * 0.35, style: .continuous)
            ZStack {
                shape.fill(Color.white)
                Path { path in
                    for i in 1..<6 {
                        let x = w * CGFloat(i) / 6
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: h))
                    }
                    path.move(to: CGPoint(x: 0, y: h / 2))
                    path.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(Color(white: 0.25), lineWidth: max(0.6, h * 0.08))
                shape.strokeBorder(Color(white: 0.08), lineWidth: max(1, h * 0.13))
            }
            .clipShape(shape)
        }
    }
}

/// Steam, an anger mark or question marks, drawn around the head.
private struct MoodDecoration: View {
    let mood: Mood
    let size: CGFloat
    let animated: Bool

    var body: some View {
        let s = size
        ZStack {
            switch mood {
            case .furious:
                SteamPuffs(size: s, mirrored: false)
                    .modifier(Bob(active: animated, scale: 0.06, lift: s * 0.02, duration: 0.45))
                SteamPuffs(size: s, mirrored: true)
                    .modifier(Bob(active: animated, scale: 0.06, lift: s * 0.02, duration: 0.55))
            case .annoyed:
                ZStack {
                    AngerMark()
                        .stroke(Color.white, style: StrokeStyle(lineWidth: s * 0.08, lineCap: .round))
                    AngerMark()
                        .stroke(Color.red, style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))
                }
                .frame(width: s * 0.26, height: s * 0.26)
                .modifier(Bob(active: animated, scale: 0.15, duration: 0.35))
                .position(x: s * 0.84, y: s * 0.14)
            case .confused:
                questionMark(size: s * 0.36)
                    .modifier(Bob(active: animated, scale: 0.05, lift: s * 0.03, duration: 0.7))
                    .position(x: s * 0.9, y: s * 0.12)
                questionMark(size: s * 0.2)
                    .rotationEffect(.degrees(20))
                    .modifier(Bob(active: animated, scale: 0.05, lift: s * 0.02, duration: 0.9))
                    .position(x: s * 0.97, y: s * 0.4)
            }
        }
        .frame(width: s, height: s)
        .allowsHitTesting(false)
    }

    private func questionMark(size: CGFloat) -> some View {
        Text("?")
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(mood.tint)
            .shadow(color: .white, radius: 0, x: 1.5, y: 1.5)
            .shadow(color: .white, radius: 0, x: -1.5, y: -1.5)
    }
}

/// A cloud of steam blowing out of each ear, plus a wavy fume line.
private struct SteamPuffs: View {
    let size: CGFloat
    let mirrored: Bool

    var body: some View {
        let s = size
        // (x, y, diameter) as fractions of the face, for the left side.
        // Overlapping circles merge into one cloud.
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (0.09, 0.33, 0.17), (0.04, 0.23, 0.15), (0.12, 0.2, 0.13), (0.06, 0.12, 0.11),
        ]
        let outline = max(1, s * 0.02)
        ZStack {
            // Outline layer first, then the fill on top, so the cloud has one outer edge.
            ForEach(puffs.indices, id: \.self) { i in
                let (x, y, d) = puffs[i]
                Circle()
                    .fill(Color(white: 0.55))
                    .frame(width: s * d + outline * 2, height: s * d + outline * 2)
                    .position(x: s * (mirrored ? 1 - x : x), y: s * y)
            }
            ForEach(puffs.indices, id: \.self) { i in
                let (x, y, d) = puffs[i]
                Circle()
                    .fill(Color(white: 0.97))
                    .frame(width: s * d, height: s * d)
                    .position(x: s * (mirrored ? 1 - x : x), y: s * y)
            }
            FumeLine()
                .stroke(Color(white: 0.55), style: StrokeStyle(lineWidth: max(1, s * 0.025), lineCap: .round))
                .frame(width: s * 0.05, height: s * 0.14)
                .position(x: s * (mirrored ? 0.92 : 0.08), y: s * 0.01)
        }
        .frame(width: s, height: s)
    }
}

/// A short vertical squiggle.
private struct FumeLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX - rect.width, y: rect.maxY - rect.height / 3),
            control2: CGPoint(x: rect.maxX + rect.width, y: rect.minY + rect.height / 3)
        )
        return path
    }
}

/// A line between two points given in 0...1 coordinates.
private struct Segment: Shape {
    var from: CGPoint
    var to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + from.x * rect.width, y: rect.minY + from.y * rect.height))
        path.addLine(to: CGPoint(x: rect.minX + to.x * rect.width, y: rect.minY + to.y * rect.height))
        return path
    }
}

/// The comic "anger vein" mark: four curved ticks around a center.
private struct AngerMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for (dx, dy) in [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)] {
            path.move(to: CGPoint(x: c.x + dx * r * 0.22, y: c.y + dy * r))
            path.addQuadCurve(
                to: CGPoint(x: c.x + dx * r, y: c.y + dy * r * 0.22),
                control: CGPoint(x: c.x + dx * r * 0.22, y: c.y + dy * r * 0.22)
            )
        }
        return path
    }
}

private struct WavyMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 4
        let w = rect.width / CGFloat(steps)
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for i in 0..<steps {
            let x = rect.minX + w * CGFloat(i + 1)
            let y = i.isMultiple(of: 2) ? rect.minY : rect.maxY
            path.addQuadCurve(to: CGPoint(x: x, y: rect.midY), control: CGPoint(x: x - w / 2, y: y))
        }
        return path
    }
}

#Preview("Faces") {
    HStack(spacing: 30) {
        ForEach(Mood.allCases, id: \.self) { mood in
            VStack {
                BossFaceView(mood: mood, size: 120, animated: true)
                Text(mood.word)
            }
        }
    }
    .padding(40)
}
