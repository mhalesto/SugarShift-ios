import AVFoundation

/// Plays bundled mp3 SFX from `SugarShift/Audio/` and a looping ambient music
/// track. Sounds courtesy of mixkit.co (Mixkit License — free for commercial
/// and personal use). Toggles in the settings panel gate playback via
/// `Persistence.soundEnabled` and `Persistence.musicEnabled`.
final class Audio {

    static let shared = Audio()

    enum SFX {
        case tap
        case swapClick
        case swapInvalid
        case match
        case combo(depth: Int)
        case bomb
        case jelly
        case crate
        case portal
        case conveyor
        case win
        case lose
    }

    // MARK: - Internals

    private let engine = AVAudioEngine()
    private let sfxMixer = AVAudioMixerNode()
    private let musicMixer = AVAudioMixerNode()
    private let musicPlayer = AVAudioPlayerNode()

    /// Pre-decoded PCM buffers, keyed by mp3 base name. Keeping decoded buffers
    /// in memory avoids a disk hit on every match — critical when 6+ smashes
    /// fire in quick succession during a cascade.
    private var sfxBuffers: [String: AVAudioPCMBuffer] = [:]
    private var musicBuffer: AVAudioPCMBuffer?
    private var musicLoopActive = false

    private init() {
        configureSession()
        setupEngine()
        preloadSFX()
    }

    // MARK: - Public API

    func play(_ sfx: SFX) {
        guard Persistence.soundEnabled else { return }
        let name = bufferName(for: sfx)
        guard let buffer = sfxBuffers[name] else { return }
        scheduleOneShot(buffer, maxDuration: maxDuration(for: sfx))
    }

    /// Hard cap each SFX so trailing silence/reverb in the source mp3 never
    /// turns a smash into a long ringing sustain. The punch is always at the
    /// start of these one-shot clips — anything past this cap is decoration.
    private func maxDuration(for sfx: SFX) -> TimeInterval {
        switch sfx {
        case .tap:          return 0.18
        case .swapClick:    return 0.20
        case .swapInvalid:  return 0.35
        case .match:        return 0.32
        case .combo:        return 0.50
        case .bomb:         return 0.70
        case .jelly:        return 0.28
        case .crate:        return 0.34
        case .portal:       return 0.24
        case .conveyor:     return 0.20
        case .win, .lose:   return 2.5
        }
    }

    /// Begin (or unmute) the ambient loop. Idempotent.
    func startMusic() {
        guard Persistence.musicEnabled else { return }
        guard !musicLoopActive else {
            musicMixer.outputVolume = 0.35
            return
        }
        if musicBuffer == nil { musicBuffer = loadBuffer(named: "music") }
        guard let buffer = musicBuffer else { return }
        if !musicPlayer.isPlaying {
            musicPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
            musicPlayer.play()
        }
        musicMixer.outputVolume = 0.35
        musicLoopActive = true
    }

    /// Mute the loop. Cheaper than stopping/restarting; the player keeps cycling.
    func stopMusic() {
        musicMixer.outputVolume = 0
        musicLoopActive = false
    }

    /// Reflect the current Persistence toggles. Call after settings change or
    /// when the scene appears.
    func syncWithPreferences() {
        if Persistence.musicEnabled { startMusic() }
        else { stopMusic() }
    }

    // MARK: - Engine setup

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        // .ambient + mixWithOthers lets the user keep their music app playing
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func setupEngine() {
        engine.attach(sfxMixer)
        engine.attach(musicMixer)
        engine.attach(musicPlayer)

        engine.connect(sfxMixer,   to: engine.mainMixerNode, format: nil)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(musicPlayer, to: musicMixer, format: nil)

        sfxMixer.outputVolume = 0.85
        musicMixer.outputVolume = 0

        do { try engine.start() }
        catch { Log.error(.audio, "engine start failed: \(error.localizedDescription)") }
    }

    // MARK: - SFX dispatch

    private func bufferName(for sfx: SFX) -> String {
        switch sfx {
        case .tap:          return "tap"
        case .swapClick:    return "swapClick"
        case .swapInvalid:  return "swapInvalid"
        case .match:        return "match"
        case .combo:        return "combo"
        case .bomb:         return "bomb"
        case .jelly:        return "match"
        case .crate:        return "swapInvalid"
        case .portal:       return "swapClick"
        case .conveyor:     return "tap"
        case .win:          return "win"
        case .lose:         return "lose"
        }
    }

    private func preloadSFX() {
        let names = [
            "tap", "swapClick", "swapInvalid",
            "match", "combo", "bomb", "win", "lose"
        ]
        for n in names {
            if let b = loadBuffer(named: n) { sfxBuffers[n] = b }
        }
    }

    private func loadBuffer(named: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: named, withExtension: "mp3")
                ?? Bundle.main.url(forResource: "Audio/" + named, withExtension: "mp3")
        else {
            Log.error(.audio, "missing \(named).mp3 in bundle")
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                           frameCapacity: AVAudioFrameCount(file.length))
            guard let buffer else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            Log.error(.audio, "failed to load \(named).mp3: \(error.localizedDescription)")
            return nil
        }
    }

    private func scheduleOneShot(_ buffer: AVAudioPCMBuffer, maxDuration: TimeInterval) {
        // Each SFX gets its own short-lived player so multiple can overlap.
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: sfxMixer, format: buffer.format)
        let toPlay = truncated(buffer, to: maxDuration) ?? buffer
        player.scheduleBuffer(toPlay, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async {
                self?.engine.detach(player)
            }
        }
        player.play()
    }

    /// Returns a copy of `source` containing only the first `maxDuration`
    /// seconds, with a quick linear fade on the last 10 ms so the cut isn't
    /// audible as a click. Returns nil if the source is already short enough
    /// or if buffer creation fails.
    private func truncated(_ source: AVAudioPCMBuffer,
                           to maxDuration: TimeInterval) -> AVAudioPCMBuffer? {
        let sr = source.format.sampleRate
        let cap = AVAudioFrameCount(maxDuration * sr)
        guard source.frameLength > cap, cap > 0 else { return nil }
        guard let out = AVAudioPCMBuffer(pcmFormat: source.format,
                                         frameCapacity: cap) else { return nil }
        out.frameLength = cap

        let channels = Int(source.format.channelCount)
        let fadeFrames = min(Int(sr * 0.010), Int(cap) / 4)

        if let src = source.floatChannelData, let dst = out.floatChannelData {
            for ch in 0..<channels {
                memcpy(dst[ch], src[ch], Int(cap) * MemoryLayout<Float>.size)
                // Linear fade-out on tail
                let start = Int(cap) - fadeFrames
                for i in 0..<fadeFrames {
                    let g = Float(fadeFrames - i) / Float(fadeFrames)
                    dst[ch][start + i] *= g
                }
            }
        } else if let src = source.int16ChannelData, let dst = out.int16ChannelData {
            for ch in 0..<channels {
                memcpy(dst[ch], src[ch], Int(cap) * MemoryLayout<Int16>.size)
                let start = Int(cap) - fadeFrames
                for i in 0..<fadeFrames {
                    let g = Float(fadeFrames - i) / Float(fadeFrames)
                    dst[ch][start + i] = Int16(Float(dst[ch][start + i]) * g)
                }
            }
        }
        return out
    }
}
