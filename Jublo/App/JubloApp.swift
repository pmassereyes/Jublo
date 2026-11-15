import SwiftData
import SwiftUI

@main
struct JubloApp: App {
    @UIApplicationDelegateAdaptor(DelegueApplication.self) private var delegueApplication
    @Environment(\.scenePhase) private var phase

    private let conteneur: ModelContainer
    @State private var depot: Depot
    @State private var identite = Identite()
    @State private var configurationAssistant: ConfigurationAssistant
    @State private var synchronisation: Synchronisation

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
        // Pas d'iCloud pendant les tests (base en mémoire, ou app hôte des tests unitaires).
        let sansSynchronisation = enMemoire || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let synchronisation = Synchronisation(contexte: conteneur.mainContext, active: !sansSynchronisation)
        depot.observateur = synchronisation
        self.conteneur = conteneur
        _depot = State(initialValue: depot)
        _synchronisation = State(initialValue: synchronisation)
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
                .environment(synchronisation)
                .task { await synchronisation.demarrer() }
                .onChange(of: phase) {
                    if phase == .active {
                        Task { await synchronisation.synchroniserMaintenant() }
                    }
                }
        }
        .modelContainer(conteneur)
    }
}
