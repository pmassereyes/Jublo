import Foundation
import SwiftData

/// Version 1 du schéma, figée : elle sert uniquement à migrer les bases existantes.
/// Ne plus modifier ce fichier ; toute évolution passe par une nouvelle version.
///
/// Un modèle inchangé reste déclaré dans la dernière version où il a changé :
/// `Cagnotte` et `Versement` vivent encore ici et sont repris par les versions suivantes.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ElementListe.self, Cagnotte.self, Versement.self]
    }
}

extension SchemaV1 {
    /// Élément de liste tel qu'en V1 (sans destinataire).
    @Model
    final class ElementListe {
        var id: UUID = UUID()
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
