/// Every physical threshold lives here so it can be tuned on the device without a rebuild.
/// All Doubles so each one can sit behind a slider.
public struct Tuning: Codable, Equatable, Sendable {
    public var chopThreshold = 0.8   // g: acceleration peak that counts as a chop
    public var refractory = 0.25     // s: minimum gap between chops (one chop = speed up + stop, two peaks)
    public var fullStrength = 3.0    // g: a chop this hard throws the largest packet
    public var minPacket = 2.0       // cards
    public var maxPacket = 20.0      // cards
    public var stillThreshold = 0.1  // g: below this the phone counts as held still
    public var stillTime = 1.5       // s of stillness that ends the shuffle
    public var tickIntensity = 0.5   // 0...1, edge-feel haptic
    public var tickSharpness = 0.9   // 0...1
    public var flickThreshold = 5.0  // rad/s around the long axis that flips the card

    public init() {}
}

/// Turns a stream of acceleration magnitudes (gravity already removed) into chops.
public struct ChopDetector: Sendable {
    public enum Event: Equatable, Sendable {
        case chop(strength: Double)
        case settled
    }

    public var tuning: Tuning
    private var peak: Double?
    private var lastChop = -Double.infinity
    private var lastMotion: Double?
    private var chops = 0

    public init(tuning: Tuning = Tuning()) {
        self.tuning = tuning
    }

    public mutating func feed(time: Double, magnitude: Double) -> Event? {
        if magnitude > tuning.stillThreshold || lastMotion == nil { lastMotion = time }

        if let p = peak {
            // ponytail: fires on the first falling sample, so sensor noise can clip the peak a little.
            // Smooth the input first if packet sizes look erratic in recordings.
            if magnitude >= p {
                peak = magnitude
                return nil
            }
            peak = nil
            lastChop = time
            chops += 1
            return .chop(strength: p)
        }
        if magnitude > tuning.chopThreshold, time - lastChop >= tuning.refractory {
            peak = magnitude
            return nil
        }
        if chops > 0, let still = lastMotion, time - still >= tuning.stillTime {
            chops = 0
            return .settled
        }
        return nil
    }

    /// Harder chop, bigger packet.
    public func packetSize(strength: Double) -> Int {
        let span = max(tuning.fullStrength - tuning.chopThreshold, 0.01)
        let f = min(max((strength - tuning.chopThreshold) / span, 0), 1)
        let extra = max(tuning.maxPacket - tuning.minPacket, 0)
        return max(Int((tuning.minPacket + f * extra).rounded()), 1)
    }
}
