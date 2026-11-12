import Foundation

/// Consignes envoyées au modèle avec chaque question : qui parle, la date, et le contenu
/// des listes. L'assistant ne connaît que les listes pour l'instant : les autres onglets
/// affichent encore des données d'exemple.
enum ContexteAssistant {
    /// Nombre maximal d'éléments par section, pour garder des requêtes courtes.
    static let maxParSection = 40

    static func consignes(pour membre: Membre, elements: [ElementListe], maintenant: Date = .now) -> String {
        let elements = elements.filter { $0.supprimeLe == nil }
        let date = maintenant.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(.jublo))
        var lignes = [
            "Tu es l'assistant de Jublo, l'application que partagent \(membre.prenom) et \(membre.autre.prenom), un couple.",
            "Tu parles avec \(membre.prenom) : « tu » désigne \(membre.prenom), et \(membre.autre.prenom) est son ou sa partenaire.",
            "Réponds en français, brièvement et chaleureusement. Appuie-toi sur les listes ci-dessous sans inventer d'éléments ; si une information manque, dis-le.",
            "Nous sommes le \(date).",
        ]
        for type in TypeListe.allCases where type != .wishList {
            lignes += section(type.titre, elements.filter { $0.type == type })
        }
        for destinataire in [membre, membre.autre] {
            let envies = elements.filter { $0.type == .wishList && $0.destinataire == destinataire }
            lignes += section("Wish list de \(destinataire.prenom)", envies)
        }
        return lignes.joined(separator: "\n")
    }

    private static func section(_ titre: String, _ elements: [ElementListe]) -> [String] {
        var lignes = ["", "## \(titre)"]
        guard !elements.isEmpty else { return lignes + ["(vide)"] }
        let aFaire = elements.filter { !$0.estCoche }.sorted { $0.creeLe > $1.creeLe }
        let faits = elements.filter(\.estCoche).sorted { ($0.cocheLe ?? $0.creeLe) > ($1.cocheLe ?? $1.creeLe) }
        if !aFaire.isEmpty {
            lignes.append("À faire :")
            lignes += puces(aFaire) { "ajouté par \(prenom($0.auteurId))" }
        }
        if !faits.isEmpty {
            lignes.append("Fait :")
            lignes += puces(faits) { "coché par \(prenom($0.cochePar))" }
        }
        return lignes
    }

    private static func puces(_ elements: [ElementListe], detail: (ElementListe) -> String) -> [String] {
        var lignes = elements.prefix(maxParSection).map { "- \($0.titre) (\(detail($0)))" }
        if elements.count > maxParSection {
            lignes.append("… et \(elements.count - maxParSection) autres")
        }
        return lignes
    }

    private static func prenom(_ id: String?) -> String {
        id.flatMap(Membre.init(rawValue:))?.prenom ?? "quelqu'un"
    }
}
