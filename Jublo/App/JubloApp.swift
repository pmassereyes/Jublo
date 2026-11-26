import AppIntents
import SwiftData
import SwiftUI
import UIKit

@main
struct JubloApp: App {
    @UIApplicationDelegateAdaptor(DelegueApplication.self) private var delegueApplication
    @Environment(\.scenePhase) private var phase

    private let conteneur: ModelContainer
    @State private var depot: Depot
    @State private var identite: Identite
    @State private var configurationAssistant: ConfigurationAssistant
    @State private var synchronisation: Synchronisation
    @State private var notificateur: Notificateur
    @State private var navigation = Navigation(courante: true)

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
        // Pas d'iCloud pendant les tests (base en mémoire, ou app hôte des tests unitaires).
        let sansSynchronisation = enMemoire || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        // Base en mémoire : l'état de synchronisation de l'iPhone n'est pas touché non plus (un build
        // debug lancé ainsi pour préparer le schéma CloudKit ne change rien à la vraie base).
        let stockageSync = enMemoire ? (UserDefaults(suiteName: "jublo-base-en-memoire") ?? .standard) : .standard
        let synchronisation = Synchronisation(
            contexte: conteneur.mainContext, stockage: stockageSync, active: !sansSynchronisation
        )
        depot.observateur = synchronisation
        // Purge automatique de la corbeille au lancement (plus de 30 jours), une fois la
        // synchronisation branchée : les suppressions définitives partent aussi vers iCloud.
        depot.purger()
        let identite = Identite()
        // Rappels et réglages des notifications. Aucune notification pendant les tests.
        let notificateur = Notificateur(
            contexte: conteneur.mainContext,
            identite: identite,
            centre: sansSynchronisation ? CentreInerte() : CentreSysteme(),
            courant: !sansSynchronisation
        )
        notificateur.ecouterLaBase()
        // Les signaux envoyés à l'autre (« Pablo a mis à jour les courses ») sont signés par ce membre.
        synchronisation.membreCourant = { [weak identite] in
            identite?.estChoisi == true ? identite?.membre : nil
        }
        // Raccourcis Siri : l'intention travaille sur la même base, le même membre et la même
        // synchronisation que l'app (voir `AjouterRendezVous`).
        AppDependencyManager.shared.add(dependency: depot)
        AppDependencyManager.shared.add(dependency: identite)
        AppDependencyManager.shared.add(dependency: synchronisation)
        self.conteneur = conteneur
        _depot = State(initialValue: depot)
        _identite = State(initialValue: identite)
        _synchronisation = State(initialValue: synchronisation)
        _notificateur = State(initialValue: notificateur)
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
                .environment(notificateur)
                .environment(navigation)
                .task { await synchronisation.demarrer() }
                // Une fois le membre choisi : demande d'autorisation (la première fois), puis rappels.
                .task(id: identite.estChoisi) {
                    guard identite.estChoisi else { return }
                    await notificateur.demanderAutorisationSiBesoin()
                    await notificateur.replanifier()
                }
                .onChange(of: identite.membre) { notificateur.planifierBientot() }
                // Abonnements aux notifications iCloud de l'autre, selon Nous › Cet iPhone.
                .task(id: notificateur.abonnementsVoulus) {
                    guard let voulus = notificateur.abonnementsVoulus else { return }
                    await synchronisation.abonner(voulus)
                }
                .onChange(of: phase) {
                    if phase == .background {
                        Task { await notificateur.replanifier() }
                    }
                    if phase == .active {
                        Task { await synchronisation.synchroniserMaintenant() }
                        Task {
                            await notificateur.actualiserStatut()
                            notificateur.planifierBientot()
                        }
                    }
                }
        }
        .modelContainer(conteneur)
    }
}
