import Foundation
import Observation

/// Membre qui utilise cet iPhone.
/// Phase 1 : choisi dans Nous › Debug. Phase 2 : déduit de l'identité iCloud.
@MainActor
@Observable
final class Identite {
    static let cle = "membreCourant"

    private let stockage: UserDefaults

    var membre: Membre {
        didSet { stockage.set(membre.rawValue, forKey: Self.cle) }
    }

    init(stockage: UserDefaults = .standard) {
        self.stockage = stockage
        membre = stockage.string(forKey: Self.cle).flatMap(Membre.init(rawValue:)) ?? .pablo
    }
}
