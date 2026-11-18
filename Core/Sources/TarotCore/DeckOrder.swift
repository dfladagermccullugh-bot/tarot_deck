/// The order of the cards. Values are card numbers; index 0 is the top of the deck.
/// Shuffling is modelled as a real overhand shuffle: packets are thrown from `hand` onto `pile`.
public struct DeckOrder: Equatable, Sendable {
    public static let count = 78

    /// Cards still held, top first. Never empty.
    public private(set) var hand: [Int]
    /// Cards already thrown this pass, top first.
    public private(set) var pile: [Int] = []

    public init(cards: [Int] = Array(0..<DeckOrder.count)) {
        precondition(!cards.isEmpty)
        hand = cards
    }

    /// The whole deck, top first, as if the shuffle stopped now (what is left in hand lands on top).
    public var cards: [Int] { hand + pile }
    public var top: Int { hand[0] }

    /// One throw: move `size` cards from the top of `hand` onto the top of `pile`.
    /// When `hand` runs out, the pile is picked up and a new pass begins.
    @discardableResult
    public mutating func chop(size: Int) -> (moved: Int, passCompleted: Bool) {
        let n = min(max(size, 1), hand.count)
        pile.insert(contentsOf: hand.prefix(n), at: 0)
        hand.removeFirst(n)
        guard hand.isEmpty else { return (n, false) }
        hand = pile
        pile = []
        return (n, true)
    }

    public mutating func squareUp() {
        hand = cards
        pile = []
    }

    /// Lift `index` cards off the top and put them on the bottom. Clamped so both halves are non-empty.
    public mutating func cut(at index: Int) {
        squareUp()
        guard hand.count > 1 else { return }
        let i = min(max(index, 1), hand.count - 1)
        hand = Array(hand[i...] + hand[..<i])
    }
}
