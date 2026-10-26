import Foundation

/// Stable pseudo-random numbers shared by the small Swift-side flickers
/// (title scramble, send button readout, avatars). The binary reveal itself
/// runs in `Shaders.metal`, which carries the same hash so both sides agree.
enum DecodeMath {
    static func hash(_ a: Int, _ b: Int, _ c: Int) -> UInt32 {
        var h = UInt32(truncatingIfNeeded: a) &* 0x8DA6_B343
        h ^= UInt32(truncatingIfNeeded: b) &* 0xD816_3841
        h ^= UInt32(truncatingIfNeeded: c) &* 0xCB1A_B31F
        h ^= h >> 15
        h &*= 0x2C1B_3C6D
        h ^= h >> 12
        h &*= 0x297A_2D39
        h ^= h >> 15
        return h
    }

    /// Stable pseudo-random value in 0...1.
    static func random(_ a: Int, _ b: Int, _ c: Int) -> Double {
        Double(hash(a, b, c)) / Double(UInt32.max)
    }
}
