import Foundation
import SwiftData

extension SchemaV4 {
    /// « Ce mois-ci, j'aimerais que tu… » : une envie confiée à l'autre pour un mois donné.
    /// L'auteur la formule, l'autre la coche quand c'est fait.
    @Model
    final class Souhait {
        var id: UUID = UUID()
        /// Suite de « j'aimerais que tu… » (« m'emmènes au cinéma »).
        var texte: String = ""
        /// Mois concerné, au format « 2026-11 » (voir `Souhait.cleMois`).
        var mois: String = ""
        var faitLe: Date?

        var auteurId: String = ""
        var creeLe: Date = Date.now
        var modifieLe: Date = Date.now
        var supprimeLe: Date?
        var supprimePar: String?

        init(texte: String, mois: String, auteur: Membre, le date: Date) {
            self.texte = texte
            self.mois = mois
            auteurId = auteur.rawValue
            creeLe = date
            modifieLe = date
        }
    }
}

extension Souhait: Suppressible {
    var libelleType: String { "Ce mois-ci" }
    var titreAffiche: String { "J'aimerais que tu \(texte)" }
    var estFait: Bool { faitLe != nil }
    /// Membre à qui le souhait est confié.
    var destinataire: Membre? { auteur?.autre }

    /// Clé du mois de `date` : « 2026-11 ».
    static func cleMois(_ date: Date, calendrier: Calendar = .current) -> String {
        let composantes = calendrier.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", composantes.year ?? 0, composantes.month ?? 0)
    }

    /// Premier jour du mois d'une clé, ou nil si la clé est invalide.
    static func debutDuMois(_ cle: String, calendrier: Calendar = .current) -> Date? {
        let parties = cle.split(separator: "-").compactMap { Int($0) }
        guard parties.count == 2 else { return nil }
        return calendrier.date(from: DateComponents(year: parties[0], month: parties[1], day: 1))
    }

    static var actifs: Predicate<Souhait> {
        #Predicate { $0.supprimeLe == nil }
    }
}
