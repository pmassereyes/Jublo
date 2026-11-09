import Foundation

extension Locale {
    /// L'app est en français : dates et montants sont formatés en français,
    /// quelle que soit la langue de l'appareil.
    static let jublo = Locale(identifier: "fr_FR")
}

enum Formats {
    /// « 420 € », « 12,50 € ».
    static func montant(_ centimes: Int) -> String {
        let decimales = centimes % 100 == 0 ? 0 : 2
        return (Decimal(centimes) / 100).formatted(
            .currency(code: "EUR").precision(.fractionLength(decimales)).locale(.jublo)
        )
    }

    /// « Lundi 9 novembre » : seule la première lettre prend une majuscule.
    static func jour(_ date: Date) -> String {
        let texte = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.jublo))
        return texte.prefix(1).uppercased() + texte.dropFirst()
    }

    /// « il y a 3 jours », « hier », « dans 2 semaines »…
    static func relatif(_ date: Date, maintenant: Date = .now) -> String {
        let formateur = RelativeDateTimeFormatter()
        formateur.locale = .jublo
        formateur.unitsStyle = .full
        formateur.dateTimeStyle = .named
        return formateur.localizedString(for: date, relativeTo: maintenant)
    }
}
