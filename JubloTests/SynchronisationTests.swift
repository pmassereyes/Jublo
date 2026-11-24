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

/// Build debug (environnement CloudKit de développement) et TestFlight (production) sur le
/// même iPhone : l'état de synchronisation de l'un ne vaut rien pour l'autre.
@MainActor
struct SynchronisationEnvironnementTests {
    let banc: Banc
    let suite = "jublo-sync-\(UUID().uuidString)"
    let stockage: UserDefaults

    init() throws {
        banc = try Banc()
        stockage = try #require(UserDefaults(suiteName: suite))
    }

    private func etatSynchronise(dans environnement: String?) throws {
        if let environnement {
            stockage.set(environnement, forKey: "sync.environnement")
        }
        stockage.set(try JSONEncoder().encode(Synchronisation.Role.participant(proprietaire: "_proprietaire")), forKey: "sync.role")
        stockage.set(Data([1, 2, 3]), forKey: "sync.etatMoteur")
        stockage.set(["+\(UUID().uuidString)"], forKey: "sync.enAttente")
        let element = try banc.ajouter("Lait")
        banc.conteneur.mainContext.insert(MetadonneesSync(nomEnregistrement: element.id.uuidString, champsSysteme: Data([4])))
        try banc.conteneur.mainContext.save()
    }

    private func ouvrir(dans environnement: String) -> Synchronisation {
        Synchronisation(contexte: banc.conteneur.mainContext, stockage: stockage, active: false, environnement: environnement)
    }

    private func expectRepartiDeZero(_ synchronisation: Synchronisation, dans environnement: String) throws {
        #expect(synchronisation.role == .proprietaire)
        #expect(stockage.data(forKey: "sync.etatMoteur") == nil)
        #expect(stockage.stringArray(forKey: "sync.enAttente") == nil)
        #expect(try banc.tous(MetadonneesSync.self).isEmpty)
        #expect(try banc.tous(ElementListe.self).map(\.titre) == ["Lait"])
        #expect(stockage.string(forKey: "sync.environnement") == environnement)
    }

    @Test func unAutreEnvironnementRepartDeZeroEnGardantLesDonnees() throws {
        defer { stockage.removePersistentDomain(forName: suite) }
        try etatSynchronise(dans: "developpement")

        let synchronisation = ouvrir(dans: "production")

        try expectRepartiDeZero(synchronisation, dans: "production")
    }

    @Test func leMemeEnvironnementGardeLePartage() throws {
        defer { stockage.removePersistentDomain(forName: suite) }
        try etatSynchronise(dans: "production")
        stockage.set(Synchronisation.versionSchemaSync, forKey: "sync.versionSchema")

        let synchronisation = ouvrir(dans: "production")

        #expect(synchronisation.role == .participant(proprietaire: "_proprietaire"))
        #expect(stockage.data(forKey: "sync.etatMoteur") != nil)
        #expect(try banc.tous(MetadonneesSync.self).count == 1)
    }

    /// Avant la clé `sync.environnement`, seuls des builds debug ont synchronisé.
    @Test func unEtatSansEnvironnementVientDUnBuildDebug() throws {
        defer { stockage.removePersistentDomain(forName: suite) }
        try etatSynchronise(dans: nil)

        let synchronisation = ouvrir(dans: "production")

        try expectRepartiDeZero(synchronisation, dans: "production")
    }

    @Test func unPremierLancementNoteSonEnvironnement() throws {
        defer { stockage.removePersistentDomain(forName: suite) }

        _ = ouvrir(dans: "production")

        #expect(stockage.string(forKey: "sync.environnement") == "production")
        #expect(stockage.integer(forKey: "sync.versionSchema") == Synchronisation.versionSchemaSync)
    }

    /// Un build plus ancien a ignoré les types qu'il ne connaissait pas : on relit toute la
    /// zone, sans perdre le partage ni les changements en attente.
    @Test func unEtatDUnBuildPlusAncienEstReluEnEntier() throws {
        defer { stockage.removePersistentDomain(forName: suite) }
        try etatSynchronise(dans: "production")
        let enAttente = stockage.stringArray(forKey: "sync.enAttente")

        let synchronisation = ouvrir(dans: "production")

        #expect(stockage.data(forKey: "sync.etatMoteur") == nil)
        #expect(synchronisation.role == .participant(proprietaire: "_proprietaire"))
        #expect(stockage.stringArray(forKey: "sync.enAttente") == enAttente)
        #expect(try banc.tous(MetadonneesSync.self).count == 1)
        #expect(stockage.integer(forKey: "sync.versionSchema") == Synchronisation.versionSchemaSync)
    }

    @Test func unEtatAJourNEstPasRelu() throws {
        defer { stockage.removePersistentDomain(forName: suite) }
        try etatSynchronise(dans: "production")
        stockage.set(Synchronisation.versionSchemaSync, forKey: "sync.versionSchema")

        _ = ouvrir(dans: "production")

        #expect(stockage.data(forKey: "sync.etatMoteur") != nil)
    }
}
