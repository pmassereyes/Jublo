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

/// Fonctionnalité prévue mais pas encore construite : un état vide, sans données d'exemple.
struct BientotDisponible: View {
    let titre: String
    let symbole: String
    let description: String

    var body: some View {
        Carte {
            HStack(alignment: .top, spacing: Mesures.espacement) {
                Image(systemName: symbole)
                    .font(.system(size: 22))
                    .foregroundStyle(.texteSecondaire)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(titre)
                            .font(.jubloCorpsFort)
                            .foregroundStyle(.texte)
                        Text("Bientôt")
                            .font(.jubloLegende)
                            .foregroundStyle(.texteSecondaire)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.fond, in: .capsule)
                    }
                    Text(description)
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
