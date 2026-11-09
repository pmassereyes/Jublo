import UIKit

/// Applique les polices de Jublo aux barres UIKit (navigation, onglets),
/// que SwiftUI ne permet pas de styler directement.
@MainActor
enum Apparence {
    static func appliquer() {
        let texte = UIColor(resource: .texte)
        let barre = UINavigationBar.appearance()
        barre.largeTitleTextAttributes = [
            .font: police(NomPolice.titreExtraGras, taille: 32, style: .largeTitle),
            .foregroundColor: texte,
        ]
        barre.titleTextAttributes = [
            .font: police(NomPolice.titreGras, taille: 17, style: .headline),
            .foregroundColor: texte,
        ]

        let onglet = police(NomPolice.texteMoyen, taille: 10, style: .caption2)
        UITabBarItem.appearance().setTitleTextAttributes([.font: onglet], for: .normal)
    }

    private static func police(_ nom: String, taille: CGFloat, style: UIFont.TextStyle) -> UIFont {
        let base = UIFont(name: nom, size: taille) ?? .systemFont(ofSize: taille)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}
