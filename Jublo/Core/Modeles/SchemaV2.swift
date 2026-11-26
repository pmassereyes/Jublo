import Foundation
import SwiftData

/// Version 2 (figée) : les envies de la wish list ont un destinataire (`ElementListe.pourId`).
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ElementListe.self, SchemaV1.Cagnotte.self, SchemaV1.Versement.self]
    }
}

extension SchemaV2 {
    /// Élément de liste tel qu'en V2 à V4 (avec destinataire, sans rappel).
    @Model
    final class ElementListe {
        var id: UUID = UUID()
        var typeBrut: String = TypeListe.penseBete.rawValue
        var titre: String = ""
        var estCoche: Bool = false
        var cocheLe: Date?
        var cochePar: String?
        var pourId: String?

        var auteurId: String = ""
        var creeLe: Date = Date.now
        var modifieLe: Date = Date.now
        var supprimeLe: Date?
        var supprimePar: String?

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
