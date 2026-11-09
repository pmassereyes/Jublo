import SwiftUI

/// Écran poussé depuis l'Accueil. L'assistant arrivera en phase 3.
struct AssistantView: View {
    var body: some View {
        Page {
            Carte(contour: .commun) {
                VStack(alignment: .leading, spacing: Mesures.espacement) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundStyle(.texte)
                        .accessibilityHidden(true)
                    Text("Bientôt")
                        .font(.jubloTitre)
                    Text("Un assistant qui tournera chez nous, sur notre propre machine, pour retrouver une idée de sortie, résumer la semaine ou compléter les courses.")
                        .font(.jubloCorps)
                        .foregroundStyle(.texteSecondaire)
                }
            }
        }
        .navigationTitle("Assistant")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack { AssistantView() }
}
#endif
