import Foundation
import Testing
@testable import Jublo

@MainActor
struct PurgeTests {
    let banc: Banc

    init() throws {
        banc = try Banc()
    }

    @Test func purgeLesElementsSupprimesDepuisPlusDeTrenteJours() throws {
        let ancien = try banc.ajouter("Ancien")
        banc.depot.supprimer(ancien, par: .pablo)
        banc.avancer(jours: 2)
        let recent = try banc.ajouter("Récent")
        banc.depot.supprimer(recent, par: .julie)

        banc.avancer(jours: 29)
        let purges = banc.depot.purger()

        #expect(purges == 1)
        #expect(try banc.tous(ElementListe.self).map(\.titre) == ["Récent"])
    }

    @Test func conserveUnElementSupprimeDepuisExactementTrenteJours() throws {
        let element = try banc.ajouter("Pile 30 jours")
        banc.depot.supprimer(element, par: .pablo)

        banc.avancer(jours: 30)

        #expect(banc.depot.purger() == 0)
        #expect(try banc.tous(ElementListe.self).count == 1)
    }

    @Test func neToucheJamaisAuxElementsActifs() throws {
        _ = try banc.ajouter("Vieux mais actif")
        banc.avancer(jours: 365)

        #expect(banc.depot.purger() == 0)
        #expect(try banc.actifs(.courses).count == 1)
    }

    @Test func purgeUneCagnotteSansVersement() throws {
        let cagnotte = banc.depot.creerCagnotte("Vide", par: .pablo)
        banc.depot.supprimer(cagnotte, par: .pablo)

        banc.avancer(jours: 31)

        #expect(banc.depot.purger() == 1)
        #expect(try banc.tous(Cagnotte.self).isEmpty)
    }

    @Test func nePurgeJamaisUneCagnotteQuiADesVersements() throws {
        let cagnotte = banc.depot.creerCagnotte("Lisbonne", par: .pablo)
        banc.depot.verser(5_000, dans: cagnotte, par: .julie)
        banc.depot.supprimer(cagnotte, par: .pablo)

        banc.avancer(jours: 400)

        #expect(banc.depot.purger() == 0)
        #expect(try banc.tous(Cagnotte.self).count == 1)
        #expect(banc.depot.elementsDansLaCorbeille().count == 1)
    }

    @Test func neRetireJamaisUnVersementMemeAnnuleDepuisLongtemps() throws {
        let cagnotte = banc.depot.creerCagnotte("Lisbonne", par: .pablo)
        let versement = banc.depot.verser(2_000, dans: cagnotte, par: .julie)
        banc.depot.annuler(versement, par: .julie)
        banc.depot.supprimer(cagnotte, par: .pablo)

        banc.avancer(jours: 400)
        banc.depot.purger()

        let versements = try banc.tous(Versement.self)
        #expect(versements.count == 1)
        #expect(versements.first?.estAnnule == true)
    }
}
