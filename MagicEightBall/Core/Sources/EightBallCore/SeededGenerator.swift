import Foundation

/// A deterministic SplitMix64 generator.
///
/// Used so that the same question, asked on the same day, gets the same answer —
/// the ball "remembers", which stops reroll-spamming until you like the result
/// (and makes the whole thing unit testable).
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        // A zero state is a valid SplitMix64 seed, but starting from the golden
        // ratio constant gives better first-draw dispersion for adjacent seeds.
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum FNV1a {
    static func hash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
