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

    /// « 14:30 ».
    static func heure(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(.jublo))
    }

    /// « Aujourd'hui », « Demain », sinon « Samedi 5 décembre ».
    static func jourProche(_ date: Date, maintenant: Date = .now, calendrier: Calendar = .current) -> String {
        if calendrier.isDate(date, inSameDayAs: maintenant) { return "Aujourd'hui" }
        if let demain = calendrier.date(byAdding: .day, value: 1, to: maintenant),
           calendrier.isDate(date, inSameDayAs: demain) {
            return "Demain"
        }
        return jour(date)
    }

    /// « Novembre 2026 » à partir d'une clé de mois (« 2026-11 »).
    static func mois(_ cle: String, calendrier: Calendar = .current) -> String {
        guard let debut = Souhait.debutDuMois(cle, calendrier: calendrier) else { return cle }
        return mois(debut)
    }

    /// « Novembre 2026 ».
    static func mois(_ date: Date) -> String {
        let texte = date.formatted(.dateTime.month(.wide).year().locale(.jublo))
        return texte.prefix(1).uppercased() + texte.dropFirst()
    }

    /// Montant saisi (« 12 », « 12,5 », « 1 250,00 € ») en centimes, ou nil s'il est invalide
    /// ou nul. Deux décimales au plus.
    static func centimes(depuis saisie: String) -> Int? {
        let nettoye = saisie
            .replacingOccurrences(of: "€", with: "")
            .filter { !$0.isWhitespace }
            .replacingOccurrences(of: ",", with: ".")
        let parties = nettoye.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let chiffres = Set("0123456789")
        guard (1...2).contains(parties.count), parties.allSatisfy({ $0.allSatisfy(chiffres.contains) }) else { return nil }
        let entier = parties[0]
        let decimales = parties.count == 2 ? parties[1] : ""
        guard !(entier.isEmpty && decimales.isEmpty), decimales.count <= 2, entier.count <= 7 else { return nil }
        let euros = Int(entier) ?? 0
        let reste = Int(decimales.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        let total = euros * 100 + reste
        return total > 0 ? total : nil
    }

    /// Montant pour un champ de saisie : « 12,5 » devient « 12,50 », « 12 » reste « 12 ».
    static func saisieMontant(_ centimes: Int?) -> String {
        guard let centimes else { return "" }
        let euros = centimes / 100, reste = centimes % 100
        return reste == 0 ? "\(euros)" : String(format: "%d,%02d", euros, reste)
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
