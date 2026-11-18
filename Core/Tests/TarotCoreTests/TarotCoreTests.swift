import XCTest
@testable import TarotCore

final class TarotCoreTests: XCTestCase {
    // MARK: Deck order

    func testAnyChopAndCutSequenceKeepsAll78Cards() {
        var deck = DeckOrder()
        let all = Array(0..<78)
        for i in 0..<500 {
            deck.chop(size: (i * 7) % 23 + 1)
            if i % 37 == 0 { deck.cut(at: (i * 13) % 90) }
            XCTAssertEqual(deck.cards.sorted(), all)
        }
        XCTAssertNotEqual(deck.cards, all)
    }

    func testOverhandPassReversesPacketOrder() {
        var deck = DeckOrder(cards: [0, 1, 2, 3, 4, 5])
        XCTAssertFalse(deck.chop(size: 2).passCompleted)
        XCTAssertEqual(deck.cards, [2, 3, 4, 5, 0, 1])
        deck.chop(size: 2)
        let last = deck.chop(size: 99)
        XCTAssertEqual(last.moved, 2)
        XCTAssertTrue(last.passCompleted)
        XCTAssertEqual(deck.cards, [4, 5, 2, 3, 0, 1])
    }

    func testCutLandsAtIndexAndClamps() {
        var deck = DeckOrder()
        deck.cut(at: 10)
        XCTAssertEqual(deck.top, 10)
        XCTAssertEqual(deck.cards.last, 9)

        var low = DeckOrder()
        low.cut(at: 0)
        XCTAssertEqual(low.top, 1)

        var high = DeckOrder()
        high.cut(at: 500)
        XCTAssertEqual(high.top, 77)
    }

    // MARK: Chop detector

    func testDetectorCountsThreeChopsThenSettles() {
        var detector = ChopDetector()
        var events: [ChopDetector.Event] = []
        for i in 0..<400 {
            let t = Double(i) / 100
            let magnitude = [0.5, 1.0, 1.5]
                .map { centre in 1.5 * exp(-pow((t - centre) / 0.03, 2)) }
                .reduce(0, +)
            if let event = detector.feed(time: t, magnitude: magnitude) { events.append(event) }
        }
        XCTAssertEqual(events.count, 4)
        for event in events.prefix(3) {
            guard case .chop(let strength) = event else { return XCTFail("expected a chop, got \(event)") }
            XCTAssertEqual(strength, 1.5, accuracy: 0.01)
        }
        XCTAssertEqual(events.last, .settled)
    }

    func testStillnessWithoutAChopNeverSettles() {
        var detector = ChopDetector()
        for i in 0..<1000 {
            XCTAssertNil(detector.feed(time: Double(i) / 100, magnitude: 0.01))
        }
    }

    func testPacketSizeGrowsWithStrengthAndStaysInBounds() {
        let detector = ChopDetector()
        XCTAssertEqual(detector.packetSize(strength: 0), 2)
        XCTAssertEqual(detector.packetSize(strength: 99), 20)
        XCTAssertLessThan(detector.packetSize(strength: 1.0), detector.packetSize(strength: 2.5))
    }

    // MARK: Deck manifest

    private func manifest(cards: Int = 78) -> DeckManifest {
        DeckManifest(
            id: "test-deck", name: "Test", back: "back.jpg",
            cards: StandardCards.all.prefix(cards).map { DeckManifest.Card(id: $0.id, image: "cards/\($0.id).jpg") })
    }

    private func error(_ manifest: DeckManifest, missing: String? = nil) -> DeckError? {
        do {
            try manifest.validate { $0 != missing }
            return nil
        } catch {
            return error as? DeckError
        }
    }

    func testStandardCardsAre78UniqueIds() {
        XCTAssertEqual(StandardCards.all.count, 78)
        XCTAssertEqual(StandardCards.ids.count, 78)
        XCTAssertEqual(StandardCards.all[0].id, "major-00")
        XCTAssertEqual(StandardCards.all[77].id, "pentacles-king")
    }

    func testValidDeckPasses() {
        XCTAssertNil(error(manifest()))
    }

    func testMalformedDecksAreRejected() {
        XCTAssertEqual(error(manifest(cards: 77)), .wrongCardCount(77))
        XCTAssertEqual(error(manifest(), missing: "back.jpg"), .missingFile("back.jpg"))

        var duplicate = manifest()
        duplicate.cards[1].id = "major-00"
        XCTAssertEqual(error(duplicate), .duplicateCard("major-00"))

        var unknown = manifest()
        unknown.cards[0].id = "joker"
        XCTAssertEqual(error(unknown), .unknownCard("joker"))

        for path in ["../secret.jpg", "/etc/passwd", "a//b.jpg", "C:\\x.jpg", ""] {
            var escaping = manifest()
            escaping.cards[5].image = path
            XCTAssertEqual(error(escaping), .unsafePath(path))
        }

        var badID = manifest()
        badID.id = "../../Library"
        XCTAssertEqual(error(badID), .badID("../../Library"))
    }
}
