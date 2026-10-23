import SwiftUI

/// Text that types itself in left to right, each character flickering
/// through 0s and 1s for a moment before it lands.
struct ScrambleText: View {
    let text: String
    var delay: Double = 0
    var perCharacter: Double = 0.045
    var flicker: Double = 0.3

    @State private var start = Date.now
    @State private var settled = false

    var body: some View {
        if settled {
            Text(text)
        } else {
            TimelineView(.periodic(from: .now, by: 1 / 30)) { timeline in
                Text(scrambled(at: timeline.date.timeIntervalSince(start)))
            }
            .task {
                let total = delay + Double(text.count) * perCharacter + 0.05
                try? await Task.sleep(for: .seconds(total))
                settled = true
            }
        }
    }

    private func scrambled(at time: Double) -> String {
        var output = ""
        for (index, character) in text.enumerated() {
            let landsAt = delay + Double(index) * perCharacter
            if time >= landsAt || character == " " {
                output.append(character)
            } else if time >= landsAt - flicker {
                let bit = DecodeMath.hash(index, Int(time * 30), 7) & 1
                output.append(bit == 0 ? "0" : "1")
            } else {
                break
            }
        }
        return output
    }
}
