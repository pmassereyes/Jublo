import SwiftData

/// Version 1 du schéma. Toute évolution des modèles passe par une nouvelle version
/// (`SchemaV2`…) ajoutée à `PlanMigrationJublo`.
///
/// Contraintes CloudKit (phase 2) : propriétés optionnelles ou avec valeur par défaut,
/// pas de `@Attribute(.unique)`, relations optionnelles.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ElementListe.self, Cagnotte.self, Versement.self]
    }
}

enum PlanMigrationJublo: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

typealias ElementListe = SchemaV1.ElementListe
typealias Cagnotte = SchemaV1.Cagnotte
typealias Versement = SchemaV1.Versement
