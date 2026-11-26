import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Jublo

/// Cagnotte rattachée à un projet de voyage (schéma V5).
@MainActor
struct CagnotteDuVoyageTests {
    let banc: Banc
    let zone = CKRecordZone.ID(zoneName: "Jublo", ownerName: CKCurrentUserDefaultName)

    init() throws {
        banc = try Banc()
    }

    private func cagnottes() throws -> [Cagnotte] {
        try banc.tous(Cagnotte.self)
    }

    @Test func laCagnotteDUnVoyagePrendSonNomEtSonBudget() throws {
        let lisbonne = try #require(banc.depot.ajouterDestination("Lisbonne", budgetCentimes: 90_000, par: .julie))
        banc.avancer(heures: 1)

        let cagnotte = banc.depot.creerCagnotte(pour: lisbonne, par: .pablo)

        #expect(cagnotte.nom == "Lisbonne")
        #expect(cagnotte.objectifCentimes == 90_000)
        #expect(cagnotte.auteur == .pablo)
        #expect(lisbonne.cagnotteId == cagnotte.id)
        #expect(lisbonne.modifieLe == banc.maintenant)
        #expect(try lisbonne.cagnotte(parmi: cagnottes())?.id == cagnotte.id)
    }

    @Test func uneCagnotteExistanteSeRattacheEtSeDetache() throws {
        let rome = try #require(banc.depot.ajouterDestination("Rome", par: .pablo))
        let vacances = banc.depot.creerCagnotte("Vacances", par: .julie)

        banc.depot.rattacher(vacances, a: rome)
        #expect(try rome.cagnotte(parmi: cagnottes())?.nom == "Vacances")

        banc.depot.rattacher(nil, a: rome)
        #expect(rome.cagnotteId == nil)
        #expect(try cagnottes().count == 1)
    }

    @Test func uneCagnotteALaCorbeilleNEstPlusAffichee() throws {
        let rome = try #require(banc.depot.ajouterDestination("Rome", par: .pablo))
        let cagnotte = banc.depot.creerCagnotte(pour: rome, par: .pablo)

        banc.depot.supprimer(cagnotte, par: .julie)
        #expect(try rome.cagnotte(parmi: cagnottes()) == nil)

        banc.depot.restaurer(cagnotte)
        #expect(try rome.cagnotte(parmi: cagnottes())?.id == cagnotte.id)
    }

    @Test func leLienFaitLAllerRetour() throws {
        let rome = try #require(banc.depot.ajouterDestination("Rome", par: .pablo))
        let cagnotte = banc.depot.creerCagnotte(pour: rome, par: .pablo)
        let miroir = MiroirLocal(contexte: banc.conteneur.mainContext)
        let enregistrements = [miroir.enregistrement(pour: rome, zone: zone), miroir.enregistrement(pour: cagnotte, zone: zone)]
        #expect(enregistrements[0]["cagnotteId"] as? String == cagnotte.id.uuidString)

        let autre = try Banc()
        MiroirLocal(contexte: autre.conteneur.mainContext).appliquer(enregistrements)

        let recue = try #require(try autre.tous(Destination.self).first)
        #expect(try recue.cagnotte(parmi: autre.tous(Cagnotte.self))?.nom == "Rome")
    }

    @Test func lAssistantSaitCeQuiEstDeCotePourLeVoyage() throws {
        let lisbonne = try #require(banc.depot.ajouterDestination("Lisbonne", par: .julie))
        let cagnotte = banc.depot.creerCagnotte(pour: lisbonne, par: .pablo)
        banc.depot.verser(2_500, dans: cagnotte, par: .julie)

        let consignes = ContexteAssistant.consignes(
            pour: .pablo, donnees: DonneesAssistant.lire(dans: banc.conteneur.mainContext), maintenant: banc.maintenant
        )

        #expect(consignes.contains("cagnotte « Lisbonne » : \(Formats.montant(2_500)) de côté"))
    }
}
