import Foundation
import SwiftData

enum Persistance {
    /// Ouvre la base locale, une base en mémoire (tests, aperçus) ou le fichier `url` (tests de migration).
    static func conteneur(enMemoire: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaActuel.self)
        // La sync passera par CKSyncEngine (phase 2). On coupe explicitement le miroir
        // CloudKit de SwiftData, qui ne sait pas gérer une base partagée.
        let configuration = if let url {
            ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: enMemoire, cloudKitDatabase: .none)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: PlanMigrationJublo.self,
            configurations: [configuration]
        )
    }
}
