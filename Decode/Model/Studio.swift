import SwiftUI
import Observation
import UIKit

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
    let ratio: AspectRatio
    let style: ImageStyle
    let model: GenModel
    let usedMoodboard: Bool
    let createdAt: Date
    var shots: [Shot]
    var phase: Phase
    var elapsed: TimeInterval?

    init(
        kind: Kind,
        title: String,
        prompt: String,
        images: [String],
        ratio: AspectRatio = .square,
        style: ImageStyle = .natural,
        model: GenModel = .standard,
        usedMoodboard: Bool = true,
        phase: Phase,
        createdAt: Date = .now,
        elapsed: TimeInterval? = nil
    ) {
        self.kind = kind
        self.title = title
        self.prompt = prompt
        self.ratio = ratio
        self.style = style
        self.model = model
        self.usedMoodboard = usedMoodboard
        self.phase = phase
        self.createdAt = createdAt
        self.elapsed = elapsed
        self.shots = images.enumerated().map { index, name in
            Shot(imageName: name, seed: index * 17 + 3, isDecoded: phase == .done)
        }
    }

    var decodedCount: Int { shots.filter(\.isDecoded).count }

    func route(for shot: Shot) -> ShotRoute {
        ShotRoute(
            id: shot.id,
            imageName: shot.imageName,
            title: title,
            prompt: prompt.isEmpty ? "Reference image from your moodboard." : prompt,
            seed: shot.seed,
            ratio: ratio,
            style: style,
            model: model
        )
    }
}

struct LibraryEntry: Identifiable {
    let id: UUID
    let route: ShotRoute
}

struct LibrarySection: Identifiable {
    let id: String
    let title: String
    let entries: [LibraryEntry]
}

@MainActor
@Observable
final class Studio {
    static let freeCredits = 240
    static let proCredits = 1000

    // Navigation
    var tab: AppTab = .create
    var createPath: [ShotRoute] = []
    var explorePath: [ShotRoute] = []
    var libraryPath: [ShotRoute] = []
    var showPaywall = false
    var onboardingPage = 0
    private(set) var hasOnboarded = UserDefaults.standard.bool(forKey: SettingsKey.hasOnboarded)

    // Canvas
    private(set) var boards: [Board] = []
    private(set) var history: [Board] = []
    var prompt = ""
    var style: ImageStyle = .natural
    var model: GenModel = .standard
    var count = 4
    /// Square only: the 2×2 then fits above the composer, so a recording
    /// catches every cell decoding.
    var ratio: AspectRatio = .square
    private(set) var usesMoodboard = true
    private(set) var isGenerating = false
    private(set) var isEnhancing = false

    // Account
    private(set) var credits = Studio.freeCredits
    private(set) var isPro = false
    private(set) var favorites: Set<String> = []

    // Signals
    /// Bumped every time a single image finishes decoding; drives haptics.
    private(set) var decodeTicks = 0
    /// Bumped to ask an open detail screen to replay its decode (used by the demo autopilot).
    var replayRequest = 0
    private(set) var toast: Toast?

    let presets = Preset.all
    let feed = FeedItem.all
    private var rotation = 0
    @ObservationIgnored private var enhanceTask: Task<Void, Never>?

    init() {
        history = Self.seedHistory()
        favorites = ["afterdark-2", "golden-2", "mist-1"]
        resetCanvas()
    }

