import Foundation
import Testing
@testable import Jublo

@MainActor
struct CagnotteTests {
    let banc: Banc

    init() throws {
        banc = try Banc()
    }

    @Test func uneCagnotteNeuveEstVide() {
        let cagnotte = banc.depot.creerCagnotte("Lisbonne", objectifCentimes: 80_000, par: .pablo)

        #expect(cagnotte.soldeCentimes == 0)
        #expect(cagnotte.historique.isEmpty)
    }

    @Test func leSoldeEstLaSommeDesVersements() {
        let cagnotte = banc.depot.creerCagnotte("Lisbonne", par: .pablo)

        banc.depot.verser(10_000, dans: cagnotte, par: .pablo)
        banc.depot.verser(2_550, dans: cagnotte, par: .julie)
        banc.depot.verser(500, dans: cagnotte, par: .julie)

        #expect(cagnotte.soldeCentimes == 13_050)
    }

    @Test func unVersementAnnuleSortDuSoldeMaisResteDansLHistorique() {
        let cagnotte = banc.depot.creerCagnotte("Lisbonne", par: .pablo)
        banc.depot.verser(10_000, dans: cagnotte, par: .pablo)
        banc.avancer(heures: 1)
        let erreur = banc.depot.verser(2_550, dans: cagnotte, par: .julie)
        banc.avancer(heures: 1)

        banc.depot.annuler(erreur, par: .julie)

        #expect(cagnotte.soldeCentimes == 10_000)
        #expect(cagnotte.historique.count == 2)
        #expect(cagnotte.historique.first?.estAnnule == true)
        #expect(erreur.annuleLe == banc.maintenant)
        #expect(erreur.annulePar == Membre.julie.rawValue)
    }

    @Test func annulerDeuxFoisGardeLaPremiereAnnulation() {
        let cagnotte = banc.depot.creerCagnotte("Lisbonne", par: .pablo)
        let versement = banc.depot.verser(1_000, dans: cagnotte, par: .pablo)
        banc.depot.annuler(versement, par: .pablo)
        let premiere = banc.maintenant

        banc.avancer(jours: 1)
        banc.depot.annuler(versement, par: .julie)

        #expect(versement.annuleLe == premiere)
        #expect(versement.annulePar == Membre.pablo.rawValue)
        #expect(cagnotte.soldeCentimes == 0)
    }

    @Test func leSoldeIgnoreLaCorbeille() {
        let cagnotte = banc.depot.creerCagnotte("Lisbonne", par: .pablo)
        banc.depot.verser(4_000, dans: cagnotte, par: .pablo)

        banc.depot.supprimer(cagnotte, par: .julie)
        banc.depot.restaurer(cagnotte)

        #expect(cagnotte.soldeCentimes == 4_000)
    }
}
