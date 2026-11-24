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
