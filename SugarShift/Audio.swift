import AVFoundation

/// Lightweight audio engine with **no bundled audio files**. SFX and music are
/// both PCM buffers synthesised at runtime via sine/square/noise generators
/// fed into `AVAudioEngine`. Toggles in the settings panel gate playback via
/// `Persistence.soundEnabled` and `Persistence.musicEnabled`.
final class Audio {

    static let shared = Audio()

    private let engine = AVAudioEngine()
    private let sfxMixer = AVAudioMixerNode()
    private let musicMixer = AVAudioMixerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private var musicBuffer: AVAudioPCMBuffer?
    private var musicLoopActive = false

    private let sampleRate: Double = 44_100

    private init() {
        configureSession()
        setupEngine()
    }

    // MARK: - Public API

    enum SFX {
        case tap
        case swapClick
        case swapInvalid
        case match
        case combo(depth: Int)
        case bomb
        case win
        case lose
    }

    func play(_ sfx: SFX) {
        guard Persistence.soundEnabled else { return }
        let buffer = buildBuffer(for: sfx)
        scheduleOneShot(buffer)
    }

    /// Begin (or unmute) the ambient loop. Idempotent.
    func startMusic() {
        guard Persistence.musicEnabled else { return }
        guard !musicLoopActive else {
            musicMixer.outputVolume = 0.18
            return
        }
        if musicBuffer == nil { musicBuffer = makeMusicLoop() }
        guard let buffer = musicBuffer else { return }
        if !musicPlayer.isPlaying {
            musicPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
            musicPlayer.play()
        }
        musicMixer.outputVolume = 0.18
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

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: sampleRate,
                                   channels: 1,
                                   interleaved: false)
        engine.connect(sfxMixer, to: engine.mainMixerNode, format: format)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: format)
        engine.connect(musicPlayer, to: musicMixer, format: format)

        sfxMixer.outputVolume = 0.6
        musicMixer.outputVolume = 0

        do { try engine.start() }
        catch { print("Audio engine start failed:", error) }
    }

    private func scheduleOneShot(_ buffer: AVAudioPCMBuffer) {
        // Each SFX gets its own short-lived player so multiple can overlap.
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: sfxMixer, format: buffer.format)
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async {
                self?.engine.detach(player)
            }
        }
        player.play()
    }

    // MARK: - SFX synthesis

    private func buildBuffer(for sfx: SFX) -> AVAudioPCMBuffer {
        switch sfx {
        case .tap:
            return tone(880, dur: 0.04, attack: 0.005, release: 0.03, gain: 0.18)
        case .swapClick:
            return chord([660, 880], dur: 0.06, attack: 0.005, release: 0.05, gain: 0.22)
        case .swapInvalid:
            return tone(180, dur: 0.18, attack: 0.005, release: 0.15, gain: 0.22, wave: .triangle)
        case .match:
            return chord([523.25, 659.25, 783.99], dur: 0.16,
                         attack: 0.005, release: 0.14, gain: 0.22)
        case .combo(let depth):
            // Each combo tier transposes a major triad up
            let base = 523.25 * pow(1.0594630943592953, Double(depth - 1) * 2)
            return chord([base, base * 5.0/4.0, base * 3.0/2.0],
                         dur: 0.22, attack: 0.005, release: 0.20, gain: 0.24)
        case .bomb:
            return explosion(dur: 0.32)
        case .win:
            return arpeggio([523.25, 659.25, 783.99, 1046.50, 1318.51],
                            step: 0.09, gain: 0.26)
        case .lose:
            return slide(from: 440, to: 220, dur: 0.45, gain: 0.22)
        }
    }

    private enum Wave { case sine, square, triangle }

    private func tone(_ freq: Double, dur: TimeInterval,
                      attack: TimeInterval = 0.01,
                      release: TimeInterval = 0.1,
                      gain: Float = 0.3,
                      wave: Wave = .sine) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(sampleRate * dur)
        let buffer = makeBuffer(frames: frames)
        guard let samples = buffer.floatChannelData?[0] else { return buffer }
        let attackFrames = Int(sampleRate * attack)
        let releaseFrames = Int(sampleRate * release)
        let total = Int(frames)
        let twoPi = 2 * Float.pi

        for i in 0..<total {
            let t = Float(i) / Float(sampleRate)
            let phase = twoPi * Float(freq) * t
            var s: Float
            switch wave {
            case .sine:     s = sin(phase)
            case .square:   s = sin(phase) >= 0 ? 1 : -1
            case .triangle:
                let p = (Float(freq) * t).truncatingRemainder(dividingBy: 1)
                s = 4 * abs(p - 0.5) - 1
            }
            samples[i] = s * envelope(i: i, total: total,
                                      attack: attackFrames,
                                      release: releaseFrames) * gain
        }
        return buffer
    }

    private func chord(_ freqs: [Double], dur: TimeInterval,
                       attack: TimeInterval, release: TimeInterval,
                       gain: Float) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(sampleRate * dur)
        let buffer = makeBuffer(frames: frames)
        guard let samples = buffer.floatChannelData?[0] else { return buffer }
        let total = Int(frames)
        let attackFrames = Int(sampleRate * attack)
        let releaseFrames = Int(sampleRate * release)
        let twoPi = 2 * Float.pi
        let perVoiceGain = gain / Float(freqs.count)

        for i in 0..<total {
            let t = Float(i) / Float(sampleRate)
            var sum: Float = 0
            for f in freqs {
                sum += sin(twoPi * Float(f) * t)
            }
            samples[i] = sum * envelope(i: i, total: total,
                                        attack: attackFrames,
                                        release: releaseFrames) * perVoiceGain
        }
        return buffer
    }

    private func explosion(dur: TimeInterval) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(sampleRate * dur)
        let buffer = makeBuffer(frames: frames)
        guard let samples = buffer.floatChannelData?[0] else { return buffer }
        let total = Int(frames)
        let twoPi = 2 * Float.pi
        var lastSample: Float = 0

        for i in 0..<total {
            let progress = Float(i) / Float(total)
            // Filtered noise + low-frequency rumble
            let noise = Float.random(in: -1...1)
            // Simple 1-pole low-pass on noise
            lastSample = lastSample * 0.7 + noise * 0.3
            let rumbleFreq: Float = 60 + 40 * (1 - progress)
            let rumble = sin(twoPi * rumbleFreq * Float(i) / Float(sampleRate))
            let env = pow(1 - progress, 2.2) * 0.45
            samples[i] = (lastSample * 0.6 + rumble * 0.4) * env
        }
        return buffer
    }

    private func arpeggio(_ notes: [Double], step: TimeInterval, gain: Float) -> AVAudioPCMBuffer {
        let stepFrames = Int(sampleRate * step)
        let total = stepFrames * notes.count
        let buffer = makeBuffer(frames: AVAudioFrameCount(total))
        guard let samples = buffer.floatChannelData?[0] else { return buffer }
        let twoPi = 2 * Float.pi
        for (idx, freq) in notes.enumerated() {
            let base = idx * stepFrames
            for i in 0..<stepFrames {
                let t = Float(i) / Float(sampleRate)
                let phase = twoPi * Float(freq) * t
                let progress = Float(i) / Float(stepFrames)
                let env = sin(progress * .pi) * gain
                samples[base + i] = sin(phase) * env
            }
        }
        return buffer
    }

    private func slide(from start: Double, to end: Double,
                       dur: TimeInterval, gain: Float) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(sampleRate * dur)
        let buffer = makeBuffer(frames: frames)
        guard let samples = buffer.floatChannelData?[0] else { return buffer }
        let total = Int(frames)
        let twoPi = 2 * Float.pi
        var phase: Float = 0
        for i in 0..<total {
            let p = Float(i) / Float(total)
            let freq = Float(start + (end - start) * Double(p))
            phase += twoPi * freq / Float(sampleRate)
            let env = (1 - p) * gain
            samples[i] = sin(phase) * env
        }
        return buffer
    }

    private func envelope(i: Int, total: Int, attack: Int, release: Int) -> Float {
        if i < attack { return Float(i) / Float(max(1, attack)) }
        if i > total - release {
            return Float(total - i) / Float(max(1, release))
        }
        return 1.0
    }

    private func makeBuffer(frames: AVAudioFrameCount) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: sampleRate,
                                   channels: 1,
                                   interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        return buffer
    }

    // MARK: - Music — gentle ambient I → V → vi → IV loop in C major

    private func makeMusicLoop() -> AVAudioPCMBuffer {
        // 4 chords × 2 seconds = 8s loop
        let chordDur: TimeInterval = 2.0
        // Voicings (root + 3rd + 5th, low octave for pad warmth)
        let chords: [[Double]] = [
            [130.81, 164.81, 196.00],   // C major (C3 E3 G3)
            [98.00, 123.47, 146.83],    // G major (G2 B2 D3)
            [110.00, 130.81, 164.81],   // A minor (A2 C3 E3)
            [87.31, 110.00, 130.81]     // F major (F2 A2 C3)
        ]
        let frames = AVAudioFrameCount(sampleRate * chordDur * Double(chords.count))
        let buffer = makeBuffer(frames: frames)
        guard let samples = buffer.floatChannelData?[0] else { return buffer }

        let chordFrames = Int(sampleRate * chordDur)
        let twoPi = 2 * Float.pi

        for (chordIdx, chord) in chords.enumerated() {
            let base = chordIdx * chordFrames
            for i in 0..<chordFrames {
                let t = Float(i) / Float(sampleRate)
                let p = Float(i) / Float(chordFrames)

                // Smooth crossfade between chords (sin envelope)
                let chordEnv = sin(p * .pi)

                // Pad: sum of sines, slightly detuned for warmth
                var pad: Float = 0
                for f in chord {
                    let detune: Float = 1.004
                    pad += sin(twoPi * Float(f) * t)
                    pad += sin(twoPi * Float(f) * detune * t) * 0.6
                }
                pad *= 0.10

                // Sparkle: high bell every half-chord
                let bellFreq = Float(chord.last! * 4)
                let bellPhase = (p * 2).truncatingRemainder(dividingBy: 1)
                let bellEnv = pow(max(0, 1 - bellPhase * 1.6), 3.0)
                let bell = sin(twoPi * bellFreq * t) * bellEnv * 0.06

                samples[base + i] = (pad + bell) * chordEnv
            }
        }
        return buffer
    }
}
