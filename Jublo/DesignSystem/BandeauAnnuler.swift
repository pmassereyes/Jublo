import SwiftUI

/// Bandeau affiché après une suppression, avec un bouton « Annuler ».
struct BandeauAnnuler: View {
    let message: String
    let annuler: () -> Void

    var body: some View {
        HStack(spacing: Mesures.espacement) {
            Image(systemName: "trash")
                .accessibilityHidden(true)
            Text(message)
                .font(.jubloCorps)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("Annuler", action: annuler)
                .buttonStyle(.pilule(.pleine(fond: .surface, texte: .texte), compacte: true))
        }
        .foregroundStyle(.surface)
        .padding(.leading, Mesures.marge)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(.texte, in: .rect(cornerRadius: Mesures.rayonCarte, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, Mesures.marge)
        .padding(.bottom, 8)
        .onAppear {
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

extension View {
    /// Affiche un `BandeauAnnuler` tant que `element` n'est pas nil, puis le masque après `duree`.
    func bandeauAnnuler<Element: Equatable>(
        _ element: Binding<Element?>,
        duree: Duration = .seconds(5),
        message: @escaping (Element) -> String,
        annuler: @escaping (Element) -> Void
    ) -> some View {
        modifier(ModificateurBandeauAnnuler(element: element, duree: duree, message: message, annuler: annuler))
    }
}

private struct ModificateurBandeauAnnuler<Element: Equatable>: ViewModifier {
    @Binding var element: Element?
    let duree: Duration
    let message: (Element) -> String
    let annuler: (Element) -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if let element {
                    BandeauAnnuler(message: message(element)) {
                        annuler(element)
                        self.element = nil
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: element)
            .task(id: element) {
                guard element != nil else { return }
                try? await Task.sleep(for: duree)
                guard !Task.isCancelled else { return }
                element = nil
            }
    }
}
