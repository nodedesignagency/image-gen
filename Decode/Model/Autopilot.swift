import Foundation

/// Hands-free demo: types prompts, generates, opens a result and tours the tabs.
/// Start it from Profile → Play demo, or launch with `-autopilot YES`
/// (that variant also replays onboarding first).
@MainActor
enum Autopilot {
    private static var isRunning = false

    nonisolated static var isRequestedAtLaunch: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.autopilot)
    }

    static func run(_ studio: Studio, fromLaunch: Bool) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        if fromLaunch {
            studio.restartOnboarding()
            await pause(2.2) // splash
        }

        if !studio.hasOnboarded {
            await pause(2.6)
            studio.onboardingPage = 1
            await pause(2.8)
            studio.onboardingPage = 2
            await pause(2.6)
            studio.finishOnboarding()
            await pause(1.0)
        }

        studio.createPath = []
        studio.select(.create)
        studio.count = 4
        studio.ratio = .portrait
        studio.style = .natural
        studio.resetCanvas()
        await pause(1.0)

        // Take 1: a typed prompt, four portrait images.
        await studio.type("neon towers at night, shot looking straight up")
        await pause(0.5)
        studio.generate()
        await pause(5.4)

        // Take 2: enhance a short prompt, two square images in a different style.
        studio.count = 2
        studio.ratio = .square
        studio.style = .cinematic
        await pause(0.6)
        await studio.type("quiet ocean, glowing jellyfish")
        await pause(0.4)
        studio.enhance()
        await pause(1.2)
        while studio.isEnhancing {
            await pause(0.1)
        }
        await pause(0.4)
        studio.generate()
        await pause(4.8)

        // Open a result and replay its decode full size.
        if let board = studio.boards.last, let shot = board.shots.first {
            studio.createPath = [board.route(for: shot)]
            await pause(1.4)
            studio.replayRequest += 1
            await pause(3.9)
            studio.toggleFavorite(shot.imageName)
            await pause(1.6)
            studio.createPath = []
            await pause(1.2)
        }

        // Tour the rest of the app.
        studio.select(.explore)
        await pause(3.4)
        studio.select(.library)
        await pause(2.8)
        studio.select(.profile)
        await pause(2.6)
        studio.select(.create)
        studio.count = 4
        studio.ratio = .portrait
        studio.style = .natural
    }

    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}
