import Foundation

/// Tiny `UserDefaults` wrapper for the persistent values we need to survive
/// app relaunches: current level, total score, wallet, lives, shuffle stock,
/// and the +Moves quantity preference.
enum Persistence {

    private enum K {
        static let level         = "ss.currentLevel"
        static let totalScore    = "ss.totalScore"
        static let cash          = "ss.cash"
        static let lives         = "ss.lives"
        static let shuffleCount  = "ss.shuffleCount"
        static let movesQuantity = "ss.movesQuantity"
        static let hammerCount   = "ss.hammerCount"
        static let swapCount     = "ss.swapCount"
        static let sound         = "ss.soundEnabled"
        static let music         = "ss.musicEnabled"
        static let haptics       = "ss.hapticsEnabled"
        static let reduceMotion  = "ss.reduceMotion"
    }

    private static let d = UserDefaults.standard

    /// Returns either the stored int for `key` or the supplied default if no
    /// value has ever been written. Avoids `integer(forKey:)`'s "always 0"
    /// problem on first launch.
    private static func storedInt(_ key: String, default fallback: Int) -> Int {
        if d.object(forKey: key) == nil { return fallback }
        return d.integer(forKey: key)
    }

    static var currentLevel: Int {
        get { max(1, storedInt(K.level, default: 1)) }
        set { d.set(newValue, forKey: K.level) }
    }

    static var totalScore: Int {
        get { storedInt(K.totalScore, default: 0) }
        set { d.set(newValue, forKey: K.totalScore) }
    }

    static var cash: Int {
        get { storedInt(K.cash, default: 2553) }
        set { d.set(newValue, forKey: K.cash) }
    }

    static var lives: Int {
        get { storedInt(K.lives, default: 5) }
        set { d.set(newValue, forKey: K.lives) }
    }

    static var shuffleCount: Int {
        get { storedInt(K.shuffleCount, default: 2) }
        set { d.set(newValue, forKey: K.shuffleCount) }
    }

    static var movesQuantity: Int {
        get { storedInt(K.movesQuantity, default: 5) }
        set { d.set(newValue, forKey: K.movesQuantity) }
    }

    static var hammerCount: Int {
        get { storedInt(K.hammerCount, default: 0) }
        set { d.set(newValue, forKey: K.hammerCount) }
    }

    static var swapCount: Int {
        get { storedInt(K.swapCount, default: 0) }
        set { d.set(newValue, forKey: K.swapCount) }
    }

    private static func storedBool(_ key: String, default fallback: Bool) -> Bool {
        if d.object(forKey: key) == nil { return fallback }
        return d.bool(forKey: key)
    }

    static var soundEnabled: Bool {
        get { storedBool(K.sound, default: true) }
        set { d.set(newValue, forKey: K.sound) }
    }
    static var musicEnabled: Bool {
        get { storedBool(K.music, default: true) }
        set { d.set(newValue, forKey: K.music) }
    }
    static var hapticsEnabled: Bool {
        get { storedBool(K.haptics, default: true) }
        set { d.set(newValue, forKey: K.haptics) }
    }
    static var reduceMotion: Bool {
        get { storedBool(K.reduceMotion, default: false) }
        set { d.set(newValue, forKey: K.reduceMotion) }
    }

    /// Wipes progress (level, cash, lives, etc.) but preserves user prefs
    /// (sound/music/haptics/reduceMotion).
    static func resetAll() {
        [K.level, K.totalScore, K.cash, K.lives, K.shuffleCount,
         K.movesQuantity, K.hammerCount, K.swapCount]
            .forEach { d.removeObject(forKey: $0) }
    }
}
