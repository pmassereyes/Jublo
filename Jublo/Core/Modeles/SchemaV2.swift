import SwiftData

/// Version 2 (figée) : les envies de la wish list ont un destinataire (`ElementListe.pourId`).
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ElementListe.self, SchemaV1.Cagnotte.self, SchemaV1.Versement.self]
    }
}
