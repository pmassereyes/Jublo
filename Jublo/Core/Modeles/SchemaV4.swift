import SwiftData

/// Version 4 : agenda, vacances envisagées, sorties à tester, retards et souhaits du mois.
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

/// Version courante du schéma, ouverte par `Persistance`.
typealias SchemaActuel = SchemaV4

enum PlanMigrationJublo: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
        ]
    }
}

typealias ElementListe = SchemaV2.ElementListe
typealias Cagnotte = SchemaV1.Cagnotte
typealias Versement = SchemaV1.Versement
typealias MetadonneesSync = SchemaV3.MetadonneesSync
typealias Evenement = SchemaV4.Evenement
typealias Destination = SchemaV4.Destination
typealias Sortie = SchemaV4.Sortie
typealias Retard = SchemaV4.Retard
typealias Souhait = SchemaV4.Souhait
