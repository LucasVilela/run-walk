import AVFoundation
import AudioToolbox
import CoreHaptics
import RunKit
import UIKit

/// Turns engine cues into voice + beeps + vibration.
/// The audio session mixes with other apps and ducks their music only while a cue plays,
/// then deactivates so the music comes back to full volume.
@MainActor
final class CuePlayer: NSObject {
    static let shared = CuePlayer()

    struct Options: Equatable {
        var voice = true
        var beeps = true
        var haptics = true
    }

    var options = Options()

    private let synth = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "en-AU")
    private let shortBeep = CuePlayer.player("beep-short")
    private let longBeep = CuePlayer.player("beep-long")
    private var haptics: CHHapticEngine?
    private var releaseTask: Task<Void, Never>?

    override private init() {
        super.init()
        synth.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .voicePrompt, options: [.duckOthers])
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            haptics = try? CHHapticEngine()
            haptics?.playsHapticsOnly = true
        }
    }

    func play(_ event: CueEvent, plan: RunPlan) {
        let line = options.voice ? CueLines.line(for: event, plan: plan) : nil
        let beep: AVAudioPlayer?
        let vibration: Vibration?
        switch event {
        case .segmentStart(let index), .current(let index, _), .resumed(let index, _):
            beep = longBeep
            vibration = plan.segments[index].kind == .run ? .run : .walk
        case .countdown:
            beep = shortBeep
            vibration = .tap
        case .halfway, .oneMinute, .paused:
            beep = nil
            vibration = .tap
        case .finished:
            beep = longBeep
            vibration = .run
        }
        guard line != nil || (options.beeps && beep != nil) || (options.haptics && vibration != nil) else {
            return
        }

        activate()
        if options.beeps, let beep {
            beep.currentTime = 0
            beep.play()
        }
        if options.haptics, let vibration { vibrate(vibration) }
        if let line { speak(line, interrupt: event.interrupts, afterBeep: options.beeps && beep != nil) }
        scheduleRelease()
    }

    // MARK: - Speech

    private func speak(_ line: String, interrupt: Bool, afterBeep: Bool) {
        if interrupt && synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: line)
        utterance.voice = voice
        utterance.preUtteranceDelay = afterBeep ? 0.45 : 0
        synth.speak(utterance)
    }

    // MARK: - Audio session (duck → restore)

    private func activate() {
        releaseTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    fileprivate func scheduleRelease() {
        releaseTask?.cancel()
        releaseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, !Task.isCancelled, !self.isBusy else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private var isBusy: Bool {
        synth.isSpeaking || shortBeep?.isPlaying == true || longBeep?.isPlaying == true
    }

    // MARK: - Vibration

    enum Vibration { case run, walk, tap }

    private func vibrate(_ vibration: Vibration) {
        // Core Haptics only plays in the foreground; when locked, fall back to the system buzz.
        guard UIApplication.shared.applicationState == .active, let engine = haptics else {
            systemVibrate(vibration)
            return
        }
        do {
            try engine.start()
            let player = try engine.makePlayer(
                with: CHHapticPattern(events: events(vibration), parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            systemVibrate(vibration)
        }
    }

    /// Run = 2 strong pulses, walk = 1 long pulse, tap = 1 light pulse.
    private func events(_ vibration: Vibration) -> [CHHapticEvent] {
        func param(_ id: CHHapticEvent.ParameterID, _ value: Float) -> CHHapticEventParameter {
            CHHapticEventParameter(parameterID: id, value: value)
        }
        switch vibration {
        case .run:
            return [0, 0.22].map {
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [param(.hapticIntensity, 1), param(.hapticSharpness, 0.8)], relativeTime: $0)
            }
        case .walk:
            return [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [param(.hapticIntensity, 0.9), param(.hapticSharpness, 0.3)], relativeTime: 0,
                    duration: 0.6)
            ]
        case .tap:
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [param(.hapticIntensity, 0.5), param(.hapticSharpness, 0.5)], relativeTime: 0)
            ]
        }
    }

    private func systemVibrate(_ vibration: Vibration) {
        guard vibration != .tap else { return }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        if vibration == .run {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }

    private static func player(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }
}

extension CuePlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.scheduleRelease() }
    }
}

extension CueEvent {
    /// A new segment cuts off whatever was still being said.
    fileprivate var interrupts: Bool {
        switch self {
        case .segmentStart, .current, .finished: true
        default: false
        }
    }
}
