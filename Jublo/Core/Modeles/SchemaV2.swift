import SwiftData

/// Version 2 : les envies de la wish list ont un destinataire (`ElementListe.pourId`).
///
/// Contraintes CloudKit (phase 2) : propriétés optionnelles ou avec valeur par défaut,
/// pas de `@Attribute(.unique)`, relations optionnelles.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ElementListe.self, SchemaV1.Cagnotte.self, SchemaV1.Versement.self]
    }
}

/// Version courante du schéma, ouverte par `Persistance`.
typealias SchemaActuel = SchemaV2

enum PlanMigrationJublo: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

typealias ElementListe = SchemaV2.ElementListe
typealias Cagnotte = SchemaV1.Cagnotte
typealias Versement = SchemaV1.Versement
