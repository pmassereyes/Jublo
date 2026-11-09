import Foundation

/// Événement d'exemple (phase 1), en attendant le modèle de l'agenda partagé.
struct EvenementExemple: Identifiable {
    let titre: String
    let debut: Date
    let lieu: String?
    /// nil : pour nous deux.
    let pour: Membre?

    var id: String { titre }
}

enum AgendaExemples {
    static func evenements(maintenant: Date = .now) -> [EvenementExemple] {
        let calendrier = Calendar.current
        let aujourdhui = calendrier.startOfDay(for: maintenant)
        func le(_ jours: Int, _ heure: Int, _ minute: Int = 0) -> Date {
            calendrier.date(byAdding: DateComponents(day: jours, hour: heure, minute: minute), to: aujourdhui) ?? aujourdhui
        }
        return [
            EvenementExemple(titre: "Dîner chez Léa et Tom", debut: le(0, 20), lieu: "Montreuil", pour: nil),
            EvenementExemple(titre: "Dentiste", debut: le(1, 9, 30), lieu: "Cabinet Voltaire", pour: .julie),
            EvenementExemple(titre: "Foot avec l'équipe", debut: le(2, 19), lieu: "Gymnase des Lilas", pour: .pablo),
            EvenementExemple(titre: "Cinéma", debut: le(4, 21), lieu: "MK2 Bibliothèque", pour: nil),
            EvenementExemple(titre: "Week-end à Annecy", debut: le(5, 8), lieu: "Départ gare de Lyon", pour: nil),
        ]
    }

    /// Événements regroupés par jour, dans l'ordre.
    static func parJour(maintenant: Date = .now) -> [(jour: Date, evenements: [EvenementExemple])] {
        let groupes = Dictionary(grouping: evenements(maintenant: maintenant)) {
            Calendar.current.startOfDay(for: $0.debut)
        }
        return groupes.keys.sorted().map { jour in
            (jour, groupes[jour, default: []].sorted { $0.debut < $1.debut })
        }
    }
}
