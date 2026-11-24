import Foundation
import Testing
@testable import Jublo

/// Raccourci Siri « Ajoute un rendez-vous dans Jublo » : enregistrement et réponse de Siri.
@MainActor
@Suite struct SiriTests {
    private let calendrier: Calendar = {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendrier.locale = Locale(identifier: "fr_FR")
        return calendrier
    }()

    /// Identité isolée : `choisi` à nil, personne n'a encore dit qui utilise l'iPhone.
    private func identite(_ choisi: Membre?) throws -> Identite {
        let suite = "tests-siri-\(UUID().uuidString)"
        let stockage = try #require(UserDefaults(suiteName: suite))
        stockage.removePersistentDomain(forName: suite)
        let identite = Identite(stockage: stockage)
        if let choisi { identite.membre = choisi }
        return identite
    }

    private func date(_ jour: Int, _ heure: Int, _ minute: Int = 0) throws -> Date {
        try #require(calendrier.date(from: DateComponents(year: 2026, month: 11, day: jour, hour: heure, minute: minute)))
    }

    @Test func unRendezVousDicteEstSigneParLeMembreDeLIPhone() throws {
        let banc = try Banc()
        let evenement = try RendezVousDicte.enregistrer(
            titre: "  Dîner chez Marc ", quand: try date(25, 20), pour: .nousDeux,
            depot: banc.depot, identite: try identite(.julie), calendrier: calendrier
        )

        #expect(evenement.titre == "Dîner chez Marc")
        #expect(evenement.auteur == .julie)
        #expect(evenement.pourId == nil)
        #expect(!evenement.journeeEntiere)
        #expect(evenement.debut == (try date(25, 20)))
        #expect(try banc.tous(Evenement.self).count == 1)
    }

    @Test(arguments: [
        (PourQuiSiri.nousDeux, Membre?.none),
        (.moi, .julie),
        (.pablo, .pablo),
        (.julie, .julie),
    ])
    func pourQui(_ pour: PourQuiSiri, attendu: Membre?) throws {
        let banc = try Banc()
        let evenement = try RendezVousDicte.enregistrer(
            titre: "Dentiste", quand: try date(26, 9), pour: pour,
            depot: banc.depot, identite: try identite(.julie), calendrier: calendrier
        )
        #expect(evenement.concerne == attendu)
    }

    @Test func uneDateSansHeureDonneUneJourneeEntiere() throws {
        let banc = try Banc()
        let evenement = try RendezVousDicte.enregistrer(
            titre: "Week-end à Lyon", quand: try date(28, 0), pour: .nousDeux,
            depot: banc.depot, identite: try identite(.pablo), calendrier: calendrier
        )
        #expect(evenement.journeeEntiere)
    }

    @Test func sansMembreChoisiRienNEstEnregistre() throws {
        let banc = try Banc()
        #expect(throws: RendezVousDicte.Erreur.membreInconnu) {
            try RendezVousDicte.enregistrer(
                titre: "Cinéma", quand: try date(25, 20), pour: .nousDeux,
                depot: banc.depot, identite: try identite(nil), calendrier: calendrier
            )
        }
        #expect(try banc.tous(Evenement.self).isEmpty)
    }

    @Test func unTitreVideEstRefuse() throws {
        let banc = try Banc()
        #expect(throws: RendezVousDicte.Erreur.titreVide) {
            try RendezVousDicte.enregistrer(
                titre: "   ", quand: try date(25, 20), pour: .nousDeux,
                depot: banc.depot, identite: try identite(.pablo), calendrier: calendrier
            )
        }
        #expect(try banc.tous(Evenement.self).isEmpty)
    }

    @Test func siriConfirmeLeJourEtLHeure() throws {
        let banc = try Banc()
        let maintenant = try date(24, 11)
        let diner = try RendezVousDicte.enregistrer(
            titre: "Dîner chez Marc", quand: try date(25, 20), pour: .nousDeux,
            depot: banc.depot, identite: try identite(.pablo), calendrier: calendrier
        )
        #expect(RendezVousDicte.confirmation(diner, vuPar: .pablo, maintenant: maintenant, calendrier: calendrier)
            == "C'est noté : « Dîner chez Marc », demain à 20:00.")

        let weekEnd = try RendezVousDicte.enregistrer(
            titre: "Week-end", quand: try date(28, 0), pour: .julie,
            depot: banc.depot, identite: try identite(.pablo), calendrier: calendrier
        )
        #expect(RendezVousDicte.confirmation(weekEnd, vuPar: .pablo, maintenant: maintenant, calendrier: calendrier)
            == "C'est noté : « Week-end », samedi 28 novembre, toute la journée (pour Julie).")
        #expect(RendezVousDicte.confirmation(weekEnd, vuPar: .julie, maintenant: maintenant, calendrier: calendrier)
            == "C'est noté : « Week-end », samedi 28 novembre, toute la journée (pour toi).")
    }

    @Test func uneAttenteTropLongueEstCoupee() async {
        let fin = AsyncStream.makeStream(of: Void.self)
        let debut = ContinuousClock.now
        await Attente.auPlus(.milliseconds(200)) {
            try? await Task.sleep(for: .seconds(3))
            fin.continuation.yield()
        }
        #expect(ContinuousClock.now - debut < .seconds(1))
        // L'opération n'est pas abandonnée : elle finit seule.
        for await _ in fin.stream { break }
        #expect(ContinuousClock.now - debut >= .seconds(3))
    }

    @Test func uneAttenteCourteNAttendPasLeDelai() async {
        let debut = ContinuousClock.now
        await Attente.auPlus(.seconds(5)) {}
        #expect(ContinuousClock.now - debut < .seconds(1))
    }

    @Test func uneSynchronisationInactiveRendLaMainToutDeSuite() async throws {
        let banc = try Banc()
        let suite = "tests-siri-sync-\(UUID().uuidString)"
        let stockage = try #require(UserDefaults(suiteName: suite))
        defer { stockage.removePersistentDomain(forName: suite) }
        let synchronisation = Synchronisation(contexte: banc.conteneur.mainContext, stockage: stockage, active: false)
        let debut = ContinuousClock.now
        await synchronisation.synchroniser(auPlus: .seconds(5))
        #expect(ContinuousClock.now - debut < .seconds(1))
    }
}
