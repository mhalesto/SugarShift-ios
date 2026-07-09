import Foundation

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum LevelSeed {
    static func make(level: Int, attempt: Int = 0, salt: UInt64 = 0) -> UInt64 {
        var value = UInt64(max(1, level)) &* 0xD6E8FEB86659FD93
        value ^= UInt64(max(0, attempt)) &* 0xA0761D6478BD642F
        value ^= salt &* 0xE7037ED1A0B428DB
        return value == 0 ? 0xC0FFEE1234567890 : value
    }

    static func liveAttempt(level: Int) -> UInt64 {
        let millis = UInt64(Date().timeIntervalSince1970 * 1_000)
        return make(level: level, attempt: Int(millis & 0xFFFF), salt: millis)
    }

    /// Seed for the shared daily challenge board. Derived from the UTF-8 bytes
    /// of the date key with FNV-1a so it is identical on every device — never
    /// use `String.hashValue` here, it is randomized per process.
    static func dailySeed(dateKey: String, level: Int) -> UInt64 {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in dateKey.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }
        return make(level: level, attempt: 0, salt: hash)
    }
}
