import SwiftUI

/// Les cinq onglets. L'assistant et la corbeille sont des écrans poussés.
struct RacineView: View {
    enum Onglet: String {
        case accueil, listes, agenda, projets, nous
    }

    @State private var onglet = Onglet.initial

    var body: some View {
        TabView(selection: $onglet) {
            NavigationStack { AccueilView() }
                .tabItem { Label("Accueil", systemImage: "house") }
                .tag(Onglet.accueil)
            NavigationStack { ListesView() }
                .tabItem { Label("Listes", systemImage: "checklist") }
                .tag(Onglet.listes)
            NavigationStack { AgendaView() }
                .tabItem { Label("Agenda", systemImage: "calendar") }
                .tag(Onglet.agenda)
            NavigationStack { ProjetsView() }
                .tabItem { Label("Projets", systemImage: "sparkles") }
                .tag(Onglet.projets)
            NavigationStack { NousView() }
                .tabItem { Label("Nous", systemImage: "heart") }
                .tag(Onglet.nous)
        }
        .tint(.texte)
    }
}

private extension RacineView.Onglet {
    /// En debug, l'argument de lancement `-onglet listes` ouvre directement un onglet.
    static var initial: Self {
        #if DEBUG
        UserDefaults.standard.string(forKey: "onglet").flatMap(Self.init(rawValue:)) ?? .accueil
        #else
        .accueil
        #endif
    }
}

#if DEBUG
#Preview {
    RacineView().apercuJublo()
}
#endif
