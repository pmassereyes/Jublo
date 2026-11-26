import Foundation
import SwiftData

/// Version 4 (figée) : agenda, vacances envisagées, sorties à tester, retards et souhaits du mois.
/// Les modèles existants sont inchangés et restent déclarés dans leur version.
///
/// Contraintes CloudKit : propriétés optionnelles ou avec valeur par défaut, pas de
/// `@Attribute(.unique)`, relations optionnelles.
enum SchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SchemaV2.ElementListe.self, SchemaV1.Cagnotte.self, SchemaV1.Versement.self,
            SchemaV3.MetadonneesSync.self,
            Evenement.self, Destination.self, Sortie.self, Retard.self, Souhait.self,
        ]
    }
}

extension SchemaV4 {
    /// Rendez-vous tel qu'en V4 (sans rappel).
    @Model
    final class Evenement {
        var id: UUID = UUID()
        var titre: String = ""
        var debut: Date = Date.now
        var fin: Date?
        var journeeEntiere: Bool = false
        var lieu: String?
        var note: String?
        var pourId: String?

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

extension SchemaV4 {
    /// Idée de vacances telle qu'en V4 (sans cagnotte).
    @Model
    final class Destination {
        var id: UUID = UUID()
        var nom: String = ""
        var quand: String?
        var budgetCentimes: Int?
        var note: String?
        var statutBrut: String = StatutDestination.envisagee.rawValue
        var avisPablo: Int?
        var avisJulie: Int?

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
