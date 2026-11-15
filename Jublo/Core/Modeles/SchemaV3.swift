import Foundation
import SwiftData

/// Version 3 : métadonnées CloudKit (`MetadonneesSync`) pour la synchronisation.
///
/// Contraintes CloudKit : propriétés optionnelles ou avec valeur par défaut, pas de
/// `@Attribute(.unique)`, relations optionnelles.
enum SchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SchemaV2.ElementListe.self, SchemaV1.Cagnotte.self, SchemaV1.Versement.self, MetadonneesSync.self]
    }
}

extension SchemaV3 {
    /// Champs système CloudKit d'un enregistrement (zone, étiquette de version…), propres à cet
    /// appareil et jamais synchronisés. Sans eux, chaque envoi serait vu comme un conflit.
    @Model
    final class MetadonneesSync {
        /// Nom de l'enregistrement CloudKit, c'est-à-dire l'`id` du modèle.
        var nomEnregistrement: String = ""
        var champsSysteme: Data?

        init(nomEnregistrement: String, champsSysteme: Data?) {
            self.nomEnregistrement = nomEnregistrement
            self.champsSysteme = champsSysteme
        }
    }
}

/// Version courante du schéma, ouverte par `Persistance`.
typealias SchemaActuel = SchemaV3

enum PlanMigrationJublo: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self] }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
        ]
    }
}

typealias ElementListe = SchemaV2.ElementListe
typealias Cagnotte = SchemaV1.Cagnotte
typealias Versement = SchemaV1.Versement
typealias MetadonneesSync = SchemaV3.MetadonneesSync
