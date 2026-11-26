import Foundation

/// Rappels à programmer sur cet iPhone : les éléments du pense-bête (sur les deux iPhones) et
/// les rendez-vous qui concernent ce membre (les siens et ceux de vous deux).
enum Rappels {
    static let prefixe = "rappel."
    /// iOS ne garde que 64 notifications programmées par app : on garde les plus proches.
    static let maximum = 60

    static func prevus(
        elements: [ElementListe], evenements: [Evenement], pour membre: Membre,
        maintenant: Date, calendrier: Calendar = .current
    ) -> [NotificationPrevue] {
        var prevus: [NotificationPrevue] = []
        for element in elements where element.type == .penseBete && element.supprimeLe == nil && !element.estCoche {
            guard let date = element.rappelLe, date > maintenant else { continue }
            prevus.append(NotificationPrevue(
                identifiant: prefixe + element.id.uuidString,
                titre: TypeListe.penseBete.titre,
                corps: element.titre,
                fil: "rappels",
                date: date,
                ouvrir: ["onglet": "listes", "liste": TypeListe.penseBete.rawValue]
            ))
        }
        for evenement in evenements where evenement.supprimeLe == nil && evenement.estPour(membre) {
            guard let date = evenement.dateRappel(calendrier: calendrier), date > maintenant else { continue }
            prevus.append(NotificationPrevue(
                identifiant: prefixe + evenement.id.uuidString,
                titre: evenement.titre,
                corps: detail(evenement, rappelLe: date, vuPar: membre, calendrier: calendrier),
                fil: "rappels",
                date: date,
                ouvrir: ["onglet": "agenda"]
            ))
        }
        return Array(prevus.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }.prefix(maximum))
    }

    /// « Demain à 14:30 · Cabinet · Vous deux », vu au moment du rappel.
    static func detail(_ evenement: Evenement, rappelLe date: Date, vuPar membre: Membre, calendrier: Calendar = .current) -> String {
        let jour = Formats.jourProche(evenement.debut, maintenant: date, calendrier: calendrier)
        var morceaux = [evenement.journeeEntiere ? "\(jour), toute la journée" : "\(jour) à \(Formats.heure(evenement.debut))"]
        if let lieu = evenement.lieu { morceaux.append(lieu) }
        morceaux.append(Libelles.concerne(evenement.concerne, vuPar: membre))
        return morceaux.joined(separator: " · ")
    }
}
