#if DEBUG
import SwiftUI

/// Vue de contrôle du design system : couleurs, polices et composants.
struct CatalogueDesignSystem: View {
    @State private var choix = Exemple.courses
    @State private var supprime: String? = "Lait"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Design system").font(.jubloGrandTitre)

                TitreSection(titre: "Couleurs")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                    pastille("Fond", .fond)
                    pastille("Surface", .surface)
                    pastille("Texte", .texte)
                    pastille("Secondaire", .texteSecondaire)
                    pastille("Séparateur", .separateur)
                    pastille("Commun", .commun)
                    pastille("Pablo", .pablo)
                    pastille("Pablo doux", .pabloDoux)
                    pastille("Julie", .julie)
                    pastille("Julie doux", .julieDoux)
                }

                TitreSection(titre: "Typographie")
                Carte {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Grand titre").font(.jubloGrandTitre)
                        Text("Titre").font(.jubloTitre)
                        Text("Sous-titre").font(.jubloSousTitre)
                        Text("Corps de texte en DM Sans.").font(.jubloCorps)
                        Text("Corps fort").font(.jubloCorpsFort)
                        Text("Légende").font(.jubloLegende).foregroundStyle(.texteSecondaire)
                    }
                    .foregroundStyle(.texte)
                }

                TitreSection(titre: "Composants")
                SelecteurPilules(options: Exemple.allCases, selection: $choix, titre: \.rawValue)
                Carte(contour: .commun) {
                    Text("Carte d'un élément commun").font(.jubloCorps)
                }
                HStack {
                    Button("Ajouter") {}.buttonStyle(.pilule)
                    Button("Pablo") {}.buttonStyle(.pilule(.douce(fond: .pabloDoux, texte: .pablo)))
                    Button("Julie") {}.buttonStyle(.pilule(.douce(fond: .julieDoux, texte: .julie)))
                }
                Button("Nous deux") {}.buttonStyle(.pilule(.contour))
            }
            .padding(Mesures.marge)
        }
        .background(.fond)
        .bandeauAnnuler($supprime, duree: .seconds(60)) { "« \($0) » mis à la corbeille" } annuler: { _ in }
    }

    private func pastille(_ nom: String, _ couleur: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(couleur)
                .frame(height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separateur)
                }
            Text(nom).font(.jubloLegende).foregroundStyle(.texteSecondaire)
        }
    }

    private enum Exemple: String, CaseIterable, Identifiable {
        case penseBete = "Pense-bête"
        case courses = "Courses"
        case wishList = "Wish list"
        var id: Self { self }
    }
}

#Preview {
    CatalogueDesignSystem()
}
#endif
