import SwiftUI
import Observation

struct Shot: Identifiable, Hashable {
    let id = UUID()
    let imageName: String
    /// Seeds the shape of the decode front so neighbouring cells don't sweep in lockstep.
    let seed: Int
    var start: Date = .distantFuture
    var duration: Double = 2.4
    var isDecoded = false
}

@Observable
final class Board: Identifiable {
    enum Kind { case moodboard, generation }

    /// linking: cable is drawing, card hidden
    /// framing: card and empty cells pop in
    /// decoding: cells sweep from bits to pixels
    /// done: settled, cells open the detail view
    enum Phase { case linking, framing, decoding, done }

    let id = UUID()
    let kind: Kind
    let title: String
    let prompt: String
    var shots: [Shot]
    var phase: Phase
    let createdAt = Date()
    var elapsed: TimeInterval?

    init(kind: Kind, title: String, prompt: String, images: [String], phase: Phase) {
        self.kind = kind
        self.title = title
        self.prompt = prompt
        self.phase = phase
        self.shots = images.enumerated().map { index, name in
            Shot(imageName: name, seed: index * 17 + 3, isDecoded: phase == .done)
        }
    }

    var decodedCount: Int { shots.filter(\.isDecoded).count }
}

@MainActor
@Observable
final class Studio {
    static let startingCredits = 120

    private(set) var boards: [Board] = []
    var prompt = ""
    private(set) var isGenerating = false
    private(set) var credits = Studio.startingCredits
    /// Bumped every time a single image finishes decoding; drives haptics.
    private(set) var decodeTicks = 0

    let presets = Preset.all
    private var rotation = 0

    init() {
        reset()
    }

    func reset() {
        guard !isGenerating else { return }
        boards = [
            Board(kind: .moodboard, title: "Moodboard", prompt: "", images: Preset.moodboard, phase: .done)
        ]
        credits = Self.startingCredits
        rotation = 0
        prompt = ""
    }

    func generate() {
        guard !isGenerating else { return }
        let typed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let preset = pick(for: typed)
        let isCustom = !typed.isEmpty && typed != preset.prompt
        let board = Board(
            kind: .generation,
            title: isCustom ? Self.title(from: typed) : preset.title,
            prompt: isCustom ? typed : preset.prompt,
            images: preset.images,
            phase: .linking
        )

        isGenerating = true
        prompt = ""
        credits = max(0, credits - board.shots.count)
        withAnimation(.smooth(duration: 0.4)) {
            boards.append(board)
        }
        Task { await run(board) }
    }

    private func run(_ board: Board) async {
        // 1. the cable draws from the previous board
        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.spring(duration: 0.5, bounce: 0.22)) {
            board.phase = .framing
        }

        // 2. empty cells settle, title starts scrambling in
        try? await Task.sleep(for: .seconds(0.55))
        let begin = Date.now
        for index in board.shots.indices {
            board.shots[index].start = begin.addingTimeInterval(Double(index) * 0.32)
            board.shots[index].duration = 2.4
        }
        board.phase = .decoding

        // 3. cells finish in order; flip each to a plain image when its sweep ends
        for index in board.shots.indices {
            let shot = board.shots[index]
            let wait = shot.start.addingTimeInterval(shot.duration + 0.05).timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
            }
            board.shots[index].isDecoded = true
            decodeTicks += 1
        }

        withAnimation(.smooth) {
            board.elapsed = Date.now.timeIntervalSince(board.createdAt)
            board.phase = .done
        }
        isGenerating = false
    }

    private func pick(for text: String) -> Preset {
        if let exact = presets.first(where: { $0.prompt == text }) {
            return exact
        }
        let lowered = text.lowercased()
        let scored = presets.map { ($0, $0.score(lowered)) }
        if let best = scored.max(by: { $0.1 < $1.1 }), best.1 > 0 {
            return best.0
        }
        defer { rotation += 1 }
        return presets[rotation % presets.count]
    }

    /// "a quiet harbour at dawn, 35mm" -> "Quiet Harbour Dawn"
    static func title(from text: String) -> String {
        let skip: Set<String> = ["a", "an", "the", "of", "at", "in", "on", "and", "with", "to", "for"]
        let words = text
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !skip.contains($0.lowercased()) }
            .prefix(3)
            .map { $0.capitalized }
        let joined = words.joined(separator: " ")
        return joined.isEmpty ? "Untitled" : String(joined.prefix(24))
    }
}
