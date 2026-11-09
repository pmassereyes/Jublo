import Foundation
import SwiftData
import Testing
@testable import Jublo

@MainActor
struct WishListTests {
    let banc: Banc

    init() throws {
        banc = try Banc()
    }

    private func envies(pour membre: Membre) throws -> [String] {
        try banc.conteneur.mainContext
            .fetch(FetchDescriptor(predicate: ElementListe.envies(pour: membre), sortBy: [SortDescriptor(\.titre)]))
            .map(\.titre)
    }

    @Test func uneEnvieEstParDefautPourSonAuteur() throws {
        let plaid = try banc.ajouter("Plaid", a: .wishList, par: .julie)

        #expect(plaid.pourId == Membre.julie.rawValue)
        #expect(plaid.destinataire == .julie)
    }

    @Test func onPeutNoterUneIdeePourLAutre() throws {
        let idee = try #require(banc.depot.ajouter("Cours de céramique", a: .wishList, par: .pablo, pour: .julie))

        #expect(idee.destinataire == .julie)
        #expect(idee.auteur == .pablo)
    }

    @Test func lesAutresListesNOntPasDeDestinataire() throws {
        let lait = try #require(banc.depot.ajouter("Lait", a: .courses, par: .pablo, pour: .julie))

        #expect(lait.pourId == nil)
    }

    @Test func chacunNeVoitQueSesEnvies() throws {
        _ = try banc.ajouter("Platine vinyle", a: .wishList, par: .pablo)
        _ = try banc.ajouter("Plaid", a: .wishList, par: .julie)
        banc.depot.ajouter("Cours de céramique", a: .wishList, par: .pablo, pour: .julie)
        _ = try banc.ajouter("Lait", a: .courses, par: .julie)

        #expect(try envies(pour: .pablo) == ["Platine vinyle"])
        #expect(try envies(pour: .julie) == ["Cours de céramique", "Plaid"])
    }

    @Test func uneEnvieSansDestinataireEstCelleDeSonAuteur() throws {
        let ancienne = try banc.ajouter("Plaid", a: .wishList, par: .julie)
        ancienne.pourId = nil

        #expect(ancienne.destinataire == .julie)
        #expect(try envies(pour: .julie) == ["Plaid"])
        #expect(try envies(pour: .pablo).isEmpty)
    }

    @Test func uneEnvieMiseALaCorbeilleDisparait() throws {
        let plaid = try banc.ajouter("Plaid", a: .wishList, par: .julie)

        banc.depot.supprimer(plaid, par: .pablo)

        #expect(try envies(pour: .julie).isEmpty)
    }
}

@MainActor
struct MigrationTests {
    @Test func uneBaseV1EstMigreeSansPerte() throws {
        let dossier = FileManager.default.temporaryDirectory.appending(path: "jublo-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        let url = dossier.appending(path: "jublo.store")
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)

        do {
            let schemaV1 = Schema(versionedSchema: SchemaV1.self)
            let v1 = try ModelContainer(
                for: schemaV1,
                configurations: [ModelConfiguration(schema: schemaV1, url: url, cloudKitDatabase: .none)]
            )
            let contexte = v1.mainContext
            contexte.insert(SchemaV1.ElementListe(type: .wishList, titre: "Plaid", auteur: .julie, le: date))
            contexte.insert(SchemaV1.ElementListe(type: .courses, titre: "Lait", auteur: .pablo, le: date))
            let cagnotte = SchemaV1.Cagnotte(nom: "Lisbonne", objectifCentimes: nil, auteur: .pablo, le: date)
            contexte.insert(cagnotte)
            let versement = SchemaV1.Versement(montantCentimes: 2_000, note: nil, auteur: .julie, le: date)
            contexte.insert(versement)
            versement.cagnotte = cagnotte
            try contexte.save()
        }

        let v2 = try Persistance.conteneur(url: url)
        let contexte = v2.mainContext
        let elements = try contexte.fetch(FetchDescriptor<ElementListe>(sortBy: [SortDescriptor(\.titre)]))
        #expect(elements.map(\.titre) == ["Lait", "Plaid"])
        #expect(elements.allSatisfy { $0.pourId == nil })
        #expect(try contexte.fetch(FetchDescriptor(predicate: ElementListe.envies(pour: .julie))).map(\.titre) == ["Plaid"])
        let cagnottes = try contexte.fetch(FetchDescriptor<Cagnotte>())
        #expect(cagnottes.map(\.soldeCentimes) == [2_000])
    }
}
