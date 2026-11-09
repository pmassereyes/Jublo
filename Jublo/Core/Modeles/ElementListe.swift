import Foundation
import SwiftData

/// Les trois listes de l'onglet Listes.
enum TypeListe: String, CaseIterable, Identifiable {
    case penseBete
    case courses
    case wishList

    var id: Self { self }

    var titre: String {
        switch self {
        case .penseBete: "Pense-bête"
        case .courses: "Courses"
        case .wishList: "Wish list"
        }
    }
}

extension SchemaV1 {
    /// Élément d'une liste : pense-bête, courses ou wish list.
    @Model
    final class ElementListe {
        var id: UUID = UUID()
        /// `TypeListe` stocké en texte, plus simple à filtrer et à synchroniser.
        var typeBrut: String = TypeListe.penseBete.rawValue
        var titre: String = ""
        var estCoche: Bool = false
        var cocheLe: Date?
        var cochePar: String?

        var auteurId: String = ""
        var creeLe: Date = Date.now
        var modifieLe: Date = Date.now
        var supprimeLe: Date?
        var supprimePar: String?

        init(type: TypeListe, titre: String, auteur: Membre, le date: Date) {
            typeBrut = type.rawValue
            self.titre = titre
            auteurId = auteur.rawValue
            creeLe = date
            modifieLe = date
        }
    }
}

extension ElementListe: Suppressible {
    var type: TypeListe { TypeListe(rawValue: typeBrut) ?? .penseBete }
    var libelleType: String { type.titre }
    var titreAffiche: String { titre }
}
