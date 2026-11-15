import Foundation
import Testing
@testable import Jublo

@MainActor
struct SynchronisationInactiveTests {
    @Test func sansICloudRienNeSort() async throws {
        let banc = try Banc()
        let suite = "jublo-sync-\(UUID().uuidString)"
        let stockage = try #require(UserDefaults(suiteName: suite))
        defer { stockage.removePersistentDomain(forName: suite) }
        let synchronisation = Synchronisation(contexte: banc.conteneur.mainContext, stockage: stockage, active: false)
        banc.depot.observateur = synchronisation

        _ = try banc.ajouter("Lait")
        await synchronisation.demarrer()

        #expect(synchronisation.role == .proprietaire)
        #expect(synchronisation.etat == .inactive("Synchronisation désactivée."))
        #expect(synchronisation.etatPartage == .aucun)
        #expect(stockage.stringArray(forKey: "sync.enAttente") == nil)
    }
}
