import Foundation
import Testing
@testable import Jublo

@MainActor
struct ListesTests {
    let banc: Banc

    init() throws {
        banc = try Banc()
    }

    @Test func unTitreVideEstRefuse() throws {
        #expect(banc.depot.ajouter("   ", a: .courses, par: .pablo) == nil)
        #expect(try banc.tous(ElementListe.self).isEmpty)
    }

    @Test func leTitreEstNettoyeEtLAuteurRetenu() throws {
        let element = try banc.ajouter("  Lait d'avoine \n", a: .courses, par: .julie)

        #expect(element.titre == "Lait d'avoine")
        #expect(element.auteur == .julie)
        #expect(element.creeLe == banc.maintenant)
    }

    @Test func chaqueListeNeMontreQueSesElements() throws {
        _ = try banc.ajouter("Lait", a: .courses)
        _ = try banc.ajouter("Plombier", a: .penseBete)

        #expect(try banc.actifs(.courses).map(\.titre) == ["Lait"])
        #expect(try banc.actifs(.wishList).isEmpty)
    }

    @Test func cocherRetientQuiEtQuandDecocherEfface() throws {
        let lait = try banc.ajouter("Lait", par: .pablo)
        banc.avancer(heures: 2)

        banc.depot.basculer(lait, par: .julie)
        #expect(lait.estCoche)
        #expect(lait.cochePar == Membre.julie.rawValue)
        #expect(lait.cocheLe == banc.maintenant)

        banc.depot.basculer(lait, par: .pablo)
        #expect(!lait.estCoche)
        #expect(lait.cochePar == nil)
        #expect(lait.cocheLe == nil)
    }
}

struct LibellesTests {
    @Test(arguments: Membre.allCases)
    func leMembreCourantEstToi(membre: Membre) {
        #expect(Libelles.qui(membre, vuPar: membre) == "toi")
        #expect(Libelles.quiEnDebut(membre, vuPar: membre) == "Toi")
    }

    @Test(arguments: Membre.allCases)
    func lAutreEstDesigneParSonPrenom(courant: Membre) {
        let autre = courant.autre
        #expect(Libelles.qui(autre, vuPar: courant) == autre.prenom)
        #expect(Libelles.qui(autre.rawValue, vuPar: courant) == autre.prenom)
    }

    @Test func unIdentifiantInconnuResteNeutre() {
        #expect(Libelles.qui("inconnu", vuPar: .pablo) == "quelqu'un")
        #expect(Libelles.qui(nil as String?, vuPar: .julie) == "quelqu'un")
    }

    @Test func laWishListSeLitSelonQuiRegarde() {
        #expect(Libelles.pour(.pablo, vuPar: .pablo) == "Pour moi")
        #expect(Libelles.pour(.julie, vuPar: .pablo) == "Pour Julie")
        #expect(Libelles.pour(.pablo, vuPar: .julie) == "Pour Pablo")
        #expect(Libelles.ajoutEnvie(pour: .julie, vuPar: .julie) == "Ajouter à mes envies")
        #expect(Libelles.ajoutEnvie(pour: .julie, vuPar: .pablo) == "Ajouter une idée pour Julie")
    }

    @Test func unSouhaitSeLitSelonQuiRegarde() {
        #expect(Libelles.souhait(de: .julie, vuPar: .pablo) == "Julie aimerait que tu…")
        #expect(Libelles.souhait(de: .julie, vuPar: .julie) == "Ta demande à Pablo")
        #expect(Libelles.texteSouhait("cuisines.", de: .julie, vuPar: .pablo) == "…cuisines.")
        #expect(Libelles.texteSouhait("cuisines.", de: .julie, vuPar: .julie) == "J'aimerais que tu cuisines.")
    }
}

@MainActor
struct IdentiteTests {
    @Test func leMembreChoisiEstMemorise() throws {
        let suite = "jublo-tests-\(UUID().uuidString)"
        let stockage = try #require(UserDefaults(suiteName: suite))
        defer { stockage.removePersistentDomain(forName: suite) }

        let neuve = Identite(stockage: stockage)
        #expect(neuve.membre == .pablo)
        #expect(!neuve.estChoisi)

        neuve.membre = .julie

        let relue = Identite(stockage: stockage)
        #expect(relue.membre == .julie)
        #expect(relue.estChoisi)
    }
}

struct FormatsTests {
    @Test(arguments: [
        ("12", 1_200), ("12,5", 1_250), ("12.50", 1_250), ("0,99", 99), ("1 250,00 €", 125_000), (",5", 50),
    ])
    func unMontantSaisiDevientDesCentimes(saisie: String, centimes: Int) {
        #expect(Formats.centimes(depuis: saisie) == centimes)
    }

    @Test(arguments: ["", "0", "0,00", "abc", "12,345", "1.2.3", "-5", "12a"])
    func unMontantInvalideEstRefuse(saisie: String) {
        #expect(Formats.centimes(depuis: saisie) == nil)
    }

    @Test func unMontantRevientDansLeChampDeSaisie() {
        #expect(Formats.saisieMontant(1_250) == "12,50")
        #expect(Formats.saisieMontant(1_200) == "12")
        #expect(Formats.saisieMontant(nil) == "")
    }

    @Test func leMoisSAfficheAvecUneMajuscule() {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris")!
        #expect(Formats.mois("2026-11", calendrier: calendrier) == "Novembre 2026")
        #expect(Formats.mois("n'importe quoi", calendrier: calendrier) == "n'importe quoi")
    }

    @Test func lesJoursProchesOntLeurNom() {
        let maintenant = Date(timeIntervalSinceReferenceDate: 800_000_000)
        #expect(Formats.jourProche(maintenant, maintenant: maintenant) == "Aujourd'hui")
        #expect(Formats.jourProche(maintenant.addingTimeInterval(86_400), maintenant: maintenant) == "Demain")
        #expect(Formats.jourProche(maintenant.addingTimeInterval(3 * 86_400), maintenant: maintenant) == Formats.jour(maintenant.addingTimeInterval(3 * 86_400)))
    }

    @Test func unRendezVousSAdresseAToiALAutreOuAuxDeux() {
        #expect(Libelles.concerne(nil, vuPar: .pablo) == "Vous deux")
        #expect(Libelles.concerne(.pablo, vuPar: .pablo) == "Toi")
        #expect(Libelles.concerne(.julie, vuPar: .pablo) == "Julie")
    }
}
