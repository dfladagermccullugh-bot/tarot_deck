import SwiftUI
import TarotCore

/// A deck on the shelf: its manifest plus the folder holding its images.
struct Deck: Identifiable, Equatable {
    let manifest: DeckManifest
    /// nil for the built-in plain deck, which is drawn instead of loaded.
    let folder: URL?

    var id: String { manifest.id }
    var isBuiltIn: Bool { folder == nil }

    static let builtIn = Deck(
        manifest: DeckManifest(
            id: "plain", name: "Plain Deck", back: "",
            cards: StandardCards.all.map { DeckManifest.Card(id: $0.id, image: "") }),
        folder: nil)

    var back: UIImage? { url(manifest.back).flatMap(ImageCache.full) }
    func face(_ card: Int) -> UIImage? { entry(card).flatMap { url($0.image) }.flatMap(ImageCache.full) }
    func thumbnail(_ card: Int) -> UIImage? { entry(card).flatMap { url($0.image) }.flatMap(ImageCache.thumbnail) }

    func name(_ card: Int) -> String { entry(card)?.name ?? StandardCards.all[card].name }
    func keywords(_ card: Int) -> [String] { entry(card)?.keywords ?? [] }
    func meaning(_ card: Int) -> String? { entry(card)?.meaning }

    private func entry(_ card: Int) -> DeckManifest.Card? {
        let id = StandardCards.all[card].id
        return manifest.cards.first { $0.id == id }
    }

    private func url(_ path: String) -> URL? {
        folder?.appendingPathComponent(path)
    }
}

extension Deck {
    init(folder: URL) throws {
        let data = try Data(contentsOf: folder.appendingPathComponent("deck.json"))
        self.init(manifest: try JSONDecoder().decode(DeckManifest.self, from: data), folder: folder)
    }
}

/// Card images are read from disk once, not on every redraw.
enum ImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func full(_ url: URL) -> UIImage? {
        cached(url.path) { UIImage(contentsOfFile: url.path) }
    }

    // ponytail: thumbnails are made on the main thread the first time a card scrolls into view.
    // Make them in the background if browsing a deck stutters.
    static func thumbnail(_ url: URL) -> UIImage? {
        cached(url.path + "#thumb") {
            UIImage(contentsOfFile: url.path)?.preparingThumbnail(of: CGSize(width: 275, height: 475))
        }
    }

    private static func cached(_ key: String, _ make: () -> UIImage?) -> UIImage? {
        if let hit = cache.object(forKey: key as NSString) { return hit }
        guard let image = make() else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }
}
