import SwiftUI

/// Page défilante sur le fond de Jublo, avec les marges standard.
struct Page<Contenu: View>: View {
    @ViewBuilder var contenu: Contenu

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                contenu
            }
            .padding(.horizontal, Mesures.marge)
            .padding(.bottom, 24)
        }
        .background(.fond)
    }
}

/// Rappelle qu'un écran affiche des données d'exemple (phase 1).
struct MentionExemple: View {
    var body: some View {
        Label("Données d'exemple : cet écran sera branché plus tard.", systemImage: "info.circle")
            .font(.jubloLegende)
            .foregroundStyle(.texteSecondaire)
            .frame(maxWidth: .infinity)
    }
}
