import SwiftUI
import TarotCore

/// The tuning values, saved on the device.
@Observable
final class TuningStore {
    static let shared = TuningStore()

    var value: Tuning

    private init() {
        let saved = UserDefaults.standard.data(forKey: "tuning")
        value = saved.flatMap { try? JSONDecoder().decode(Tuning.self, from: $0) } ?? Tuning()
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: "tuning")
    }
}

/// Sliders for every physical threshold, live readouts, and a motion recorder.
/// Exists because the feel can only be judged on the phone and a rebuild takes minutes.
struct TuningView: View {
    let session: RitualSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = TuningStore.shared
        NavigationStack {
            Form {
                Section("Live") {
                    LabeledContent("Chops", value: "\(session.chopCount)")
                    LabeledContent("Last strength", value: String(format: "%.2f g", session.lastStrength))
                    LabeledContent("Last packet", value: "\(session.lastPacket) cards")
                    Button("Restart shuffle") { session.reset() }
                }
                Section("Shuffle") {
                    knob("Chop threshold (g)", $store.value.chopThreshold, 0.2...3)
                    knob("Gap between chops (s)", $store.value.refractory, 0.05...0.8)
                    knob("Full-strength chop (g)", $store.value.fullStrength, 1...8)
                    knob("Smallest packet", $store.value.minPacket, 1...10, step: 1)
                    knob("Largest packet", $store.value.maxPacket, 5...40, step: 1)
                    knob("Stillness level (g)", $store.value.stillThreshold, 0.02...0.5)
                    knob("Stillness time (s)", $store.value.stillTime, 0.5...4)
                }
                Section("Cut") {
                    knob("Tick intensity", $store.value.tickIntensity, 0...1)
                    knob("Tick sharpness", $store.value.tickSharpness, 0...1)
                    Button("Feel a tick") { session.feelEdge() }
                }
                Section("Flip") {
                    knob("Wrist flick (rad/s)", $store.value.flickThreshold, 1...15)
                }
                Section("Motion recording") {
                    Button(session.isRecording ? "Stop recording" : "Record motion") { session.toggleRecording() }
                    if let url = session.recordingURL {
                        ShareLink("Share motion.csv", item: url)
                    }
                }
                Section {
                    Button("Reset to defaults", role: .destructive) { store.value = Tuning() }
                }
            }
            .navigationTitle("Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: store.value) { store.save() }
        }
    }

    private func knob(
        _ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, step: Double = 0.01
    ) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(value.wrappedValue, specifier: "%.2f")")
            Slider(value: value, in: range, step: step)
        }
    }
}
