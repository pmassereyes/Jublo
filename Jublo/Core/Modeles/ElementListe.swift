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

    /// Invite du champ d'ajout.
    var invitationAjout: String {
        switch self {
        case .penseBete: "Ajouter au pense-bête"
        case .courses: "Ajouter aux courses"
        case .wishList: "Ajouter à la wish list"
        }
    }
}

extension SchemaV2 {
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
        /// Wish list seulement : membre à qui l'envie est destinée.
        /// nil pour les autres listes, et pour les envies créées avant la V2 (voir `destinataire`).
        var pourId: String?

        var auteurId: String = ""
        var creeLe: Date = Date.now
        var modifieLe: Date = Date.now
        var supprimeLe: Date?
        var supprimePar: String?

        /// `pour` ne compte que pour la wish list ; par défaut, l'envie est celle de l'auteur.
        init(type: TypeListe, titre: String, auteur: Membre, pour destinataire: Membre? = nil, le date: Date) {
            typeBrut = type.rawValue
            self.titre = titre
            pourId = type == .wishList ? (destinataire ?? auteur).rawValue : nil
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

extension ElementListe {
    /// Membre à qui l'envie est destinée. Une envie sans destinataire est celle de son auteur.
    var destinataire: Membre? {
        pourId.flatMap(Membre.init(rawValue:)) ?? auteur
    }

    /// Éléments d'une liste qui ne sont pas dans la corbeille.
    static func actifs(dans type: TypeListe) -> Predicate<ElementListe> {
        let brut = type.rawValue
        return #Predicate { $0.typeBrut == brut && $0.supprimeLe == nil }
    }

    /// Envies de la wish list destinées à `membre`, hors corbeille.
    static func envies(pour membre: Membre) -> Predicate<ElementListe> {
        let wishList = TypeListe.wishList.rawValue
        let id: String? = membre.rawValue
        let auteur = membre.rawValue
        return #Predicate { element in
            element.typeBrut == wishList && element.supprimeLe == nil
                && (element.pourId == id || (element.pourId == nil && element.auteurId == auteur))
        }
    }
}
