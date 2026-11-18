/// The 78 standard cards. A card's number (0..<78) is its position in `all`.
public enum StandardCards {
    public static let all: [(id: String, name: String)] = {
        let majors = [
            "The Fool", "The Magician", "The High Priestess", "The Empress", "The Emperor",
            "The Hierophant", "The Lovers", "The Chariot", "Strength", "The Hermit",
            "Wheel of Fortune", "Justice", "The Hanged Man", "Death", "Temperance",
            "The Devil", "The Tower", "The Star", "The Moon", "The Sun", "Judgement", "The World",
        ]
        let ranks: [(id: String, name: String)] = [
            ("ace", "Ace"), ("02", "Two"), ("03", "Three"), ("04", "Four"), ("05", "Five"),
            ("06", "Six"), ("07", "Seven"), ("08", "Eight"), ("09", "Nine"), ("10", "Ten"),
            ("page", "Page"), ("knight", "Knight"), ("queen", "Queen"), ("king", "King"),
        ]
        var cards: [(id: String, name: String)] = []
        for (i, name) in majors.enumerated() {
            cards.append((i < 10 ? "major-0\(i)" : "major-\(i)", name))
        }
        for suit in ["Wands", "Cups", "Swords", "Pentacles"] {
            for rank in ranks {
                cards.append(("\(suit.lowercased())-\(rank.id)", "\(rank.name) of \(suit)"))
            }
        }
        return cards
    }()

    public static let ids = Set(all.map { $0.id })
}

/// `deck.json` inside a deck folder.
public struct DeckManifest: Codable, Equatable, Sendable {
    public struct Card: Codable, Equatable, Sendable {
        public var id: String
        public var image: String
        public var name: String?
        public var keywords: [String]?
        public var meaning: String?

        public init(id: String, image: String, name: String? = nil, keywords: [String]? = nil, meaning: String? = nil) {
            self.id = id
            self.image = image
            self.name = name
            self.keywords = keywords
            self.meaning = meaning
        }
    }

    public var id: String
    public var name: String
    public var author: String?
    public var back: String
    public var cards: [Card]

    public init(id: String, name: String, author: String? = nil, back: String, cards: [Card]) {
        self.id = id
        self.name = name
        self.author = author
        self.back = back
        self.cards = cards
    }
}

public enum DeckError: Error, Equatable, CustomStringConvertible {
    case badID(String)
    case wrongCardCount(Int)
    case unknownCard(String)
    case duplicateCard(String)
    case unsafePath(String)
    case missingFile(String)

    public var description: String {
        switch self {
        case .badID(let id): return "Deck id \"\(id)\" may only use letters, numbers, - and _ (64 max)."
        case .wrongCardCount(let n): return "A deck needs exactly 78 cards; this one has \(n)."
        case .unknownCard(let id): return "\"\(id)\" is not a standard card id."
        case .duplicateCard(let id): return "Card \"\(id)\" appears more than once."
        case .unsafePath(let path): return "Image path \"\(path)\" must stay inside the deck folder."
        case .missingFile(let path): return "Image \"\(path)\" is missing."
        }
    }
}

extension DeckManifest {
    /// Imported decks are untrusted input: check everything before any file is copied.
    /// `fileExists` receives a path relative to the deck folder.
    public func validate(fileExists: (String) -> Bool) throws {
        guard DeckManifest.isSafeName(id) else { throw DeckError.badID(id) }
        guard cards.count == DeckOrder.count else { throw DeckError.wrongCardCount(cards.count) }
        var seen = Set<String>()
        for card in cards {
            guard StandardCards.ids.contains(card.id) else { throw DeckError.unknownCard(card.id) }
            guard seen.insert(card.id).inserted else { throw DeckError.duplicateCard(card.id) }
        }
        for path in [back] + cards.map({ $0.image }) {
            guard DeckManifest.isSafePath(path) else { throw DeckError.unsafePath(path) }
            guard fileExists(path) else { throw DeckError.missingFile(path) }
        }
    }

    static func isSafeName(_ s: String) -> Bool {
        !s.isEmpty && s.count <= 64
            && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    static func isSafePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.contains("\\"), !path.contains(":") else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false)
            .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
}
