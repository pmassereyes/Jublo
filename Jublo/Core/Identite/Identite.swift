import Foundation
import Observation

/// Membre qui utilise cet iPhone. Il est choisi au premier lancement et modifiable dans
/// Nous › Cet iPhone. Il signe ce que l'on ajoute, coche ou supprime, et voyage avec les
/// données partagées.
@MainActor
@Observable
final class Identite {
    static let cle = "membreCourant"

    private let stockage: UserDefaults

    var membre: Membre {
        didSet {
            stockage.set(membre.rawValue, forKey: Self.cle)
            estChoisi = true
        }
    }

    /// Faux tant que personne n'a dit qui utilise cet iPhone.
    private(set) var estChoisi: Bool

    init(stockage: UserDefaults = .standard) {
        self.stockage = stockage
        let enregistre = stockage.string(forKey: Self.cle).flatMap(Membre.init(rawValue:))
        membre = enregistre ?? .pablo
        estChoisi = enregistre != nil
    }
}
