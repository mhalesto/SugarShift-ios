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
        case fruitBreak
        case stripe
        case wrapped
        case fish
        case colorCharge
        case landing
        case smashReady
        case smash
        case win
        case lose
    }

    // MARK: - Internals

    private let engine = AVAudioEngine()
    private let sfxMixer = AVAudioMixerNode()
    private let musicMixer = AVAudioMixerNode()
    private let musicPlayer = AVAudioPlayerNode()
    /// AVAudioEngine graph mutations must be serialized. Completion callbacks
    /// arrive on an audio thread, so they return to this queue before detaching
    /// their short-lived nodes.
    private let audioQueue = DispatchQueue(label: "com.sugarshift.audio.engine")

    /// Pre-decoded PCM buffers, keyed by mp3 base name. Keeping decoded buffers
    /// in memory avoids a disk hit on every match — critical when 6+ smashes
    /// fire in quick succession during a cascade.
    private var sfxBuffers: [String: AVAudioPCMBuffer] = [:]
    private var musicBuffer: AVAudioPCMBuffer?
    private var musicLoopActive = false
    private var musicDuckGeneration = 0

    private init() {
        configureSession()
        setupEngine()
        preloadSFX()
    }

    // MARK: - Public API

    func play(_ sfx: SFX, pan: Float? = nil) {
        guard Persistence.soundEnabled else { return }
        let name = bufferName(for: sfx)
        guard let buffer = sfxBuffers[name] else { return }
        let duration = maxDuration(for: sfx)
        var treatment = playbackTreatment(for: sfx)
        if let pan { treatment.pan = max(-1, min(1, pan)) }
        audioQueue.async { [weak self] in
            guard Persistence.soundEnabled else { return }
            self?.scheduleOneShot(buffer,
                                  maxDuration: duration,
                                  treatment: treatment)
        }
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
        case .fruitBreak:   return 0.12
        case .stripe:       return 0.28
        case .wrapped:      return 0.34
        case .fish:         return 0.20
        case .colorCharge:  return 0.42
        case .landing:      return 0.09
        case .smashReady:   return 0.36
        case .smash:        return 0.58
        case .win, .lose:   return 2.5
        }
    }

    /// Briefly makes room in the mix for a major impact. Generation tracking
    /// prevents an older restore callback from cancelling a newer duck.
    func duckMusic(for duration: TimeInterval, to volume: Float = 0.12) {
        audioQueue.async { [weak self] in
            guard let self, self.musicLoopActive else { return }
            self.musicDuckGeneration += 1
            let generation = self.musicDuckGeneration
            self.musicMixer.outputVolume = max(0, min(0.35, volume))
            self.audioQueue.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self,
                      self.musicLoopActive,
                      self.musicDuckGeneration == generation else { return }
                self.musicMixer.outputVolume = 0.35
            }
        }
    }

    /// Begin (or unmute) the ambient loop. Idempotent.
    func startMusic() {
        audioQueue.async { [weak self] in
            guard Persistence.musicEnabled else { return }
            self?.startMusicOnQueue()
        }
    }

    private func startMusicOnQueue() {
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
        audioQueue.async { [weak self] in
            self?.musicMixer.outputVolume = 0
            self?.musicLoopActive = false
        }
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
        case .fruitBreak:   return "fruitBreak"
        case .stripe:       return "stripe"
        case .wrapped:      return "wrapped"
        case .fish:         return "fish"
        case .colorCharge:  return "colorCharge"
        case .landing:      return "landing"
        case .smashReady:   return "smashReady"
        case .smash:        return "smash"
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
        for name in ["fruitBreak", "stripe", "wrapped", "fish",
                     "colorCharge", "landing", "smashReady", "smash"] {
            if let buffer = makeProceduralBuffer(named: name) {
                sfxBuffers[name] = buffer
            }
        }
    }

    /// Lightweight processing gives reused source clips distinct identities.
    /// Combo pitch rises by 110 cents per cascade step (capped at depth 8),
    /// accompanied by a small rate and level lift so deep chains feel urgent
    /// without becoming shrill or clipping the shared mixer.
    private struct PlaybackTreatment {
        var pitch: Float = 0
        var rate: Float = 1
        var volume: Float = 0.88
        var pan: Float = 0

        var needsTimePitch: Bool {
            abs(pitch) > 0.01 || abs(rate - 1) > 0.01
        }
    }

    private func playbackTreatment(for sfx: SFX) -> PlaybackTreatment {
        switch sfx {
        case .tap:
            return PlaybackTreatment(volume: 0.68)
        case .swapClick:
            return PlaybackTreatment(volume: 0.74)
        case .swapInvalid:
            return PlaybackTreatment(pitch: -120, rate: 0.96, volume: 0.80)
        case .match:
            return PlaybackTreatment(volume: 0.82)
        case let .combo(depth):
            let boundedDepth = min(max(depth, 1), 8)
            let step = Float(boundedDepth - 1)
            return PlaybackTreatment(pitch: step * 110,
                                     rate: 1 + step * 0.025,
                                     volume: min(0.90 + step * 0.012, 0.98))
        case .bomb:
            return PlaybackTreatment(pitch: -90, rate: 0.94, volume: 1.0)
        case .jelly:
            return PlaybackTreatment(pitch: 360, rate: 1.12, volume: 0.72,
                                     pan: 0.10)
        case .crate:
            return PlaybackTreatment(pitch: -420, rate: 0.86, volume: 0.94,
                                     pan: -0.08)
        case .portal:
            return PlaybackTreatment(pitch: 720, rate: 0.82, volume: 0.76,
                                     pan: 0.20)
        case .conveyor:
            return PlaybackTreatment(pitch: -180, rate: 0.88, volume: 0.68,
                                     pan: -0.16)
        case .fruitBreak:
            return PlaybackTreatment(volume: 0.54)
        case .stripe:
            return PlaybackTreatment(volume: 0.82)
        case .wrapped:
            return PlaybackTreatment(pitch: -70, rate: 0.96, volume: 0.92)
        case .fish:
            return PlaybackTreatment(volume: 0.72)
        case .colorCharge:
            return PlaybackTreatment(volume: 0.82)
        case .landing:
            return PlaybackTreatment(volume: 0.28)
        case .smashReady:
            return PlaybackTreatment(volume: 0.76)
        case .smash:
            return PlaybackTreatment(pitch: -80, rate: 0.94, volume: 1.0)
        case .win, .lose:
            return PlaybackTreatment(volume: 0.90)
        }
    }

    /// Small synthesized accents cover interactions for which the project has
    /// no bundled recording. They are deterministic, pre-rendered once, and
    /// layered with the licensed source clips rather than generated per hit.
    private func makeProceduralBuffer(named name: String) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let duration: Double
        switch name {
        case "fruitBreak": duration = 0.12
        case "stripe": duration = 0.28
        case "wrapped": duration = 0.34
        case "fish": duration = 0.20
        case "colorCharge": duration = 0.42
        case "landing": duration = 0.09
        case "smashReady": duration = 0.36
        case "smash": duration = 0.58
        default: return nil
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate,
                                         channels: 1) else { return nil }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        var phase = 0.0
        var noiseState: UInt64 = 0x51A7E5EED
        func noise() -> Double {
            noiseState = noiseState &* 6_364_136_223_846_793_005 &+ 1
            return Double((noiseState >> 40) & 0xFFFF) / Double(0x7FFF) - 1
        }

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let progress = min(1, t / duration)
            let attack = min(1, t / 0.008)
            let envelope = attack * pow(1 - progress, name == "stripe" ? 1.25 : 2.1)
            let frequency: Double
            let noiseMix: Double
            let toneMix: Double
            switch name {
            case "fruitBreak":
                frequency = 520 - progress * 180
                noiseMix = 0.72; toneMix = 0.28
            case "stripe":
                frequency = 230 + progress * 1_050
                noiseMix = 0.48; toneMix = 0.52
            case "wrapped":
                frequency = 125 - progress * 58
                noiseMix = 0.22; toneMix = 0.78
            case "fish":
                frequency = 620 + sin(progress * .pi) * 760
                noiseMix = 0.10; toneMix = 0.90
            case "colorCharge":
                let step = floor(progress * 5)
                frequency = 440 * pow(2, step / 12)
                noiseMix = 0.08; toneMix = 0.92
            case "landing":
                frequency = 145 - progress * 70
                noiseMix = 0.30; toneMix = 0.70
            case "smashReady":
                frequency = 330 * pow(2, floor(progress * 4) / 12)
                noiseMix = 0.06; toneMix = 0.94
            case "smash":
                frequency = 92 - progress * 42
                noiseMix = 0.38; toneMix = 0.62
            default:
                frequency = 440
                noiseMix = 0; toneMix = 1
            }
            phase += frequency / sampleRate
            let transient = progress < 0.035 ? noise() * (1 - progress / 0.035) : 0
            let value = (sin(phase * 2 * .pi) * toneMix + noise() * noiseMix + transient * 0.32)
                * envelope * 0.52
            samples[frame] = Float(max(-1, min(1, value)))
        }
        return buffer
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

    private func scheduleOneShot(_ buffer: AVAudioPCMBuffer,
                                 maxDuration: TimeInterval,
                                 treatment: PlaybackTreatment) {
        // Each SFX gets its own short-lived player so multiple can overlap.
        let player = AVAudioPlayerNode()
        let timePitch = treatment.needsTimePitch ? AVAudioUnitTimePitch() : nil
        engine.attach(player)
        player.volume = treatment.volume
        player.pan = treatment.pan

        if let timePitch {
            timePitch.pitch = treatment.pitch
            timePitch.rate = treatment.rate
            engine.attach(timePitch)
            engine.connect(player, to: timePitch, format: buffer.format)
            engine.connect(timePitch, to: sfxMixer, format: buffer.format)
        } else {
            engine.connect(player, to: sfxMixer, format: buffer.format)
        }

        let toPlay = truncated(buffer, to: maxDuration) ?? buffer
        player.scheduleBuffer(toPlay,
                              at: nil,
                              options: [],
                              completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.audioQueue.async { [weak self] in
                guard let self else { return }
                self.engine.detach(player)
                if let timePitch {
                    self.engine.detach(timePitch)
                }
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
