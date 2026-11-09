/// Les deux membres du couple. `rawValue` est la valeur stockée dans `auteurId`,
/// `supprimePar`, `cochePar`…
enum Membre: String, CaseIterable, Identifiable, Codable {
    case pablo
    case julie

    var id: Self { self }

    var prenom: String {
        switch self {
        case .pablo: "Pablo"
        case .julie: "Julie"
        }
    }

    var initiale: String { String(prenom.prefix(1)) }

    var autre: Membre {
        switch self {
        case .pablo: .julie
        case .julie: .pablo
        }
    }
}
