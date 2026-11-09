import SwiftUI

/// Polices embarquées (voir `Info.plist` › `UIAppFonts`).
enum NomPolice {
    static let titreDemiGras = "BricolageGrotesque-SemiBold"
    static let titreGras = "BricolageGrotesque-Bold"
    static let titreExtraGras = "BricolageGrotesque-ExtraBold"
    static let texte = "DMSans-Regular"
    static let texteMoyen = "DMSans-Medium"
    static let texteDemiGras = "DMSans-SemiBold"
    static let texteGras = "DMSans-Bold"
}

/// Styles de texte de Jublo : Bricolage Grotesque pour les titres, DM Sans pour le texte.
/// Chaque style suit la taille de texte choisie dans iOS (`relativeTo:`).
extension Font {
    static var jubloGrandTitre: Font { .custom(NomPolice.titreExtraGras, size: 32, relativeTo: .largeTitle) }
    static var jubloTitre: Font { .custom(NomPolice.titreGras, size: 22, relativeTo: .title2) }
    static var jubloSousTitre: Font { .custom(NomPolice.titreDemiGras, size: 17, relativeTo: .headline) }
    static var jubloChiffre: Font { .custom(NomPolice.titreExtraGras, size: 36, relativeTo: .largeTitle) }
    static var jubloCorps: Font { .custom(NomPolice.texte, size: 16, relativeTo: .body) }
    static var jubloCorpsFort: Font { .custom(NomPolice.texteDemiGras, size: 16, relativeTo: .body) }
    static var jubloBouton: Font { .custom(NomPolice.texteGras, size: 16, relativeTo: .body) }
    static var jubloLegende: Font { .custom(NomPolice.texteMoyen, size: 13, relativeTo: .footnote) }
}
