import SwiftData
import SwiftUI

@main
struct JubloApp: App {
    private let conteneur: ModelContainer
    @State private var depot: Depot
    @State private var identite = Identite()
    @State private var configurationAssistant: ConfigurationAssistant

    init() {
        Apparence.appliquer()
        let conteneur: ModelContainer
        #if DEBUG
        // `-baseEnMemoire` : base vierge à chaque lancement (tests d'interface).
        let enMemoire = CommandLine.arguments.contains("-baseEnMemoire")
        #else
        let enMemoire = false
        #endif
        do {
            conteneur = try Persistance.conteneur(enMemoire: enMemoire)
        } catch {
            fatalError("Impossible d'ouvrir la base locale : \(error)")
        }
        #if DEBUG
        // `-exemples` au lancement remplit une base vide (captures, essais).
        if CommandLine.arguments.contains("-exemples"),
           (try? conteneur.mainContext.fetchCount(FetchDescriptor<ElementListe>())) == 0 {
            DonneesDebug.remplir(conteneur.mainContext)
        }
        #endif
        let depot = Depot(contexte: conteneur.mainContext)
        // Purge automatique de la corbeille au lancement (plus de 30 jours).
        depot.purger()
        self.conteneur = conteneur
        _depot = State(initialValue: depot)
        #if DEBUG
        // `-assistantSimule` : l'assistant répond sans fournisseur (captures, tests d'interface).
        let simulee = CommandLine.arguments.contains("-assistantSimule")
        #else
        let simulee = false
        #endif
        _configurationAssistant = State(initialValue: ConfigurationAssistant(simulee: simulee))
    }

    var body: some Scene {
        WindowGroup {
            RacineView()
                .environment(depot)
                .environment(identite)
                .environment(configurationAssistant)
        }
        .modelContainer(conteneur)
    }
}
