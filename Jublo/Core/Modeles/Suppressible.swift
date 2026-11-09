import Foundation
import SwiftData

/// Élément partagé supprimé « en douceur » : il passe par la corbeille avant d'être purgé
/// (voir `Depot.supprimer`, `Depot.restaurer` et `Depot.purger`).
protocol Suppressible: PersistentModel {
    var auteurId: String { get }
    var creeLe: Date { get }
    var modifieLe: Date { get set }
    var supprimeLe: Date? { get set }
    var supprimePar: String? { get set }

    /// Type affiché dans la corbeille (« Courses », « Cagnotte »…).
    var libelleType: String { get }
    /// Titre affiché dans la corbeille.
    var titreAffiche: String { get }
    /// Faux si l'élément ne doit jamais être purgé.
    var estPurgeable: Bool { get }
}

extension Suppressible {
    var estSupprime: Bool { supprimeLe != nil }
    var auteur: Membre? { Membre(rawValue: auteurId) }
    var estPurgeable: Bool { true }
}
