import Foundation
import SwiftData

extension SchemaV5 {
    /// Rendez-vous de l'agenda partagé.
    @Model
    final class Evenement {
        var id: UUID = UUID()
        var titre: String = ""
        var debut: Date = Date.now
        /// Fin, pour un événement sur plusieurs heures ou plusieurs jours.
        var fin: Date?
        var journeeEntiere: Bool = false
        var lieu: String?
        var note: String?
        /// Membre concerné ; nil quand l'événement concerne les deux.
        var pourId: String?
        /// `RappelEvenement` stocké en texte ; nil sans rappel (depuis la V5).
        var rappelBrut: String?

        var auteurId: String = ""
        var creeLe: Date = Date.now
        var modifieLe: Date = Date.now
        var supprimeLe: Date?
        var supprimePar: String?

        init(titre: String, debut: Date, auteur: Membre, le date: Date) {
            self.titre = titre
            self.debut = debut
            auteurId = auteur.rawValue
            creeLe = date
            modifieLe = date
        }
    }
}

extension Evenement: Suppressible {
    var libelleType: String { "Agenda" }
    var titreAffiche: String { titre }
}

extension Evenement {
    /// Membre concerné ; nil pour les deux.
    var concerne: Membre? { pourId.flatMap(Membre.init(rawValue:)) }

    /// Fin effective : la fin saisie, sinon le début.
    var finEffective: Date { max(fin ?? debut, debut) }

    /// Vrai si l'événement n'est pas encore terminé à `date` : un événement d'une journée
    /// entière reste à venir jusqu'au soir.
    func estAVenir(a date: Date, calendrier: Calendar = .current) -> Bool {
        if journeeEntiere {
            let dernierJour = calendrier.startOfDay(for: finEffective)
            return calendrier.date(byAdding: .day, value: 1, to: dernierJour).map { $0 > date } ?? false
        }
        return finEffective >= date
    }

    var rappel: RappelEvenement? { rappelBrut.flatMap(RappelEvenement.init(rawValue:)) }

    /// Date du rappel, s'il y en a un.
    func dateRappel(calendrier: Calendar = .current) -> Date? {
        rappel?.date(debut: debut, journeeEntiere: journeeEntiere, calendrier: calendrier)
    }

    /// Vrai si le rendez-vous concerne `membre` : lui seul, ou les deux.
    func estPour(_ membre: Membre) -> Bool {
        concerne == nil || concerne == membre
    }

    /// Événements hors corbeille.
    static var actifs: Predicate<Evenement> {
        #Predicate { $0.supprimeLe == nil }
    }
}
