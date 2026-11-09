import SwiftData

enum Persistance {
    /// Ouvre la base locale (ou une base en mémoire pour les tests et les aperçus).
    static func conteneur(enMemoire: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: enMemoire,
            // La sync passera par CKSyncEngine (phase 2). On coupe explicitement le miroir
            // CloudKit de SwiftData, qui ne sait pas gérer une base partagée.
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: PlanMigrationJublo.self,
            configurations: [configuration]
        )
    }
}
