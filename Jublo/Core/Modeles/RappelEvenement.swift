import Foundation

/// Rappel d'un rendez-vous, avant son début. Une journée entière n'a pas d'heure de début :
/// son rappel tombe à 9 h (ou à 18 h la veille).
enum RappelEvenement: String, CaseIterable, Identifiable {
    case auDebut
    case cinqMinutes
    case quinzeMinutes
    case trenteMinutes
    case uneHeure
    case deuxHeures
    case unJour
    case deuxJours
    case uneSemaine

    var id: Self { self }

    /// Rappels proposés : à la minute près pour un rendez-vous, au jour près pour une journée entière.
    static func choix(journeeEntiere: Bool) -> [RappelEvenement] {
        journeeEntiere ? [.auDebut, .unJour, .deuxJours, .uneSemaine] : allCases
    }

    func libelle(journeeEntiere: Bool) -> String {
        switch self {
        case .auDebut: journeeEntiere ? "Le jour même à 9 h" : "À l'heure du rendez-vous"
        case .cinqMinutes: "5 min avant"
        case .quinzeMinutes: "15 min avant"
        case .trenteMinutes: "30 min avant"
        case .uneHeure: "1 h avant"
        case .deuxHeures: "2 h avant"
        case .unJour: journeeEntiere ? "La veille à 18 h" : "1 jour avant"
        case .deuxJours: journeeEntiere ? "2 jours avant à 9 h" : "2 jours avant"
        case .uneSemaine: journeeEntiere ? "1 semaine avant à 9 h" : "1 semaine avant"
        }
    }

    /// Rappel gardé quand le rendez-vous passe en journée entière : à défaut d'équivalent,
    /// le jour même.
    func adapte(journeeEntiere: Bool) -> RappelEvenement {
        Self.choix(journeeEntiere: journeeEntiere).contains(self) ? self : .auDebut
    }

    /// Date du rappel d'un rendez-vous qui commence à `debut`.
    func date(debut: Date, journeeEntiere: Bool, calendrier: Calendar = .current) -> Date? {
        if journeeEntiere {
            let (jours, heure) = switch self {
            case .unJour: (1, 18)
            case .deuxJours: (2, 9)
            case .uneSemaine: (7, 9)
            default: (0, 9)
            }
            let jour = calendrier.startOfDay(for: debut)
            guard let jourDuRappel = calendrier.date(byAdding: .day, value: -jours, to: jour) else { return nil }
            return calendrier.date(bySettingHour: heure, minute: 0, second: 0, of: jourDuRappel)
        }
        switch self {
        case .auDebut: return debut
        case .cinqMinutes: return debut.addingTimeInterval(-5 * 60)
        case .quinzeMinutes: return debut.addingTimeInterval(-15 * 60)
        case .trenteMinutes: return debut.addingTimeInterval(-30 * 60)
        case .uneHeure: return debut.addingTimeInterval(-60 * 60)
        case .deuxHeures: return debut.addingTimeInterval(-2 * 60 * 60)
        case .unJour: return calendrier.date(byAdding: .day, value: -1, to: debut)
        case .deuxJours: return calendrier.date(byAdding: .day, value: -2, to: debut)
        case .uneSemaine: return calendrier.date(byAdding: .day, value: -7, to: debut)
        }
    }
}
