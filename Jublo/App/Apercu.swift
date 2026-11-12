#if DEBUG
import SwiftData
import SwiftUI

extension View {
    /// Prépare un aperçu Xcode : base en mémoire remplie d'exemples, dépôt, identité,
    /// et assistant simulé.
    func apercuJublo(membre: Membre = .pablo) -> some View {
        let conteneur = try! Persistance.conteneur(enMemoire: true)
        DonneesDebug.remplir(conteneur.mainContext)
        let identite = Identite(stockage: UserDefaults(suiteName: "apercu")!)
        identite.membre = membre
        return self
            .modelContainer(conteneur)
            .environment(Depot(contexte: conteneur.mainContext))
            .environment(identite)
            .environment(ConfigurationAssistant(
                stockage: UserDefaults(suiteName: "apercu")!, serviceTrousseau: "apercu", simulee: true
            ))
    }
}
#endif
