import SwiftUI

/// Bouton en forme de pilule, haut d'au moins 44 pt.
struct StylePilule: ButtonStyle {
    enum Variante {
        /// Fond plein.
        case pleine(fond: Color, texte: Color)
        /// Fond doux et texte coloré, par exemple aux couleurs d'un membre.
        case douce(fond: Color, texte: Color)
        /// Contour seul, pour les éléments communs.
        case contour
    }

    var variante: Variante
    var compacte = false

    @Environment(\.isEnabled) private var actif

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.jubloBouton)
            .lineLimit(1)
            .padding(.horizontal, compacte ? 14 : 20)
            .frame(minHeight: Mesures.zoneTactile)
            .foregroundStyle(couleurTexte)
            .background(couleurFond, in: .capsule)
            .overlay {
                if case .contour = variante {
                    Capsule().strokeBorder(Color.commun, lineWidth: 1.5)
                }
            }
            .contentShape(.capsule)
            .opacity(actif ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var couleurFond: Color {
        switch variante {
        case .pleine(let fond, _), .douce(let fond, _): fond
        case .contour: .clear
        }
    }

    private var couleurTexte: Color {
        switch variante {
        case .pleine(_, let texte), .douce(_, let texte): texte
        case .contour: .commun
        }
    }
}

extension ButtonStyle where Self == StylePilule {
    /// Pilule pleine aux couleurs du texte.
    static var pilule: StylePilule {
        StylePilule(variante: .pleine(fond: .texte, texte: .surface))
    }

    static func pilule(_ variante: StylePilule.Variante, compacte: Bool = false) -> StylePilule {
        StylePilule(variante: variante, compacte: compacte)
    }
}
