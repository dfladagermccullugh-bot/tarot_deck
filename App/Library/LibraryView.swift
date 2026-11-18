import SwiftUI
import TarotCore
import UniformTypeIdentifiers

/// The shelf of decks. Tap a deck to pick it up.
struct LibraryView: View {
    @State private var store = DeckStore()
    @State private var picked: Deck?
    @State private var browsing: Deck?
    @State private var deleting: Deck?
    @State private var importing = false
    @Namespace private var shelf

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 24)], spacing: 28) {
                    ForEach(store.decks) { deck in
                        Button {
                            picked = deck
                        } label: {
                            cover(deck)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Browse cards", systemImage: "square.grid.3x3") { browsing = deck }
                            if !deck.isBuiltIn {
                                Button("Delete", systemImage: "trash", role: .destructive) { deleting = deck }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Library")
            .toolbar {
                Button("Import deck", systemImage: "plus") { importing = true }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.folder, .zip]) { result in
            if case .success(let url) = result { store.importDeck(from: url) }
        }
        .alert(
            "Could not import deck",
            isPresented: Binding(get: { store.importError != nil }, set: { if !$0 { store.importError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(store.importError ?? "")
        }
        .confirmationDialog(
            "Delete this deck?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { deck in
            Button("Delete \(deck.manifest.name)", role: .destructive) { store.delete(deck) }
        } message: { _ in
            Text("Its images are removed from this phone. This cannot be undone.")
        }
        .fullScreenCover(item: $picked) { deck in
            RitualView(deck: deck).zoomTransition(from: deck.id, in: shelf)
        }
        .sheet(item: $browsing) { deck in
            DeckBrowser(deck: deck)
        }
    }

    private func cover(_ deck: Deck) -> some View {
        VStack(spacing: 8) {
            CardBack(image: deck.back, corner: 8)
                .aspectRatio(2.75 / 4.75, contentMode: .fit)
                .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
                .zoomSource(id: deck.id, in: shelf)
            Text(deck.manifest.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
}

/// All 78 cards of a deck, with their meanings.
struct DeckBrowser: View {
    let deck: Deck

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 16) {
                    ForEach(0..<DeckOrder.count, id: \.self) { card in
                        NavigationLink {
                            ScrollView {
                                CardFace(image: deck.face(card), name: deck.name(card))
                                    .aspectRatio(2.75 / 4.75, contentMode: .fit)
                                    .padding(32)
                                CardText(deck: deck, card: card).padding()
                            }
                        } label: {
                            CardFace(image: deck.thumbnail(card), name: deck.name(card), corner: 6)
                                .aspectRatio(2.75 / 4.75, contentMode: .fit)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle(deck.manifest.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// A card's name, keywords and meaning.
struct CardText: View {
    let deck: Deck
    let card: Int

    var body: some View {
        VStack(spacing: 8) {
            Text(deck.name(card)).font(.title2.weight(.semibold))
            if !deck.keywords(card).isEmpty {
                Text(deck.keywords(card).joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
            }
            if let meaning = deck.meaning(card) {
                Text(meaning).font(.body)
            }
        }
        .multilineTextAlignment(.center)
    }
}

// The cover grows into the full-screen deck on iOS 18 and later; older systems slide it up.
extension View {
    @ViewBuilder func zoomSource(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder func zoomTransition(from id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
