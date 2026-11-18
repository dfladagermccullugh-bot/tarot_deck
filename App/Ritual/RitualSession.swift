import CoreMotion
import SwiftUI
import TarotCore

/// The whole ritual: shuffle -> cut twice -> flip -> revealed.
/// The deck keeps its order between readings, like a real one.
@Observable
final class RitualSession {
    enum Phase: Equatable {
        case shuffling
        case cutting(remaining: Int)
        case readyToFlip
        case revealed
    }

    private(set) var phase = Phase.shuffling
    private(set) var order = DeckOrder()

    // Shown live on the tuning screen; chopCount also triggers the packet animation.
    private(set) var chopCount = 0
    private(set) var lastStrength = 0.0
    private(set) var lastPacket = 0

    /// While the tuning screen is open, stillness does not end the shuffle.
    var tuningOpen = false

    private(set) var isRecording = false
    private(set) var recordingURL: URL?

    @ObservationIgnored private var detector = ChopDetector()
    private let motion = MotionSource()
    private let haptics = Haptics()
    @ObservationIgnored private var samples: [String] = []
    @ObservationIgnored private var readySince: Double?

    private var tuning: Tuning { TuningStore.shared.value }

    func start() {
        motion.start { [weak self] sample in self?.handle(sample) }
    }

    func stop() {
        motion.stop()
    }

    private func handle(_ sample: CMDeviceMotion) {
        let a = sample.userAcceleration
        let r = sample.rotationRate
        if isRecording {
            samples.append("\(sample.timestamp),\(a.x),\(a.y),\(a.z),\(r.x),\(r.y),\(r.z)")
            if samples.count >= 12_000 { toggleRecording() }  // two minutes is plenty
        }

        switch phase {
        case .shuffling:
            detector.tuning = tuning
            let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            switch detector.feed(time: sample.timestamp, magnitude: magnitude) {
            case .chop(let strength)?: chop(strength: strength)
            case .settled?: if !tuningOpen { finishShuffle() }
            case nil: break
            }
        case .readyToFlip:
            // Ignore the first moments after the cut so the hand leaving the screen cannot flip the card.
            let since = readySince ?? sample.timestamp
            readySince = since
            if sample.timestamp - since > 0.4, abs(r.y) > tuning.flickThreshold { flip() }
        case .cutting, .revealed:
            break
        }
    }

    private func chop(strength: Double) {
        let result = order.chop(size: detector.packetSize(strength: strength))
        chopCount += 1
        lastStrength = strength
        lastPacket = result.moved
        if result.passCompleted {
            haptics.tap(intensity: 1, sharpness: 0.1)
        } else {
            haptics.tap(intensity: 0.4 + 0.6 * Double(result.moved) / max(tuning.maxPacket, 1), sharpness: 0.5)
        }
    }

    private func finishShuffle() {
        order.squareUp()
        haptics.tap(intensity: 1, sharpness: 0.1)
        withAnimation { phase = .cutting(remaining: 2) }
    }

    /// A card edge passing under the finger.
    func feelEdge() {
        haptics.tap(intensity: tuning.tickIntensity, sharpness: tuning.tickSharpness)
    }

    func cut(at index: Int) {
        guard case .cutting(let remaining) = phase else { return }
        order.cut(at: index)
        haptics.tap(intensity: 1, sharpness: 0.2)
        readySince = nil
        withAnimation { phase = remaining > 1 ? .cutting(remaining: remaining - 1) : .readyToFlip }
    }

    func flip() {
        guard phase == .readyToFlip else { return }
        haptics.tap(intensity: 0.8, sharpness: 0.6)
        withAnimation(.spring(duration: 0.6)) { phase = .revealed }
    }

    func reset() {
        detector = ChopDetector()
        order.squareUp()
        phase = .shuffling
    }

    func toggleRecording() {
        guard isRecording else {
            samples = []
            recordingURL = nil
            isRecording = true
            return
        }
        isRecording = false
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("motion.csv")
        let text = (["t,ax,ay,az,rx,ry,rz"] + samples).joined(separator: "\n")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            recordingURL = url
        } catch {
            recordingURL = nil
        }
    }
}
