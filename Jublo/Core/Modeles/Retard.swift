import Foundation
import SwiftData

extension SchemaV4 {
    /// Retard noté au compteur : qui a fait attendre l'autre, et combien de temps.
    @Model
    final class Retard {
        var id: UUID = UUID()
        /// Membre qui était en retard.
        var retardataireId: String = Membre.pablo.rawValue
        var minutes: Int = 0
        var motif: String?
        var survenuLe: Date = Date.now

        /// Membre qui a noté le retard.
        var auteurId: String = ""
        var creeLe: Date = Date.now
        var modifieLe: Date = Date.now
        var supprimeLe: Date?
        var supprimePar: String?

        init(retardataire: Membre, minutes: Int, survenuLe: Date, auteur: Membre, le date: Date) {
            retardataireId = retardataire.rawValue
            self.minutes = minutes
            self.survenuLe = survenuLe
            auteurId = auteur.rawValue
            creeLe = date
            modifieLe = date
        }
    }
}

extension Retard: Suppressible {
    var libelleType: String { "Retards" }
    var titreAffiche: String {
        let duree = "\(minutes) min de retard"
        guard let motif, !motif.isEmpty else { return duree }
        return "\(duree) · \(motif)"
    }
    var retardataire: Membre? { Membre(rawValue: retardataireId) }

    static var actifs: Predicate<Retard> {
        #Predicate { $0.supprimeLe == nil }
    }
}

/// Bilan des retards d'un membre sur une période.
struct BilanRetards: Equatable {
    var nombre = 0
    var minutes = 0

    /// Bilan de chaque membre pour les retards survenus dans le mois de `date`.
    static func duMois(
        _ retards: [Retard], contenant date: Date, calendrier: Calendar = .current
    ) -> [Membre: BilanRetards] {
        var bilans = Dictionary(uniqueKeysWithValues: Membre.allCases.map { ($0, BilanRetards()) })
        for retard in retards where retard.supprimeLe == nil
            && calendrier.isDate(retard.survenuLe, equalTo: date, toGranularity: .month) {
            guard let membre = retard.retardataire else { continue }
            bilans[membre, default: BilanRetards()].nombre += 1
            bilans[membre, default: BilanRetards()].minutes += retard.minutes
        }
        return bilans
    }
}
