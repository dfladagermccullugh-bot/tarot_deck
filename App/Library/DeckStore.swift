import SwiftUI
import TarotCore
import ZIPFoundation

enum ImportError: LocalizedError {
    case noManifest
    case reservedID(String)
    case tooLarge
    case badImage(String)

    var errorDescription: String? {
        switch self {
        case .noManifest: return "No deck.json was found. A deck is a folder (or zip) with deck.json and its images."
        case .reservedID(let id): return "The deck id \"\(id)\" is already used by a built-in deck."
        case .tooLarge: return "This deck is too large (500 MB at most, 20 MB per image)."
        case .badImage(let path): return "\"\(path)\" is not a readable image, or is over 20 MB."
        }
    }
}

/// The shelf: the built-in deck plus every folder in Application Support/Decks.
@Observable
final class DeckStore {
    private(set) var decks: [Deck] = [.builtIn]
    var importError: String?

    private let files = FileManager.default
    private let root = URL.applicationSupportDirectory.appendingPathComponent("Decks", isDirectory: true)
    private let maxDeckBytes = 500_000_000
    private let maxImageBytes = 20_000_000

    init() {
        reload()
    }

    func reload() {
        let folders = (try? files.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        let imported = folders
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? Deck(folder: $0) }
        decks = [Deck.builtIn] + imported
    }

    func delete(_ deck: Deck) {
        guard !deck.isBuiltIn, let folder = deck.folder else { return }
        try? files.removeItem(at: folder)
        reload()
    }

    /// `url` is a folder or a .zip picked in Files. Nothing is installed unless the whole deck is valid.
    func importDeck(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let scratch = files.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? files.removeItem(at: scratch) }

        do {
            var source = url
            if url.pathExtension.lowercased() == "zip" {
                let unzipped = scratch.appendingPathComponent("unzipped", isDirectory: true)
                try unzip(url, to: unzipped)
                source = try deckRoot(in: unzipped)
            }
            try install(from: source, staging: scratch.appendingPathComponent("staged", isDirectory: true))
            reload()
        } catch let error as DeckError {
            importError = error.description
        } catch {
            importError = error.localizedDescription
        }
    }

    private func unzip(_ zip: URL, to destination: URL) throws {
        // ponytail: trusts the sizes the zip declares. ZIPFoundation refuses entries that escape the
        // destination, but a crafted zip can lie about size; fine for decks you chose to import yourself.
        let archive = try Archive(url: zip, accessMode: .read)
        var total: UInt64 = 0
        var count = 0
        for entry in archive {
            total += UInt64(entry.uncompressedSize)
            count += 1
        }
        guard count <= 400, total <= UInt64(maxDeckBytes) else { throw ImportError.tooLarge }
        try files.createDirectory(at: destination, withIntermediateDirectories: true)
        try files.unzipItem(at: zip, to: destination)
    }

    /// The deck may sit at the top of the zip or inside one wrapping folder.
    private func deckRoot(in folder: URL) throws -> URL {
        func hasManifest(_ url: URL) -> Bool {
            files.fileExists(atPath: url.appendingPathComponent("deck.json").path)
        }
        if hasManifest(folder) { return folder }
        let inner = try files.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first(where: hasManifest)
        guard let inner else { throw ImportError.noManifest }
        return inner
    }

    private func install(from source: URL, staging: URL) throws {
        guard files.fileExists(atPath: source.appendingPathComponent("deck.json").path) else {
            throw ImportError.noManifest
        }
        let manifest = try Deck(folder: source).manifest
        guard manifest.id != Deck.builtIn.id else { throw ImportError.reservedID(manifest.id) }
        try manifest.validate { files.fileExists(atPath: source.appendingPathComponent($0).path) }

        // Every image must really live inside the deck folder, be a real image, and fit the size limits.
        let base = source.resolvingSymlinksInPath().path + "/"
        let paths = [manifest.back] + manifest.cards.map { $0.image }
        var total = 0
        for path in paths {
            let file = source.appendingPathComponent(path)
            guard file.resolvingSymlinksInPath().path.hasPrefix(base) else { throw DeckError.unsafePath(path) }
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            total += size
            guard total <= maxDeckBytes else { throw ImportError.tooLarge }
            guard size <= maxImageBytes, UIImage(contentsOfFile: file.path) != nil else {
                throw ImportError.badImage(path)
            }
        }

        // Copy into a staging folder first so a failed copy never damages a deck that is already installed.
        for path in ["deck.json"] + paths {
            let target = staging.appendingPathComponent(path)
            try files.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !files.fileExists(atPath: target.path) {
                try files.copyItem(at: source.appendingPathComponent(path), to: target)
            }
        }
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent(manifest.id, isDirectory: true)
        try? files.removeItem(at: destination)
        try files.moveItem(at: staging, to: destination)
    }
}
