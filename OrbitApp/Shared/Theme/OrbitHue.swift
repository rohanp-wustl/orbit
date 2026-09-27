import SwiftUI

/// The six recolor hues from the style sheet, as a type — so a package's
/// color can be stored by name (CapsuleLayout.packageColor) and a crew
/// member's planet can get a stable hue from their id.
enum OrbitHue: String, CaseIterable, Identifiable, Codable {
    case magenta, violet, seafoam, gold, ember, lime

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .magenta: .orbitMagenta
        case .violet: .orbitViolet
        case .seafoam: .orbitSeafoam
        case .gold: .orbitGold
        case .ember: .orbitEmber
        case .lime: .orbitLime
        }
    }

    /// Stable hue for a user, so the same crew member is always the same
    /// planet color on every screen and every phone.
    static func forUser(_ id: UUID) -> OrbitHue {
        // UUID's own bytes, not hashValue — hashValue is randomized per launch.
        let sum = withUnsafeBytes(of: id.uuid) { $0.reduce(0) { $0 &+ Int($1) } }
        return allCases[sum % allCases.count]
    }

    /// Falls back to magenta for missing/unknown names (old capsules).
    static func named(_ name: String?) -> OrbitHue {
        name.flatMap(OrbitHue.init(rawValue:)) ?? .magenta
    }
}
