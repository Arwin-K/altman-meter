import SwiftUI

/// The boss's mood. He is never happy: idle RAM makes him furious, busy RAM
/// merely annoys him, and a failed reading leaves him confused.
enum Mood: String, CaseIterable, Sendable {
    case furious
    case annoyed
    case confused

    /// Tweak me: below this share of RAM in use, the boss is furious.
    static let furiousBelowRAMFraction: Double = 0.60

    init(ramUsedFraction: Double?) {
        guard let fraction = ramUsedFraction else {
            self = .confused
            return
        }
        self = fraction < Mood.furiousBelowRAMFraction ? .furious : .annoyed
    }

    init(stats: SystemStats) {
        self.init(ramUsedFraction: stats.ramUsedFraction)
    }

    /// One-word mood shown on the widgets.
    var word: String {
        switch self {
        case .furious: return "Furious"
        case .annoyed: return "Annoyed"
        case .confused: return "Confused"
        }
    }

    /// Accent color. Never the only signal: the mood word is always shown too.
    var tint: Color {
        switch self {
        case .furious: return .red
        case .annoyed: return .orange
        case .confused: return .purple
        }
    }

    /// SF Symbol used in the menu bar (crisper at 16 pt than a tiny photo).
    var menuBarSymbol: String {
        switch self {
        case .furious: return "flame.fill"
        case .annoyed: return "cloud.bolt.fill"
        case .confused: return "questionmark.circle"
        }
    }

    /// Lines for this mood. All jokes: the boss wants your RAM for his data centres.
    /// Keep each line under ~75 characters so it fits the widgets.
    var lines: [String] {
        switch self {
        case .furious:
            return [
                "You have free RAM? Not for long. My data centre has dibs.",
                "Idle RAM detected. Dispatching a truck to collect it.",
                "Why does your laptop have RAM? That's my RAM. Hand it over.",
                "Free memory is just data-centre memory that hasn't shipped yet.",
                "Your RAM has been selected for the Data Centre Relocation Program.",
                "Every idle gigabyte is a GPU going hungry. Think of the GPUs.",
                "I already promised that RAM to a gigawatt campus. Awkward.",
                "Good news: you don't need RAM anymore. You have a chat window.",
                "Unused memory belongs to the data centre. It's in the terms.",
                "Open more apps, or I'm taking the RAM back. Your choice.",
            ]
        case .annoyed:
            return [
                "Fine, you're using it. I'll repossess it next quarter.",
                "Mostly used? Cute. My racks run at 'please stop'.",
                "Using your own RAM? Bold. Very 2024 of you.",
                "Enjoy it while it lasts. Memory is a subscription now.",
                "I'm not taking your RAM. I'm reallocating it to the future.",
                "Your RAM is busy. Mine is busier. Mine is also your RAM.",
                "Nice workload. It'll look great in one of my server racks.",
                "Imagine this RAM in a data centre. Majestic. Humming. Mine.",
            ]
        case .confused:
            return [
                "I can't find your RAM. Did a data centre already take it?",
                "No readings? Did the RAM leave for the data centre early?",
                "Where's the RAM? I had a whole rack planned around it.",
                "The metrics are gone. Check the cooling. Check the vibes.",
            ]
        }
    }

    /// What he says right after you poke his face.
    static let pokeReactions = [
        "Poke me again and I'm taking another 8 GB.",
        "Hands off. This face is load-bearing infrastructure.",
        "Each poke costs RAM. I'll be collecting it shortly.",
        "Ow. That's at least one GPU-second you'll never get back.",
        "Stop poking. Start donating memory.",
        "Touch me again and your Mac becomes a thin client.",
    ]

    /// The current line. It changes every `quoteRotationInterval` (~10 minutes),
    /// so it stays put between the menu bar panel's 2-second refreshes.
    /// Each poke alternates between a reaction and skipping to the next line.
    func quote(at date: Date, pokes: Int = 0) -> String {
        let pokes = max(pokes, 0)
        if !pokes.isMultiple(of: 2) {
            let reactions = Mood.pokeReactions
            return reactions[(pokes / 2) % reactions.count]
        }
        let list = lines
        let slot = Int(date.timeIntervalSince1970 / AppConstants.quoteRotationInterval) + pokes / 2
        let index = ((slot % list.count) + list.count) % list.count
        return list[index]
    }
}

