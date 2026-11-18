import SwiftUI
import TarotCore

struct RitualView: View {
    @State private var session = RitualSession()
    @State private var showTuning = false
    @State private var dragTurn = 0.0
    @State private var feltIndex: Int?

    private var topCardName: String { StandardCards.all[session.order.top].name }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            deck
            if case .cutting = session.phase {
                edgeStrip
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                showTuning = true
            } label: {
                Image(systemName: "slider.horizontal.3").padding(16)
            }
            .tint(.white.opacity(0.4))
        }
        .overlay(alignment: .bottom) { footer }
        .sheet(isPresented: $showTuning) { TuningView(session: session) }
        .onChange(of: showTuning) { session.tuningOpen = showTuning }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            session.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            session.stop()
        }
        .statusBarHidden()
    }

    // MARK: Deck

    private var deck: some View {
        ZStack {
            // The rest of the deck showing beneath the top card.
            ForEach([4, 3, 2, 1], id: \.self) { layer in
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.85 - Double(layer) * 0.12))
                    .offset(x: CGFloat(layer) * 2, y: CGFloat(layer) * 2)
            }
            FlipCard(angle: session.phase == .revealed ? 180 : dragTurn) {
                CardBack()
            } back: {
                CardFace(name: topCardName)
            }
            // Each chop lifts the top packet and drops it back.
            .phaseAnimator([false, true], trigger: session.chopCount) { card, lifted in
                card.offset(y: lifted ? -120 : 0)
            } animation: { _ in
                .spring(duration: 0.15)
            }
            .gesture(flipGesture)
        }
        .aspectRatio(2.75 / 4.75, contentMode: .fit)
        .padding(.horizontal, 48)
        .padding(.vertical, 64)
    }

    private var flipGesture: some Gesture {
        DragGesture()
            .onChanged { drag in
                guard session.phase == .readyToFlip else { return }
                dragTurn = min(Double(abs(drag.translation.width)) / 220 * 180, 180)
            }
            .onEnded { _ in
                withAnimation(.spring(duration: 0.5)) {
                    if dragTurn > 90 { session.flip() }
                    dragTurn = 0
                }
            }
    }

    // MARK: Cut

    /// The side of the deck: 78 card edges. Row 0 is the top card.
    private var edgeStrip: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for row in 0..<DeckOrder.count {
                    let y = (CGFloat(row) + 0.5) / CGFloat(DeckOrder.count) * size.height
                    let lifted = feltIndex.map { row < $0 } ?? false
                    var edge = Path()
                    edge.move(to: CGPoint(x: lifted ? 0 : 10, y: y))
                    edge.addLine(to: CGPoint(x: size.width - (lifted ? 10 : 0), y: y))
                    context.stroke(edge, with: .color(.white.opacity(lifted ? 0.9 : 0.45)), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let row = Int(drag.location.y / geo.size.height * CGFloat(DeckOrder.count))
                        let index = min(max(row, 1), DeckOrder.count - 1)
                        if index != feltIndex {
                            feltIndex = index
                            session.feelEdge()
                        }
                    }
                    .onEnded { _ in
                        if let index = feltIndex { session.cut(at: index) }
                        feltIndex = nil
                    }
            )
        }
        .frame(width: 56)
        .padding(.vertical, 64)
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        switch session.phase {
        case .shuffling:
            caption("Shuffle. Hold still when you are done.")
        case .cutting(let remaining):
            caption(remaining == 2 ? "Run a finger along the edge. Lift to cut." : "Cut once more.")
        case .readyToFlip:
            caption("Turn the card.")
        case .revealed:
            VStack(spacing: 12) {
                Text(topCardName).font(.title2.weight(.semibold))
                Button("Shuffle again") {
                    withAnimation(.spring(duration: 0.5)) { session.reset() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.bottom, 16)
    }
}

/// A two-sided card. Animatable so the face swaps exactly at the halfway point of the turn.
struct FlipCard<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let front: Front
    let back: Back

    init(angle: Double, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.angle = angle
        self.front = front()
        self.back = back()
    }

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            if angle < 90 {
                front
            } else {
                back.scaleEffect(x: -1, y: 1)
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}

// Placeholder art until real decks arrive with the library.
struct CardBack: View {
    private let gold = Color(red: 0.85, green: 0.7, blue: 0.35)

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.16, green: 0.1, blue: 0.35), Color(red: 0.05, green: 0.03, blue: 0.15)],
                    startPoint: .top, endPoint: .bottom)
            )
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(gold, lineWidth: 2).padding(10))
            .overlay(Image(systemName: "moon.stars.fill").font(.system(size: 64)).foregroundStyle(gold))
    }
}

struct CardFace: View {
    let name: String

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(red: 0.96, green: 0.93, blue: 0.85))
            .overlay(
                Text(name)
                    .font(.system(.title, design: .serif))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding()
            )
    }
}
