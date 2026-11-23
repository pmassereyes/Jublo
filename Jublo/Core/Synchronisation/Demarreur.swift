import Foundation

/// Lance au plus un démarrage à la fois.
///
/// Un appel qui arrive pendant un démarrage en attend la fin, puis relance si rien ne tourne :
/// le démarrage en cours a pu être abandonné par une réinitialisation (invitation acceptée,
/// changement de compte iCloud). Le démarrage lui-même ne doit jamais rappeler `demarrer` :
/// il attendrait sa propre fin.
@MainActor
final class Demarreur {
    private var enCours: Task<Void, Never>?

    /// - Parameters:
    ///   - dejaDemarre: vrai quand il n'y a rien à lancer.
    ///   - lancer: le démarrage. Il peut échouer ou être abandonné sans rien démarrer.
    func demarrer(saufSi dejaDemarre: () -> Bool, _ lancer: @escaping @Sendable @MainActor () async -> Void) async {
        while let tache = enCours {
            await tache.value
        }
        guard !dejaDemarre() else { return }
        let tache = Task { @MainActor in
            await lancer()
            // Effacé par la tâche elle-même, avant sa fin : ceux qui l'attendent voient tout de
            // suite qu'elle est terminée.
            self.enCours = nil
        }
        enCours = tache
        await tache.value
    }
}
