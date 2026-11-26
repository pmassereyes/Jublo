import Foundation
import SwiftData

/// Où en est une idée de vacances.
enum StatutDestination: String, CaseIterable, Identifiable {
    case envisagee
    case reservee
    case faite

    var id: Self { self }

    var titre: String {
        switch self {
        case .envisagee: "Envisagée"
        case .reservee: "Réservée"
        case .faite: "Faite"
        }
    }
}

extension SchemaV5 {
    /// Idée de vacances, que chacun note pour comparer à deux.
    @Model
    final class Destination {
        var id: UUID = UUID()
        var nom: String = ""
        /// Période envisagée, en texte libre (« été 2027 », « un long week-end »).
        var quand: String?
        var budgetCentimes: Int?
        var note: String?
        var statutBrut: String = StatutDestination.envisagee.rawValue
        var avisPablo: Int?
        var avisJulie: Int?
        /// Cagnotte rattachée au voyage (depuis la V5). Un simple identifiant : la cagnotte
        /// vit sa vie (corbeille, versements) sans dépendre du voyage.
        var cagnotteId: UUID?

        var auteurId: String = ""
        var creeLe: Date = Date.now
        var modifieLe: Date = Date.now
        var supprimeLe: Date?
        var supprimePar: String?

        init(nom: String, auteur: Membre, le date: Date) {
            self.nom = nom
            auteurId = auteur.rawValue
            creeLe = date
            modifieLe = date
        }
    }
}

extension Destination: Suppressible, AvisDuCouple {
    var libelleType: String { "Vacances" }
    var titreAffiche: String { nom }
    var statut: StatutDestination { StatutDestination(rawValue: statutBrut) ?? .envisagee }

    static var actives: Predicate<Destination> {
        #Predicate { $0.supprimeLe == nil }
    }

    /// Cagnotte rattachée, si elle est parmi `cagnottes` et hors corbeille.
    func cagnotte(parmi cagnottes: [Cagnotte]) -> Cagnotte? {
        guard let cagnotteId else { return nil }
        return cagnottes.first { $0.id == cagnotteId && $0.supprimeLe == nil }
    }
}
