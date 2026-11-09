import Foundation
import SwiftData

extension SchemaV1 {
    /// Versement dans une cagnotte. Il n'est ni supprimé ni purgé : une annulation le garde
    /// dans l'historique et l'exclut du solde.
    @Model
    final class Versement {
        var id: UUID = UUID()
        var montantCentimes: Int = 0
        var note: String?
        var cagnotte: Cagnotte?

        var auteurId: String = ""
        var creeLe: Date = Date.now
        var modifieLe: Date = Date.now
        var annuleLe: Date?
        var annulePar: String?

        init(montantCentimes: Int, note: String?, auteur: Membre, le date: Date) {
            self.montantCentimes = montantCentimes
            self.note = note
            auteurId = auteur.rawValue
            creeLe = date
            modifieLe = date
        }
    }
}

extension Versement {
    var estAnnule: Bool { annuleLe != nil }
    var auteur: Membre? { Membre(rawValue: auteurId) }
}
