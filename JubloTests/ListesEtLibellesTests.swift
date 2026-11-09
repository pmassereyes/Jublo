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

        #expect(Identite(stockage: stockage).membre == .pablo)
        Identite(stockage: stockage).membre = .julie
        #expect(Identite(stockage: stockage).membre == .julie)
    }
}
