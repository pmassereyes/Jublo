import Foundation

/// Notifications « l'autre a mis à jour une liste ou l'agenda », tirées des changements reçus
/// de CloudKit (`ChangementRecu`). Une notification par liste et par nature de changement, pour
/// ne pas en envoyer vingt quand l'autre fait les courses.
///
/// Ne sont pas annoncés : ses propres changements, ceux de plus de 24 h, les suppressions dans
/// les listes, les rendez-vous déjà passés, et dans la wish list tout sauf les envies que l'autre
/// ajoute pour lui-même (une idée pour toi ou un cadeau offert gâcheraient la surprise).
enum Annonces {
    static let prefixe = "annonce."
    static let fraicheur: TimeInterval = 24 * 60 * 60

    private enum Rubrique: Hashable {
        case liste(TypeListe)
        case agenda
    }

    private struct Groupe: Hashable {
        let rubrique: Rubrique
        let nature: ChangementRecu.Nature
        let auteur: Membre
    }

    static func prevues(
        _ changements: [ChangementRecu], pour courant: Membre, listes: Bool, agenda: Bool,
        maintenant: Date, calendrier: Calendar = .current
    ) -> [NotificationPrevue] {
        var ordre: [Groupe] = []
        var groupes: [Groupe: [ChangementRecu]] = [:]
        for changement in changements {
            let auteur = changement.par ?? courant.autre
            guard auteur != courant, changement.le >= maintenant.addingTimeInterval(-fraicheur) else { continue }
            let rubrique: Rubrique
            switch changement.sujet {
            case .liste(let type, let pour):
                guard listes else { continue }
                switch type {
                case .wishList:
                    guard changement.nature == .ajout, pour == auteur else { continue }
                case .penseBete, .courses:
                    guard changement.nature == .ajout || changement.nature == .coche else { continue }
                }
                rubrique = .liste(type)
            case .agenda(_, let fin, _):
                guard agenda, changement.nature != .coche, fin >= calendrier.startOfDay(for: maintenant) else { continue }
                rubrique = .agenda
            }
            let groupe = Groupe(rubrique: rubrique, nature: changement.nature, auteur: auteur)
            if groupes[groupe] == nil {
                ordre.append(groupe)
            }
            groupes[groupe, default: []].append(changement)
        }
        return ordre.map { groupe in
            notification(groupe, groupes[groupe] ?? [], courant: courant, maintenant: maintenant, calendrier: calendrier)
        }
    }

    private static func notification(
        _ groupe: Groupe, _ changements: [ChangementRecu], courant: Membre, maintenant: Date, calendrier: Calendar
    ) -> NotificationPrevue {
        let qui = Libelles.quiEnDebut(groupe.auteur, vuPar: courant)
        let verbe = switch groupe.nature {
        case .ajout: "a ajouté"
        case .coche: "a coché"
        case .modification: "a modifié"
        case .suppression: "a supprimé"
        }
        let titres = changements.map(\.titre)
        let identifiant = prefixe + UUID().uuidString
        switch groupe.rubrique {
        case .liste(let type):
            let corps = if titres.count == 1 {
                type == .wishList ? "\(qui) \(verbe) « \(titres[0]) » à ses envies" : "\(qui) \(verbe) « \(titres[0]) »"
            } else {
                "\(qui) \(verbe) \(titres.count) \(type == .wishList ? "envies" : "éléments") : \(enumeration(titres))"
            }
            var ouvrir = ["onglet": "listes", "liste": type.rawValue]
            if type == .wishList {
                // Les envies annoncées sont celles de l'autre : on ouvre son côté.
                ouvrir["pour"] = groupe.auteur.rawValue
            }
            return NotificationPrevue(
                identifiant: identifiant, titre: type.titre, corps: corps, fil: "listes.\(type.rawValue)",
                date: nil, ouvrir: ouvrir
            )
        case .agenda:
            let corps: String
            if titres.count > 1 {
                corps = "\(qui) \(verbe) \(titres.count) rendez-vous : \(enumeration(titres))"
            } else if groupe.nature == .suppression {
                corps = "\(qui) a retiré « \(titres[0]) » de l'agenda"
            } else if case .agenda(let debut, _, let journeeEntiere) = changements[0].sujet {
                let jour = Formats.jourProche(debut, maintenant: maintenant, calendrier: calendrier)
                let quand = journeeEntiere ? jour : "\(jour) à \(Formats.heure(debut))"
                corps = "\(qui) \(verbe) « \(titres[0]) » · \(quand)"
            } else {
                corps = "\(qui) \(verbe) « \(titres[0]) »"
            }
            return NotificationPrevue(
                identifiant: identifiant, titre: "Agenda", corps: corps, fil: "agenda",
                date: nil, ouvrir: ["onglet": "agenda"]
            )
        }
    }

    /// « Lait, Œufs et Pain », « Lait, Œufs, Pain et 2 autres ».
    static func enumeration(_ titres: [String]) -> String {
        switch titres.count {
        case 0: return ""
        case 1: return titres[0]
        case 2, 3: return titres.dropLast().joined(separator: ", ") + " et " + (titres.last ?? "")
        default: return titres.prefix(3).joined(separator: ", ") + " et \(titres.count - 3) autres"
        }
    }
}
