import SwiftUI

extension View {
    /// Ligne de `List` présentée comme une carte arrondie sur le fond de Jublo.
    func ligneCarte() -> some View {
        listRowBackground(
            RoundedRectangle(cornerRadius: Mesures.rayonCarte, style: .continuous)
                .fill(Color.surface)
                .padding(.horizontal, Mesures.marge)
                .padding(.vertical, 4)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 10, leading: Mesures.marge + 4, bottom: 10, trailing: Mesures.marge + 12))
    }

    /// Ligne de `List` sans fond (état vide, bouton, explication).
    func ligneNue() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: Mesures.marge, bottom: 8, trailing: Mesures.marge))
    }

    /// `List` sur le fond de Jublo, sans séparateurs système.
    func listeJublo() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.fond)
    }
}

/// En-tête de section d'une `List` aux couleurs de Jublo.
struct EnTeteListe: View {
    let titre: String
    var detail: String?

    var body: some View {
        TitreSection(titre: titre, detail: detail)
            .padding(.horizontal, Mesures.marge)
            .padding(.top, 8)
            .listRowInsets(EdgeInsets())
    }
}
