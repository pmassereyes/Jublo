import SwiftData

/// Version 5 : rappels (`ElementListe.rappelLe` pour le pense-bête, `Evenement.rappelBrut` pour
/// l'agenda) et cagnotte d'un voyage (`Destination.cagnotteId`).
/// Les autres modèles sont inchangés et restent déclarés dans leur version.
///
/// Contraintes CloudKit : propriétés optionnelles ou avec valeur par défaut, pas de
/// `@Attribute(.unique)`, relations optionnelles.
enum SchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            ElementListe.self, SchemaV1.Cagnotte.self, SchemaV1.Versement.self,
            SchemaV3.MetadonneesSync.self,
            Evenement.self, Destination.self, SchemaV4.Sortie.self, SchemaV4.Retard.self,
            SchemaV4.Souhait.self,
        ]
    }
}

/// Version courante du schéma, ouverte par `Persistance`.
typealias SchemaActuel = SchemaV5

enum PlanMigrationJublo: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
            .lightweight(fromVersion: SchemaV4.self, toVersion: SchemaV5.self),
        ]
    }
}

typealias ElementListe = SchemaV5.ElementListe
typealias Cagnotte = SchemaV1.Cagnotte
typealias Versement = SchemaV1.Versement
typealias MetadonneesSync = SchemaV3.MetadonneesSync
typealias Evenement = SchemaV5.Evenement
typealias Destination = SchemaV5.Destination
typealias Sortie = SchemaV4.Sortie
typealias Retard = SchemaV4.Retard
typealias Souhait = SchemaV4.Souhait
