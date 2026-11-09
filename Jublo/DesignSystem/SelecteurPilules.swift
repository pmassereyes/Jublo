import SwiftUI

/// Sélecteur segmenté en pilules (par exemple Pense-bête / Courses / Wish list).
struct SelecteurPilules<Valeur: Hashable & Identifiable>: View {
    let options: [Valeur]
    @Binding var selection: Valeur
    let titre: (Valeur) -> String

    @Namespace private var espace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let choisie = option == selection
                Button {
                    withAnimation(.snappy) { selection = option }
                } label: {
                    Text(titre(option))
                        .font(.jubloCorpsFort)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: Mesures.zoneTactile)
                        .foregroundStyle(choisie ? Color.surface : Color.texte)
                        .background {
                            if choisie {
                                Capsule()
                                    .fill(Color.texte)
                                    .matchedGeometryEffect(id: "selection", in: espace)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(choisie ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.surface, in: .capsule)
    }
}
