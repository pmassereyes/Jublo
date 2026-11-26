import SwiftUI
import UIKit

/// Notifications de cet iPhone : autorisation, et annonces des changements de l'autre.
/// Les rappels, eux, se règlent élément par élément.
struct CarteNotifications: View {
    @Environment(Notificateur.self) private var notificateur
    @Environment(Identite.self) private var identite
    @Environment(\.openURL) private var ouvrir

    var body: some View {
        @Bindable var notificateur = notificateur

        Carte {
            VStack(alignment: .leading, spacing: Mesures.espacement) {
                Label("Notifications", systemImage: "bell")
                    .font(.jubloCorpsFort)
                    .foregroundStyle(.texte)
                switch notificateur.statut {
                case .autorisees:
                    Toggle(Libelles.quandLAutreModifie("les listes", vuPar: identite.membre), isOn: $notificateur.annoncerListes)
                    Toggle(Libelles.quandLAutreModifie("l'agenda", vuPar: identite.membre), isOn: $notificateur.annoncerAgenda)
                    Text("Elles arrivent quand Jublo tourne en arrière-plan, parfois avec un peu de retard. Les rappels du pense-bête et de l'agenda sonnent toujours.")
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                case .aDemander:
                    Text("Pour les rappels, et pour savoir quand \(identite.membre.autre.prenom) modifie une liste ou l'agenda.")
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                    Button("Activer les notifications") {
                        Task { await notificateur.demanderAutorisationSiBesoin() }
                    }
                    .buttonStyle(.pilule(.contour, compacte: true))
                case .refusees:
                    Text("Les notifications sont coupées pour Jublo : ni rappels, ni nouvelles de \(identite.membre.autre.prenom).")
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                    Button("Ouvrir les Réglages") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            ouvrir(url)
                        }
                    }
                    .buttonStyle(.pilule(.contour, compacte: true))
                }
            }
            .font(.jubloCorps)
            .tint(.commun)
        }
        .task { await notificateur.actualiserStatut() }
    }
}
