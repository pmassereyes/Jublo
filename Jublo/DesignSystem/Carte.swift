import SwiftUI

/// Surface arrondie à 20 pt qui regroupe un contenu.
/// `contour` sert à distinguer les éléments communs (`.commun`).
struct Carte<Contenu: View>: View {
    var contour: Color?
    @ViewBuilder var contenu: Contenu

    init(contour: Color? = nil, @ViewBuilder contenu: () -> Contenu) {
        self.contour = contour
        self.contenu = contenu()
    }

    var body: some View {
        contenu
            .padding(Mesures.marge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.surface, in: .rect(cornerRadius: Mesures.rayonCarte, style: .continuous))
            .overlay {
                if let contour {
                    RoundedRectangle(cornerRadius: Mesures.rayonCarte, style: .continuous)
                        .strokeBorder(contour, lineWidth: 1.5)
                }
            }
    }
}

/// Titre de section au-dessus d'une carte ou d'une liste.
struct TitreSection: View {
    let titre: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titre)
                .font(.jubloSousTitre)
                .foregroundStyle(.texte)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
            }
        }
    }
}
