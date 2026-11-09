import SwiftData
import SwiftUI

@main
struct JubloApp: App {
    private let conteneur: ModelContainer
    @State private var depot: Depot
    @State private var identite = Identite()

    init() {
        Apparence.appliquer()
        let conteneur: ModelContainer
        do {
            conteneur = try Persistance.conteneur()
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
    }

    var body: some Scene {
        WindowGroup {
            RacineView()
                .environment(depot)
                .environment(identite)
        }
        .modelContainer(conteneur)
    }
}
