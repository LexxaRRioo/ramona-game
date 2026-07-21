import Testing
import Foundation
@testable import Ramona

/// Exercises CatSaveState's Codable shape directly - deliberately NOT calling
/// persist()/load(), which read/write the real
/// ~/Library/Application Support/Ramona/state.json used by the actual app.
@Suite struct CatSaveStateTests {
    private func makeCodec() -> (JSONEncoder, JSONDecoder) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (encoder, decoder)
    }

    @Test func roundTripPreservesNeedsAndTimestamp() throws {
        let (encoder, decoder) = makeCodec()
        let original = CatSaveState(
            needs: NeedsState(hunger: 0.42, energy: 0.73, play: 0.15, social: 0.9),
            lastUpdate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(CatSaveState.self, from: data)

        #expect(abs(decoded.needs.hunger - original.needs.hunger) < 0.0001)
        #expect(abs(decoded.needs.energy - original.needs.energy) < 0.0001)
        #expect(abs(decoded.needs.play - original.needs.play) < 0.0001)
        #expect(abs(decoded.needs.social - original.needs.social) < 0.0001)
        #expect(decoded.lastUpdate == original.lastUpdate)
    }

    @Test func decodingMalformedDataFails() {
        let (_, decoder) = makeCodec()
        let garbage = Data("not json".utf8)
        #expect(throws: (any Error).self) {
            try decoder.decode(CatSaveState.self, from: garbage)
        }
    }
}
