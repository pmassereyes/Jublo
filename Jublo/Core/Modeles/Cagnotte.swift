import Foundation
import SwiftData

extension SchemaV1 {
    /// Cagnotte commune. Son solde est la somme des versements non annulés.
    @Model
    final class Cagnotte {
        var id: UUID = UUID()
        var nom: String = ""
        var objectifCentimes: Int?
        /// `.nullify` : les versements ne disparaissent jamais avec la cagnotte.
        @Relationship(deleteRule: .nullify, inverse: \Versement.cagnotte)
        var versements: [Versement]? = []

        var auteurId: String = ""
        var creeLe: Date = Date.now
        var modifieLe: Date = Date.now
        var supprimeLe: Date?
        var supprimePar: String?

        init(nom: String, objectifCentimes: Int?, auteur: Membre, le date: Date) {
            self.nom = nom
            self.objectifCentimes = objectifCentimes
            auteurId = auteur.rawValue
            creeLe = date
            modifieLe = date
        }
    }
}

extension Cagnotte {
    /// Somme des versements non annulés.
    var soldeCentimes: Int {
        (versements ?? []).filter { !$0.estAnnule }.reduce(0) { $0 + $1.montantCentimes }
    }

    /// Tous les versements, annulés compris, du plus récent au plus ancien.
    var historique: [Versement] {
        (versements ?? []).sorted { $0.creeLe > $1.creeLe }
    }
}

extension Cagnotte: Suppressible {
    var libelleType: String { "Cagnotte" }
    var titreAffiche: String { nom }
    /// Une cagnotte qui a des versements n'est jamais purgée, pour garder son historique.
    var estPurgeable: Bool { versements?.isEmpty ?? true }
}
