import Foundation
import Testing
@testable import Jublo

@MainActor
struct SuppressionDouceTests {
    let banc: Banc

    init() throws {
        banc = try Banc()
    }

    @Test func supprimerMetALaCorbeilleSansEffacer() throws {
        let lait = try banc.ajouter("Lait", par: .pablo)
        banc.avancer(heures: 1)

        banc.depot.supprimer(lait, par: .julie)

        #expect(lait.supprimeLe == banc.maintenant)
        #expect(lait.supprimePar == Membre.julie.rawValue)
        #expect(lait.modifieLe == banc.maintenant)
        #expect(try banc.actifs(.courses).isEmpty)
        #expect(try banc.tous(ElementListe.self).count == 1)
        #expect(banc.depot.elementsDansLaCorbeille().map(\.titreAffiche) == ["Lait"])
    }

    @Test func supprimerDeuxFoisGardeLaPremiereSuppression() throws {
        let lait = try banc.ajouter("Lait")
        banc.depot.supprimer(lait, par: .julie)
        let premiere = banc.maintenant

        banc.avancer(jours: 3)
        banc.depot.supprimer(lait, par: .pablo)

        #expect(lait.supprimeLe == premiere)
        #expect(lait.supprimePar == Membre.julie.rawValue)
    }

    @Test func restaurerRemetLElementDansSaListe() throws {
        let lait = try banc.ajouter("Lait")
        banc.depot.supprimer(lait, par: .julie)
        banc.avancer(jours: 2)

        banc.depot.restaurer(lait)

        #expect(lait.supprimeLe == nil)
        #expect(lait.supprimePar == nil)
        #expect(lait.modifieLe == banc.maintenant)
        #expect(try banc.actifs(.courses).map(\.titre) == ["Lait"])
        #expect(banc.depot.elementsDansLaCorbeille().isEmpty)
    }

    @Test func restaurerUnElementActifNeChangeRien() throws {
        let lait = try banc.ajouter("Lait")
        let modifie = lait.modifieLe
        banc.avancer(heures: 1)

        banc.depot.restaurer(lait)

        #expect(lait.modifieLe == modifie)
    }

    @Test func laCorbeilleMelangeLesTypesDuPlusRecentAuPlusAncien() throws {
        let lait = try banc.ajouter("Lait")
        let cagnotte = banc.depot.creerCagnotte("Lisbonne", par: .julie)
        let rappel = try banc.ajouter("Plombier", a: .penseBete)

        banc.depot.supprimer(lait, par: .pablo)
        banc.avancer(heures: 1)
        banc.depot.supprimer(cagnotte, par: .julie)
        banc.avancer(heures: 1)
        banc.depot.supprimer(rappel, par: .julie)

        let corbeille = banc.depot.elementsDansLaCorbeille()
        #expect(corbeille.map(\.titreAffiche) == ["Plombier", "Lisbonne", "Lait"])
        #expect(corbeille.map(\.libelleType) == ["Pense-bête", "Cagnotte", "Courses"])
    }
}
