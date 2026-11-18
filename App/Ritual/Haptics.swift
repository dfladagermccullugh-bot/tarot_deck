import CoreHaptics

final class Haptics {
    private var engine: CHHapticEngine?
    private var needsStart = true

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        // The system stops the engine when the app leaves the foreground; restart lazily on the next tap.
        engine?.stoppedHandler = { [weak self] _ in self?.needsStart = true }
        engine?.resetHandler = { [weak self] in self?.needsStart = true }
    }

    /// One transient tap. Intensity and sharpness are 0...1.
    func tap(intensity: Double, sharpness: Double) {
        guard let engine else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(min(max(intensity, 0), 1))),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(min(max(sharpness, 0), 1))),
            ],
            relativeTime: 0)
        do {
            if needsStart {
                try engine.start()
                needsStart = false
            }
            let player = try engine.makePlayer(with: CHHapticPattern(events: [event], parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            needsStart = true
        }
    }
}
