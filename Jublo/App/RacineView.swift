import SwiftUI

/// Les cinq onglets. L'assistant et la corbeille sont des écrans poussés.
struct RacineView: View {
    enum Onglet: String {
        case accueil, listes, agenda, projets, nous
    }

    @Environment(Identite.self) private var identite
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation

        TabView(selection: $navigation.onglet) {
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
        .fullScreenCover(isPresented: .constant(!identite.estChoisi)) {
            ChoixMembreView()
                .environment(identite)
        }
    }
}

extension RacineView.Onglet {
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
