import Testing
@testable import Jublo

/// Coordination des démarrages de la synchronisation, sans iCloud : un démarrage simulé,
/// retenu par une porte, tient lieu de lancement du moteur.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct DemarreurTests {
    @Test func rienNeSeLanceQuandLeMoteurTourneDeja() async {
        let demarreur = Demarreur()
        let moteur = MoteurSimule()
        moteur.tourne = true

        await demarreur.demarrer(saufSi: { moteur.tourne }) { await moteur.lancer() }

        #expect(moteur.lancements == 0)
    }

    @Test func deuxDemandesPendantUnDemarrageNeLancentQuUnMoteur() async {
        let demarreur = Demarreur()
        let moteur = MoteurSimule()
        moteur.porte = Porte()

        let premier = Task { await demarreur.demarrer(saufSi: { moteur.tourne }) { await moteur.lancer() } }
        await attendre { moteur.lancements == 1 }
        let second = Task { await demarreur.demarrer(saufSi: { moteur.tourne }) { await moteur.lancer() } }
        await laisserTourner()
        moteur.porte?.ouvrir()
        await premier.value
        await second.value

        #expect(moteur.lancements == 1)
        #expect(moteur.tourne)
    }

    /// Le cas de l'invitation : la réinitialisation abandonne le démarrage en cours, puis
    /// redemande un démarrage. Celui-ci doit relancer un moteur au lieu de rendre la main.
    @Test func unDemarrageAbandonneEstRelanceParCeluiQuiAttendait() async {
        let demarreur = Demarreur()
        let moteur = MoteurSimule()
        moteur.porte = Porte()
        moteur.abandonsRestants = 1

        let auLancement = Task { await demarreur.demarrer(saufSi: { moteur.tourne }) { await moteur.lancer() } }
        await attendre { moteur.lancements == 1 }
        let apresInvitation = Task { await demarreur.demarrer(saufSi: { moteur.tourne }) { await moteur.lancer() } }
        await laisserTourner()
        moteur.porte?.ouvrir()
        await auLancement.value
        await apresInvitation.value

        #expect(moteur.lancements == 2)
        #expect(moteur.tourne)
    }

    @Test func unDemarrageSansICloudNeBouclePas() async {
        let demarreur = Demarreur()
        let moteur = MoteurSimule()
        moteur.abandonsRestants = .max

        await demarreur.demarrer(saufSi: { moteur.tourne }) { await moteur.lancer() }
        await demarreur.demarrer(saufSi: { moteur.tourne }) { await moteur.lancer() }

        #expect(moteur.lancements == 2)
        #expect(!moteur.tourne)
    }

    private func attendre(_ condition: () -> Bool) async {
        while !condition() {
            await Task.yield()
        }
    }

    private func laisserTourner() async {
        for _ in 0..<20 {
            await Task.yield()
        }
    }
}

/// Lancement simulé : attend la porte s'il y en a une, puis démarre, sauf s'il doit être
/// abandonné (réinitialisation, iCloud indisponible).
@MainActor
private final class MoteurSimule {
    var tourne = false
    var lancements = 0
    var abandonsRestants = 0
    var porte: Porte?

    func lancer() async {
        lancements += 1
        await porte?.attendre()
        porte = nil
        if abandonsRestants > 0 {
            abandonsRestants -= 1
        } else {
            tourne = true
        }
    }
}

@MainActor
private final class Porte {
    private var ouverte = false
    private var enAttente: [CheckedContinuation<Void, Never>] = []

    func attendre() async {
        guard !ouverte else { return }
        await withCheckedContinuation { enAttente.append($0) }
    }

    func ouvrir() {
        ouverte = true
        enAttente.forEach { $0.resume() }
        enAttente = []
    }
}