    // MARK: Onboarding & navigation

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: SettingsKey.hasOnboarded)
        withAnimation(.smooth(duration: 0.5)) {
            hasOnboarded = true
            tab = .create
        }
    }

    func restartOnboarding() {
        UserDefaults.standard.set(false, forKey: SettingsKey.hasOnboarded)
        onboardingPage = 0
        withAnimation(.smooth(duration: 0.5)) {
            hasOnboarded = false
        }
    }

    func select(_ next: AppTab) {
        tab = next
    }

    // MARK: Canvas

    func resetCanvas() {
        guard !isGenerating else { return }
        boards = [
            Board(kind: .moodboard, title: "Moodboard", prompt: "", images: Preset.moodboard, phase: .done)
        ]
        rotation = 0
        prompt = ""
    }

    func toggleMoodboard() {
        usesMoodboard.toggle()
        show(usesMoodboard ? "Moodboard linked" : "Moodboard off", systemImage: "square.grid.2x2")
    }

    func generate() {
        guard !isGenerating else { return }
        let cost = count * model.cost
        guard credits >= cost else {
            showPaywall = true
            return
        }
        // A still-typing enhance would otherwise keep appending after the field clears.
        enhanceTask?.cancel()
        enhanceTask = nil
        isEnhancing = false
        let typed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let preset = pick(for: typed)
        let isCustom = !typed.isEmpty && typed != preset.prompt
        let board = Board(
            kind: .generation,
            title: isCustom ? Self.title(from: typed) : preset.title,
            prompt: isCustom ? typed : preset.prompt,
            images: Array(preset.images.prefix(count)),
            ratio: ratio,
            style: style,
            model: model,
            usedMoodboard: usesMoodboard,
            phase: .linking
        )

        isGenerating = true
        prompt = ""
        credits = max(0, credits - cost)
        withAnimation(.smooth(duration: 0.4)) {
            boards.append(board)
        }
        Self.warm(board.shots.map(\.imageName))
        Task { await run(board) }
    }

    /// Decodes the JPEGs and their ambient-light palettes off the main thread
    /// now, so the first decode frame isn't the one that pays for it.
    private static func warm(_ names: [String]) {
        for name in names {
            PaletteCache.shared.warm(name, columns: 3, rows: 3)
        }
        PhotoLibrary.shared.warm(names)
    }

    private func run(_ board: Board) async {
        let pace = SettingsKey.speed.multiplier

        // 1. the cable draws from the previous board
        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.spring(duration: 0.5, bounce: 0.22)) {
            board.phase = .framing
        }

        // 2. empty cells settle, title starts scrambling in
        try? await Task.sleep(for: .seconds(0.55))
        let begin = Date.now
        for index in board.shots.indices {
            board.shots[index].start = begin.addingTimeInterval(Double(index) * 0.32 * pace)
            board.shots[index].duration = 2.4 * pace
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

    /// Appends a few style words to the prompt, typed in like an assistant would.
    func enhance() {
        guard !isEnhancing, !isGenerating else { return }
        var base = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty {
            base = presets[rotation % presets.count].prompt
            prompt = base
        }
        let pool = [
            "cinematic lighting", "shot on 35mm film", "soft volumetric haze", "rich texture",
            "high detail", "editorial composition", "subtle grain", "natural colour",
        ]
        let seed = base.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        var picks: [String] = []
        var cursor = 0
        while picks.count < 3 {
            let candidate = pool[Int(DecodeMath.hash(seed, cursor, 41) % UInt32(pool.count))]
            if !picks.contains(candidate) { picks.append(candidate) }
            cursor += 1
        }
        let suffix = ", " + picks.joined(separator: ", ")

        isEnhancing = true
        enhanceTask = Task {
            for character in suffix {
                try? await Task.sleep(for: .milliseconds(16))
                if Task.isCancelled { return }
                prompt.append(character)
            }
            isEnhancing = false
        }
    }

    /// Types `text` into the prompt field one character at a time (demo autopilot).
    func type(_ text: String, perCharacter: Double = 0.045) async {
        prompt = ""
        for character in text {
            prompt.append(character)
            try? await Task.sleep(for: .seconds(perCharacter))
        }
    }

    // MARK: Results

    func remix(_ route: ShotRoute) {
        prompt = route.prompt
        style = route.style
        model = route.model
        createPath = []
        explorePath = []
        libraryPath = []
        tab = .create
        show("Prompt loaded", systemImage: "arrow.triangle.branch")
    }

    func vary(_ route: ShotRoute) {
        remix(route)
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            generate()
        }
    }

    func isFavorite(_ imageName: String) -> Bool {
        favorites.contains(imageName)
    }

    func toggleFavorite(_ imageName: String) {
        if favorites.contains(imageName) {
            favorites.remove(imageName)
            show("Removed from favourites", systemImage: "heart.slash")
        } else {
            favorites.insert(imageName)
            show("Added to favourites", systemImage: "heart.fill")
        }
    }

    func copyPrompt(_ text: String) {
        UIPasteboard.general.string = text
        show("Prompt copied", systemImage: "doc.on.doc")
    }

    func upgrade() {
        isPro = true
        credits = Self.proCredits
        showPaywall = false
        show("Welcome to Decode Pro", systemImage: "sparkles")
    }

    func show(_ message: String, systemImage: String = "checkmark.circle.fill") {
        let next = Toast(message: message, systemImage: systemImage)
        toast = next
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if toast?.id == next.id {
                toast = nil
            }
        }
    }

    // MARK: Library

    /// Images whose colours light the canvas edges: the newest finished board,
    /// else the moodboard. Not a decoding one: the lights sit behind every
    /// blur, so their cross-fade re-renders all of them, and doing that on
    /// top of a decode is what made it stutter.
    var ambientImages: [String] {
        let board = boards.last { $0.kind == .generation && $0.phase == .done } ?? boards.first
        return board?.shots.map(\.imageName) ?? Preset.moodboard
    }

    var generatedBoards: [Board] {
        (boards.filter { $0.kind == .generation } + history).sorted { $0.createdAt > $1.createdAt }
    }

    var imageCount: Int {
        generatedBoards.reduce(0) { $0 + $1.shots.count }
    }

    func librarySections(favoritesOnly: Bool) -> [LibrarySection] {
        let calendar = Calendar.current
        var sections: [LibrarySection] = []
        var currentDay: Date?
        var entries: [LibraryEntry] = []
        var title = ""

        func flush() {
            if let day = currentDay, !entries.isEmpty {
                sections.append(LibrarySection(id: "\(day.timeIntervalSince1970)", title: title, entries: entries))
            }
            entries = []
        }

        for board in generatedBoards where board.phase == .done {
            let day = calendar.startOfDay(for: board.createdAt)
            if day != currentDay {
                flush()
                currentDay = day
                title = Self.dayTitle(for: board.createdAt)
            }
            for shot in board.shots where !favoritesOnly || favorites.contains(shot.imageName) {
                entries.append(LibraryEntry(id: shot.id, route: board.route(for: shot)))
            }
        }
        flush()
        return sections
    }

    private static func dayTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private static func seedHistory() -> [Board] {
        let day: TimeInterval = 86_400
        let now = Date.now
        func board(_ id: String, _ count: Int, _ ratio: AspectRatio, _ style: ImageStyle, _ model: GenModel = .standard, ago: TimeInterval) -> Board? {
            guard let preset = Preset.all.first(where: { $0.id == id }) else { return nil }
            return Board(
                kind: .generation,
                title: preset.title,
                prompt: preset.prompt,
                images: Array(preset.images.prefix(count)),
                ratio: ratio,
                style: style,
                model: model,
                phase: .done,
                createdAt: now.addingTimeInterval(-ago),
                elapsed: 4.2
            )
        }
        return [
            board("mist", 4, .portrait, .natural, ago: day * 1 + 3_600),
            board("golden", 2, .square, .warm, ago: day * 1 + 7_200),
            board("stilllife", 4, .portrait, .cinematic, .pro, ago: day * 3),
            board("concrete", 4, .story, .mono, ago: day * 4),
        ].compactMap { $0 }
    }

    // MARK: Prompt matching

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
