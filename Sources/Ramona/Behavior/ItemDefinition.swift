import Foundation

/// Decoded from Resources/Items/*.json - a food/toy/furniture item's static
/// definition. "restores" is generic (need name -> amount) rather than a
/// fixed field per need, so a future item (e.g. a bed restoring energy)
/// doesn't need a schema change - see BehaviorEngine.use(_:).
struct ItemDefinition: Codable {
    enum Kind: String, Codable {
        case food
        case toy
    }

    let id: String
    let displayName: String
    let kind: Kind
    let restores: [String: Double]
}

extension ItemDefinition {
    /// Loads every Resources/Items/*.json bundled with the app. Order isn't
    /// meaningful - callers that need a specific one filter by id, and
    /// SpeciesDefinition.itemPreferences is what encodes preference order.
    static func loadAll() -> [ItemDefinition] {
        guard let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "Items") else {
            return []
        }
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(ItemDefinition.self, from: data)
        }
    }
}
